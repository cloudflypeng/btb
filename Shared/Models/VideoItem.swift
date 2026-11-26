import Foundation

struct VideoItem: Identifiable, Hashable, Codable {
    let bvid: String
    let aid: Int64?
    let cid: Int?
    let title: String
    let coverURL: URL?
    let ownerName: String
    let ownerFaceURL: URL?
    let ownerMid: Int64?
    let viewCount: Int
    let danmakuCount: Int
    let likeCount: Int
    let durationText: String
    let description: String
    let publishedAt: Date?
    var historyKid: String?
    var historyBusiness: String?

    var id: String { bvid }

    var pageURL: URL {
        URL(string: "https://www.bilibili.com/video/\(bvid)")!
    }

    var playerURL: URL {
        var components = URLComponents(string: "https://player.bilibili.com/player.html")!
        components.queryItems = [
            URLQueryItem(name: "bvid", value: bvid),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "high_quality", value: "1"),
            URLQueryItem(name: "danmaku", value: "1"),
            URLQueryItem(name: "autoplay", value: "1"),
        ]
        return components.url!
    }

    var viewText: String { Self.formatCount(viewCount) }
    var danmakuText: String { Self.formatCount(danmakuCount) }
    var likeText: String { Self.formatCount(likeCount) }
    var publishedText: String {
        guard let publishedAt else { return "" }
        return publishedAt.formatted(date: .abbreviated, time: .omitted)
    }
    var publishedAgoText: String {
        guard let publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
    var spaceURL: URL? {
        guard let ownerMid else { return nil }
        return URL(string: "https://space.bilibili.com/\(ownerMid)")
    }

    init?(hot video: HotVideo) {
        guard let bvid = video.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = video.aid
        cid = video.cid
        title = Self.cleanHTML(video.title)
        coverURL = MediaURL.normalize(video.pic ?? video.cover43)
        ownerName = video.owner?.name ?? "未知 UP 主"
        ownerFaceURL = MediaURL.normalize(video.owner?.face)
        ownerMid = video.owner?.mid
        viewCount = video.stat?.view ?? 0
        danmakuCount = video.stat?.danmaku ?? 0
        likeCount = video.stat?.like ?? 0
        durationText = Self.formatDuration(video.duration)
        description = Self.cleanHTML(video.desc)
        publishedAt = Self.date(video.pubdate)
    }

    /// Placeholder item for navigation by BV id; the detail page fills in the rest.
    init(bvid: String, title: String = "") {
        self.bvid = bvid
        aid = nil
        cid = nil
        self.title = title
        coverURL = nil
        ownerName = ""
        ownerFaceURL = nil
        ownerMid = nil
        viewCount = 0
        danmakuCount = 0
        likeCount = 0
        durationText = ""
        description = ""
        publishedAt = nil
    }

    init(
        dynamicVideo video: DynamicVideoAttachment,
        ownerName: String,
        ownerFaceURL: URL?,
        ownerMid: Int64?
    ) {
        bvid = video.bvid
        aid = nil
        cid = nil
        title = video.title
        coverURL = video.coverURL
        self.ownerName = ownerName
        self.ownerFaceURL = ownerFaceURL
        self.ownerMid = ownerMid
        viewCount = 0
        danmakuCount = 0
        likeCount = 0
        durationText = video.durationText
        description = video.desc
        publishedAt = nil
    }

    init?(search video: SearchVideo) {        guard let bvid = video.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = video.aid
        cid = nil
        title = Self.cleanHTML(video.title)
        coverURL = MediaURL.normalize(video.pic)
        ownerName = video.author ?? "未知 UP 主"
        ownerFaceURL = MediaURL.normalize(video.upic)
        ownerMid = nil
        viewCount = video.play ?? 0
        danmakuCount = video.danmaku ?? 0
        likeCount = 0
        durationText = video.duration?.value ?? ""
        let desc = Self.cleanHTML(video.description)
        description = desc == "-" ? "" : desc
        publishedAt = Self.date(video.pubdate)
    }

    init?(related video: RelatedVideo) {
        guard let bvid = video.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = video.aid
        cid = video.cid
        title = Self.cleanHTML(video.title)
        coverURL = MediaURL.normalize(video.pic)
        ownerName = video.owner?.name ?? "未知 UP 主"
        ownerFaceURL = MediaURL.normalize(video.owner?.face)
        ownerMid = video.owner?.mid
        viewCount = video.stat?.view ?? 0
        danmakuCount = video.stat?.danmaku ?? 0
        likeCount = video.stat?.like ?? 0
        durationText = Self.formatDuration(video.duration)
        description = Self.cleanHTML(video.desc)
        publishedAt = Self.date(video.pubdate)
    }

    init?(userVideo video: UserVideo) {
        guard let bvid = video.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = nil
        cid = nil
        title = Self.cleanHTML(video.title)
        coverURL = MediaURL.normalize(video.pic)
        ownerName = video.author ?? ""
        ownerFaceURL = nil
        ownerMid = nil
        viewCount = video.play ?? 0
        danmakuCount = video.videoReview ?? 0
        likeCount = 0
        durationText = video.length ?? ""
        description = Self.cleanHTML(video.description)
        publishedAt = Self.date(video.created)
    }

    init?(history video: UserHistoryVideo) {
        guard let bvid = video.history?.bvid ?? video.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = nil
        cid = video.history?.cid
        title = Self.cleanHTML(video.title)
        coverURL = MediaURL.normalize(video.cover)
        ownerName = video.authorName ?? ""
        ownerFaceURL = MediaURL.normalize(video.authorFace)
        ownerMid = nil
        viewCount = 0
        danmakuCount = 0
        likeCount = 0
        durationText = Self.formatDuration(video.duration)
        description = ""
        publishedAt = Self.date(video.viewAt)
        historyKid = video.kid.map(String.init)
        historyBusiness = video.history?.business
    }

    init(download job: DownloadJob) {
        bvid = job.bvid
        aid = nil
        cid = job.cid.map(Int.init)
        title = job.title
        coverURL = job.coverURL
        ownerName = job.owner ?? "未知 UP 主"
        ownerFaceURL = nil
        ownerMid = nil
        viewCount = 0
        danmakuCount = 0
        likeCount = 0
        durationText = job.durationText
        description = ""
        publishedAt = nil
    }

    init?(fav media: FavMedia) {
        guard let bvid = media.bvid, !bvid.isEmpty else { return nil }
        self.bvid = bvid
        aid = media.id
        cid = nil
        title = Self.cleanHTML(media.title)
        coverURL = MediaURL.normalize(media.cover)
        ownerName = media.upper?.name ?? "未知 UP 主"
        ownerFaceURL = MediaURL.normalize(media.upper?.face)
        ownerMid = media.upper?.mid
        viewCount = media.countInfo?.play ?? 0
        danmakuCount = media.countInfo?.danmaku ?? 0
        likeCount = 0
        durationText = Self.formatDuration(media.duration)
        description = Self.cleanHTML(media.intro)
        publishedAt = Self.date(media.pubtime)
    }

    private static func cleanHTML(_ raw: String?) -> String {
        guard var value = raw, !value.isEmpty else { return "" }
        value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " ",
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatDuration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func formatCount(_ count: Int) -> String {
        let value = Double(count)
        switch value {
        case 100_000_000...:
            return String(format: "%.1f亿", value / 100_000_000)
        case 10_000...:
            return String(format: "%.1f万", value / 10_000)
        default:
            return "\(count)"
        }
    }

    private static func date(_ timestamp: Int?) -> Date? {
        guard let timestamp, timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
