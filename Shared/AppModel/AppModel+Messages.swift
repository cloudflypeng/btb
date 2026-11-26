#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func prepareMessages() async {
        await loadMessageUnread()
        await loadMessageFeed(messageTab)
    }

    func selectMessageTab(_ tab: MessageTab) async {
        messageTab = tab
        await loadMessageFeed(tab)
    }

    func refreshMessages() async {
        messageRequest = UUID()
        await loadMessageUnread(force: true)
        switch messageTab {
        case .replies: messageReplies = MessageFeed()
        case .ats: messageAts = MessageFeed()
        case .likes: messageLikes = MessageFeed()
        case .system: messageSystem = MessageFeed()
        }
        await loadMessageFeed(messageTab)
    }

    func loadMessageUnread(force: Bool = false) async {
        guard hasAccount else {
            messageUnread = nil
            return
        }
        guard force || messageUnread == nil else { return }
        let request = UUID()
        messageUnreadRequest = request
        do {
            let value = try await core.call("msg.unread")
            let response = try CoreCoding.decode(UpstreamResponse<MessageUnread>.self, from: value)
            guard messageUnreadRequest == request, hasAccount else { return }
            if response.code == 0 {
                messageUnread = response.data
            }
        } catch {
            // The badge is optional; message tabs surface their own errors.
        }
    }

    func loadMessageFeed(_ tab: MessageTab) async {
        guard hasAccount else { return }
        switch tab {
        case .replies:
            await loadMessageReplies(force: false)
        case .ats:
            await loadMessageAts(force: false)
        case .likes:
            await loadMessageLikes(force: false)
        case .system:
            await loadMessageSystem(force: false)
        }
    }

    func loadMoreMessages() async {
        guard hasAccount else { return }
        switch messageTab {
        case .replies:
            await loadMoreMessageReplies()
        case .ats:
            await loadMoreMessageAts()
        case .likes:
            await loadMoreMessageLikes()
        case .system:
            await loadMoreMessageSystem()
        }
    }

    func openMessageDestination(_ destination: MessageDestination) {
        switch destination {
        case .video(let bvid):
            openVideo(VideoItem(bvid: bvid))
        case .videoAID(let aid):
            Task { await openMessageVideo(aid: aid) }
        case .season(let seasonID):
            openAnimeSeason(seasonID)
        case .external(let url):
#if canImport(AppKit)
            NSWorkspace.shared.open(url)
#elseif canImport(UIKit)
            UIApplication.shared.open(url)
#endif
        }
    }

    func resolveVideoBVID(aid: Int64) async -> String? {
        guard aid > 0, coreState == .ready else { return nil }
        do {
            let value = try await core.call("video.info", params: ["aid": .number(Double(aid))])
            let response = try CoreCoding.decode(UpstreamResponse<MessageVideoInfo>.self, from: value)
            guard response.code == 0, let bvid = response.data?.bvid, !bvid.isEmpty else { return nil }
            return bvid
        } catch {
            return nil
        }
    }

    func loadMessageReplies(force: Bool) async {
        guard force || !messageReplies.loaded, !messageReplies.isLoading else { return }
        let request = messageRequest
        if force { messageReplies = MessageFeed() }
        messageReplies.isLoading = true
        messageReplies.error = nil
        defer {
            if messageRequest == request {
                messageReplies.isLoading = false
                messageReplies.loaded = true
            }
        }
        do {
            let result = try await fetchMessageReplies(
                cursorID: messageReplies.cursorID,
                cursorTime: messageReplies.cursorTime
            )
            guard messageRequest == request, hasAccount else { return }
            messageReplies.items = result.items
            messageReplies.cursorID = result.cursorID
            messageReplies.cursorTime = result.cursorTime
            messageReplies.hasMore = result.hasMore
            messageReplies.lastViewAt = result.lastViewAt
        } catch {
            guard messageRequest == request else { return }
            messageReplies.error = "回复加载失败：\(describe(error))"
            messageReplies.hasMore = false
        }
    }

    func loadMoreMessageReplies() async {
        guard !messageReplies.isLoading,
              !messageReplies.isLoadingMore,
              messageReplies.hasMore else { return }
        let request = messageRequest
        messageReplies.isLoadingMore = true
        messageReplies.failed = false
        defer {
            if messageRequest == request {
                messageReplies.isLoadingMore = false
            }
        }
        do {
            let result = try await fetchMessageReplies(
                cursorID: messageReplies.cursorID,
                cursorTime: messageReplies.cursorTime
            )
            guard messageRequest == request else { return }
            guard !result.items.isEmpty else {
                messageReplies.hasMore = false
                return
            }
            var seen = Set(messageReplies.items.map(\.id))
            for item in result.items where seen.insert(item.id).inserted {
                messageReplies.items.append(item)
            }
            messageReplies.cursorID = result.cursorID
            messageReplies.cursorTime = result.cursorTime
            messageReplies.hasMore = result.hasMore
        } catch {
            guard messageRequest == request else { return }
            messageReplies.failed = true
        }
    }

    func loadMessageAts(force: Bool) async {
        guard force || !messageAts.loaded, !messageAts.isLoading else { return }
        let request = messageRequest
        if force { messageAts = MessageFeed() }
        messageAts.isLoading = true
        messageAts.error = nil
        defer {
            if messageRequest == request {
                messageAts.isLoading = false
                messageAts.loaded = true
            }
        }
        do {
            let result = try await fetchMessageAts(
                cursorID: messageAts.cursorID,
                cursorTime: messageAts.cursorTime
            )
            guard messageRequest == request, hasAccount else { return }
            messageAts.items = result.items
            messageAts.cursorID = result.cursorID
            messageAts.cursorTime = result.cursorTime
            messageAts.hasMore = result.hasMore
            messageAts.lastViewAt = result.lastViewAt
        } catch {
            guard messageRequest == request else { return }
            messageAts.error = "@ 消息加载失败：\(describe(error))"
            messageAts.hasMore = false
        }
    }

    func loadMoreMessageAts() async {
        guard !messageAts.isLoading,
              !messageAts.isLoadingMore,
              messageAts.hasMore else { return }
        let request = messageRequest
        messageAts.isLoadingMore = true
        messageAts.failed = false
        defer {
            if messageRequest == request {
                messageAts.isLoadingMore = false
            }
        }
        do {
            let result = try await fetchMessageAts(
                cursorID: messageAts.cursorID,
                cursorTime: messageAts.cursorTime
            )
            guard messageRequest == request else { return }
            guard !result.items.isEmpty else {
                messageAts.hasMore = false
                return
            }
            var seen = Set(messageAts.items.map(\.id))
            for item in result.items where seen.insert(item.id).inserted {
                messageAts.items.append(item)
            }
            messageAts.cursorID = result.cursorID
            messageAts.cursorTime = result.cursorTime
            messageAts.hasMore = result.hasMore
        } catch {
            guard messageRequest == request else { return }
            messageAts.failed = true
        }
    }

    func loadMessageLikes(force: Bool) async {
        guard force || !messageLikes.loaded, !messageLikes.isLoading else { return }
        let request = messageRequest
        if force { messageLikes = MessageFeed() }
        messageLikes.isLoading = true
        messageLikes.error = nil
        defer {
            if messageRequest == request {
                messageLikes.isLoading = false
                messageLikes.loaded = true
            }
        }
        do {
            let result = try await fetchMessageLikes(
                cursorID: messageLikes.cursorID,
                cursorTime: messageLikes.cursorTime
            )
            guard messageRequest == request, hasAccount else { return }
            messageLikes.items = result.items
            messageLikes.cursorID = result.cursorID
            messageLikes.cursorTime = result.cursorTime
            messageLikes.hasMore = result.hasMore
            messageLikes.lastViewAt = result.lastViewAt
        } catch {
            guard messageRequest == request else { return }
            messageLikes.error = "点赞消息加载失败：\(describe(error))"
            messageLikes.hasMore = false
        }
    }

    func loadMoreMessageLikes() async {
        guard !messageLikes.isLoading,
              !messageLikes.isLoadingMore,
              messageLikes.hasMore else { return }
        let request = messageRequest
        messageLikes.isLoadingMore = true
        messageLikes.failed = false
        defer {
            if messageRequest == request {
                messageLikes.isLoadingMore = false
            }
        }
        do {
            let result = try await fetchMessageLikes(
                cursorID: messageLikes.cursorID,
                cursorTime: messageLikes.cursorTime
            )
            guard messageRequest == request else { return }
            guard !result.items.isEmpty else {
                messageLikes.hasMore = false
                return
            }
            var seen = Set(messageLikes.items.map(\.id))
            for item in result.items where seen.insert(item.id).inserted {
                messageLikes.items.append(item)
            }
            messageLikes.cursorID = result.cursorID
            messageLikes.cursorTime = result.cursorTime
            messageLikes.hasMore = result.hasMore
        } catch {
            guard messageRequest == request else { return }
            messageLikes.failed = true
        }
    }

    func loadMessageSystem(force: Bool) async {
        guard force || !messageSystem.loaded, !messageSystem.isLoading else { return }
        let request = messageRequest
        if force { messageSystem = MessageFeed() }
        messageSystem.isLoading = true
        messageSystem.error = nil
        defer {
            if messageRequest == request {
                messageSystem.isLoading = false
                messageSystem.loaded = true
            }
        }
        do {
            let result = try await fetchMessageSystem(cursor: messageSystem.cursorID)
            guard messageRequest == request, hasAccount else { return }
            messageSystem.items = result.items
            messageSystem.cursorID = result.cursorID
            messageSystem.hasMore = result.hasMore
        } catch {
            guard messageRequest == request else { return }
            messageSystem.error = "系统通知加载失败：\(describe(error))"
            messageSystem.hasMore = false
        }
    }

    func loadMoreMessageSystem() async {
        guard !messageSystem.isLoading,
              !messageSystem.isLoadingMore,
              messageSystem.hasMore else { return }
        let request = messageRequest
        messageSystem.isLoadingMore = true
        messageSystem.failed = false
        defer {
            if messageRequest == request {
                messageSystem.isLoadingMore = false
            }
        }
        do {
            let result = try await fetchMessageSystem(cursor: messageSystem.cursorID)
            guard messageRequest == request else { return }
            guard !result.items.isEmpty else {
                messageSystem.hasMore = false
                return
            }
            var seen = Set(messageSystem.items.map(\.id))
            for item in result.items where seen.insert(item.id).inserted {
                messageSystem.items.append(item)
            }
            messageSystem.cursorID = result.cursorID
            messageSystem.hasMore = result.hasMore
        } catch {
            guard messageRequest == request else { return }
            messageSystem.failed = true
        }
    }

    func fetchMessageReplies(
        cursorID: Int64,
        cursorTime: Int64
    ) async throws -> (items: [MessageReplyEntry], cursorID: Int64, cursorTime: Int64, hasMore: Bool, lastViewAt: Int64) {
        var params: [String: JSONValue] = [:]
        if cursorID > 0 { params["cursor"] = .integer(cursorID) }
        if cursorTime > 0 { params["cursor_time"] = .integer(cursorTime) }
        let value = try await core.call("msg.replies", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<MessageReplyFeed>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "回复加载失败")
        }
        let items = response.data?.items ?? []
        let cursor = response.data?.cursor
        return (
            items,
            cursor?.id ?? 0,
            cursor?.time ?? 0,
            cursor.map { !($0.isEnd ?? false) && !items.isEmpty } ?? (items.count >= 20),
            response.data?.lastViewAt ?? 0
        )
    }

    func fetchMessageAts(
        cursorID: Int64,
        cursorTime: Int64
    ) async throws -> (items: [MessageAtEntry], cursorID: Int64, cursorTime: Int64, hasMore: Bool, lastViewAt: Int64) {
        var params: [String: JSONValue] = [:]
        if cursorID > 0 { params["cursor"] = .integer(cursorID) }
        if cursorTime > 0 { params["cursor_time"] = .integer(cursorTime) }
        let value = try await core.call("msg.ats", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<MessageAtFeed>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "@ 消息加载失败")
        }
        let items = response.data?.items ?? []
        let cursor = response.data?.cursor
        return (
            items,
            cursor?.id ?? 0,
            cursor?.time ?? 0,
            cursor.map { !($0.isEnd ?? false) && !items.isEmpty } ?? (items.count >= 20),
            response.data?.lastViewAt ?? 0
        )
    }

    func fetchMessageLikes(
        cursorID: Int64,
        cursorTime: Int64
    ) async throws -> (items: [MessageLikeEntry], cursorID: Int64, cursorTime: Int64, hasMore: Bool, lastViewAt: Int64) {
        var params: [String: JSONValue] = [:]
        if cursorID > 0 { params["cursor"] = .integer(cursorID) }
        if cursorTime > 0 { params["cursor_time"] = .integer(cursorTime) }
        let value = try await core.call("msg.likes", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<MessageLikeData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "点赞消息加载失败")
        }
        let latest = response.data?.latest
        let total = response.data?.total
        let items = total?.items?.isEmpty == false ? (total?.items ?? []) : (latest?.items ?? [])
        let cursor = total?.cursor
        return (
            items,
            cursor?.id ?? 0,
            cursor?.time ?? 0,
            cursor.map { !($0.isEnd ?? false) && !items.isEmpty } ?? false,
            latest?.lastViewAt ?? 0
        )
    }

    func fetchMessageSystem(
        cursor: Int64
    ) async throws -> (items: [SystemMessage], cursorID: Int64, hasMore: Bool) {
        var params: [String: JSONValue] = ["page_size": .number(20)]
        if cursor > 0 { params["cursor"] = .integer(cursor) }
        let value = try await core.call("msg.system", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<[SystemMessage]>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "系统通知加载失败")
        }
        let items = response.data ?? []
        let nextCursor = items.compactMap(\.cursor).last ?? 0
        return (items, nextCursor, items.count >= 20 && nextCursor > 0)
    }

    func openMessageVideo(aid: Int64) async {
        do {
            let value = try await core.call("video.info", params: ["aid": .number(Double(aid))])
            let response = try CoreCoding.decode(UpstreamResponse<MessageVideoInfo>.self, from: value)
            guard response.code == 0, let bvid = response.data?.bvid, !bvid.isEmpty else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "视频信息加载失败")
            }
            openVideo(VideoItem(bvid: bvid))
        } catch {
            showToast("无法打开视频：\(describe(error))")
        }
    }

    func resetMessages() {
        messageUnreadRequest = UUID()
        messageRequest = UUID()
        messageUnread = nil
        messageReplies = MessageFeed()
        messageAts = MessageFeed()
        messageLikes = MessageFeed()
        messageSystem = MessageFeed()
    }
}
