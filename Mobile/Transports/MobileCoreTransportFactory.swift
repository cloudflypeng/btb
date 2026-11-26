import Foundation

enum MobileCoreTransportFactory {
    static func make() -> any CoreTransport {
#if DEBUG
        let debugEndpoint = ProcessInfo.processInfo.environment["BBCORE_HTTP_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let debugEndpoint, !debugEndpoint.isEmpty {
            return HTTPCoreClient()
        }
#endif
#if canImport(BTBCore)
        return EmbeddedTransport()
#else
        return HTTPCoreClient()
#endif
    }
}
