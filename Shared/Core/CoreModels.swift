import Foundation

struct UpstreamResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

struct HotData: Decodable {
    let list: [HotVideo]?
}

struct RecommendData: Decodable {
    let item: [HotVideo]?
}

struct LaterData: Decodable {
    let list: [HotVideo]?
    let count: Int?
}

struct FavFoldersData: Decodable {
    let list: [FavFolderRaw]?
    let count: Int?
}

struct FavFolderRaw: Decodable {
    let id: Int64?
    let title: String?
    let cover: String?
    let intro: String?
    let mediaCount: Int?
    let attr: Int?
    let favState: Int?
    let state: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case cover
        case intro
        case mediaCount = "media_count"
        case attr
        case favState = "fav_state"
        case state
    }
}

struct FavListData: Decodable {
    let info: FavFolderRaw?
    let medias: [FavMedia]?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case info
        case medias
        case hasMore = "has_more"
    }
}

struct FavMedia: Decodable {
    let id: Int64?
    let type: Int?
    let bvid: String?
    let title: String?
    let cover: String?
    let duration: Int?
    let intro: String?
    let pubtime: Int?
    let favTime: Int64?
    let upper: FavUpper?
    let countInfo: FavCountInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case bvid
        case title
        case cover
        case duration
        case intro
        case pubtime
        case favTime = "fav_time"
        case upper
        case countInfo = "cnt_info"
    }
}

struct FavUpper: Decodable {
    let mid: Int64?
    let name: String?
    let face: String?
}

struct FavCountInfo: Decodable {
    let play: Int?
    let danmaku: Int?
    let collect: Int?
}

struct HotVideo: Decodable {
    let aid: Int64?
    let bvid: String?
    let cid: Int?
    let title: String?
    let pic: String?
    let cover43: String?
    let desc: String?
    let duration: Int?
    let pubdate: Int?
    let owner: HotOwner?
    let stat: HotStat?
}

struct HotOwner: Decodable {
    let mid: Int64?
    let name: String?
    let face: String?
}

struct HotStat: Decodable {
    let view: Int?
    let danmaku: Int?
    let like: Int?
}

struct SearchVideo: Decodable {
    let aid: Int64?
    let bvid: String?
    let title: String?
    let pic: String?
    let author: String?
    let upic: String?
    let play: Int?
    let danmaku: Int?
    let duration: StringOrInt?
    let pubdate: Int?
    let description: String?
}

struct StringOrInt: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            value = ""
        }
    }
}
