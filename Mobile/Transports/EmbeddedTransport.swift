#if os(iOS) && canImport(BTBCore)
import Foundation
import BTBCore

/// Runs bbcore inside the app process through the gomobile framework. Calls go
/// to the Go service directly; event notifications arrive on Go threads and are
/// decoded into the same stream shape as the stdio and SSE transports.
final class EmbeddedTransport: CoreTransport, @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.cloudflypeng.btb.bbcore",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let stateLock = NSLock()
    private var handler: EventBridge?
    private var running = false

    private let stream: AsyncStream<CoreEvent>
    private let continuation: AsyncStream<CoreEvent>.Continuation

    init() {
        (stream, continuation) = AsyncStream<CoreEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1024)
        )
    }

    nonisolated func events() -> AsyncStream<CoreEvent> {
        stream
    }

    func start() async throws {
        let directory = try Self.prepareDataDirectory()
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [self] in
                let bridge = EventBridge { [continuation] payload in
                    guard let event = Self.decode(payload) else { return }
                    continuation.yield(event)
                }
                MobileSetEventHandler(bridge)

                var error: NSError?
                let started = MobileStart(directory.path, &error)
                if started {
                    stateLock.lock()
                    handler = bridge
                    running = true
                    stateLock.unlock()
                    done.resume()
                    return
                }

                let message = error?.localizedDescription ?? "bbcore 启动失败"
                if message.contains("already running") {
                    stateLock.lock()
                    handler = bridge
                    running = true
                    stateLock.unlock()
                    done.resume()
                    return
                }
                MobileSetEventHandler(nil)
                done.resume(throwing: BBCoreError.launchFailed(message))
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async(flags: .barrier) { [self] in
                stateLock.lock()
                let wasRunning = running
                running = false
                handler = nil
                stateLock.unlock()
                if wasRunning {
                    MobileStop()
                    MobileSetEventHandler(nil)
                }
                done.resume()
            }
        }
    }

    func call(_ method: String, params: [String: JSONValue] = [:]) async throws -> JSONValue {
        let paramsJSON: String
        if params.isEmpty {
            paramsJSON = ""
        } else {
            let data = try JSONEncoder().encode(JSONValue.object(params))
            paramsJSON = String(decoding: data, as: UTF8.self)
        }

        let payload: String = try await withCheckedThrowingContinuation { done in
            queue.async {
                var error: NSError?
                let raw = MobileCall(method, paramsJSON, &error)
                if let error {
                    done.resume(throwing: Self.mapError(error))
                } else {
                    done.resume(returning: raw)
                }
            }
        }

        guard let data = payload.data(using: .utf8) else {
            throw BBCoreError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw BBCoreError.invalidResponse
        }
    }

    private static func mapError(_ error: NSError) -> BBCoreError {
        let message = error.localizedDescription
        if let separator = message.range(of: ": "),
           let code = Int(message[..<separator.lowerBound]) {
            return .rpc(code: code, message: String(message[separator.upperBound...]))
        }
        return .connection(message)
    }

    private static func decode(_ payload: String) -> CoreEvent? {
        guard let data = payload.data(using: .utf8),
              let notification = try? JSONDecoder().decode(CoreNotification.self, from: data) else {
            return nil
        }
        return notification.coreEvent()
    }

    private static func prepareDataDirectory() throws -> URL {
        let manager = FileManager.default
        let directory: URL
#if DEBUG
        let override = ProcessInfo.processInfo.environment["BBCORE_DATA_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty {
            directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            directory = try defaultDataDirectory()
        }
#else
        directory = try defaultDataDirectory()
#endif

        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try? manager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = directory
        try? mutable.setResourceValues(values)
        return directory
    }

    private static func defaultDataDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appendingPathComponent("bbcore", isDirectory: true)
    }
}

private final class EventBridge: NSObject, MobileEventHandlerProtocol {
    private let emit: (String) -> Void

    init(emit: @escaping (String) -> Void) {
        self.emit = emit
    }

    func onEvent(_ payload: String?) {
        guard let payload, !payload.isEmpty else { return }
        emit(payload)
    }
}
#endif
