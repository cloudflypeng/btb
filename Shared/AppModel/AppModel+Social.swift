#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func loadRecentUPs() async {
        guard coreState == .ready else { return }
        isLoadingRecentUPs = true
        defer { isLoadingRecentUPs = false }

        if hasAccount {
            do {
                let value = try await core.call("dynamic.feed", params: ["type": .string("video")])
                let response = try CoreCoding.decode(UpstreamResponse<DynamicFeedResult>.self, from: value)
                if response.code == 0, let items = response.data?.items, !items.isEmpty {
                    var seen = Set<Int64>()
                    var result: [RecentUP] = []
                    for item in items {
                        guard let card = DynamicModelParser.card(from: item),
                              let mid = card.author.mid, mid > 0,
                              seen.insert(mid).inserted else { continue }
                        result.append(RecentUP(
                            mid: mid,
                            name: card.author.name,
                            avatarURL: card.author.avatarURL,
                            updateText: card.author.pubTime,
                            latestTitle: card.attachment.video?.title ?? card.text
                        ))
                        if result.count >= 8 { break }
                    }
                    if !result.isEmpty {
                        recentUPs = result
                        return
                    }
                }
            } catch {
                // Fall back to the owners of the current feed.
            }
        }

        var seen = Set<Int64>()
        var result: [RecentUP] = []
        for video in videos {
            guard let mid = video.ownerMid, mid > 0, seen.insert(mid).inserted else { continue }
            result.append(RecentUP(
                mid: mid,
                name: video.ownerName,
                avatarURL: video.ownerFaceURL,
                updateText: video.publishedAgoText,
                latestTitle: video.title
            ))
            if result.count >= 8 { break }
        }
        recentUPs = result
    }

    func loadFollowing(force: Bool = false) async {
        guard hasAccount else {
            followingUPs = []
            followingTotal = 0
            followingError = nil
            followingLoaded = false
            followingPager.reset()
            return
        }
        guard force || !followingLoaded, !isLoadingFollowing else { return }
        if force { specialFollowMidsLoaded = false }

        let request = UUID()
        followingRequest = request
        isLoadingFollowing = true
        followingError = nil
        followingPager.reset()
        defer {
            if followingRequest == request {
                isLoadingFollowing = false
            }
        }

        do {
            let page = try await fetchFollowingPage(page: 1)
            guard hasAccount, followingRequest == request else { return }
            followingUPs = page.items
            followingTotal = page.total
            followingLoaded = true
            followingPager.nextPage = 2
            if page.total > 0 {
                followingPager.hasMore = page.items.count < page.total
            } else {
                followingPager.hasMore = page.items.count >= libraryPageSize
            }
        } catch {
            guard hasAccount, followingRequest == request else { return }
            followingError = "关注列表加载失败：\(describe(error))"
            followingPager.hasMore = false
        }
    }

    func loadMoreFollowing() async {
        guard hasAccount,
              !isLoadingFollowing,
              !followingPager.isLoadingMore,
              followingPager.hasMore else { return }
        let request = followingRequest
        followingPager.isLoadingMore = true
        followingPager.failed = false
        defer {
            if followingRequest == request {
                followingPager.isLoadingMore = false
            }
        }

        let page = followingPager.nextPage
        do {
            let result = try await fetchFollowingPage(page: page)
            guard hasAccount, followingRequest == request else { return }
            followingPager.nextPage = page + 1
            if result.items.isEmpty {
                followingPager.stop()
                return
            }
            var seen = Set(followingUPs.map(\.mid))
            for item in result.items where seen.insert(item.mid).inserted {
                followingUPs.append(item)
            }
            if result.total > followingTotal {
                followingTotal = result.total
            }
            if followingTotal > 0 {
                followingPager.hasMore = followingUPs.count < followingTotal
            } else {
                followingPager.hasMore = result.items.count >= libraryPageSize
            }
        } catch {
            guard followingRequest == request else { return }
            followingPager.failed = true
        }
    }

    func loadFollowTags(force: Bool = false) async {
        guard hasAccount else {
            followTags = []
            followTagsLoaded = false
            followTagsError = nil
            return
        }
        guard force || !followTagsLoaded, !isLoadingFollowTags else { return }

        let request = UUID()
        followTagsRequest = request
        isLoadingFollowTags = true
        followTagsError = nil
        defer {
            if followTagsRequest == request {
                isLoadingFollowTags = false
            }
        }

        do {
            let value = try await core.call("user.follow_tags")
            let response = try CoreCoding.decode(UpstreamResponse<[FollowTag]>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注分组加载失败")
            }
            guard hasAccount, followTagsRequest == request else { return }
            followTags = response.data ?? []
            followTagsLoaded = true
        } catch {
            guard followTagsRequest == request else { return }
            followTagsError = "关注分组加载失败：\(describe(error))"
        }
    }

    func selectFollowTag(_ tagID: Int64?) async {
        if selectedFollowTagID == tagID && followSearchKeyword.isEmpty {
            return
        }
        selectedFollowTagID = tagID
        followSearchInput = ""
        followSearchKeyword = ""
        await reloadFollowingList()
    }

    func searchFollowing() async {
        let keyword = followSearchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            await clearFollowingSearch()
            return
        }
        if keyword == followSearchKeyword && selectedFollowTagID == nil {
            return
        }
        selectedFollowTagID = nil
        followSearchKeyword = keyword
        await reloadFollowingList()
    }

    func clearFollowingSearch() async {
        guard !followSearchKeyword.isEmpty || !followSearchInput.isEmpty else { return }
        followSearchInput = ""
        followSearchKeyword = ""
        selectedFollowTagID = nil
        await reloadFollowingList()
    }

    func reloadFollowingList() async {
        followingRequest = UUID()
        isLoadingFollowing = false
        followingPager.reset()
        followingUPs = []
        followingTotal = 0
        followingLoaded = false
        followingError = nil
        await loadFollowing(force: true)
    }

    func loadFollowers(force: Bool = false) async {
        guard hasAccount else {
            followers = []
            followersTotal = 0
            followersError = nil
            followersLoaded = false
            followersPager.reset()
            return
        }
        guard force || !followersLoaded, !isLoadingFollowers else { return }

        let request = UUID()
        followersRequest = request
        isLoadingFollowers = true
        followersError = nil
        followersPager.reset()
        defer {
            if followersRequest == request {
                isLoadingFollowers = false
            }
        }

        do {
            let page = try await fetchFollowersPage(page: 1)
            guard hasAccount, followersRequest == request else { return }
            followers = page.items
            followersTotal = page.total
            followersLoaded = true
            followersPager.nextPage = 2
            if page.total > 0 {
                followersPager.hasMore = page.items.count < page.total
            } else {
                followersPager.hasMore = page.items.count >= libraryPageSize
            }
        } catch {
            guard hasAccount, followersRequest == request else { return }
            followersError = "粉丝列表加载失败：\(describe(error))"
            followersPager.hasMore = false
        }
    }

    func loadMoreFollowers() async {
        guard hasAccount,
              !isLoadingFollowers,
              !followersPager.isLoadingMore,
              followersPager.hasMore else { return }
        let request = followersRequest
        followersPager.isLoadingMore = true
        followersPager.failed = false
        defer {
            if followersRequest == request {
                followersPager.isLoadingMore = false
            }
        }

        let page = followersPager.nextPage
        do {
            let result = try await fetchFollowersPage(page: page)
            guard hasAccount, followersRequest == request else { return }
            followersPager.nextPage = page + 1
            if result.items.isEmpty {
                followersPager.stop()
                return
            }
            var seen = Set(followers.map(\.mid))
            for item in result.items where seen.insert(item.mid).inserted {
                followers.append(item)
            }
            if result.total > followersTotal {
                followersTotal = result.total
            }
            if followersTotal > 0 {
                followersPager.hasMore = followers.count < followersTotal
            } else {
                followersPager.hasMore = result.items.count >= libraryPageSize
            }
        } catch {
            guard followersRequest == request else { return }
            followersPager.failed = true
        }
    }


    func fetchFollowingPage(
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let keyword = followSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            return try await fetchFollowingSearchPage(page: page, keyword: keyword)
        }
        if let tagID = selectedFollowTagID {
            return try await fetchFollowingGroupPage(tagID: tagID, page: page)
        }

        let value = try await core.call("user.followings", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注列表加载失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(response.data?.list ?? [], specialMids: specials)
        return (items, response.data?.total ?? items.count)
    }

    func fetchFollowingGroupPage(
        tagID: Int64,
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.follow_tag_members", params: [
            "tagid": .number(Double(tagID)),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<[FollowingUser]>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "分组加载失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(
            response.data ?? [],
            markingSpecial: tagID == -10,
            specialMids: specials
        )
        let total = followTags.first(where: { $0.tagid == tagID })?.count ?? items.count
        return (items, total)
    }

    func fetchFollowingSearchPage(
        page: Int,
        keyword: String
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.follow_search", params: [
            "name": .string(keyword),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "搜索关注失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(response.data?.list ?? [], specialMids: specials)
        return (items, response.data?.total ?? items.count)
    }

    func fetchFollowersPage(
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.followers", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "粉丝列表加载失败")
        }
        let items = mapFollowing(response.data?.list ?? [])
        return (items, response.data?.total ?? items.count)
    }

    func mapFollowing(
        _ users: [FollowingUser],
        markingSpecial: Bool = false,
        specialMids: Set<Int64> = []
    ) -> [FollowingUP] {
        users.compactMap { user in
            guard let mid = user.mid, mid > 0 else { return nil }
            return FollowingUP(
                mid: mid,
                name: user.uname ?? "UP 主",
                avatarURL: MediaURL.normalize(user.face),
                officialDesc: user.officialVerify?.desc ?? "",
                sign: user.sign ?? "",
                isSpecial: markingSpecial
                    || specialMids.contains(mid)
                    || (user.special ?? 0) == 1
                    || (user.tags?.contains(-10) ?? false),
                relationAttribute: user.attribute ?? 0
            )
        }
    }

    func specialFollowMidsForBadges() async -> Set<Int64> {
        if specialFollowMidsLoaded { return specialFollowMids }
        let value = try? await core.call("user.follow_tag_members", params: [
            "tagid": .number(-10),
            "pn": .number(1),
            "ps": .number(50),
        ])
        guard let value,
              let response = try? CoreCoding.decode(UpstreamResponse<[FollowingUser]>.self, from: value),
              response.code == 0 else {
            return []
        }
        let mids = Set((response.data ?? []).compactMap { $0.mid })
        specialFollowMids = mids
        specialFollowMidsLoaded = true
        return mids
    }

    func resetSocial() {
        followingRequest = UUID()
        isLoadingFollowing = false
        followingUPs = []
        followingTotal = 0
        followingLoaded = false
        followingError = nil
        followingPager.reset()
        followTags = []
        followTagsLoaded = false
        followTagsError = nil
        isLoadingFollowTags = false
        followTagsRequest = UUID()
        selectedFollowTagID = nil
        followSearchInput = ""
        followSearchKeyword = ""
        specialFollowMids = []
        specialFollowMidsLoaded = false
        followersRequest = UUID()
        isLoadingFollowers = false
        followers = []
        followersTotal = 0
        followersLoaded = false
        followersError = nil
        followersPager.reset()
    }
}
