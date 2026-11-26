import Foundation

actor BBCoreClient: CoreTransport {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var readTask: Task<Void, Never>?
    private var pending: [Int: CheckedContinuation<RPCResponse, Error>] = [:]
    private var nextID = 1

    private nonisolated let eventStream: AsyncStream<CoreEvent>
    private nonisolated let eventContinuation: AsyncStream<CoreEvent>.Continuation

    init() {
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
        guard process == nil else { return }

        let binaryPath = Self.resolveCoreBinary()
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw BBCoreError.coreNotFound
        }
        let dataDirectory = try Self.prepareDataDirectory()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--data-dir", dataDirectory.path]
        process.currentDirectoryURL = dataDirectory

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination() }
        }

        do {
            try process.run()
        } catch {
            throw BBCoreError.launchFailed(error.localizedDescription)
        }

        self.process = process
        stdinHandle = stdinPipe.fileHandleForWriting

        Task.detached(priority: .utility) { [stderrHandle = stderrPipe.fileHandleForReading] in
            while true {
                let data = try? stderrHandle.read(upToCount: 4096)
                if data == nil || data?.isEmpty == true { break }
            }
        }

        readTask = Task { [stdoutHandle = stdoutPipe.fileHandleForReading] in
            do {
                for try await line in stdoutHandle.bytes.lines {
                    self.handleLine(line)
                }
            } catch {
                // The stream ends when the child process exits.
            }
            self.handleTermination()
        }
    }

    func stop() async {
        readTask?.cancel()
        readTask = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdinHandle = nil
        failAllPending(BBCoreError.coreExited)
    }

    func call(_ method: String, params: [String: JSONValue] = [:]) async throws -> JSONValue {
        let result = try await send(method: method, params: .object(params))
        return result ?? .null
    }

    private func send(method: String, params: JSONValue) async throws -> JSONValue? {
        guard let stdinHandle, process?.isRunning == true else {
            throw BBCoreError.notStarted
        }

        let id = nextID
        nextID += 1
        var payload = try JSONEncoder().encode(RPCRequest(jsonrpc: "2.0", id: id, method: method, params: params))
        payload.append(0x0A)

        let response: RPCResponse = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            do {
                try stdinHandle.write(contentsOf: payload)
            } catch {
                pending.removeValue(forKey: id)
                continuation.resume(throwing: BBCoreError.writeFailed(error.localizedDescription))
            }
        }

        if let error = response.error {
            throw BBCoreError.rpc(code: error.code, message: error.message)
        }
        return response.result
    }

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        if let response = try? JSONDecoder().decode(RPCResponse.self, from: data),
           let id = response.id,
           let continuation = pending.removeValue(forKey: id) {
            continuation.resume(returning: response)
            return
        }

        if let notification = try? JSONDecoder().decode(CoreNotification.self, from: data),
           let event = notification.coreEvent() {
            eventContinuation.yield(event)
        }
    }

    private func handleTermination() {
        guard process != nil || !pending.isEmpty else { return }
        process = nil
        stdinHandle = nil
        failAllPending(BBCoreError.coreExited)
    }

    private func failAllPending(_ error: Error) {
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    private static func prepareDataDirectory() throws -> URL {
        let manager = FileManager.default
        if let raw = ProcessInfo.processInfo.environment["BBCORE_DATA_DIR"], !raw.isEmpty {
            let url = URL(fileURLWithPath: raw, isDirectory: true)
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dataDirectory = support.appendingPathComponent("BTB", isDirectory: true).appendingPathComponent("core", isDirectory: true)
        try manager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        return dataDirectory
    }

    private static func resolveCoreBinary() -> String {
        let manager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let raw = environment["BBCORE_BIN"], !raw.isEmpty {
            return URL(fileURLWithPath: raw).path
        }
        if let bundled = Bundle.main.url(forResource: "bbcore", withExtension: nil),
           manager.isExecutableFile(atPath: bundled.path) {
            return bundled.path
        }
        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/bbcore")
        if manager.isExecutableFile(atPath: fallback.path) {
            return fallback.path
        }

        let currentDirectory = URL(fileURLWithPath: manager.currentDirectoryPath, isDirectory: true)
        var directory = currentDirectory
        for _ in 0..<5 {
            let candidate = directory.appendingPathComponent("bbcore/bbcore")
            if manager.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
            directory.deleteLastPathComponent()
        }
        return currentDirectory.appendingPathComponent("../bbcore/bbcore").standardizedFileURL.path
    }
}
