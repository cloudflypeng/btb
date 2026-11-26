#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func setDynamicFeedType(_ type: DynamicFeedType) async {
        guard type != dynamicFeedType else { return }
        dynamicFeedType = type
        await loadDynamicFeed(reset: true)
    }

    func loadDynamicFeed(reset: Bool = false) async {
        guard coreState == .ready else { return }
        if reset {
            dynamicRequest = UUID()
            dynamicCards = []
            dynamicOffset = ""
            dynamicHasMore = false
            dynamicLoaded = false
            dynamicError = nil
            // A reset supersedes any in-flight load; its late response is
            // dropped by the request check and must not keep the spinner up.
            isLoadingDynamic = false
        } else {
            guard !dynamicLoaded else { return }
        }
        guard hasAccount else {
            dynamicLoaded = true
            dynamicError = nil
            return
        }
        guard !isLoadingDynamic else { return }

        let request = dynamicRequest
        isLoadingDynamic = true
        dynamicError = nil
        defer {
            if dynamicRequest == request {
                isLoadingDynamic = false
                dynamicLoaded = true
            }
        }

        do {
            var params: [String: JSONValue] = ["type": .string(dynamicFeedType.rawValue)]
            if !dynamicOffset.isEmpty {
                params["offset"] = .string(dynamicOffset)
            }
            let value = try await core.call("dynamic.feed", params: params)
            let response = try CoreCoding.decode(UpstreamResponse<DynamicFeedResult>.self, from: value)
            guard dynamicRequest == request else { return }
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "动态加载失败")
            }
            let cards = (response.data?.items ?? []).compactMap(DynamicModelParser.card)
            appendUniqueDynamic(cards)
            dynamicOffset = response.data?.offset ?? ""
            dynamicHasMore = response.data?.hasMore ?? false
#if DEBUG
            if activeDynamic == nil,
               ProcessInfo.processInfo.environment["BTB_OPEN_DYNAMIC"] == "1",
               let first = dynamicCards.first {
                openDynamic(first)
            }
#endif
        } catch {
            guard dynamicRequest == request else { return }
            dynamicError = "动态加载失败：\(describe(error))"
        }
    }

    func loadMoreDynamic() async {
        guard dynamicHasMore, !isLoadingDynamic, dynamicError == nil else { return }
        dynamicLoaded = false
        await loadDynamicFeed()
    }

    func appendUniqueDynamic(_ cards: [DynamicCard]) {
        var existing = Set(dynamicCards.map(\.id))
        for card in cards where !existing.contains(card.id) {
            dynamicCards.append(card)
            existing.insert(card.id)
        }
    }

    func toggleDynamicLike(_ card: DynamicCard) async {
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        let wasLiked = card.isLiked
        let previousCount = card.likeCount
        let nextLiked = !wasLiked
        let nextCount = max(0, previousCount + (wasLiked ? -1 : 1))

        func apply(isLiked: Bool, likeCount: Int) {
            if let index = dynamicCards.firstIndex(where: { $0.id == card.id }) {
                dynamicCards[index].isLiked = isLiked
                dynamicCards[index].likeCount = likeCount
            }
            if activeDynamic?.id == card.id {
                activeDynamic?.isLiked = isLiked
                activeDynamic?.likeCount = likeCount
            }
        }
        apply(isLiked: nextLiked, likeCount: nextCount)

        do {
            let value = try await core.call("dynamic.like", params: [
                "id": .string(card.id),
                "like": .bool(nextLiked),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "点赞失败")
            }
        } catch {
            apply(isLiked: wasLiked, likeCount: previousCount)
            showToast("操作失败，请稍后重试")
        }
    }

    func openDynamic(_ card: DynamicCard) {
        closeVideo()
        closeUP()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        section = .dynamic
        activeDynamic = card
        dynamicComments = []
        dynamicCommentTotal = 0
        dynamicCommentPage = 0
        dynamicCommentNextOffset = 0
        dynamicCommentsError = nil
    }

    func closeDynamic() {
        activeDynamic = nil
        dynamicComments = []
        dynamicCommentTotal = 0
        dynamicCommentPage = 0
        dynamicCommentNextOffset = 0
        dynamicCommentsError = nil
    }

    func loadDynamicComments(for card: DynamicCard, reset: Bool = false) async {
        guard card.commentType > 0, let oid = Int64(card.commentID), oid > 0 else {
            dynamicCommentsError = "该动态暂不支持评论"
            return
        }
        guard !isLoadingDynamicComments else { return }
        if reset {
            dynamicComments = []
            dynamicCommentTotal = 0
            dynamicCommentPage = 0
            dynamicCommentNextOffset = 0
        } else {
            guard dynamicComments.count < dynamicCommentTotal else { return }
        }
        let nextPage = reset ? 1 : dynamicCommentPage + 1
        isLoadingDynamicComments = true
        dynamicCommentsError = nil
        defer { isLoadingDynamicComments = false }
        do {
            let result = try await fetchComments(
                oid: oid,
                type: String(card.commentType),
                page: nextPage,
                sort: 0,
                nextOffset: dynamicCommentNextOffset
            )
            guard activeDynamic?.id == card.id else { return }
            if reset {
                dynamicComments = result.items
            } else {
                var existing = Set(dynamicComments.map(\.id))
                dynamicComments.append(contentsOf: result.items.filter { existing.insert($0.id).inserted })
            }
            dynamicCommentTotal = result.total
            dynamicCommentPage = nextPage
            dynamicCommentNextOffset = result.nextOffset
        } catch {
            guard activeDynamic?.id == card.id else { return }
            dynamicCommentsError = "评论加载失败"
        }
    }

    func postDynamicComment(
        _ text: String,
        card: DynamicCard,
        replyTo comment: VideoComment? = nil,
        rootID: Int64? = nil
    ) async -> Bool {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let oid = Int64(card.commentID), oid > 0 else { return false }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return false
        }
        isPostingDynamicComment = true
        defer { isPostingDynamicComment = false }
        do {
            var params: [String: JSONValue] = [
                "oid": .integer(oid),
                "type": .string(String(card.commentType)),
                "message": .string(message),
            ]
            if let comment {
                params["root"] = .integer(rootID ?? comment.id)
                params["parent"] = .integer(comment.id)
            }
            let value = try await core.call("reply.add", params: params)
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "评论失败")
            }
            await loadDynamicComments(for: card, reset: true)
            showToast(comment == nil ? "评论已发布" : "回复已发布")
            return true
        } catch {
            showToast(comment == nil ? "评论发布失败，请稍后重试" : "回复失败，请稍后重试")
            return false
        }
    }

    func toggleDynamicCommentLike(_ comment: VideoComment, card: DynamicCard) async {
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard let oid = Int64(card.commentID),
              let index = dynamicComments.firstIndex(where: { $0.id == comment.id }) else { return }
        let wasLiked = dynamicComments[index].isLiked
        let previousCount = dynamicComments[index].likeCount
        dynamicComments[index].isLiked = !wasLiked
        dynamicComments[index].likeCount = max(0, previousCount + (wasLiked ? -1 : 1))
        do {
            let value = try await core.call("reply.like", params: [
                "oid": .integer(oid),
                "type": .string(String(card.commentType)),
                "rpid": .integer(comment.id),
                "action": .number(wasLiked ? 0 : 1),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "点赞失败")
            }
        } catch {
            if let index = dynamicComments.firstIndex(where: { $0.id == comment.id }) {
                dynamicComments[index].isLiked = wasLiked
                dynamicComments[index].likeCount = previousCount
            }
            showToast("操作失败，请稍后重试")
        }
    }

    func reportDynamicComment(_ comment: VideoComment, card: DynamicCard, reason: Int) async {
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard let oid = Int64(card.commentID) else { return }
        do {
            let value = try await core.call("reply.report", params: [
                "oid": .integer(oid),
                "type": .string(String(card.commentType)),
                "rpid": .integer(comment.id),
                "reason": .integer(Int64(reason)),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "举报失败")
            }
            showToast("举报已提交")
        } catch {
            showToast("举报失败，请稍后重试")
        }
    }

    var filteredLiveRooms: [LiveRoom] {
        switch liveFeedFilter {
        case .live: return liveRooms.filter(\.isLive)
        case .all: return liveRooms
        }
    }
}
