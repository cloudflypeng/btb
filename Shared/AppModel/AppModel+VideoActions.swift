#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func toggleLike() async {
        guard let video = currentVideo else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        let next = !(relation?.like ?? false)
        let previous = relation
        if relation == nil {
            relation = VideoRelationData(attention: nil, like: next, coin: nil, favorite: nil, dislike: nil)
        } else {
            relation?.like = next
        }
        do {
            let value = try await core.call("video.like", params: [
                "bvid": .string(video.bvid),
                "like": .bool(next),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "点赞失败")
            }
            showToast(next ? "已点赞" : "已取消点赞")
        } catch {
            relation = previous
            showToast("操作失败，请稍后重试")
        }
    }

    func addCoin(multiply: Int = 1) async {
        guard let video = currentVideo else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        do {
            let value = try await core.call("video.coin", params: [
                "bvid": .string(video.bvid),
                "multiply": .number(Double(multiply)),
                "select_like": .number(0),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "投币失败")
            }
            if relation == nil {
                relation = VideoRelationData(
                    attention: nil,
                    like: nil,
                    coin: multiply,
                    favorite: nil,
                    dislike: nil
                )
            } else {
                relation?.coin = (relation?.coin ?? 0) + multiply
            }
            showToast("已投 \(multiply) 枚硬币")
        } catch {
            showToast("操作失败，请稍后重试")
        }
    }

    func tripleVideo() async {
        guard let video = currentVideo else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        do {
            let value = try await core.call("video.triple", params: ["bvid": .string(video.bvid)])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "三连失败")
            }
            if relation == nil {
                relation = VideoRelationData(
                    attention: nil,
                    like: true,
                    coin: 2,
                    favorite: true,
                    dislike: nil
                )
            } else {
                relation?.like = true
                relation?.coin = 2
                relation?.favorite = true
            }
            showToast("一键三连成功")
        } catch {
            showToast("操作失败，请稍后重试")
        }
    }

    func addToFavorite(folderID: Int64) async {
        guard let video = currentVideo else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard let aid = detail?.aid ?? video.aid, aid > 0 else {
            showToast("暂时无法收藏该视频")
            return
        }
        do {
            let value = try await core.call("fav.add", params: [
                "resources": .string("\(aid):2"),
                "add_media_ids": .string(String(folderID)),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "收藏失败")
            }
            if relation == nil {
                relation = VideoRelationData(
                    attention: nil,
                    like: nil,
                    coin: nil,
                    favorite: true,
                    dislike: nil
                )
            } else {
                relation?.favorite = true
            }
            showToast("已收藏")
        } catch {
            showToast("收藏失败，请稍后重试")
        }
    }

    func toggleFollow() async {
        guard let mid = detail?.owner?.mid, mid > 0 else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        let next = !(relation?.attention ?? false)
        let previous = relation
        if relation == nil {
            relation = VideoRelationData(attention: next, like: nil, coin: nil, favorite: nil, dislike: nil)
        } else {
            relation?.attention = next
        }
        do {
            let value = try await core.call("user.follow", params: [
                "fid": .number(Double(mid)),
                "follow": .bool(next),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注失败")
            }
            showToast(next ? "已关注 UP 主" : "已取消关注")
        } catch {
            relation = previous
            showToast("操作失败，请稍后重试")
        }
    }

    func addToWatchLater() async {
        guard let video = currentVideo else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        if watchLaterVideos.contains(video.bvid) {
            showToast("已在稍后再看")
            return
        }
        do {
            let value = try await core.call("user.later.add", params: ["bvid": .string(video.bvid)])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "添加失败")
            }
            watchLaterVideos.insert(video.bvid)
            showToast("已添加到稍后再看")
        } catch {
            showToast("添加失败，请稍后重试")
        }
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        toastMessage = text
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    func fetchVideoInfo(bvid: String) async throws -> VideoInfoData {
        let value = try await core.call("video.info", params: ["bvid": .string(bvid)])
        let response = try CoreCoding.decode(UpstreamResponse<VideoInfoData>.self, from: value)
        guard response.code == 0, let data = response.data else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "无法获取视频信息")
        }
        return data
    }

    func fetchRelatedVideos(bvid: String) async -> [VideoItem] {
        do {
            let value = try await core.call("video.related", params: ["bvid": .string(bvid)])
            let response = try CoreCoding.decode(UpstreamResponse<[RelatedVideo]>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data ?? []).compactMap(VideoItem.init(related:))
        } catch {
            return []
        }
    }

    func fetchComments(
        aid: Int64,
        page: Int,
        sort: Int,
        nextOffset: Int
    ) async throws -> (items: [VideoComment], total: Int, nextOffset: Int) {
        try await fetchComments(
            oid: aid,
            type: "1",
            page: page,
            sort: sort,
            nextOffset: nextOffset
        )
    }

    func fetchComments(
        oid: Int64,
        type: String,
        page: Int,
        sort: Int,
        nextOffset: Int
    ) async throws -> (items: [VideoComment], total: Int, nextOffset: Int) {
        var params: [String: JSONValue] = [
            "oid": .integer(oid),
            "type": .string(type),
        ]
        if hasAccount {
            params["pn"] = .number(Double(page))
            params["ps"] = .number(20)
            params["sort"] = .number(Double(sort))
        } else {
            params["mode"] = .number(sort == 0 ? 3 : 2)
            if nextOffset > 0 {
                params["next"] = .integer(Int64(nextOffset))
            }
        }

        let value = try await core.call("reply.list", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<ReplyData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "评论加载失败")
        }

        var seen = Set<Int64>()
        var items: [VideoComment] = []
        let raw = (response.data?.topReplies ?? []) + (response.data?.replies ?? [])
        for (index, reply) in raw.enumerated() {
            guard let item = VideoComment(raw: reply, index: index) else { continue }
            if seen.insert(item.id).inserted {
                items.append(item)
            }
        }
        let total = response.data?.cursor?.allCount
            ?? response.data?.page?.acount
            ?? response.data?.page?.count
            ?? items.count
        let next = response.data?.cursor?.next ?? 0
        return (items, total, next)
    }

    func fetchCommentThread(
        oid: Int64,
        type: String,
        rootID: Int64,
        page: Int
    ) async throws -> (items: [VideoComment], total: Int) {
        guard oid > 0, rootID > 0 else {
            throw BBCoreError.upstream(code: -1, message: "评论目标无效")
        }
        let value = try await core.call("reply.replies", params: [
            "oid": .integer(oid),
            "type": .string(type),
            "root": .integer(rootID),
            "pn": .number(Double(page)),
            "sort": .number(1),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<ReplyData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "回复加载失败")
        }
        let items = (response.data?.replies ?? [])
            .enumerated()
            .compactMap { offset, reply in
                VideoComment(raw: reply, index: page * 100 + offset)
            }
        let total = max(response.data?.page?.count ?? 0, items.count)
        return (items, total)
    }

    func fetchRelation(bvid: String) async -> VideoRelationData? {
        guard hasAccount else { return nil }
        do {
            let value = try await core.call("video.relation", params: ["bvid": .string(bvid)])
            let response = try CoreCoding.decode(UpstreamResponse<VideoRelationData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }
}
