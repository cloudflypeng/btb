import Foundation

struct AccountsData: Decodable {
    let activeMid: Int64
    let accounts: [StoredAccount]

    enum CodingKeys: String, CodingKey {
        case activeMid = "active_mid"
        case accounts
    }
}

struct StoredAccount: Decodable, Identifiable, Equatable {
    let mid: Int64
    let name: String?
    let avatar: String?
    let active: Bool?

    var id: Int64 { mid }
    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "UID \(mid)"
    }
    var avatarURL: URL? { MediaURL.normalize(avatar) }
}

struct QRPayload: Decodable, Equatable {
    let url: String
    let authCode: String

    enum CodingKeys: String, CodingKey {
        case url
        case authCode = "auth_code"
    }
}

struct QRGenerateResponse: Decodable {
    let code: Int
    let message: String?
    let data: QRPayload?
}

struct QRPollResponse: Decodable {
    let code: Int
    let message: String?
    let account: StoredAccount?
}

struct SMSSendResponse: Decodable {
    let code: Int
    let message: String?
    let data: SMSSendData?
}

struct SMSSendData: Decodable {
    let captchaKey: String?
    let recaptchaURL: String?

    enum CodingKeys: String, CodingKey {
        case captchaKey = "captcha_key"
        case recaptchaURL = "recaptcha_url"
    }
}

struct SMSLoginResponse: Decodable {
    let code: Int
    let message: String?
    let account: StoredAccount?
}

struct SMSCaptchaChallenge: Equatable {
    let gt: String
    let challenge: String
    let token: String

    init?(recaptchaURL: String) {
        guard let components = URLComponents(string: recaptchaURL) else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            let raw = items.first(where: { $0.name == name })?.value
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        }
        guard let gt = value("gee_gt"),
              let challenge = value("gee_challenge"),
              let token = value("recaptcha_token") else { return nil }
        self.gt = gt
        self.challenge = challenge
        self.token = token
    }
}

struct NavData: Decodable {
    let isLogin: Bool?
    let mid: Int64?
    let uname: String?
    let face: String?
    let levelInfo: NavLevelInfo?
    let vipStatus: Int?
    let coins: Int?

    enum CodingKeys: String, CodingKey {
        case isLogin
        case mid
        case uname
        case face
        case levelInfo = "level_info"
        case vipStatus
        case coins
    }
}

struct NavLevelInfo: Decodable {
    let currentLevel: Int?

    enum CodingKeys: String, CodingKey {
        case currentLevel = "current_level"
    }
}

struct UserInfoData: Decodable {
    let mid: Int64?
    let name: String?
    let face: String?
    let sign: String?
    let level: Int?
    let topPhoto: String?

    enum CodingKeys: String, CodingKey {
        case mid
        case name
        case face
        case sign
        case level
        case topPhoto = "top_photo"
    }
}

struct UserStatData: Decodable {
    let follower: Int?
    let following: Int?
}

struct UPCardData: Decodable {
    let archiveCount: Int?
    let following: Bool?
    let likeNum: Int?

    enum CodingKeys: String, CodingKey {
        case archiveCount = "archive_count"
        case following
        case likeNum = "like_num"
    }
}

struct UserVideosData: Decodable {
    let list: UserVideoList?
}

struct UserVideoList: Decodable {
    let vlist: [UserVideo]?
}

struct UserVideo: Decodable {
    let bvid: String?
    let title: String?
    let pic: String?
    let author: String?
    let length: String?
    let description: String?
    let play: Int?
    let videoReview: Int?
    let created: Int?

    enum CodingKeys: String, CodingKey {
        case bvid
        case title
        case pic
        case author
        case length
        case description
        case play
        case videoReview = "video_review"
        case created
    }
}

struct UserHistoryData: Decodable {
    let list: [UserHistoryVideo]?
    let cursor: UserHistoryCursor?
}

struct FollowingsData: Decodable {
    let list: [FollowingUser]?
    let total: Int?
}

struct FollowingUser: Decodable {
    let mid: Int64?
    let uname: String?
    let face: String?
    let sign: String?
    let attribute: Int?
    let special: Int?
    let tags: [Int64]?
    let officialVerify: FollowingOfficialVerify?

    enum CodingKeys: String, CodingKey {
        case mid
        case uname
        case face
        case sign
        case attribute
        case special
        case tags = "tag"
        case officialVerify = "official_verify"
    }
}

struct FollowTag: Decodable, Identifiable, Hashable {
    let tagid: Int64
    let name: String
    let count: Int?
    let tip: String?

    var id: Int64 { tagid }
    var isSpecial: Bool { tagid == -10 }
}

struct FollowingOfficialVerify: Decodable {
    let type: Int?
    let desc: String?
}

struct UserHistoryCursor: Decodable {
    let max: Int?
    let viewAt: Int?

    enum CodingKeys: String, CodingKey {
        case max
        case viewAt = "view_at"
    }
}

struct UserHistoryVideo: Decodable {
    let kid: Int64?
    let bvid: String?
    let title: String?
    let cover: String?
    let duration: Int?
    let authorName: String?
    let authorFace: String?
    let viewAt: Int?
    let history: UserHistoryRef?

    enum CodingKeys: String, CodingKey {
        case kid
        case bvid
        case title
        case cover
        case duration
        case authorName = "author_name"
        case authorFace = "author_face"
        case viewAt = "view_at"
        case history
    }
}

struct UserHistoryRef: Decodable {
    let business: String?
    let bvid: String?
    let cid: Int?
}
