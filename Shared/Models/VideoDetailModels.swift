import Foundation

struct VideoInfoData: Decodable {
    let aid: Int64?
    let bvid: String?
    let cid: Int?
    let title: String?
    let desc: String?
    let pic: String?
    let duration: Int?
    let pubdate: Int?
    let owner: VideoOwnerInfo?
    let stat: VideoStatInfo?
    let dimension: VideoDimension?

    var publishedAt: Date? {
        guard let pubdate, pubdate > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(pubdate))
    }

    var publishedAgoText: String {
        guard let publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
}

struct VideoOwnerInfo: Decodable {
    let mid: Int64?
    let name: String?
    let face: String?
}

struct VideoStatInfo: Decodable {
    let view: Int?
    let danmaku: Int?
    let like: Int?
    let favorite: Int?
    let share: Int?
    let reply: Int?
    let coin: Int?
}

struct VideoDimension: Decodable {
    let width: Int?
    let height: Int?
}

struct RelatedVideo: Decodable {
    let aid: Int64?
    let bvid: String?
    let cid: Int?
    let title: String?
    let pic: String?
    let duration: Int?
    let pubdate: Int?
    let desc: String?
    let owner: VideoOwnerInfo?
    let stat: VideoStatInfo?
}

struct VideoRelationData: Decodable {
    var attention: Bool?
    var like: Bool?
    var coin: Int?
    var favorite: Bool?
    var dislike: Bool?
}

struct VideoTagItem: Decodable {
    let tagID: Int64?
    let tagName: String?

    enum CodingKeys: String, CodingKey {
        case tagID = "tag_id"
        case tagName = "tag_name"
    }
}

struct AIConclusionData: Decodable {
    let modelResult: AIConclusionResult?
}

struct AIConclusionResult: Decodable {
    let summary: String?
    let outline: [AIOutline]?
}

struct AIOutline: Decodable {
    let title: String?
    let partOutline: [AIPartOutline]?

    enum CodingKeys: String, CodingKey {
        case title
        case partOutline = "part_outline"
    }
}

struct AIPartOutline: Decodable {
    let timestamp: Int?
    let content: String?
}

struct BasicResponse: Decodable {
    let code: Int
    let message: String?
}

struct ReplyData: Decodable {
    let page: ReplyPage?
    let replies: [ReplyRaw]?
    let topReplies: [ReplyRaw]?
    let cursor: ReplyCursor?

    enum CodingKeys: String, CodingKey {
        case page
        case replies
        case topReplies = "top_replies"
        case cursor
    }
}

struct ReplyCursor: Decodable {
    let allCount: Int?
    let next: Int?
    let isEnd: Bool?

    enum CodingKeys: String, CodingKey {
        case allCount = "all_count"
        case next
        case isEnd = "is_end"
    }
}

struct ReplyPage: Decodable {
    let acount: Int?
    let count: Int?
    let num: Int?
    let size: Int?
}

struct ReplyRaw: Decodable {
    let rpid: Int64?
    let member: ReplyMember?
    let content: ReplyContent?
    let like: Int?
    let action: Int?
    let ctime: Int?
    let rcount: Int?
    let replies: [ReplyRaw]?
    let replyControl: ReplyControl?

    enum CodingKeys: String, CodingKey {
        case rpid
        case member
        case content
        case like
        case action
        case ctime
        case rcount
        case replies
        case replyControl = "reply_control"
    }
}

struct ReplyMember: Decodable {
    let uname: String?
    let avatar: String?
}

struct ReplyContent: Decodable {
    let message: String?
}

struct ReplyControl: Decodable {
    let timeDesc: String?

    enum CodingKeys: String, CodingKey {
        case timeDesc = "time_desc"
    }
}

struct VideoComment: Identifiable {
    let id: Int64
    let author: String
    let avatarURL: URL?
    let message: String
    var likeCount: Int
    var isLiked: Bool
    let timeText: String
    let replyCount: Int
    let replies: [VideoComment]

    init?(raw: ReplyRaw, index: Int) {
        guard let message = raw.content?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }
        id = raw.rpid ?? Int64(index)
        author = raw.member?.uname ?? "哔哩哔哩用户"
        avatarURL = MediaURL.normalize(raw.member?.avatar)
        self.message = message
        likeCount = max(0, raw.like ?? 0)
        isLiked = raw.action == 1
        if let timeDesc = raw.replyControl?.timeDesc, !timeDesc.isEmpty {
            timeText = timeDesc
        } else if let ctime = raw.ctime, ctime > 0 {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.unitsStyle = .short
            timeText = formatter.localizedString(
                for: Date(timeIntervalSince1970: TimeInterval(ctime)),
                relativeTo: Date()
            )
        } else {
            timeText = ""
        }
        let previews = (raw.replies ?? [])
            .enumerated()
            .compactMap { offset, reply in
                VideoComment(raw: reply, index: index * 100 + offset)
            }
            .prefix(2)
            .map { $0 }
        replies = previews
        replyCount = max(raw.rcount ?? 0, previews.count)
    }

    var likeText: String {
        if likeCount >= 10_000 {
            return String(format: "%.1f万", Double(likeCount) / 10_000)
        }
        return "\(likeCount)"
    }
}
