import Foundation

enum DynamicFeedType: String, CaseIterable, Identifiable {
    case all
    case video
    case pgc
    case up

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .video: return "视频"
        case .pgc: return "番剧"
        case .up: return "UP 主"
        }
    }
}

struct DynamicAuthor: Hashable {
    let mid: Int64?
    let name: String
    let avatarURL: URL?
    let pubTime: String
    let pubAction: String
    let isFollowing: Bool
    let isTop: Bool
}

struct DynamicPicture: Identifiable, Hashable {
    let id: String
    let url: URL
    let width: Int
    let height: Int
}

struct DynamicVideoAttachment: Hashable {
    let bvid: String
    let title: String
    let coverURL: URL?
    let durationText: String
    let playText: String
    let desc: String
}

struct DynamicPGCAttachment: Hashable {
    let seasonID: String
    let episodeID: String
    let title: String
    let coverURL: URL?
    let badge: String
    let jumpURL: URL?
}

struct DynamicArticleAttachment: Hashable {
    let id: String
    let title: String
    let summary: String
    let coverURL: URL?
    let jumpURL: URL?
}

struct DynamicLiveAttachment: Hashable {
    let roomID: Int64
    let title: String
    let coverURL: URL?
    let areaName: String
}

struct DynamicAttachment: Hashable {
    var video: DynamicVideoAttachment? = nil
    var pictures: [DynamicPicture] = []
    var pgc: DynamicPGCAttachment? = nil
    var article: DynamicArticleAttachment? = nil
    var live: DynamicLiveAttachment? = nil

    var isEmpty: Bool {
        video == nil && pictures.isEmpty && pgc == nil && article == nil && live == nil
    }
}

struct DynamicStats: Hashable {
    var likeCount: Int
    var commentCount: Int
    var forwardCount: Int
    var isLiked: Bool
}

struct DynamicOriginal: Identifiable, Hashable {
    let id: String
    let type: String
    let author: DynamicAuthor
    let text: String
    let attachment: DynamicAttachment
}

struct DynamicCard: Identifiable, Hashable {
    let id: String
    let type: String
    let author: DynamicAuthor
    let text: String
    let attachment: DynamicAttachment
    let commentID: String
    let commentType: Int
    let orig: DynamicOriginal?
    var likeCount: Int
    var commentCount: Int
    var forwardCount: Int
    var isLiked: Bool

    var stats: DynamicStats {
        DynamicStats(
            likeCount: likeCount,
            commentCount: commentCount,
            forwardCount: forwardCount,
            isLiked: isLiked
        )
    }
}

struct DynamicFeedResult: Decodable {
    let items: [DynamicRawItem]?
    let offset: String?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case items
        case offset
        case hasMore = "has_more"
    }
}

struct DynamicRawItem: Decodable {
    let idStr: String?
    let type: String?
    let basic: DynamicBasicRaw?
    let modules: DynamicModulesRaw?
    let orig: DynamicOrigRaw?

    enum CodingKeys: String, CodingKey {
        case idStr = "id_str"
        case type
        case basic
        case modules
        case orig
    }
}

struct DynamicOrigRaw: Decodable {
    let idStr: String?
    let type: String?
    let modules: DynamicModulesRaw?

    enum CodingKeys: String, CodingKey {
        case idStr = "id_str"
        case type
        case modules
    }
}

struct DynamicBasicRaw: Decodable {
    let commentIDStr: String?
    let commentType: Int?
    let ridStr: String?

    enum CodingKeys: String, CodingKey {
        case commentIDStr = "comment_id_str"
        case commentType = "comment_type"
        case ridStr = "rid_str"
    }
}

struct DynamicModulesRaw: Decodable {
    let author: DynamicAuthorRaw?
    let dynamic: DynamicContentRaw?
    let stat: DynamicStatRaw?

    enum CodingKeys: String, CodingKey {
        case author = "module_author"
        case dynamic = "module_dynamic"
        case stat = "module_stat"
    }
}

struct DynamicAuthorRaw: Decodable {
    let mid: Int64?
    let name: String?
    let face: String?
    let pubTime: String?
    let pubTs: String?
    let following: Bool?
    let isTop: Bool?
    let pubAction: String?

    enum CodingKeys: String, CodingKey {
        case mid
        case name
        case face
        case pubTime = "pub_time"
        case pubTs = "pub_ts"
        case following
        case isTop = "is_top"
        case pubAction = "pub_action"
    }
}

struct DynamicContentRaw: Decodable {
    let desc: DynamicTextRaw?
    let major: DynamicMajorRaw?
}

struct DynamicTextRaw: Decodable {
    let text: String?
    let richTextNodes: [DynamicRichNodeRaw]?

    enum CodingKeys: String, CodingKey {
        case text
        case richTextNodes = "rich_text_nodes"
    }
}

struct DynamicRichNodeRaw: Decodable {
    let text: String?
}

struct DynamicSummaryRaw: Decodable {
    let richTextNodes: [DynamicRichNodeRaw]?

    enum CodingKeys: String, CodingKey {
        case richTextNodes = "rich_text_nodes"
    }
}

struct DynamicMajorRaw: Decodable {
    let type: String?
    let archive: DynamicArchiveRaw?
    let opus: DynamicOpusRaw?
    let draw: DynamicDrawRaw?
    let article: DynamicArticleRaw?
    let pgc: DynamicPGCRaw?
    let live: DynamicLiveRaw?
    let liveRcmd: DynamicLiveRcmdRaw?

    enum CodingKeys: String, CodingKey {
        case type
        case archive
        case opus
        case draw
        case article
        case pgc
        case live
        case liveRcmd = "live_rcmd"
    }
}

struct DynamicArchiveRaw: Decodable {
    let bvid: String?
    let title: String?
    let cover: String?
    let desc: String?
    let durationText: String?
    let jumpURL: String?
    let stat: DynamicArchiveStatRaw?

    enum CodingKeys: String, CodingKey {
        case bvid
        case title
        case cover
        case desc
        case durationText = "duration_text"
        case jumpURL = "jump_url"
        case stat
    }
}

struct DynamicArchiveStatRaw: Decodable {
    let play: String?
    let danmaku: String?
}

struct DynamicOpusRaw: Decodable {
    let title: String?
    let summary: DynamicSummaryRaw?
    let pictures: [DynamicPictureRaw]?
    let jumpURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case pictures = "pics"
        case jumpURL = "jump_url"
    }
}

struct DynamicPictureRaw: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
}

struct DynamicDrawRaw: Decodable {
    let items: [DynamicPictureRaw]?
}

struct DynamicArticleRaw: Decodable {
    let id: StringOrInt?
    let title: String?
    let desc: String?
    let covers: [String]?
    let jumpURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case desc
        case covers
        case jumpURL = "jump_url"
    }
}

struct DynamicPGCRaw: Decodable {
    let seasonID: StringOrInt?
    let episodeID: StringOrInt?
    let title: String?
    let cover: String?
    let jumpURL: String?
    let subType: StringOrInt?
    let badge: DynamicBadgeRaw?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case episodeID = "epid"
        case title
        case cover
        case jumpURL = "jump_url"
        case subType = "sub_type"
        case badge
    }
}

struct DynamicBadgeRaw: Decodable {
    let text: String?
}

struct DynamicLiveRaw: Decodable {
    let roomID: Int64?
    let title: String?
    let cover: String?
    let areaName: String?

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case title
        case cover
        case areaName = "area_name"
    }
}

struct DynamicLiveRcmdRaw: Decodable {
    let content: String?
}

struct DynamicLiveRcmdContent: Decodable {
    let livePlayInfo: DynamicLivePlayInfoRaw?

    enum CodingKeys: String, CodingKey {
        case livePlayInfo = "live_play_info"
    }
}

struct DynamicLivePlayInfoRaw: Decodable {
    let roomID: Int64?
    let title: String?
    let cover: String?
    let areaName: String?

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case title
        case cover
        case areaName = "area_name"
    }
}

struct DynamicStatRaw: Decodable {
    let like: DynamicCountRaw?
    let comment: DynamicCountRaw?
    let forward: DynamicCountRaw?
}

struct DynamicCountRaw: Decodable {
    let count: Int?
    let status: Bool?
}

enum DynamicModelParser {
    static func card(from raw: DynamicRawItem) -> DynamicCard? {
        guard let id = raw.idStr, let modules = raw.modules else { return nil }
        let author = author(from: modules.author)
        let text = text(from: modules.dynamic)
        let attachment = attachment(from: modules.dynamic?.major)
        guard !text.isEmpty || !attachment.isEmpty else { return nil }

        let stats = modules.stat
        let orig = raw.orig.flatMap(original(from:))
        return DynamicCard(
            id: id,
            type: raw.type ?? "",
            author: author,
            text: text,
            attachment: attachment,
            commentID: raw.basic?.commentIDStr ?? "",
            commentType: raw.basic?.commentType ?? 0,
            orig: orig,
            likeCount: stats?.like?.count ?? 0,
            commentCount: stats?.comment?.count ?? 0,
            forwardCount: stats?.forward?.count ?? 0,
            isLiked: stats?.like?.status == true
        )
    }

    private static func original(from raw: DynamicOrigRaw) -> DynamicOriginal? {
        guard let id = raw.idStr, let modules = raw.modules else { return nil }
        return DynamicOriginal(
            id: id,
            type: raw.type ?? "",
            author: author(from: modules.author),
            text: text(from: modules.dynamic),
            attachment: attachment(from: modules.dynamic?.major)
        )
    }

    private static func author(from raw: DynamicAuthorRaw?) -> DynamicAuthor {
        let name = raw?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return DynamicAuthor(
            mid: raw?.mid,
            name: name.isEmpty ? "哔哩哔哩用户" : name,
            avatarURL: MediaURL.normalize(raw?.face),
            pubTime: raw?.pubTime ?? "",
            pubAction: raw?.pubAction ?? "",
            isFollowing: raw?.following ?? false,
            isTop: raw?.isTop ?? false
        )
    }

    private static func text(from content: DynamicContentRaw?) -> String {
        guard let content else { return "" }
        var value = content.desc?.text ?? nodesText(content.desc?.richTextNodes)
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let opus = content.major?.opus {
                value = nodesText(opus.summary?.richTextNodes)
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    value = opus.title ?? ""
                }
            } else if let article = content.major?.article {
                value = article.desc ?? article.title ?? ""
            }
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nodesText(_ nodes: [DynamicRichNodeRaw]?) -> String {
        (nodes ?? []).compactMap(\.text).joined()
    }

    private static func attachment(from major: DynamicMajorRaw?) -> DynamicAttachment {
        var attachment = DynamicAttachment(pictures: [])
        guard let major else { return attachment }

        if let archive = major.archive,
           let bvid = archive.bvid,
           !bvid.isEmpty {
            attachment.video = DynamicVideoAttachment(
                bvid: bvid,
                title: archive.title ?? "",
                coverURL: MediaURL.normalize(archive.cover),
                durationText: archive.durationText ?? "",
                playText: archive.stat?.play ?? "",
                desc: archive.desc ?? ""
            )
        }

        if let opus = major.opus {
            attachment.pictures = pictures(opus.pictures)
        } else if let draw = major.draw {
            attachment.pictures = pictures(draw.items)
        }

        if let pgc = major.pgc {
            attachment.pgc = DynamicPGCAttachment(
                seasonID: pgc.seasonID?.value ?? "",
                episodeID: pgc.episodeID?.value ?? "",
                title: pgc.title ?? "",
                coverURL: MediaURL.normalize(pgc.cover),
                badge: pgc.badge?.text ?? "",
                jumpURL: MediaURL.normalize(pgc.jumpURL)
            )
        }

        if let article = major.article {
            attachment.article = DynamicArticleAttachment(
                id: article.id?.value ?? "",
                title: article.title ?? "",
                summary: article.desc ?? "",
                coverURL: MediaURL.normalize(article.covers?.first),
                jumpURL: MediaURL.normalize(article.jumpURL)
            )
        }

        if let live = major.live {
            attachment.live = liveAttachment(
                roomID: live.roomID,
                title: live.title,
                cover: live.cover,
                areaName: live.areaName
            )
        } else if let content = major.liveRcmd?.content,
                  let data = content.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode(DynamicLiveRcmdContent.self, from: data),
                  let info = parsed.livePlayInfo {
            attachment.live = liveAttachment(
                roomID: info.roomID,
                title: info.title,
                cover: info.cover,
                areaName: info.areaName
            )
        }

        return attachment
    }

    private static func liveAttachment(
        roomID: Int64?,
        title: String?,
        cover: String?,
        areaName: String?
    ) -> DynamicLiveAttachment? {
        guard let roomID, roomID > 0 else { return nil }
        return DynamicLiveAttachment(
            roomID: roomID,
            title: title ?? "直播",
            coverURL: MediaURL.normalize(cover),
            areaName: areaName ?? ""
        )
    }

    private static func pictures(_ raw: [DynamicPictureRaw]?) -> [DynamicPicture] {
        (raw ?? []).enumerated().compactMap { index, picture in
            guard let url = MediaURL.normalize(picture.url) else { return nil }
            return DynamicPicture(
                id: "\(index)-\(url.absoluteString)",
                url: url,
                width: picture.width ?? 0,
                height: picture.height ?? 0
            )
        }
    }
}
