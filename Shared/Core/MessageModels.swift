import Foundation

enum MessageTab: String, CaseIterable, Identifiable {
    case replies
    case ats
    case likes
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replies: return "回复我的"
        case .ats: return "@我的"
        case .likes: return "收到的赞"
        case .system: return "系统通知"
        }
    }

    var icon: String {
        switch self {
        case .replies: return "bubble.left"
        case .ats: return "at"
        case .likes: return "hand.thumbsup"
        case .system: return "bell.badge"
        }
    }

    var emptyTitle: String {
        switch self {
        case .replies: return "还没有收到回复"
        case .ats: return "还没有人提到你"
        case .likes: return "还没有收到赞"
        case .system: return "没有系统通知"
        }
    }

    var emptyMessage: String {
        switch self {
        case .replies: return "别人回复你的评论时会出现在这里。"
        case .ats: return "有人在评论或动态中 @ 你时会出现在这里。"
        case .likes: return "别人赞了你的评论、弹幕或动态时会出现在这里。"
        case .system: return "账号与平台通知会出现在这里。"
        }
    }
}

struct MessageUnread: Decodable {
    let reply: Int?
    let at: Int?
    let like: Int?
    let recvLike: Int?
    let sysMsg: Int?
    let chat: Int?

    enum CodingKeys: String, CodingKey {
        case reply
        case at
        case like
        case recvLike = "recv_like"
        case sysMsg = "sys_msg"
        case chat
    }

    func count(for tab: MessageTab) -> Int {
        switch tab {
        case .replies: return reply ?? 0
        case .ats: return at ?? 0
        case .likes: return max(like ?? 0, recvLike ?? 0)
        case .system: return sysMsg ?? 0
        }
    }

    var total: Int {
        MessageTab.allCases.reduce(0) { $0 + count(for: $1) }
    }
}

struct MessageCursor: Decodable {
    let id: Int64?
    let time: Int64?
    let isEnd: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case isEnd = "is_end"
    }
}

struct MessageUser: Decodable, Hashable {
    let mid: Int64?
    let nickname: String?
    let avatar: String?
    let fans: Int?
    let follow: Bool?

    var avatarURL: URL? { MediaURL.normalize(avatar) }
    var displayName: String {
        let name = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "B站用户" : name
    }
}

struct MessageContent: Decodable, Hashable {
    let business: String?
    let businessID: Int?
    let type: String?
    let title: String?
    let desc: String?
    let sourceContent: String?
    let rootReplyContent: String?
    let targetReplyContent: String?
    let uri: String?
    let nativeURI: String?
    let image: String?
    let subjectID: Int64?
    let sourceID: Int64?

    enum CodingKeys: String, CodingKey {
        case business
        case type
        case title
        case desc
        case uri
        case image
        case businessID = "business_id"
        case sourceContent = "source_content"
        case rootReplyContent = "root_reply_content"
        case targetReplyContent = "target_reply_content"
        case nativeURI = "native_uri"
        case subjectID = "subject_id"
        case sourceID = "source_id"
    }

    var businessLabel: String {
        let value = business?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty { return value }
        let kind = type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return kind.isEmpty ? "内容" : kind
    }

    var displayContent: String {
        for candidate in [title, sourceContent, desc] {
            let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { return text }
        }
        return ""
    }

    var sourceSnippet: String {
        let main = displayContent
        for candidate in [targetReplyContent, rootReplyContent, sourceContent, desc] {
            let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty, text != main { return text }
        }
        return ""
    }

    var imageURL: URL? { MediaURL.normalize(image) }

    var destination: MessageDestination? {
        MessageDestination.parse(uri: uri, nativeURI: nativeURI)
    }
}

struct MessageReplyEntry: Decodable, Identifiable {
    let id: Int64
    let replyTime: Int64?
    let isMulti: Int?
    let counts: Int?
    let user: MessageUser?
    let item: MessageContent?

    enum CodingKeys: String, CodingKey {
        case id
        case counts
        case user
        case item
        case replyTime = "reply_time"
        case isMulti = "is_multi"
    }
}

struct MessageAtEntry: Decodable, Identifiable {
    let id: Int64
    let atTime: Int64?
    let user: MessageUser?
    let item: MessageContent?

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case item
        case atTime = "at_time"
    }
}

struct MessageLikeEntry: Decodable, Identifiable {
    let id: Int64
    let likeTime: Int64?
    let noticeState: Int?
    let counts: Int?
    let users: [MessageUser]?
    let item: MessageContent?

    enum CodingKeys: String, CodingKey {
        case id
        case counts
        case users
        case item
        case likeTime = "like_time"
        case noticeState = "notice_state"
    }

    var primaryUser: MessageUser? { users?.first }
}

struct MessageReplyFeed: Decodable {
    let cursor: MessageCursor?
    let items: [MessageReplyEntry]?
    let lastViewAt: Int64?

    enum CodingKeys: String, CodingKey {
        case cursor
        case items
        case lastViewAt = "last_view_at"
    }
}

struct MessageAtFeed: Decodable {
    let cursor: MessageCursor?
    let items: [MessageAtEntry]?
    let lastViewAt: Int64?

    enum CodingKeys: String, CodingKey {
        case cursor
        case items
        case lastViewAt = "last_view_at"
    }
}

struct MessageLikeLatest: Decodable {
    let items: [MessageLikeEntry]?
    let lastViewAt: Int64?

    enum CodingKeys: String, CodingKey {
        case items
        case lastViewAt = "last_view_at"
    }
}

struct MessageLikeTotal: Decodable {
    let items: [MessageLikeEntry]?
    let cursor: MessageCursor?
}

struct MessageLikeData: Decodable {
    let latest: MessageLikeLatest?
    let total: MessageLikeTotal?
}

struct SystemMessage: Decodable, Identifiable {
    let id: Int64
    let cursor: Int64?
    let title: String?
    let content: String?
    let timeAt: String?
    let type: Int?
    let cardLink: String?
    let cardCover: String?
    let isStation: Int?
    let source: SystemMessageSource?

    enum CodingKeys: String, CodingKey {
        case id
        case cursor
        case title
        case content
        case type
        case source
        case timeAt = "time_at"
        case cardLink = "card_link"
        case cardCover = "card_cover"
        case isStation = "is_station"
    }

    var bodyText: String {
        guard let content else { return "" }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let web = object["web"] as? String {
            return Self.plainText(web)
        }
        return Self.plainText(trimmed)
    }

    var coverURL: URL? {
        MediaURL.normalize(cardCover) ?? MediaURL.normalize(source?.logo)
    }

    var webURL: URL? {
        if let link = cardLink?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: link), url.scheme?.hasPrefix("http") == true {
            return url
        }
        guard let match = Self.firstURL(in: content ?? "") else { return nil }
        return URL(string: match)
    }

    private static func plainText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: "#\\{[^}]*\\}\\{[^}]*\\}",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstURL(in text: String) -> String? {
        let pattern = "https?://[^\\s\"\\\\]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (text as NSString).substring(with: match.range)
    }
}

struct SystemMessageSource: Decodable {
    let name: String?
    let logo: String?
}

enum MessageDestination: Hashable {
    case video(bvid: String)
    case videoAID(Int64)
    case season(Int64)
    case external(URL)

    static func parse(uri: String?, nativeURI: String?) -> MessageDestination? {
        let texts = [uri, nativeURI].compactMap { $0 }

        for text in texts {
            if let bvid = match("BV[0-9A-Za-z]{10}", in: text) {
                return .video(bvid: bvid)
            }
        }
        for text in texts {
            if let season = match("bangumi/play/ss(\\d+)", in: text), let id = Int64(season) {
                return .season(id)
            }
        }
        for text in texts {
            if text.hasPrefix("bilibili://video/"),
               let raw = match("bilibili://video/(\\d+)", in: text),
               let aid = Int64(raw) {
                return .videoAID(aid)
            }
        }
        if let uri, let url = URL(string: uri), url.scheme?.hasPrefix("http") == true {
            return .external(url)
        }
        if let nativeURI, let dynamicID = match("bilibili://following/detail/(\\d+)", in: nativeURI) {
            return .external(URL(string: "https://t.bilibili.com/\(dynamicID)")!)
        }
        return nil
    }

    private static func match(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard groupRange.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: groupRange)
    }
}

struct MessageFeed<Item> {
    var items: [Item] = []
    var cursorID: Int64 = 0
    var cursorTime: Int64 = 0
    var hasMore = true
    var loaded = false
    var isLoading = false
    var isLoadingMore = false
    var failed = false
    var error: String?
    var lastViewAt: Int64 = 0
}

struct MessageVideoInfo: Decodable {
    let bvid: String?
}
