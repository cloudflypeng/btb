import Foundation

struct CoreEvent: Sendable {
    let topic: String
    let seq: UInt64
    let timestamp: Int64
    let data: JSONValue

    var method: String { "event." + topic }
}

struct CoreNotification: Decodable {
    let method: String
    let params: JSONValue?

    func coreEvent() -> CoreEvent? {
        guard method.hasPrefix("event.") else { return nil }
        let topic = String(method.dropFirst("event.".count))
        guard !topic.isEmpty else { return nil }

        if let object = params?.objectValue,
           let seq = object["seq"]?.int64Value,
           let data = object["data"] {
            return CoreEvent(
                topic: topic,
                seq: UInt64(max(0, seq)),
                timestamp: object["ts"]?.int64Value ?? 0,
                data: data
            )
        }

        return CoreEvent(topic: topic, seq: 0, timestamp: 0, data: params ?? .null)
    }
}

struct CoreCapabilities: Decodable, Sendable {
    let name: String?
    let version: String?
    let protocolVersion: Int?
    let eventProtocol: Int?
    let methods: Int?
    let endpoints: Int?
    let events: [String]?
    let features: [String: Bool]?

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case protocolVersion = "protocol"
        case eventProtocol = "event_protocol"
        case methods
        case endpoints
        case events
        case features
    }

    func supports(_ feature: String) -> Bool {
        features?[feature] ?? false
    }
}
