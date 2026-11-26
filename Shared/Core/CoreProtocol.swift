import Foundation

enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case integer(Int64)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var intValue: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .integer(let value): return Int(value)
        default: return nil
        }
    }

    var int64Value: Int64? {
        switch self {
        case .number(let value): return Int64(value)
        case .integer(let value): return value
        default: return nil
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

enum BBCoreError: LocalizedError {
    case notStarted
    case coreNotFound
    case launchFailed(String)
    case writeFailed(String)
    case invalidResponse
    case coreExited
    case connection(String)
    case rpc(code: Int, message: String)
    case upstream(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notStarted:
            return "核心服务尚未启动"
        case .coreNotFound:
            return "找不到 bbcore 可执行文件，请先运行 make core"
        case .launchFailed(let message):
            return "无法启动 bbcore：\(message)"
        case .writeFailed(let message):
            return "向核心写入请求失败：\(message)"
        case .invalidResponse:
            return "核心返回了无法识别的响应"
        case .coreExited:
            return "核心服务已退出"
        case .connection(let message):
            return "无法连接核心服务：\(message)"
        case .rpc(let code, let message):
            return "核心错误 \(code)：\(message)"
        case .upstream(let code, let message):
            return "B 站接口错误 \(code)：\(message)"
        }
    }
}

struct RPCRequest: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: JSONValue
}

struct RPCResponse: Decodable {
    let id: Int?
    let result: JSONValue?
    let error: RPCErrorPayload?

    struct RPCErrorPayload: Decodable {
        let code: Int
        let message: String
    }
}

enum CoreCoding {
    static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

protocol CoreTransport: Sendable {
    func start() async throws
    func stop() async
    func call(_ method: String, params: [String: JSONValue]) async throws -> JSONValue
    func events() -> AsyncStream<CoreEvent>
}

extension CoreTransport {
    func call(_ method: String) async throws -> JSONValue {
        try await call(method, params: [:])
    }

    func events() -> AsyncStream<CoreEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func capabilities() async throws -> CoreCapabilities {
        let value = try await call("core.capabilities")
        return try CoreCoding.decode(CoreCapabilities.self, from: value)
    }
}
