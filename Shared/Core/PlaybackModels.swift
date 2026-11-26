import Foundation

struct PlaybackPage: Decodable, Identifiable, Hashable {
    let page: Int
    let cid: Int64
    let part: String?
    let durationMS: Int64?

    var id: Int64 { cid }

    enum CodingKeys: String, CodingKey {
        case page
        case cid
        case part
        case durationMS = "duration_ms"
    }
}

struct PlaybackQuality: Decodable, Identifiable, Hashable {
    let qn: Int64
    let label: String?
    let codecid: Int?
    let codec: String?
    let codecs: String?
    let width: Int?
    let height: Int?
    let bandwidth: Int64?
    let frameRate: String?

    var id: String { "\(qn)-\(codec ?? "unknown")" }

    var displayLabel: String {
        let base = label ?? "QN\(qn)"
        guard let codec, codec != "unknown" else { return base }
        return "\(base) · \(codec.uppercased())"
    }

    enum CodingKeys: String, CodingKey {
        case qn
        case label
        case codecid
        case codec
        case codecs
        case width
        case height
        case bandwidth
        case frameRate = "frame_rate"
    }
}

struct PlaybackAudio: Decodable, Identifiable, Hashable {
    let id: Int
    let codecs: String?
    let bandwidth: Int64?
}

struct PlaybackSubtitle: Decodable, Identifiable, Hashable {
    let lan: String?
    let label: String?
    let url: String?
    let subtitleID: String?

    var id: String { subtitleID ?? url ?? lan ?? "unknown" }
    var displayLabel: String { label ?? lan ?? "字幕" }

    enum CodingKeys: String, CodingKey {
        case lan
        case label
        case url
        case subtitleID = "id"
    }
}

struct PlayerResolveResult: Decodable {
    let bvid: String
    let aid: Int64?
    let cid: Int64
    let page: Int?
    let title: String?
    let pageTitle: String?
    let durationMS: Int64?
    let pages: [PlaybackPage]
    let qualities: [PlaybackQuality]
    let audio: [PlaybackAudio]
    let subtitles: [PlaybackSubtitle]
    let resumeMS: Int64?
    let lastPlayCID: Int64?
    let defaultQN: Int64?
    let defaultCodec: String?
    let playable: Bool?
    let isPreview: Bool?

    var canPlay: Bool { playable ?? !qualities.isEmpty }
    var resumeSeconds: Double { Double(resumeMS ?? 0) / 1000 }

    enum CodingKeys: String, CodingKey {
        case bvid
        case aid
        case cid
        case page
        case title
        case pageTitle = "page_title"
        case durationMS = "duration_ms"
        case pages
        case qualities
        case audio
        case subtitles
        case resumeMS = "resume_ms"
        case lastPlayCID = "last_play_cid"
        case defaultQN = "default_qn"
        case defaultCodec = "default_codec"
        case playable
        case isPreview = "is_preview"
    }
}

extension PlayerResolveResult {
    /// The rendition a new playback should start with: the highest quality at
    /// or below the user's ceiling, preferring their codec.
    ///
    /// Shared by the player and the touch-down prewarm, which must agree — a
    /// mismatch means the prefetched stream is thrown away.
    func preferredQuality(defaultQN: Int64, defaultCodec: String) -> PlaybackQuality? {
        let target = min(self.defaultQN ?? defaultQN, defaultQN)
        let sorted = qualities.sorted { $0.qn > $1.qn }
        let eligible = sorted.filter { $0.qn <= target }
        let preferredCodec = self.defaultCodec ?? defaultCodec
        if let best = eligible.first {
            if let exact = eligible.first(where: { $0.qn == best.qn && $0.codec == preferredCodec }) {
                return exact
            }
            return best
        }
        return sorted.first
    }
}

struct SubtitleVTTResponse: Decodable {
    let vtt: String
    let cueCount: Int?

    enum CodingKeys: String, CodingKey {
        case vtt
        case cueCount = "cue_count"
    }
}

struct SubtitleCue: Hashable {
    let start: Double
    let end: Double
    let text: String
}

enum WebVTTParser {
    static func parse(_ source: String) -> [SubtitleCue] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []
        for block in blocks {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }
            let timing = lines[timingIndex]
            let parts = timing.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = parseTimestamp(parts[0]),
                  let end = parseTimestamp(parts[1]) else {
                continue
            }
            let text = lines[(timingIndex + 1)...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, end >= start else { continue }
            cues.append(SubtitleCue(start: start, end: end, text: stripTags(text)))
        }
        return cues.sorted { $0.start < $1.start }
    }

    private static func parseTimestamp(_ raw: String) -> Double? {
        let value = raw.trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
        let pieces = value.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard pieces.count == 2 || pieces.count == 3 else { return nil }
        let seconds = Double(pieces.last ?? "")
        let minutes = Double(pieces[pieces.count - 2])
        let hours = pieces.count == 3 ? Double(pieces[0]) : 0
        guard let seconds, let minutes, let hours else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
