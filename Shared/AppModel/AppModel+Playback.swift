#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func startStream(for video: VideoItem, qn: Int64 = 80, codec: String = "hevc") async throws -> StreamSession {
        try await startStream(bvid: video.bvid, cid: video.cid.map(Int64.init), qn: qn, codec: codec)
    }

    func startStream(bvid: String, cid: Int64?, qn: Int64 = 80, codec: String = "hevc") async throws -> StreamSession {
        guard coreState == .ready else { throw BBCoreError.notStarted }
        var params: [String: JSONValue] = [
            "bvid": .string(bvid),
            "qn": .number(Double(qn)),
            "codec": .string(codec),
        ]
        if let cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        }

        do {
            return try await startStream(params: params)
        } catch {
            guard codec != "avc" else { throw error }
            params["codec"] = .string("avc")
            return try await startStream(params: params)
        }
    }

    func resolvePlayback(
        for video: VideoItem,
        page: Int = 1,
        qn: Int64 = 127,
        codec: String = "hevc",
        cid: Int64? = nil
    ) async throws -> PlayerResolveResult {
        guard coreState == .ready else { throw BBCoreError.notStarted }
        var params: [String: JSONValue] = [
            "bvid": .string(video.bvid),
            "page": .number(Double(page)),
            "qn": .number(Double(qn)),
            "codec": .string(codec),
        ]
        if let cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        } else if let storedCID = video.cid, storedCID > 0 {
            params["cid"] = .number(Double(storedCID))
        }
        let value = try await core.call("player.resolve", params: params)
        return try CoreCoding.decode(PlayerResolveResult.self, from: value)
    }

    func reportPlaybackProgress(
        for video: VideoItem,
        cid: Int64,
        progressMS: Int64,
        event: String
    ) async {
        guard coreState == .ready, cid > 0 else { return }
        _ = try? await core.call("player.progress", params: [
            "bvid": .string(video.bvid),
            "cid": .number(Double(cid)),
            "progress_ms": .number(Double(max(progressMS, -1))),
            "event": .string(event),
        ])
    }

    func fetchSubtitleCues(url: String) async throws -> [SubtitleCue] {
        guard coreState == .ready else { throw BBCoreError.notStarted }
        let value = try await core.call("video.subtitle_vtt", params: ["url": .string(url)])
        let response = try CoreCoding.decode(SubtitleVTTResponse.self, from: value)
        return WebVTTParser.parse(response.vtt)
    }

    func fetchDanmaku(cid: Int64, segment: Int) async throws -> [DanmakuItem] {
        guard coreState == .ready else { throw BBCoreError.notStarted }
        let value = try await core.call("danmaku.seg", params: [
            "cid": .number(Double(cid)),
            "segment_index": .number(Double(segment)),
        ])
        let response = try CoreCoding.decode(DanmakuSegmentResponse.self, from: value)
        return (response.elems ?? []).compactMap(DanmakuItem.init(elem:))
    }

    func sendDanmaku(
        cid: Int64,
        bvid: String,
        progressMS: Int64,
        content: String
    ) async -> Bool {
        let message = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return false }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return false
        }
        do {
            let value = try await core.call("danmaku.send", params: [
                "cid": .number(Double(cid)),
                "bvid": .string(bvid),
                "msg": .string(message),
                "progress": .number(Double(max(progressMS, 0))),
                "mode": .number(1),
                "color": .number(16_777_215),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "弹幕发送失败")
            }
            showToast("弹幕已发送")
            return true
        } catch {
            showToast("弹幕发送失败，请稍后重试")
            return false
        }
    }

    func stopStream(sessionID: String) async {
        _ = try? await core.call("stream.stop", params: ["session_id": .string(sessionID)])
    }

    func startStream(params: [String: JSONValue]) async throws -> StreamSession {
        let value = try await core.call("stream.start", params: params)
        return try CoreCoding.decode(StreamSession.self, from: value)
    }

    func openVideo(_ video: VideoItem) {
        if currentVideo?.bvid == video.bvid { return }
        Perf.begin("video.firstFrame")
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        detailBVID = video.bvid
        detail = nil
        relatedVideos = []
        comments = []
        commentTotal = 0
        commentPage = 0
        commentNextOffset = 0
        relation = nil
        videoTags = []
        aiConclusion = nil
        isLoadingAI = false
        detailError = nil
        commentsError = nil
        navigationPath = [video]
    }

    func closeVideo() {
        navigationPath.removeAll()
        detailBVID = nil
    }

    func loadWatchPage(for video: VideoItem, force: Bool = false) async {
        if !force, detail?.bvid == video.bvid {
            return
        }
        detailBVID = video.bvid
        isLoadingDetail = true
        isLoadingRelated = true
        isLoadingComments = false
        isLoadingAI = true
        detailError = nil
        commentsError = nil
        if force {
            detail = nil
            relatedVideos = []
            comments = []
            commentTotal = 0
            commentPage = 0
            commentNextOffset = 0
            videoTags = []
            aiConclusion = nil
        }
        defer {
            if detailBVID == video.bvid {
                isLoadingDetail = false
                isLoadingRelated = false
                isLoadingComments = false
                isLoadingAI = false
            }
        }

        do {
            let info = try await fetchVideoInfo(bvid: video.bvid)
            guard detailBVID == video.bvid else { return }
            detail = info

            async let relatedTask = fetchRelatedVideos(bvid: video.bvid)
            async let tagsTask = fetchVideoTags(bvid: video.bvid)
            async let aiTask = fetchAIConclusion(
                bvid: video.bvid,
                cid: info.cid,
                upMid: info.owner?.mid
            )
            if let aid = info.aid {
                isLoadingComments = true
                async let commentsTask = fetchComments(
                    aid: aid,
                    page: 1,
                    sort: commentSort,
                    nextOffset: 0
                )
                async let relationTask = fetchRelation(bvid: video.bvid)
                do {
                    let result = try await commentsTask
                    guard detailBVID == video.bvid else { return }
                    comments = result.items
                    commentTotal = result.total
                    commentPage = 1
                    commentNextOffset = result.nextOffset
                } catch {
                    guard detailBVID == video.bvid else { return }
                    commentsError = "评论加载失败"
                }
                relation = await relationTask
                isLoadingComments = false
            }

            let related = await relatedTask
            guard detailBVID == video.bvid else { return }
            relatedVideos = related
            isLoadingRelated = false

            let tags = await tagsTask
            if detailBVID == video.bvid {
                videoTags = tags
            }
            let ai = await aiTask
            if detailBVID == video.bvid {
                aiConclusion = ai
                isLoadingAI = false
            }
        } catch {
            guard detailBVID == video.bvid else { return }
            detailError = "视频信息加载失败：\(describe(error))"
        }
    }

    func fetchVideoTags(bvid: String) async -> [String] {
        guard hasAccount else { return [] }
        do {
            let value = try await core.call("video.tags", params: ["bvid": .string(bvid)])
            let response = try CoreCoding.decode(UpstreamResponse<[VideoTagItem]>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data ?? [])
                .compactMap(\.tagName)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    func fetchAIConclusion(bvid: String, cid: Int?, upMid: Int64?) async -> AIConclusionResult? {
        guard hasAccount else { return nil }
        var params: [String: JSONValue] = ["bvid": .string(bvid)]
        if let cid {
            params["cid"] = .number(Double(cid))
        }
        if let upMid, upMid > 0 {
            params["up_mid"] = .number(Double(upMid))
        }
        do {
            let value = try await core.call("video.ai_conclusion", params: params)
            let response = try CoreCoding.decode(UpstreamResponse<AIConclusionData>.self, from: value)
            guard response.code == 0,
                  let result = response.data?.modelResult,
                  !(result.summary ?? "").isEmpty || !(result.outline ?? []).isEmpty else {
                return nil
            }
            return result
        } catch {
            return nil
        }
    }

    func loadMoreComments() async {
        guard hasAccount,
              let aid = detail?.aid,
              !isLoadingComments,
              comments.count < commentTotal else { return }
        let nextPage = commentPage + 1
        isLoadingComments = true
        commentsError = nil
        defer { isLoadingComments = false }
        do {
            let result = try await fetchComments(
                aid: aid,
                page: nextPage,
                sort: commentSort,
                nextOffset: commentNextOffset
            )
            comments.append(contentsOf: result.items)
            commentTotal = result.total
            commentPage = nextPage
            commentNextOffset = result.nextOffset
        } catch {
            commentsError = "更多评论加载失败"
        }
    }

    func setCommentSort(_ sort: Int) async {
        guard sort != commentSort else { return }
        commentSort = sort
        await reloadComments()
    }

    func reloadComments() async {
        guard let aid = detail?.aid else { return }
        isLoadingComments = true
        commentsError = nil
        defer { isLoadingComments = false }
        do {
            let result = try await fetchComments(
                aid: aid,
                page: 1,
                sort: commentSort,
                nextOffset: 0
            )
            comments = result.items
            commentTotal = result.total
            commentPage = 1
            commentNextOffset = result.nextOffset
        } catch {
            commentsError = "评论加载失败"
        }
    }

    func postComment(
        _ text: String,
        replyTo comment: VideoComment? = nil,
        rootID: Int64? = nil
    ) async -> Bool {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let aid = detail?.aid else { return false }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return false
        }
        isPostingComment = true
        defer { isPostingComment = false }
        do {
            var params: [String: JSONValue] = [
                "oid": .integer(aid),
                "type": .string("1"),
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
            await reloadComments()
            showToast(comment == nil ? "评论已发布" : "回复已发布")
            return true
        } catch {
            showToast(comment == nil ? "评论发布失败，请稍后重试" : "回复失败，请稍后重试")
            return false
        }
    }

    func toggleCommentLike(_ comment: VideoComment) async {
        guard let aid = detail?.aid else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let wasLiked = comments[index].isLiked
        let previousCount = comments[index].likeCount
        comments[index].isLiked = !wasLiked
        comments[index].likeCount = max(0, previousCount + (wasLiked ? -1 : 1))
        do {
            let value = try await core.call("reply.like", params: [
                "oid": .integer(aid),
                "type": .string("1"),
                "rpid": .integer(comment.id),
                "action": .number(wasLiked ? 0 : 1),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "点赞失败")
            }
        } catch {
            if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[index].isLiked = wasLiked
                comments[index].likeCount = previousCount
            }
            showToast("操作失败，请稍后重试")
        }
    }

    func reportComment(_ comment: VideoComment, reason: Int) async {
        guard let aid = detail?.aid else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        do {
            let value = try await core.call("reply.report", params: [
                "oid": .integer(aid),
                "type": .string("1"),
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
}
