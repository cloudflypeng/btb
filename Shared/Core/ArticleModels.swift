import Foundation

struct ArticleAuthor: Decodable, Hashable {
    let mid: Int64?
    let name: String?
    let face: String?

    var avatarURL: URL? { MediaURL.normalize(face) }
}

struct ArticleStats: Decodable, Hashable {
    let view: Int?
    let like: Int?
    let reply: Int?
    let favorite: Int?
    let coin: Int?
}

struct ArticleCategory: Decodable, Hashable {
    let id: Int?
    let name: String?
}

struct ArticleDetail: Decodable, Identifiable {
    let id: Int64
    let title: String
    let summary: String?
    let bannerURL: String?
    let content: String?
    let publishTime: Int64?
    let words: Int?
    let author: ArticleAuthor?
    let stats: ArticleStats?
    let category: ArticleCategory?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case bannerURL = "banner_url"
        case content
        case publishTime = "publish_time"
        case words
        case author
        case stats
        case category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        title = (try container.decodeIfPresent(String.self, forKey: .title) ?? "").strippingSearchMarkup()
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        bannerURL = try container.decodeIfPresent(String.self, forKey: .bannerURL)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        publishTime = try container.decodeIfPresent(Int64.self, forKey: .publishTime)
        words = try container.decodeIfPresent(Int.self, forKey: .words)
        author = try container.decodeIfPresent(ArticleAuthor.self, forKey: .author)
        stats = try container.decodeIfPresent(ArticleStats.self, forKey: .stats)
        category = try container.decodeIfPresent(ArticleCategory.self, forKey: .category)
    }

    var bannerLink: URL? { MediaURL.normalize(bannerURL) }

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
        if let words, words > 0 {
            parts.append("\(SearchFormat.count(words))字")
        }
        return parts.joined(separator: " · ")
    }
}

struct ArticleDetailResponse: Decodable {
    let code: Int
    let message: String?
    let data: ArticleDetail?
}
