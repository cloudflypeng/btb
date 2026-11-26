import Foundation

enum DiscoverTab: String, CaseIterable, Identifiable {
    case ranking
    case weekly
    case categories
    case articles
    case topics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ranking: return "排行榜"
        case .weekly: return "每周必看"
        case .categories: return "分区"
        case .articles: return "专栏"
        case .topics: return "话题"
        }
    }

    var icon: String {
        switch self {
        case .ranking: return "chart.bar.xaxis"
        case .weekly: return "calendar.badge.clock"
        case .categories: return "square.grid.2x2"
        case .articles: return "doc.text"
        case .topics: return "number"
        }
    }
}

struct WeeklySeries: Decodable, Identifiable, Hashable {
    let name: String
    let number: Int
    let status: Int?
    let subject: String?

    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case name
        case number
        case status
        case subject
    }
}

struct WeeklySeriesData: Decodable {
    let list: [WeeklySeries]?
}

struct WeeklyConfig: Decodable {
    let id: Int?
    let name: String?
    let number: Int?
    let subject: String?
    let label: String?
    let shareTitle: String?
    let shareSubtitle: String?
    let cover: String?
    let stime: Int?
    let etime: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case number
        case subject
        case label
        case cover
        case stime
        case etime
        case shareTitle = "share_title"
        case shareSubtitle = "share_subtitle"
    }
}

struct WeeklyIssueData: Decodable {
    let config: WeeklyConfig?
    let list: [HotVideo]?
}

struct TopicSquareItem: Decodable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let description: String?
    let discuss: Int?
    let view: Int?
    let statDesc: String?

    init(
        id: Int64,
        name: String,
        description: String? = nil,
        discuss: Int? = nil,
        view: Int? = nil,
        statDesc: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.discuss = discuss
        self.view = view
        self.statDesc = statDesc
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case discuss
        case view
        case statDesc = "stat_desc"
    }

    var summaryText: String {
        if let statDesc, !statDesc.isEmpty { return statDesc }
        var parts: [String] = []
        if let view, view > 0 { parts.append("\(SearchFormat.count(view))浏览") }
        if let discuss, discuss > 0 { parts.append("\(SearchFormat.count(discuss))讨论") }
        return parts.joined(separator: "·")
    }
}

struct TopicSquareData: Decodable {
    let topicItems: [TopicSquareItem]?

    enum CodingKeys: String, CodingKey {
        case topicItems = "topic_items"
    }
}

struct TopicDetailItem: Decodable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let description: String?
    let backColor: String?
    let sharePic: String?
    let dynamics: Int?
    let view: Int?
    let discuss: Int?
    let jumpURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case dynamics
        case view
        case discuss
        case backColor = "back_color"
        case sharePic = "share_pic"
        case jumpURL = "jump_url"
    }

    var bannerURL: URL? { MediaURL.normalize(sharePic) }
}

struct TopicDetailData: Decodable {
    let topDetails: TopicTopDetails?

    enum CodingKeys: String, CodingKey {
        case topDetails = "top_details"
    }
}

struct TopicTopDetails: Decodable {
    let topicItem: TopicDetailItem?

    enum CodingKeys: String, CodingKey {
        case topicItem = "topic_item"
    }
}

struct TopicFeedItem: Decodable {
    let dynamicCardItem: DynamicRawItem?
    let topicType: String?

    enum CodingKeys: String, CodingKey {
        case dynamicCardItem = "dynamic_card_item"
        case topicType = "topic_type"
    }
}

struct TopicCardList: Decodable {
    let items: [TopicFeedItem]?
    let offset: String?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case items
        case offset
        case hasMore = "has_more"
    }
}

struct TopicFeedData: Decodable {
    let topicCardList: TopicCardList?

    enum CodingKeys: String, CodingKey {
        case topicCardList = "topic_card_list"
    }
}

struct ArticleRankItem: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let summary: String?
    let bannerURL: String?
    let imageURLs: [String]?
    let author: ArticleAuthor?
    let stats: ArticleStats?
    let publishTime: Int64?
    let category: ArticleCategory?
    let words: Int?
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case author
        case stats
        case words
        case score
        case category
        case bannerURL = "banner_url"
        case imageURLs = "image_urls"
        case publishTime = "publish_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        title = (try container.decodeIfPresent(String.self, forKey: .title) ?? "").strippingSearchMarkup()
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        bannerURL = try container.decodeIfPresent(String.self, forKey: .bannerURL)
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
        author = try container.decodeIfPresent(ArticleAuthor.self, forKey: .author)
        stats = try container.decodeIfPresent(ArticleStats.self, forKey: .stats)
        publishTime = try container.decodeIfPresent(Int64.self, forKey: .publishTime)
        category = try container.decodeIfPresent(ArticleCategory.self, forKey: .category)
        words = try container.decodeIfPresent(Int.self, forKey: .words)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
    }

    var coverURL: URL? {
        if let bannerURL, !bannerURL.isEmpty {
            return MediaURL.normalize(bannerURL)
        }
        return MediaURL.normalize(imageURLs?.first)
    }

    var authorName: String {
        let name = author?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "未知作者" : name
    }

    var summaryText: String {
        guard let summary else { return "" }
        return summary
            .replacingOccurrences(of: "[图片]", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var publishedText: String {
        guard let publishTime, publishTime > 0 else { return "" }
        return Date(timeIntervalSince1970: TimeInterval(publishTime))
            .formatted(date: .abbreviated, time: .omitted)
    }

    var statsText: String {
        var parts: [String] = []
        if let view = stats?.view, view > 0 {
            parts.append("\(SearchFormat.count(view))阅读")
        }
        if let like = stats?.like, like > 0 {
            parts.append("\(SearchFormat.count(like))点赞")
        }
        if let reply = stats?.reply, reply > 0 {
            parts.append("\(SearchFormat.count(reply))评论")
        }
        return parts.joined(separator: " · ")
    }
}
