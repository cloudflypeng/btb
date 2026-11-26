import Foundation

actor HTTPCoreClient: CoreTransport {
    private let endpoint: URL
    private let eventsEndpoint: URL
    private let token: String?
    private let session: URLSession
    private var nextID = 1
    private var eventTask: Task<Void, Never>?
    private var lastEventSeq: UInt64 = 0

    private nonisolated let eventStream: AsyncStream<CoreEvent>
    private nonisolated let eventContinuation: AsyncStream<CoreEvent>.Continuation

    init() {
        let configured = ProcessInfo.processInfo.environment["BBCORE_HTTP_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = (configured?.isEmpty == false ? configured! : "http://127.0.0.1:8787")
        let base = URL(string: raw) ?? URL(string: "http://127.0.0.1:8787")!
        endpoint = base
        eventsEndpoint = base.appendingPathComponent("events")

        let configuredToken = ProcessInfo.processInfo.environment["BBCORE_HTTP_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        token = (configuredToken?.isEmpty == false) ? configuredToken : nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)

        let (stream, continuation) = AsyncStream<CoreEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1024)
        )
        eventStream = stream
        eventContinuation = continuation
    }

    nonisolated func events() -> AsyncStream<CoreEvent> {
        eventStream
    }

    func start() async throws {
        guard eventTask == nil else { return }
        eventTask = Task { [weak self] in
            await self?.runEventStream()
        }
    }

    func stop() async {
        eventTask?.cancel()
        eventTask = nil
        lastEventSeq = 0
    }

    func call(_ method: String, params: [String: JSONValue] = [:]) async throws -> JSONValue {
        let id = nextID
        nextID += 1
        let payload = try JSONEncoder().encode(
            RPCRequest(jsonrpc: "2.0", id: id, method: method, params: .object(params))
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = payload

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw BBCoreError.connection("核心服务返回异常状态")
            }
            guard let decoded = try? JSONDecoder().decode(RPCResponse.self, from: data) else {
                throw BBCoreError.invalidResponse
            }
            if let error = decoded.error {
                throw BBCoreError.rpc(code: error.code, message: error.message)
            }
            return decoded.result ?? .null
        } catch let error as BBCoreError {
            throw error
        } catch {
            throw BBCoreError.connection(error.localizedDescription)
        }
    }

    private func runEventStream() async {
        var backoff: UInt64 = 1
        while !Task.isCancelled {
            do {
                try await streamEvents()
                backoff = 1
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: backoff * 1_000_000_000)
            backoff = min(backoff * 2, 15)
        }
    }

    private func streamEvents() async throws {
        var components = URLComponents(url: eventsEndpoint, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []
        query.append(URLQueryItem(name: "since", value: String(lastEventSeq)))
        components?.queryItems = query
        guard let url = components?.url else {
            throw BBCoreError.connection("事件地址无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BBCoreError.connection("事件流返回异常状态")
        }

        var dataLines: [String] = []
        var eventID: UInt64 = 0
        for try await line in bytes.lines {
            if Task.isCancelled { return }

            if line.isEmpty {
                if !dataLines.isEmpty {
                    decodeEvent(dataLines.joined(separator: "\n"), fallbackSeq: eventID)
                    dataLines.removeAll(keepingCapacity: true)
                }
                eventID = 0
                continue
            }
            if line.hasPrefix("data:") {
                var value = String(line.dropFirst(5))
                if value.hasPrefix(" ") {
                    value.removeFirst()
                }
                dataLines.append(value)
                // bbcore emits one data line per event; AsyncLineSequence drops
                // the blank separator, so flush as soon as the payload arrives.
                decodeEvent(dataLines.joined(separator: "\n"), fallbackSeq: eventID)
                dataLines.removeAll(keepingCapacity: true)
                eventID = 0
            } else if line.hasPrefix("id:") {
                let raw = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                eventID = UInt64(raw) ?? 0
            }
        }
    }

    private func decodeEvent(_ payload: String, fallbackSeq: UInt64) {
        guard let data = payload.data(using: .utf8),
              let notification = try? JSONDecoder().decode(CoreNotification.self, from: data),
              let event = notification.coreEvent() else { return }

        let seq = event.seq > 0 ? event.seq : fallbackSeq
        if seq > lastEventSeq {
            lastEventSeq = seq
        }
        eventContinuation.yield(event)
    }
}
