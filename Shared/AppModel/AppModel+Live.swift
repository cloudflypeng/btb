#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func setLiveFeedFilter(_ filter: LiveFeedFilter) {
        liveFeedFilter = filter
    }

    func loadLiveFeed(reset: Bool = false) async {
        guard coreState == .ready else { return }
        if reset {
            liveRequest = UUID()
            liveRooms = []
            livePage = 1
            liveHasMore = false
            liveLoaded = false
            liveError = nil
            liveFollowedLiveCount = 0
            // A reset supersedes any in-flight load; its late response is
            // dropped by the request check and must not keep the spinner up.
            isLoadingLive = false
        } else {
            guard !liveLoaded else { return }
        }
        guard hasAccount else {
            liveLoaded = true
            liveError = nil
            return
        }
        guard !isLoadingLive else { return }

        let request = liveRequest
        let page = reset ? 1 : livePage + 1
        isLoadingLive = true
        liveError = nil
        defer {
            if liveRequest == request {
                isLoadingLive = false
                liveLoaded = true
            }
        }

        do {
            let value = try await core.call("live.following", params: ["page": .number(Double(page))])
            let response = try CoreCoding.decode(UpstreamResponse<LiveFollowingData>.self, from: value)
            guard liveRequest == request else { return }
            guard response.code == 0, let data = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "直播列表加载失败")
            }
            let rooms = (data.list ?? []).compactMap(LiveRoom.init(raw:))
            appendUniqueLiveRooms(rooms)
            livePage = page
            liveFollowedLiveCount = data.liveCount ?? rooms.filter(\.isLive).count
            let totalPage = data.totalPage ?? page
            liveHasMore = page < totalPage && !rooms.isEmpty
#if DEBUG
            if activeLiveRoom == nil,
               ProcessInfo.processInfo.environment["BTB_OPEN_LIVE"] == "1",
               let first = filteredLiveRooms.first {
                openLiveRoom(first)
            }
#endif
        } catch {
            guard liveRequest == request else { return }
            liveError = "直播列表加载失败：\(describe(error))"
        }
    }

    func loadMoreLive() async {
        guard liveHasMore, !isLoadingLive, liveError == nil else { return }
        liveLoaded = false
        await loadLiveFeed()
    }

    func appendUniqueLiveRooms(_ rooms: [LiveRoom]) {
        var existing = Set(liveRooms.map(\.roomID))
        for room in rooms where !existing.contains(room.roomID) {
            liveRooms.append(room)
            existing.insert(room.roomID)
        }
    }

    func openLiveRoom(_ room: LiveRoom) {
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        section = .live
        activeLiveRoom = room
        livePopularity = 0
        liveIsFollowing = room.isFollowed
        startLiveEventStream()
        let roomID = room.roomID
        Task {
            await prepareLivePlayback(roomID: roomID, qn: nil)
            await connectLiveDanmaku(roomID: roomID)
        }
    }

    func closeLiveRoom() {
        liveEventsTask?.cancel()
        liveEventsTask = nil
        let roomID = activeLiveRoom?.roomID
        let sessionID = livePlayback?.sessionID
        activeLiveRoom = nil
        liveRoomInfo = nil
        livePlayback = nil
        liveQualities = []
        liveSelectedQN = nil
        livePlayError = nil
        isLoadingLivePlay = false
        liveChatMessages = []
        liveConnected = false
        livePopularity = 0
        liveWatched = 0
        liveAttention = 0
        liveIsFollowing = false
        if let roomID {
            Task {
                if let sessionID {
                    await stopStream(sessionID: sessionID)
                }
                _ = try? await core.call("live.disconnect", params: ["room_id": .number(Double(roomID))])
            }
        }
    }

    func prepareLivePlayback(roomID: Int64, qn: Int?) async {
        guard activeLiveRoom?.roomID == roomID else { return }
        isLoadingLivePlay = true
        livePlayError = nil
        defer {
            if activeLiveRoom?.roomID == roomID {
                isLoadingLivePlay = false
            }
        }

        var params: [String: JSONValue] = ["room_id": .number(Double(roomID))]
        if let qn {
            params["qn"] = .number(Double(qn))
        }

        do {
            let value = try await core.call("live.play", params: params)
            let result = try CoreCoding.decode(LivePlayResult.self, from: value)
            guard activeLiveRoom?.roomID == roomID else {
                if let sessionID = result.sessionID {
                    await stopStream(sessionID: sessionID)
                }
                return
            }

            if let room = result.room {
                liveRoomInfo = room
                liveWatched = room.watched
                liveAttention = room.attention
                if result.playable {
                    livePopularity = max(livePopularity, room.online)
                }
            }
            if let qualities = result.qualities {
                liveQualities = qualities
            }

            guard result.playable else {
                failLivePlayback(result.unavailableText)
                if livePlayback == nil {
                    livePlayback = result
                }
                return
            }

            let previous = livePlayback?.sessionID
            if let previous, previous != result.sessionID {
                await stopStream(sessionID: previous)
            }
            livePlayback = result
            liveSelectedQN = result.quality?.qn
                ?? result.qualities?.first(where: { $0.current == true })?.qn
        } catch {
            failLivePlayback("直播加载失败：\(describe(error))")
        }
    }

    func failLivePlayback(_ message: String) {
        if livePlayback?.playable == true, livePlayback?.playbackURL != nil {
            showToast(message)
        } else {
            livePlayError = message
        }
    }

    func selectLiveQuality(_ qn: Int) async {
        guard let room = activeLiveRoom, qn != liveSelectedQN else { return }
        await prepareLivePlayback(roomID: room.roomID, qn: qn)
    }

    func refreshLivePlayback() async {
        guard let room = activeLiveRoom else { return }
        await prepareLivePlayback(roomID: room.roomID, qn: liveSelectedQN)
    }

    func connectLiveDanmaku(roomID: Int64) async {
        guard activeLiveRoom?.roomID == roomID else { return }
        do {
            _ = try await core.call("live.connect", params: ["room_id": .number(Double(roomID))])
        } catch {
            liveConnected = false
        }
    }

    func toggleLiveFollow() async {
        guard let room = activeLiveRoom, room.uid > 0 else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        let next = !liveIsFollowing
        liveIsFollowing = next
        do {
            let value = try await core.call("user.follow", params: [
                "fid": .number(Double(room.uid)),
                "follow": .bool(next),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注失败")
            }
            showToast(next ? "已关注主播" : "已取消关注")
        } catch {
            liveIsFollowing = !next
            showToast("操作失败，请稍后重试")
        }
    }

    @discardableResult
    func sendLiveMessage(_ raw: String) async -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let room = activeLiveRoom else { return false }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return false
        }
        guard !isSendingLiveMessage else { return false }
        isSendingLiveMessage = true
        let local = LiveChatMessage.localDanmaku(
            text: text,
            userName: profile?.name ?? activeAccount?.displayName ?? "我"
        )
        liveChatMessages.append(local)
        defer { isSendingLiveMessage = false }

        do {
            let value = try await core.call("live.send_msg", params: [
                "room_id": .number(Double(room.roomID)),
                "msg": .string(text),
            ])
            let response = try CoreCoding.decode(BasicResponse.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "弹幕发送失败")
            }
            if let index = liveChatMessages.firstIndex(where: { $0.id == local.id }) {
                liveChatMessages[index].isLocal = false
            }
            return true
        } catch {
            if let index = liveChatMessages.firstIndex(where: { $0.id == local.id }),
               liveChatMessages[index].isLocal {
                liveChatMessages.remove(at: index)
            }
            showToast("弹幕发送失败，请稍后重试")
            return false
        }
    }

    func startLiveEventStream() {
        liveEventsTask?.cancel()
        let stream = eventHub.subscribe(topics: ["live.*"])
        liveEventsTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.handleLiveEvent(event)
            }
        }
    }

    func handleLiveEvent(_ event: CoreEvent) {
        guard let active = activeLiveRoom else { return }
        let roomID = LiveEventParser.roomID(from: event.data)
        guard roomID == active.roomID else { return }

        switch event.topic {
        case "live.connected":
            liveConnected = true
        case "live.disconnected":
            liveConnected = false
        case "live.popularity":
            // Heartbeat replies now carry the placeholder 1; real popularity
            // only comes from the room info snapshot.
            if let value = LiveEventParser.popularity(from: event.data), value > 1 {
                livePopularity = value
            }
        case "live.message":
            if let watched = LiveEventParser.watched(from: event.data) {
                liveWatched = watched
            }
            if let attention = LiveEventParser.attention(from: event.data) {
                liveAttention = attention
            }
            appendLiveChat(LiveEventParser.messages(from: event.data))
        default:
            break
        }
    }

    func appendLiveChat(_ messages: [LiveChatMessage]) {
        guard !messages.isEmpty else { return }
        for var message in messages {
            if message.kind == .danmaku,
               let index = liveChatMessages.lastIndex(where: {
                   $0.isLocal && $0.kind == .danmaku && $0.text == message.text
               }) {
                message.isLocal = false
                liveChatMessages[index] = message
                continue
            }
            liveChatMessages.append(message)
        }
        if liveChatMessages.count > 240 {
            liveChatMessages.removeFirst(liveChatMessages.count - 240)
        }
    }

    func resetLiveFeed() {
        liveRooms = []
        livePage = 1
        liveHasMore = false
        liveLoaded = false
        liveError = nil
        liveFollowedLiveCount = 0
        liveRequest = UUID()
    }

    var animeActiveDay: AnimeTimelineDay? {
        animeTimeline.first(where: { $0.date == animeSelectedDay }) ?? animeTimeline.first
    }
}
