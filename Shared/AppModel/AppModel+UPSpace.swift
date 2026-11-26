#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func openUP(_ up: RecentUP) {
        openUP(mid: up.mid, name: up.name, avatarURL: up.avatarURL)
    }

    func openUP(mid: Int64, name: String? = nil, avatarURL: URL? = nil) {
        closeVideo()
        activeDynamic = nil
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        section = .home
        if activeUPMid != mid {
            upVideos = []
            upError = nil
            upPager.reset()
        }
        activeUPMid = mid
        if let name {
            activeUP = UPProfile(
                mid: mid,
                name: name,
                avatarURL: avatarURL,
                sign: "",
                level: 0,
                follower: 0,
                following: 0,
                topPhotoURL: nil,
                archiveCount: 0,
                isFollowed: false
            )
        } else if activeUP?.mid != mid {
            activeUP = nil
        }
    }

    func closeUP() {
        activeUPMid = nil
        activeUP = nil
        upVideos = []
        upError = nil
        isLoadingUP = false
        upPager.reset()
    }

    func loadUP(mid: Int64) async {
        guard coreState == .ready else { return }
        isLoadingUP = true
        upError = nil
        upPager.reset()
        defer {
            if activeUPMid == mid { isLoadingUP = false }
        }

        do {
            let info = try await fetchUPInfo(mid: mid)
            guard activeUPMid == mid else { return }

            let placeholder = UPProfile(
                mid: mid,
                name: info.name ?? activeUP?.name ?? "UP 主",
                avatarURL: MediaURL.normalize(info.face) ?? activeUP?.avatarURL,
                sign: info.sign ?? "",
                level: info.level ?? 0,
                follower: 0,
                following: 0,
                topPhotoURL: MediaURL.normalize(info.topPhoto),
                archiveCount: 0,
                isFollowed: false
            )
            activeUP = placeholder

            async let statTask = fetchUPStat(mid: mid)
            async let cardTask = fetchUPCard(mid: mid)
            async let videosTask = fetchUPVideos(mid: mid, page: 1)
            async let relationTask = fetchUPRelation(mid: mid)
            let stat = await statTask
            let card = await cardTask
            let videos = (try? await videosTask) ?? []
            let relation = await relationTask
            guard activeUPMid == mid else { return }

            activeUP = UPProfile(
                mid: mid,
                name: placeholder.name,
                avatarURL: placeholder.avatarURL,
                sign: placeholder.sign,
                level: placeholder.level,
                follower: stat?.follower ?? 0,
                following: stat?.following ?? 0,
                topPhotoURL: placeholder.topPhotoURL,
                archiveCount: card?.archiveCount ?? videos.count,
                isFollowed: card?.following ?? false,
                isBlocked: relation?.attribute == 128
            )
            upVideos = videos
            upPager.nextPage = 2
            upPager.hasMore = videos.count >= libraryPageSize
        } catch {
            guard activeUPMid == mid else { return }
            upError = "UP 主信息加载失败：\(describe(error))"
            upPager.hasMore = false
        }
    }

    func loadMoreUP() async {
        guard let mid = activeUPMid,
              !isLoadingUP,
              !upPager.isLoadingMore,
              upPager.hasMore else { return }
        upPager.isLoadingMore = true
        upPager.failed = false
        defer {
            if activeUPMid == mid { upPager.isLoadingMore = false }
        }

        let page = upPager.nextPage
        do {
            let items = try await fetchUPVideos(mid: mid, page: page)
            guard activeUPMid == mid else { return }
            upPager.nextPage = page + 1
            if items.isEmpty {
                upPager.stop()
                return
            }
            _ = appendUnique(items, to: &upVideos)
            var hasMore = items.count >= libraryPageSize
            if let count = activeUP?.archiveCount, count > 0, upVideos.count >= count {
                hasMore = false
            }
            upPager.hasMore = hasMore
        } catch {
            guard activeUPMid == mid else { return }
            upPager.failed = true
        }
    }

    func toggleUPFollow() async {
        guard let mid = activeUPMid, var up = activeUP else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard !isUpFollowBusy else { return }
        isUpFollowBusy = true
        defer { isUpFollowBusy = false }

        let target = !up.isFollowed
        do {
            let value = try await core.call("user.follow", params: [
                "fid": .number(Double(mid)),
                "follow": .bool(target),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "操作失败")
            }
            up.isFollowed = target
            activeUP = up
            showToast(target ? "已关注" : "已取消关注")
        } catch {
            showToast("操作失败：\(describe(error))")
        }
    }

    func setUPBlocked(_ blocked: Bool) async {
        guard let mid = activeUPMid, var up = activeUP else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard !isUpFollowBusy else { return }
        isUpFollowBusy = true
        defer { isUpFollowBusy = false }

        do {
            let value = try await core.call("user.follow", params: [
                "fid": .number(Double(mid)),
                "act": .number(Double(blocked ? 5 : 6)),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "操作失败")
            }
            up.isBlocked = blocked
            if blocked {
                up.isFollowed = false
            }
            activeUP = up
            showToast(blocked ? "已拉黑该 UP 主" : "已解除拉黑")
        } catch {
            showToast("操作失败：\(describe(error))")
        }
    }

    func fetchUPRelation(mid: Int64) async -> UPRelationData? {
        do {
            let value = try await core.call("user.relation", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UPRelationData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    func fetchUPInfo(mid: Int64) async throws -> UserInfoData {
        let value = try await core.call("user.info", params: ["mid": .number(Double(mid))])
        let response = try CoreCoding.decode(UpstreamResponse<UserInfoData>.self, from: value)
        guard response.code == 0, let data = response.data else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "UP 主信息加载失败")
        }
        return data
    }

    func fetchUPStat(mid: Int64) async -> UserStatData? {
        do {
            let value = try await core.call("user.stat", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserStatData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    func fetchUPCard(mid: Int64) async -> UPCardData? {
        do {
            let value = try await core.call("user.card", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UPCardData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    func fetchUPVideos(mid: Int64, page: Int) async throws -> [VideoItem] {
        let value = try await core.call("user.videos", params: [
            "mid": .number(Double(mid)),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<UserVideosData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "投稿加载失败")
        }
        return (response.data?.list?.vlist ?? []).compactMap(VideoItem.init(userVideo:))
    }
}
