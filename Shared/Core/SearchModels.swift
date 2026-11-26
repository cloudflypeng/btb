import Foundation

enum SearchTab: String, CaseIterable, Identifiable {
    case all
    case video
    case user
    case media
    case live
    case article

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "综合"
        case .video: return "视频"
        case .user: return "用户"
        case .media: return "番剧"
        case .live: return "直播"
        case .article: return "专栏"
        }
    }
}

enum SearchMediaKind: String, CaseIterable, Identifiable {
    case bangumi
    case film

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bangumi: return "番剧"
        case .film: return "影视"
        }
    }

    var searchType: String {
        switch self {
        case .bangumi: return "media_bangumi"
        case .film: return "media_ft"
        }
    }
}

struct SearchFilterOption: Identifiable, Hashable {
    let id: String
    let title: String
}

enum SearchFilterCatalog {
    static let orders = [
        SearchFilterOption(id: "totalrank", title: "综合排序"),
        SearchFilterOption(id: "click", title: "最多播放"),
        SearchFilterOption(id: "pubdate", title: "最新发布"),
        SearchFilterOption(id: "dm", title: "最多弹幕"),
        SearchFilterOption(id: "stow", title: "最多收藏"),
    ]

    static let durations = [
        SearchFilterOption(id: "", title: "全部时长"),
        SearchFilterOption(id: "1", title: "10 分钟以下"),
        SearchFilterOption(id: "2", title: "10-30 分钟"),
        SearchFilterOption(id: "3", title: "30-60 分钟"),
        SearchFilterOption(id: "4", title: "60 分钟以上"),
    ]

    static let partitions = [
        SearchFilterOption(id: "", title: "全部分区"),
        SearchFilterOption(id: "1", title: "动画"),
        SearchFilterOption(id: "4", title: "游戏"),
        SearchFilterOption(id: "36", title: "知识"),
        SearchFilterOption(id: "188", title: "科技"),
        SearchFilterOption(id: "160", title: "生活"),
        SearchFilterOption(id: "181", title: "影视"),
        SearchFilterOption(id: "5", title: "娱乐"),
        SearchFilterOption(id: "3", title: "音乐"),
        SearchFilterOption(id: "129", title: "舞蹈"),
        SearchFilterOption(id: "119", title: "鬼畜"),
        SearchFilterOption(id: "211", title: "美食"),
    ]

    static func title(_ options: [SearchFilterOption], for id: String) -> String {
        options.first(where: { $0.id == id })?.title ?? options.first?.title ?? ""
    }
}

struct SearchPageData<T: Decodable>: Decodable {
    var result: [T]?
    var numResults: Int?
    var numPages: Int?
    var vVoucher: String?

    enum CodingKeys: String, CodingKey {
        case result
        case numResults
        case numPages
        case vVoucher = "v_voucher"
    }
}

struct SearchAllData: Decodable {
    var result: [SearchAllGroup]?
    var numResults: Int?
    var vVoucher: String?

    enum CodingKeys: String, CodingKey {
        case result
        case numResults
        case vVoucher = "v_voucher"
    }
}

struct SearchAllGroup: Decodable {
    var resultType: String
    var data: JSONValue?

    enum CodingKeys: String, CodingKey {
        case resultType = "result_type"
        case data
    }
}

struct SearchUserOfficial: Decodable, Hashable {
    let type: Int?
    let desc: String?
}

struct SearchUser: Decodable, Identifiable, Hashable {
    let mid: Int64
    let uname: String
    let upic: String?
    let fans: Int?
    let videos: Int?
    let level: Int?
    let sign: String?
    let official: SearchUserOfficial?
    let isLive: Int?
    let roomID: Int64?

    enum CodingKeys: String, CodingKey {
        case mid
        case uname
        case upic
        case fans
        case videos
        case level
        case sign = "usign"
        case official = "official_verify"
        case isLive = "is_live"
        case roomID = "room_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mid = try container.decodeIfPresent(Int64.self, forKey: .mid) ?? 0
        uname = (try container.decodeIfPresent(String.self, forKey: .uname) ?? "").strippingSearchMarkup()
        upic = try container.decodeIfPresent(String.self, forKey: .upic)
        fans = try container.decodeIfPresent(Int.self, forKey: .fans)
        videos = try container.decodeIfPresent(Int.self, forKey: .videos)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        sign = try container.decodeIfPresent(String.self, forKey: .sign)?.strippingSearchMarkup()
        official = try container.decodeIfPresent(SearchUserOfficial.self, forKey: .official)
        isLive = try container.decodeIfPresent(Int.self, forKey: .isLive)
        roomID = try container.decodeIfPresent(Int64.self, forKey: .roomID)
    }

    var id: Int64 { mid }
    var avatarURL: URL? { MediaURL.normalize(upic) }
    var isLiveNow: Bool { (isLive ?? 0) == 1 }

    var detailText: String {
        if let desc = official?.desc?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            return desc
        }
        return sign ?? ""
    }

    var statsText: String {
        var parts: [String] = []
        if let fans, fans > 0 {
            parts.append("\(SearchFormat.count(fans))粉丝")
        }
        if let videos, videos > 0 {
            parts.append("\(SearchFormat.count(videos))个视频")
        }
        return parts.joined(separator: " · ")
    }
}

struct SearchMediaBadge: Decodable, Hashable {
    let text: String?
}

struct SearchMediaScore: Decodable, Hashable {
    let score: Double?
    let userCount: Int?

    enum CodingKeys: String, CodingKey {
        case score
        case userCount = "user_count"
    }
}

struct SearchMedia: Decodable, Identifiable, Hashable {
    let seasonID: Int64
    let mediaID: Int64?
    let title: String
    let cover: String?
    let desc: String?
    let areas: String?
    let epSize: Int?
    let indexShow: String?
    let seasonTypeName: String?
    let score: SearchMediaScore?
    let badges: [SearchMediaBadge]?
    let gotoURL: String?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case pgcSeasonID = "pgc_season_id"
        case mediaID = "media_id"
        case title
        case cover
        case desc
        case areas
        case epSize = "ep_size"
        case indexShow = "index_show"
        case seasonTypeName = "season_type_name"
        case score = "media_score"
        case badges
        case gotoURL = "goto_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let direct = try container.decodeIfPresent(Int64.self, forKey: .seasonID) ?? 0
        let fallback = try container.decodeIfPresent(Int64.self, forKey: .pgcSeasonID) ?? 0
        seasonID = direct > 0 ? direct : fallback
        mediaID = try container.decodeIfPresent(Int64.self, forKey: .mediaID)
        title = (try container.decodeIfPresent(String.self, forKey: .title) ?? "").strippingSearchMarkup()
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        desc = try container.decodeIfPresent(String.self, forKey: .desc)?.strippingSearchMarkup()
        areas = try container.decodeIfPresent(String.self, forKey: .areas)
        epSize = try container.decodeIfPresent(Int.self, forKey: .epSize)
        indexShow = try container.decodeIfPresent(String.self, forKey: .indexShow)
        seasonTypeName = try container.decodeIfPresent(String.self, forKey: .seasonTypeName)
        score = try container.decodeIfPresent(SearchMediaScore.self, forKey: .score)
        badges = try container.decodeIfPresent([SearchMediaBadge].self, forKey: .badges)
        gotoURL = try container.decodeIfPresent(String.self, forKey: .gotoURL)
    }

    var id: Int64 { seasonID > 0 ? seasonID : (mediaID ?? 0) }
    var coverURL: URL? { MediaURL.normalize(cover) }
    var badgeText: String? { badges?.compactMap(\.text).first(where: { !$0.isEmpty }) }

    var scoreText: String {
        guard let value = score?.score, value > 0 else { return "暂无评分" }
        return String(format: "%.1f", value)
    }

    var infoText: String {
        var parts: [String] = []
        if let seasonTypeName, !seasonTypeName.isEmpty {
            parts.append(seasonTypeName)
        }
        if let areas, !areas.isEmpty {
            parts.append(areas)
        }
        if let indexShow, !indexShow.isEmpty {
            parts.append(indexShow)
        }
        if parts.isEmpty, let epSize, epSize > 0 {
            parts.append("全 \(epSize) 话")
        }
        return parts.joined(separator: " · ")
    }

    var pageURL: URL? {
        if let gotoURL, let url = URL(string: gotoURL), !gotoURL.isEmpty {
            return url
        }
        guard seasonID > 0 else { return nil }
        return URL(string: "https://www.bilibili.com/bangumi/play/ss\(seasonID)")
    }
}

struct SearchLiveRoom: Decodable, Identifiable, Hashable {
    let roomID: Int64
    let uid: Int64?
    let title: String
    let uname: String
    let uface: String?
    let cover: String?
    let pic: String?
    let online: Int?
    let attentions: Int?
    let areaID: Int?
    let liveStatus: Int?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case roomID = "roomid"
        case uid
        case title
        case uname
        case uface
        case cover
        case pic
        case online
        case attentions
        case areaID = "area"
        case liveStatus = "live_status"
        case categoryName = "cate_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decodeIfPresent(Int64.self, forKey: .roomID) ?? 0
        uid = try container.decodeIfPresent(Int64.self, forKey: .uid)
        title = (try container.decodeIfPresent(String.self, forKey: .title) ?? "").strippingSearchMarkup()
        uname = (try container.decodeIfPresent(String.self, forKey: .uname) ?? "").strippingSearchMarkup()
        uface = try container.decodeIfPresent(String.self, forKey: .uface)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        pic = try container.decodeIfPresent(String.self, forKey: .pic)
        online = try container.decodeIfPresent(Int.self, forKey: .online)
        attentions = try container.decodeIfPresent(Int.self, forKey: .attentions)
        areaID = try container.decodeIfPresent(Int.self, forKey: .areaID)
        liveStatus = try container.decodeIfPresent(Int.self, forKey: .liveStatus)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)?.strippingSearchMarkup()
    }

    var id: Int64 { roomID }
    var coverURL: URL? { MediaURL.normalize(cover ?? pic) }
}

extension LiveRoom {
    init?(search room: SearchLiveRoom) {
        guard room.roomID > 0 else { return nil }
        self.init(raw: LiveRoomRaw(
            roomid: room.roomID,
            uid: room.uid,
            uname: room.uname,
            face: room.uface,
            roomCover: room.cover ?? room.pic,
            title: room.title,
            areaName: room.categoryName,
            areaNameV2: nil,
            parentAreaID: room.areaID,
            liveStatus: room.liveStatus,
            textSmall: room.online.flatMap { $0 > 0 ? SearchFormat.count($0) + "人气" : nil },
            isAttention: 0
        ))
    }
}

struct SearchArticle: Decodable, Identifiable, Hashable {
    let articleID: Int64
    let title: String
    let desc: String?
    let imageURLs: [String]?
    let author: String?
    let mid: Int64?
    let view: Int?
    let like: Int?
    let reply: Int?
    let publishTime: Int64?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case articleID = "id"
        case title
        case desc
        case imageURLs = "image_urls"
        case author
        case mid
        case view
        case like
        case reply
        case publishTime = "pub_time"
        case categoryName = "category_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        articleID = try container.decodeIfPresent(Int64.self, forKey: .articleID) ?? 0
        title = (try container.decodeIfPresent(String.self, forKey: .title) ?? "").strippingSearchMarkup()
        desc = try container.decodeIfPresent(String.self, forKey: .desc)?.strippingSearchMarkup()
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
        author = try container.decodeIfPresent(String.self, forKey: .author)?.strippingSearchMarkup()
        mid = try container.decodeIfPresent(Int64.self, forKey: .mid)
        view = try container.decodeIfPresent(Int.self, forKey: .view)
        like = try container.decodeIfPresent(Int.self, forKey: .like)
        reply = try container.decodeIfPresent(Int.self, forKey: .reply)
        publishTime = try container.decodeIfPresent(Int64.self, forKey: .publishTime)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
    }

    var id: Int64 { articleID }
    var coverURL: URL? { MediaURL.normalize(imageURLs?.first) }
    var pageURL: URL { URL(string: "https://www.bilibili.com/read/cv\(articleID)")! }

    var publishedText: String {
        guard let publishTime, publishTime > 0 else { return "" }
        return Date(timeIntervalSince1970: TimeInterval(publishTime))
            .formatted(date: .abbreviated, time: .omitted)
    }

    var statsText: String {
        var parts: [String] = []
        if let view, view > 0 {
            parts.append("\(SearchFormat.count(view))阅读")
        }
        if let reply, reply > 0 {
            parts.append("\(SearchFormat.count(reply))评论")
        }
        return parts.joined(separator: " · ")
    }
}

struct SearchHotWord: Decodable, Identifiable, Hashable {
    let keyword: String?
    let showName: String?
    let icon: String?
    let hotID: Int64?

    enum CodingKeys: String, CodingKey {
        case keyword
        case showName = "show_name"
        case icon
        case hotID = "hot_id"
    }

    var display: String {
        let name = (showName ?? keyword ?? "").strippingSearchMarkup()
        return name
    }

    var id: String {
        if let hotID, hotID > 0 {
            return String(hotID)
        }
        return display
    }
}

struct SearchHotPayload: Decodable {
    struct DataBlock: Decodable {
        let list: [SearchHotWord]?
    }

    let code: Int?
    let data: DataBlock?
}

struct SearchSuggestItem: Decodable, Identifiable, Hashable {
    let name: String?
    let term: String?
    let value: String?

    var display: String {
        (name ?? value ?? term ?? "").strippingSearchMarkup()
    }

    var query: String {
        let value = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { return value }
        let term = (term ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? display : term
    }

    var id: String { query }
}

struct SearchSuggestPayload: Decodable {
    struct DataBlock: Decodable {
        let result: ResultBlock?
    }

    struct ResultBlock: Decodable {
        let tag: [SearchSuggestItem]?
    }

    let code: Int?
    let data: DataBlock?
}

struct SearchAllResult {
    var videos: [VideoItem] = []
    var bangumi: [SearchMedia] = []
    var films: [SearchMedia] = []
    var users: [SearchUser] = []
    var liveRooms: [SearchLiveRoom] = []
    var articles: [SearchArticle] = []
    var total = 0

    var isEmpty: Bool {
        videos.isEmpty && bangumi.isEmpty && films.isEmpty && users.isEmpty
            && liveRooms.isEmpty && articles.isEmpty
    }
}

struct SearchChunk {
    var videos: [VideoItem] = []
    var users: [SearchUser] = []
    var media: [SearchMedia] = []
    var liveRooms: [SearchLiveRoom] = []
    var articles: [SearchArticle] = []
    var total = 0
    var numPages = 0
    var page = 1
    var pageSize = 20

    var itemCount: Int {
        videos.count + users.count + media.count + liveRooms.count + articles.count
    }

    var isEmpty: Bool { itemCount == 0 }

    var hasMore: Bool {
        if numPages > 0 {
            return page < numPages
        }
        return itemCount >= pageSize
    }
}

enum SearchFormat {
    static func count(_ value: Int?) -> String {
        guard let value, value > 0 else { return "0" }
        let number = Double(value)
        if number >= 100_000_000 {
            return String(format: "%.1f亿", number / 100_000_000)
        }
        if number >= 10_000 {
            return String(format: "%.1f万", number / 10_000)
        }
        return "\(value)"
    }
}

extension String {
    func strippingSearchMarkup() -> String {
        var value = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
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
}
