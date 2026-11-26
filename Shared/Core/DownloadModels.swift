import Foundation

struct DownloadJob: Decodable, Identifiable, Hashable {
    let id: String
    let bvid: String
    let cid: Int64?
    let title: String
    let cover: String?
    let owner: String?
    let qn: Int?
    let codec: String?
    let audioID: Int?
    let durationMS: Int64?
    let status: String
    let error: String?
    let downloadedBytes: Int64
    let totalBytes: Int64
    let hasAudio: Bool
    let createdAt: Int64
    let updatedAt: Int64?
    let finishedAt: Int64?
    let masterURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bvid
        case cid
        case title
        case cover
        case owner
        case qn
        case codec
        case audioID = "audio_id"
        case durationMS = "duration_ms"
        case status
        case error
        case downloadedBytes = "downloaded_bytes"
        case totalBytes = "total_bytes"
        case hasAudio = "has_audio"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case finishedAt = "finished_at"
        case masterURL = "master_url"
    }

    var isCompleted: Bool { status == "completed" }
    var isDownloading: Bool { status == "downloading" || status == "queued" }
    var isPaused: Bool { status == "paused" }
    var isFailed: Bool { status == "failed" }

    var progress: Double {
        if isCompleted { return 1 }
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(downloadedBytes) / Double(totalBytes)))
    }

    var coverURL: URL? { MediaURL.normalize(cover) }

    var videoItem: VideoItem {
        VideoItem(download: self)
    }

    var statusText: String {
        switch status {
        case "queued": return "等待下载"
        case "downloading": return "下载中 \(Int(progress * 100))%"
        case "paused": return "已暂停"
        case "completed": return "已完成"
        case "failed": return "下载失败"
        default: return status
        }
    }

    var qualityText: String {
        let label = Self.qualityLabel(qn ?? 80)
        let codecName = (codec ?? "hevc").lowercased() == "avc" ? "AVC" : "HEVC"
        return "\(label) · \(codecName)"
    }

    var sizeText: String {
        Self.byteText(totalBytes > 0 ? totalBytes : downloadedBytes)
    }

    var downloadedText: String {
        "\(Self.byteText(downloadedBytes)) / \(Self.byteText(totalBytes))"
    }

    var durationText: String {
        guard let durationMS, durationMS > 0 else { return "" }
        let total = Int(durationMS / 1000)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func byteText(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }

    static func qualityLabel(_ qn: Int) -> String {
        switch qn {
        case 127: return "8K"
        case 126: return "杜比视界"
        case 125: return "HDR"
        case 120: return "4K"
        case 116: return "1080P60"
        case 112: return "1080P+"
        case 80: return "1080P"
        case 74: return "720P60"
        case 64: return "720P"
        case 32: return "480P"
        case 16: return "360P"
        default: return "QN\(qn)"
        }
    }
}

struct DownloadListResult: Decodable {
    let items: [DownloadJob]?
    let usedBytes: Int64?
    let freeBytes: Int64?
    let diskBytes: Int64?

    enum CodingKeys: String, CodingKey {
        case items
        case usedBytes = "used_bytes"
        case freeBytes = "free_bytes"
        case diskBytes = "disk_bytes"
    }
}

struct DownloadURLResult: Decodable {
    let masterURL: String
    let durationMS: Int64?

    enum CodingKeys: String, CodingKey {
        case masterURL = "master_url"
        case durationMS = "duration_ms"
    }
}

struct DownloadConfigResult: Decodable {
    let concurrency: Int?
    let limitKbps: Int64?
    let downloadDir: String?

    enum CodingKeys: String, CodingKey {
        case concurrency
        case limitKbps = "limit_kbps"
        case downloadDir = "download_dir"
    }
}

struct LocalPlaybackSource: Hashable {
    let masterURL: URL
    let durationMS: Int64?
}
