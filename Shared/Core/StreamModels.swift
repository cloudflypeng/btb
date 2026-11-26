import Foundation

struct StreamSession: Decodable {
    let sessionID: String
    let masterURL: String
    let expiresAt: Int64?
    let durationMS: Int64?
    let video: StreamTrackInfo?
    let audio: StreamTrackInfo?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case masterURL = "master_url"
        case expiresAt = "expires_at"
        case durationMS = "duration_ms"
        case video
        case audio
    }

    var playbackURL: URL? { URL(string: masterURL) }
}

struct StreamTrackInfo: Decodable {
    let id: Int?
    let codecid: Int?
    let codecs: String?
    let width: Int?
    let height: Int?
    let bandwidth: Int?
    let segments: Int?
}
