import Foundation

struct UpstreamResultResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let result: T?
}

struct AnimeTimelineEpisode: Decodable, Hashable, Identifiable {
    let seasonID: Int64
    let episodeID: Int64?
    let title: String
    let cover: String?
    let squareCover: String?
    let pubIndex: String?
    let pubTime: String?
    let published: Int?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case episodeID = "episode_id"
        case title
        case cover
        case squareCover = "square_cover"
        case pubIndex = "pub_index"
        case pubTime = "pub_time"
        case published
    }

    var id: String { "\(seasonID)-\(pubIndex ?? episodeID.map(String.init) ?? title)" }
    var coverURL: URL? { MediaURL.normalize(squareCover ?? cover) }
    var isPublished: Bool { (published ?? 1) == 1 }
}

struct AnimeTimelineDay: Decodable, Identifiable {
    let date: String
    let dayOfWeek: Int
    let isToday: Int?
    let episodes: [AnimeTimelineEpisode]

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
        case isToday = "is_today"
        case episodes
    }

    var id: String { date }
    var isTodayDay: Bool { (isToday ?? 0) == 1 }

    var weekdayTitle: String {
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let index = (dayOfWeek - 1 + 7) % 7
        return names[index]
    }
}

struct AnimeRating: Decodable, Hashable {
    let score: Double?
    let count: Int?

    var text: String {
        guard let score, score > 0 else { return "暂无评分" }
        return String(format: "%.1f", score)
    }
}

struct AnimeArea: Decodable, Hashable {
    let name: String?
}

struct AnimeNewEp: Decodable, Hashable {
    let desc: String?
    let title: String?
    let indexShow: String?

    enum CodingKeys: String, CodingKey {
        case desc
        case title
        case indexShow = "index_show"
    }
}

struct AnimeSeasonStat: Decodable, Hashable {
    let views: Int64?
    let danmakus: Int64?
    let favorites: Int64?
    let followText: String?

    enum CodingKeys: String, CodingKey {
        case views
        case danmakus
        case favorites
        case followText = "follow_text"
    }
}

struct AnimeUserStatus: Decodable, Hashable {
    let follow: Int?
    let followStatus: Int?
    let pay: Int?
    let login: Int?

    enum CodingKeys: String, CodingKey {
        case follow
        case followStatus = "follow_status"
        case pay
        case login
    }

    var isFollowing: Bool { (follow ?? 0) == 1 || (followStatus ?? 0) == 2 }
}

struct AnimePublish: Decodable, Hashable {
    let isFinish: Int?
    let isStarted: Int?
    let pubTimeShow: String?

    enum CodingKeys: String, CodingKey {
        case isFinish = "is_finish"
        case isStarted = "is_started"
        case pubTimeShow = "pub_time_show"
    }
}

struct AnimeEpisode: Decodable, Hashable, Identifiable {
    let epID: Int64
    let cid: Int64?
    let aid: Int64?
    let bvid: String?
    let title: String
    let longTitle: String?
    let showTitle: String?
    let cover: String?
    let durationMS: Int64?
    let badge: String?
    let pubTime: Int64?

    enum CodingKeys: String, CodingKey {
        case epID = "ep_id"
        case cid
        case aid
        case bvid
        case title
        case longTitle = "long_title"
        case showTitle = "show_title"
        case cover
        case durationMS = "duration"
        case durationMSAlt = "duration_ms"
        case badge
        case pubTime = "pub_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        epID = try container.decodeIfPresent(Int64.self, forKey: .epID) ?? 0
        cid = try container.decodeIfPresent(Int64.self, forKey: .cid)
        aid = try container.decodeIfPresent(Int64.self, forKey: .aid)
        bvid = try container.decodeIfPresent(String.self, forKey: .bvid)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        longTitle = try container.decodeIfPresent(String.self, forKey: .longTitle)
        showTitle = try container.decodeIfPresent(String.self, forKey: .showTitle)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        if let value = try container.decodeIfPresent(Int64.self, forKey: .durationMS) {
            durationMS = value
        } else {
            durationMS = try container.decodeIfPresent(Int64.self, forKey: .durationMSAlt)
        }
        badge = try container.decodeIfPresent(String.self, forKey: .badge)
        pubTime = try container.decodeIfPresent(Int64.self, forKey: .pubTime)
    }

    var id: Int64 { epID > 0 ? epID : (cid ?? 0) }
    var coverURL: URL? { MediaURL.normalize(cover) }

    var displayTitle: String {
        if let longTitle, !longTitle.isEmpty {
            return longTitle
        }
        return title
    }
}

struct AnimeSeason: Decodable {
    let seasonID: Int64
    let mediaID: Int64?
    let title: String
    let seasonTitle: String?
    let cover: String?
    let squareCover: String?
    let backgroundCover: String?
    let evaluate: String?
    let total: Int?
    let rating: AnimeRating?
    let areas: [AnimeArea]?
    let newEp: AnimeNewEp?
    let episodes: [AnimeEpisode]?
    let stat: AnimeSeasonStat?
    let userStatus: AnimeUserStatus?
    let publish: AnimePublish?
    let typeName: String?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case mediaID = "media_id"
        case title
        case seasonTitle = "season_title"
        case cover
        case squareCover = "square_cover"
        case backgroundCover = "bkg_cover"
        case evaluate
        case total
        case rating
        case areas
        case newEp = "new_ep"
        case episodes
        case stat
        case userStatus = "user_status"
        case publish
        case typeName = "type_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seasonID = try container.decodeIfPresent(Int64.self, forKey: .seasonID) ?? 0
        mediaID = try container.decodeIfPresent(Int64.self, forKey: .mediaID)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        seasonTitle = try container.decodeIfPresent(String.self, forKey: .seasonTitle)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        squareCover = try container.decodeIfPresent(String.self, forKey: .squareCover)
        backgroundCover = try container.decodeIfPresent(String.self, forKey: .backgroundCover)
        evaluate = try container.decodeIfPresent(String.self, forKey: .evaluate)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        rating = try container.decodeIfPresent(AnimeRating.self, forKey: .rating)
        areas = try container.decodeIfPresent([AnimeArea].self, forKey: .areas)
        newEp = try container.decodeIfPresent(AnimeNewEp.self, forKey: .newEp)
        episodes = try container.decodeIfPresent([AnimeEpisode].self, forKey: .episodes)
        stat = try container.decodeIfPresent(AnimeSeasonStat.self, forKey: .stat)
        userStatus = try container.decodeIfPresent(AnimeUserStatus.self, forKey: .userStatus)
        publish = try container.decodeIfPresent(AnimePublish.self, forKey: .publish)
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
    }

    var coverURL: URL? { MediaURL.normalize(cover) }
    var backgroundURL: URL? { MediaURL.normalize(backgroundCover) ?? coverURL }
    var isFollowing: Bool { userStatus?.isFollowing ?? false }
    var areaText: String {
        (areas ?? []).compactMap(\.name).filter { !$0.isEmpty }.joined(separator: " · ")
    }
    var episodeCount: Int { episodes?.count ?? 0 }
}

struct AnimeSeasonBrief: Decodable, Hashable {
    let seasonID: Int64?
    let mediaID: Int64?
    let title: String?
    let cover: String?
    let total: Int?
    let typeName: String?
    let evaluate: String?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case mediaID = "media_id"
        case title
        case cover
        case total
        case typeName = "type_name"
        case evaluate
    }

    var coverURL: URL? { MediaURL.normalize(cover) }
}

struct AnimeQuality: Decodable, Hashable, Identifiable {
    let qn: Int
    let label: String
    let codecs: [String]?
    let width: Int?
    let height: Int?
    let bandwidth: Int64?

    var id: Int { qn }
}

struct AnimePlayResult: Decodable {
    let playable: Bool
    let reason: String?
    let message: String?
    let sessionID: String?
    let playbackURLString: String?
    let expiresAt: Int64?
    let durationMS: Int64?
    let isPreview: Bool?
    let quality: AnimeQuality?
    let qualities: [AnimeQuality]?
    let episode: AnimeEpisode?
    let season: AnimeSeasonBrief?
    let episodes: [AnimeEpisode]?

    enum CodingKeys: String, CodingKey {
        case playable
        case reason
        case message
        case sessionID = "session_id"
        case playbackURLString = "playback_url"
        case expiresAt = "expires_at"
        case durationMS = "duration_ms"
        case isPreview = "is_preview"
        case quality
        case qualities
        case episode
        case season
        case episodes
    }

    var playbackURL: URL? {
        guard let playbackURLString, !playbackURLString.isEmpty else { return nil }
        return URL(string: playbackURLString)
    }

    var unavailableText: String {
        switch reason {
        case "hls_unavailable":
            return message ?? "当前剧集没有可用的播放流"
        case "entitlement_required":
            return "需要大会员或购买后才能观看"
        case "region_limited":
            return "该剧集在当前地区不可用"
        case "auth_required":
            return "请先登录后观看"
        case "not_found":
            return "剧集不存在或已下架"
        default:
            return message ?? "剧集暂不可播放"
        }
    }
}

struct AnimeReviewAuthor: Decodable, Hashable {
    let uname: String?
    let avatar: String?

    var avatarURL: URL? { MediaURL.normalize(avatar) }
}

struct AnimeReviewStat: Decodable, Hashable {
    let likes: Int?
}

struct AnimeReview: Decodable, Identifiable, Hashable {
    let reviewID: Int64
    let score: Int?
    let content: String
    let ctime: Int64?
    let pushTimeStr: String?
    let progress: String?
    let author: AnimeReviewAuthor?
    let stat: AnimeReviewStat?

    enum CodingKeys: String, CodingKey {
        case reviewID = "review_id"
        case score
        case content
        case ctime
        case pushTimeStr = "push_time_str"
        case progress
        case author
        case stat
    }

    var id: Int64 { reviewID }
    var authorName: String { author?.uname ?? "观众" }
}

struct AnimeReviewData: Decodable {
    let list: [AnimeReview]?
    let next: String?
    let total: Int?
}

struct AnimeRankItem: Decodable, Identifiable, Hashable {
    let seasonID: Int64
    let title: String
    let cover: String?
    let rank: Int?
    let rating: String?
    let badge: String?
    let newEp: AnimeNewEp?
    let iconText: String?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case title
        case cover
        case rank
        case rating
        case badge
        case newEp = "new_ep"
        case iconFont = "icon_font"
    }

    private struct IconFont: Decodable, Hashable {
        let text: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seasonID = try container.decodeIfPresent(Int64.self, forKey: .seasonID) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        rating = try container.decodeIfPresent(String.self, forKey: .rating)
        badge = try container.decodeIfPresent(String.self, forKey: .badge)
        newEp = try container.decodeIfPresent(AnimeNewEp.self, forKey: .newEp)
        iconText = try container.decodeIfPresent(IconFont.self, forKey: .iconFont)?.text
    }

    var id: Int64 { seasonID }
    var coverURL: URL? { MediaURL.normalize(cover) }
}

struct AnimeRankData: Decodable {
    let list: [AnimeRankItem]?
}

enum AnimeTab: String, CaseIterable, Identifiable {
    case timeline
    case rank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "时间表"
        case .rank: return "排行榜"
        }
    }
}
