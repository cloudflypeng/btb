import Foundation

struct LiveFollowingData: Decodable {
    let list: [LiveRoomRaw]?
    let pageSize: Int?
    let totalPage: Int?
    let liveCount: Int?
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case list
        case pageSize = "pageSize"
        case totalPage
        case liveCount = "live_count"
        case count
    }
}

struct LiveRoomRaw: Decodable {
    let roomid: Int64?
    let uid: Int64?
    let uname: String?
    let face: String?
    let roomCover: String?
    let title: String?
    let areaName: String?
    let areaNameV2: String?
    let parentAreaID: Int?
    let liveStatus: Int?
    let textSmall: String?
    let isAttention: Int?

    enum CodingKeys: String, CodingKey {
        case roomid
        case uid
        case uname
        case face
        case roomCover = "room_cover"
        case title
        case areaName = "area_name"
        case areaNameV2 = "area_name_v2"
        case parentAreaID = "parent_area_id"
        case liveStatus = "live_status"
        case textSmall = "text_small"
        case isAttention = "is_attention"
    }
}

struct LiveRoom: Identifiable, Hashable {
    let roomID: Int64
    let uid: Int64
    let anchorName: String
    let avatarURL: URL?
    let coverURL: URL?
    let title: String
    let areaName: String
    let parentAreaID: Int
    let liveStatus: Int
    let popularText: String
    let isFollowed: Bool

    var id: Int64 { roomID }
    var isLive: Bool { liveStatus == 1 }
    var pageURL: URL { URL(string: "https://live.bilibili.com/\(roomID)")! }

    init?(raw: LiveRoomRaw) {
        guard let roomID = raw.roomid, roomID > 0 else { return nil }
        self.roomID = roomID
        uid = raw.uid ?? 0
        anchorName = raw.uname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        avatarURL = MediaURL.normalize(raw.face)
        coverURL = MediaURL.normalize(raw.roomCover)
        title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let area = raw.areaNameV2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        areaName = area.isEmpty ? (raw.areaName ?? "") : area
        parentAreaID = raw.parentAreaID ?? 0
        liveStatus = raw.liveStatus ?? 0
        popularText = raw.textSmall?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        isFollowed = (raw.isAttention ?? 0) == 1
    }

    init(play info: LiveRoomInfo) {
        roomID = info.roomID
        uid = info.uid
        anchorName = info.anchorName
        avatarURL = info.avatarURL
        coverURL = info.coverURL
        title = info.title
        areaName = info.areaName
        parentAreaID = 0
        liveStatus = info.liveStatus
        popularText = LiveFormat.count(info.online)
        isFollowed = false
    }

    init(
        roomID: Int64,
        uid: Int64 = 0,
        anchorName: String = "",
        avatarURL: URL? = nil,
        coverURL: URL? = nil,
        title: String = "",
        areaName: String = "",
        parentAreaID: Int = 0,
        liveStatus: Int = 1,
        popularText: String = "",
        isFollowed: Bool = false
    ) {
        self.roomID = roomID
        self.uid = uid
        self.anchorName = anchorName
        self.avatarURL = avatarURL
        self.coverURL = coverURL
        self.title = title
        self.areaName = areaName
        self.parentAreaID = parentAreaID
        self.liveStatus = liveStatus
        self.popularText = popularText
        self.isFollowed = isFollowed
    }
}

enum LiveFeedFilter: String, CaseIterable, Identifiable {
    case live
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: return "直播中"
        case .all: return "全部关注"
        }
    }
}

struct LivePlayResult: Decodable {
    let playable: Bool
    let reason: String?
    let message: String?
    let sessionID: String?
    let playbackURLString: String?
    let expiresAt: Int64?
    let format: String?
    let codec: String?
    let quality: LiveQuality?
    let qualities: [LiveQuality]?
    let room: LiveRoomInfo?

    enum CodingKeys: String, CodingKey {
        case playable
        case reason
        case message
        case sessionID = "session_id"
        case playbackURLString = "playback_url"
        case expiresAt = "expires_at"
        case format
        case codec
        case quality
        case qualities
        case room
    }

    var playbackURL: URL? {
        guard let playbackURLString, !playbackURLString.isEmpty else { return nil }
        return URL(string: playbackURLString)
    }

    var unavailableText: String {
        switch reason {
        case "not_live":
            return "主播暂未开播"
        case "hls_unavailable":
            return message ?? "当前直播没有可用的 HLS 流"
        case "risk_control":
            return "请求被 B 站风控拦截，请稍后再试"
        case "upstream_error":
            return message ?? "直播信息加载失败"
        default:
            return message ?? "直播暂不可播放"
        }
    }
}

struct LiveQuality: Decodable, Hashable, Identifiable {
    let qn: Int
    let desc: String
    let current: Bool?

    var id: Int { qn }
}

struct LiveRoomInfo: Decodable, Hashable {
    let roomID: Int64
    let uid: Int64
    let title: String
    let anchorName: String
    let anchorFace: String
    let cover: String
    let keyframe: String
    let areaName: String
    let parentAreaName: String
    let description: String
    let online: Int
    let watched: Int
    let attention: Int
    let liveStatus: Int
    let liveStartTime: Int64

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case uid
        case title
        case anchorName = "anchor_name"
        case anchorFace = "anchor_face"
        case cover
        case keyframe
        case areaName = "area_name"
        case parentAreaName = "parent_area_name"
        case description
        case online
        case watched
        case attention
        case liveStatus = "live_status"
        case liveStartTime = "live_start_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decodeIfPresent(Int64.self, forKey: .roomID) ?? 0
        uid = try container.decodeIfPresent(Int64.self, forKey: .uid) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        anchorName = try container.decodeIfPresent(String.self, forKey: .anchorName) ?? ""
        anchorFace = try container.decodeIfPresent(String.self, forKey: .anchorFace) ?? ""
        cover = try container.decodeIfPresent(String.self, forKey: .cover) ?? ""
        keyframe = try container.decodeIfPresent(String.self, forKey: .keyframe) ?? ""
        areaName = try container.decodeIfPresent(String.self, forKey: .areaName) ?? ""
        parentAreaName = try container.decodeIfPresent(String.self, forKey: .parentAreaName) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        online = try container.decodeIfPresent(Int.self, forKey: .online) ?? 0
        watched = try container.decodeIfPresent(Int.self, forKey: .watched) ?? 0
        attention = try container.decodeIfPresent(Int.self, forKey: .attention) ?? 0
        liveStatus = try container.decodeIfPresent(Int.self, forKey: .liveStatus) ?? 0
        liveStartTime = try container.decodeIfPresent(Int64.self, forKey: .liveStartTime) ?? 0
    }

    var avatarURL: URL? { MediaURL.normalize(anchorFace) }
    var coverURL: URL? { MediaURL.normalize(cover) }
    var keyframeURL: URL? { MediaURL.normalize(keyframe) }
    var pageURL: URL { URL(string: "https://live.bilibili.com/\(roomID)")! }
    var isLive: Bool { liveStatus == 1 }
    var liveStartDate: Date? {
        liveStartTime > 0 ? Date(timeIntervalSince1970: TimeInterval(liveStartTime)) : nil
    }
}

struct LiveChatMessage: Identifiable, Equatable {
    enum Kind: Equatable {
        case danmaku
        case superChat
        case gift
        case enter
        case system
    }

    let id: String
    let kind: Kind
    let userName: String
    let text: String
    let color: UInt32?
    let price: Int?
    let medalName: String?
    let medalLevel: Int?
    let timestamp: Date
    var isLocal = false
    var isFailed = false

    static func localDanmaku(text: String, userName: String) -> LiveChatMessage {
        LiveChatMessage(
            id: "local-\(UUID().uuidString)",
            kind: .danmaku,
            userName: userName,
            text: text,
            color: nil,
            price: nil,
            medalName: nil,
            medalLevel: nil,
            timestamp: Date(),
            isLocal: true
        )
    }
}

enum LiveEventParser {
    static func roomID(from data: JSONValue) -> Int64? {
        integer(data.objectValue?["room_id"]).map(Int64.init)
    }

    static func popularity(from data: JSONValue) -> Int? {
        integer(data.objectValue?["value"])
    }

    static func watched(from data: JSONValue) -> Int? {
        guard let root = data.objectValue,
              let cmd = root["cmd"]?.stringValue,
              cmd == "WATCHED_CHANGE" || cmd == "ROOM_REAL_TIME_MESSAGE_UPDATE" else { return nil }
        let raw = root["data"]?.objectValue
        if cmd == "WATCHED_CHANGE" {
            return integer(raw?["num"])
        }
        return nil
    }

    static func attention(from data: JSONValue) -> Int? {
        guard let root = data.objectValue,
              root["cmd"]?.stringValue == "ROOM_REAL_TIME_MESSAGE_UPDATE" else { return nil }
        return integer(root["data"]?.objectValue?["fans"])
    }

    static func messages(from data: JSONValue) -> [LiveChatMessage] {
        guard let root = data.objectValue,
              let cmd = root["cmd"]?.stringValue,
              let raw = root["data"]?.objectValue else { return [] }
        let now = Date()

        if cmd.hasPrefix("DANMU_MSG") {
            guard let message = danmaku(root: root, raw: raw, timestamp: now) else { return [] }
            return [message]
        }

        if cmd == "SUPER_CHAT_MESSAGE" {
            return superChat(raw: raw, timestamp: now).map { [$0] } ?? []
        }

        if cmd == "SEND_GIFT" || cmd == "COMBO_SEND" {
            return gift(raw: raw, timestamp: now).map { [$0] } ?? []
        }

        if cmd == "GUARD_BUY" {
            let userName = string(raw["uname"]) ?? ""
            let giftName = string(raw["gift_name"]) ?? "大航海"
            let count = integer(raw["num"]) ?? 1
            let text = count > 1 ? "开通了 \(giftName) ×\(count)" : "开通了 \(giftName)"
            return [LiveChatMessage(
                id: "guard-\(string(raw["uid"]) ?? "0")-\(now.timeIntervalSince1970)",
                kind: .system,
                userName: userName,
                text: text,
                color: nil,
                price: nil,
                medalName: nil,
                medalLevel: nil,
                timestamp: now
            )]
        }

        if cmd == "INTERACT_WORD" {
            guard let message = interact(raw: raw, timestamp: now) else { return [] }
            return [message]
        }

        return []
    }

    private static func danmaku(root: [String: JSONValue], raw: [String: JSONValue], timestamp: Date) -> LiveChatMessage? {
        let summary = root["danmaku"]?.objectValue
        let text = string(summary?["text"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        let info = raw["info"]?.arrayValue
        var uid = integer(summary?["uid"])
        var userName = string(summary?["uname"]) ?? ""
        if let info, info.count > 2, let user = info[2].arrayValue {
            if uid == nil { uid = integer(user.first) }
            if userName.isEmpty, user.count > 1 { userName = string(user[1]) ?? "" }
        }
        var medalName: String?
        var medalLevel: Int?
        if let info, info.count > 3, let medal = info[3].arrayValue, medal.count >= 2 {
            medalLevel = integer(medal[0])
            let name = string(medal[1])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            medalName = name.isEmpty ? nil : name
        }
        let id = string(summary?["id"])
            ?? string(raw["msg_id"])
            ?? "danmaku-\(uid ?? 0)-\(text.hashValue)-\(UUID().uuidString)"
        let colorValue = integer(summary?["color"]).map { UInt32(max(0, $0)) }
        return LiveChatMessage(
            id: id,
            kind: .danmaku,
            userName: userName.isEmpty ? "观众" : userName,
            text: text,
            color: colorValue,
            price: nil,
            medalName: medalName,
            medalLevel: medalLevel,
            timestamp: timestamp
        )
    }

    private static func superChat(raw: [String: JSONValue], timestamp: Date) -> LiveChatMessage? {
        let user = raw["user_info"]?.objectValue
        let text = string(raw["message"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        return LiveChatMessage(
            id: string(raw["id"]) ?? "sc-\(UUID().uuidString)",
            kind: .superChat,
            userName: string(user?["uname"]) ?? "观众",
            text: text,
            color: nil,
            price: integer(raw["price"]),
            medalName: nil,
            medalLevel: nil,
            timestamp: timestamp
        )
    }

    private static func gift(raw: [String: JSONValue], timestamp: Date) -> LiveChatMessage? {
        let coinType = string(raw["coin_type"]) ?? ""
        let price = integer(raw["price"]) ?? integer(raw["total_coin"]) ?? 0
        if coinType == "silver" && price == 0 { return nil }
        let giftName = string(raw["giftName"])
            ?? string(raw["gift_name"])
            ?? "礼物"
        let count = integer(raw["num"]) ?? integer(raw["gift_num"]) ?? 1
        let userName = string(raw["uname"]) ?? "观众"
        let text = count > 1 ? "投喂 \(giftName) ×\(count)" : "投喂 \(giftName)"
        return LiveChatMessage(
            id: "gift-\(string(raw["uid"]) ?? "0")-\(giftName)-\(timestamp.timeIntervalSince1970)",
            kind: .gift,
            userName: userName,
            text: text,
            color: nil,
            price: price > 0 ? price : nil,
            medalName: nil,
            medalLevel: nil,
            timestamp: timestamp
        )
    }

    private static func interact(raw: [String: JSONValue], timestamp: Date) -> LiveChatMessage? {
        let uname = string(raw["uname"]) ?? "观众"
        let type = integer(raw["msg_type"]) ?? 0
        let text: String
        switch type {
        case 1: text = "进入直播间"
        case 2: text = "关注了主播"
        case 3: text = "分享了直播间"
        case 4: text = "特别关注了主播"
        case 5: text = "与主播互粉"
        default: return nil
        }
        return LiveChatMessage(
            id: "interact-\(string(raw["uid"]) ?? "0")-\(type)-\(timestamp.timeIntervalSince1970)",
            kind: .enter,
            userName: uname,
            text: text,
            color: nil,
            price: nil,
            medalName: nil,
            medalLevel: nil,
            timestamp: timestamp
        )
    }

    private static func string(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        if let string = value.stringValue { return string }
        if let number = value.int64Value { return String(number) }
        return nil
    }

    private static func integer(_ value: JSONValue?) -> Int? {
        guard let value else { return nil }
        if let number = value.int64Value { return Int(number) }
        if let string = value.stringValue { return Int(string) }
        return nil
    }
}

enum LiveFormat {
    static func count(_ value: Int) -> String {
        let number = Double(value)
        switch number {
        case 100_000_000...:
            return String(format: "%.1f亿", number / 100_000_000)
        case 10_000...:
            return String(format: "%.1f万", number / 10_000)
        default:
            return "\(value)"
        }
    }

    static func durationText(since date: Date?) -> String {
        guard let date else { return "" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "已播 \(hours) 小时 \(minutes) 分"
        }
        return "已播 \(minutes) 分钟"
    }
}
