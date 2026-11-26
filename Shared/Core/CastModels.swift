import Foundation

/// A DLNA renderer as reported by `cast.discover` (the TV's SSDP description).
struct CastDeviceInfo: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let model: String?
    let manufacturer: String?
    let host: String?
    let location: String?
    let avTransportURL: String

    var subtitle: String {
        let parts = [model, manufacturer]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let text = Array(Set(parts)).joined(separator: " · ")
        return text.isEmpty ? (host ?? "") : text
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case model
        case manufacturer
        case host
        case location
        case avTransportURL = "av_transport_url"
    }
}

struct CastDevicesResponse: Decodable {
    let devices: [CastDeviceInfo]
}

/// Reply to `cast.play`. `mode == "direct"` means the TV pulls the stream from
/// Bilibili itself; `"proxy"` means it plays through the core on this phone.
struct CastPlayResult: Decodable {
    let playing: Bool
    let mode: String?
    let kind: String?
    let title: String?
    let message: String?
    let sessionID: String?
    let playbackURL: String?
    let device: CastDeviceInfo?

    enum CodingKeys: String, CodingKey {
        case playing
        case mode
        case kind
        case title
        case message
        case device
        case sessionID = "session_id"
        case playbackURL = "playback_url"
    }
}
