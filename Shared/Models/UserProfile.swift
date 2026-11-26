import Foundation

enum MediaURL {
    static func normalize(_ raw: String?) -> URL? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("//") {
            value = "https:" + value
        } else if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        }
        return URL(string: value)
    }
}

struct UserProfile: Identifiable, Equatable {
    let mid: Int64
    let name: String
    let avatarURL: URL?
    let sign: String
    let level: Int
    let follower: Int
    let following: Int

    var id: Int64 { mid }
    var spaceURL: URL { URL(string: "https://space.bilibili.com/\(mid)")! }
}

struct RecentUP: Identifiable, Hashable {
    let mid: Int64
    let name: String
    let avatarURL: URL?
    let updateText: String
    let latestTitle: String

    var id: Int64 { mid }
}

struct FollowingUP: Identifiable, Hashable {
    let mid: Int64
    let name: String
    let avatarURL: URL?
    let officialDesc: String
    let sign: String
    var isSpecial: Bool = false
    var relationAttribute: Int = 0

    var id: Int64 { mid }
    var isMutual: Bool { relationAttribute == 6 }
}

struct UPProfile: Identifiable, Equatable {
    let mid: Int64
    var name: String
    var avatarURL: URL?
    var sign: String
    var level: Int
    var follower: Int
    var following: Int
    var topPhotoURL: URL?
    var archiveCount: Int
    var isFollowed: Bool
    var isBlocked: Bool = false

    var id: Int64 { mid }
    var spaceURL: URL { URL(string: "https://space.bilibili.com/\(mid)")! }
}

struct UPRelationData: Decodable {
    let mid: Int64?
    let attribute: Int?
    let special: Int?
}

struct FavFolder: Identifiable, Hashable {
    let id: Int64
    var title: String
    var coverURL: URL?
    var count: Int
    var intro: String = ""
    var cover: String = ""
    var isPrivate: Bool = false
    var isDefault: Bool = false

    init?(raw: FavFolderRaw) {
        guard let id = raw.id else { return nil }
        self.id = id
        title = raw.title ?? "未命名收藏夹"
        coverURL = MediaURL.normalize(raw.cover)
        count = raw.mediaCount ?? 0
        intro = raw.intro ?? ""
        cover = raw.cover ?? ""
        let attr = raw.attr ?? 0
        isPrivate = attr & 1 == 1
        isDefault = attr == 0
    }

    init(
        id: Int64,
        title: String,
        coverURL: URL?,
        count: Int,
        intro: String = "",
        cover: String = "",
        isPrivate: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.count = count
        self.intro = intro
        self.cover = cover
        self.isPrivate = isPrivate
        self.isDefault = isDefault
    }
}
