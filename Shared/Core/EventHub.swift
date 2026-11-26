import Foundation
import Observation

@MainActor
@Observable
final class EventHub {
    private let transport: any CoreTransport

    private(set) var capabilities: CoreCapabilities?
    private(set) var lastSeq: UInt64 = 0

    @ObservationIgnored private var consumeTask: Task<Void, Never>?
    @ObservationIgnored private var subscriptions: [UUID: Subscription] = [:]

    private struct Subscription {
        let topics: [String]
        let continuation: AsyncStream<CoreEvent>.Continuation
    }

    init(transport: any CoreTransport) {
        self.transport = transport
    }

    func start() {
        guard consumeTask == nil else { return }
        consumeTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.transport.events() {
                if Task.isCancelled { return }
                self.receive(event)
            }
        }
    }

    func stop() {
        consumeTask?.cancel()
        consumeTask = nil
        for subscription in subscriptions.values {
            subscription.continuation.finish()
        }
        subscriptions.removeAll()
    }

    func refreshCapabilities() async {
        capabilities = try? await transport.capabilities()
    }

    func subscribe(topics: [String] = []) -> AsyncStream<CoreEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<CoreEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        subscriptions[id] = Subscription(topics: topics, continuation: continuation)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.subscriptions.removeValue(forKey: id)
            }
        }
        return stream
    }

    func supports(_ feature: String) -> Bool {
        capabilities?.supports(feature) ?? false
    }

    private func receive(_ event: CoreEvent) {
        lastSeq = max(lastSeq, event.seq)
        for subscription in subscriptions.values
        where topicMatches(subscription.topics, event.topic) {
            subscription.continuation.yield(event)
        }
    }

    private func topicMatches(_ patterns: [String], _ topic: String) -> Bool {
        if patterns.isEmpty { return true }
        for pattern in patterns {
            if pattern == "*" || pattern == topic {
                return true
            }
            if pattern.hasSuffix(".*") {
                let prefix = String(pattern.dropLast(1))
                if topic.hasPrefix(prefix) {
                    return true
                }
            }
        }
        return false
    }
}
