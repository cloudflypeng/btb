#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func loadMyUploads(force: Bool = false) async {
        guard let mid = activeAccount?.mid else {
            myUploads = []
            myUploadsError = nil
            uploadsPager.reset()
            return
        }
        guard force || myUploads.isEmpty, !isLoadingMyUploads else { return }
        isLoadingMyUploads = true
        myUploadsError = nil
        uploadsPager.reset()
        defer { isLoadingMyUploads = false }

        do {
            let items = try await fetchUserVideos(mid: mid, page: 1)
            guard activeAccount?.mid == mid else { return }
            myUploads = items
            uploadsPager.nextPage = 2
            uploadsPager.hasMore = items.count >= libraryPageSize
        } catch {
            guard activeAccount?.mid == mid else { return }
            myUploadsError = "投稿加载失败：\(describe(error))"
            uploadsPager.hasMore = false
        }
    }

    func loadMoreMyUploads() async {
        guard let mid = activeAccount?.mid,
              !isLoadingMyUploads,
              !uploadsPager.isLoadingMore,
              uploadsPager.hasMore else { return }
        uploadsPager.isLoadingMore = true
        uploadsPager.failed = false
        defer {
            if activeAccount?.mid == mid { uploadsPager.isLoadingMore = false }
        }

        let page = uploadsPager.nextPage
        do {
            let items = try await fetchUserVideos(mid: mid, page: page)
            guard activeAccount?.mid == mid else { return }
            uploadsPager.nextPage = page + 1
            if items.isEmpty {
                uploadsPager.stop()
                return
            }
            _ = appendUnique(items, to: &myUploads)
            uploadsPager.hasMore = items.count >= libraryPageSize
        } catch {
            guard activeAccount?.mid == mid else { return }
            uploadsPager.failed = true
        }
    }

    func fetchUserVideos(mid: Int64, page: Int) async throws -> [VideoItem] {
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

    func loadHistoryVideos(force: Bool = false) async {
        guard hasAccount else {
            history = []
            historyError = nil
            historyPager.reset()
            return
        }
        guard force || !historyLoaded, !isLoadingHistory else { return }
        isLoadingHistory = true
        historyError = nil
        historyPager.reset()
        historyCursorMax = 0
        historyCursorViewAt = 0
        defer { isLoadingHistory = false }

        do {
            let page = try await fetchHistoryPage(max: 0, viewAt: 0)
            history = page.items
            historyCursorMax = page.nextMax
            historyCursorViewAt = page.nextViewAt
            historyLoaded = true
            historyPager.nextPage = 2
            historyPager.hasMore = !page.items.isEmpty && page.nextMax > 0
        } catch {
            historyError = "历史记录加载失败：\(describe(error))"
            historyPager.hasMore = false
        }
    }

    func loadMoreHistory() async {
        guard hasAccount,
              !isLoadingHistory,
              !historyPager.isLoadingMore,
              historyPager.hasMore else { return }
        let cursorMax = historyCursorMax
        let cursorViewAt = historyCursorViewAt
        guard cursorMax > 0 else {
            historyPager.stop()
            return
        }

        historyPager.isLoadingMore = true
        historyPager.failed = false
        defer { historyPager.isLoadingMore = false }

        do {
            let page = try await fetchHistoryPage(max: cursorMax, viewAt: cursorViewAt)
            historyCursorMax = page.nextMax
            historyCursorViewAt = page.nextViewAt
            if page.items.isEmpty {
                historyPager.stop()
                return
            }
            _ = appendUnique(page.items, to: &history)
            historyPager.nextPage += 1
            historyPager.hasMore = page.nextMax > 0
        } catch {
            historyPager.failed = true
        }
    }

    func loadHistoryStatus(force: Bool = false) async {
        guard hasAccount else {
            historyPaused = false
            historyStatusLoaded = false
            return
        }
        guard force || !historyStatusLoaded else { return }
        do {
            let value = try await core.call("history.status")
            let response = try CoreCoding.decode(UpstreamResponse<Bool>.self, from: value)
            guard response.code == 0 else { return }
            historyPaused = response.data ?? false
            historyStatusLoaded = true
        } catch {
            return
        }
    }

    func setHistoryPaused(_ paused: Bool) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("history.pause", params: ["pause": .bool(paused)])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "设置失败")
        }
        historyPaused = paused
        historyStatusLoaded = true
        showToast(paused ? "已暂停记录观看历史" : "已恢复记录观看历史")
    }

    func deleteHistoryEntry(_ video: VideoItem) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        guard let key = historyDeleteKey(for: video) else {
            throw BBCoreError.upstream(code: -1, message: "无法识别这条观看记录")
        }
        let value = try await core.call("history.delete", params: ["kid": .string(key)])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "删除失败")
        }
        history.removeAll {
            $0.bvid == video.bvid && $0.historyKid == video.historyKid
        }
        if history.isEmpty {
            historyPager.stop()
        }
        showToast("已删除这条观看记录")
    }

    func clearHistory() async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("history.clear")
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "清空失败")
        }
        history = []
        historyCursorMax = 0
        historyCursorViewAt = 0
        historyPager.stop()
        showToast("历史记录已清空")
    }

    func historyDeleteKey(for video: VideoItem) -> String? {
        guard let kid = video.historyKid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !kid.isEmpty else { return nil }
        if kid.contains("_") { return kid }
        let business = video.historyBusiness?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(business.isEmpty ? "archive" : business)_\(kid)"
    }

    func fetchHistoryPage(
        max: Int,
        viewAt: Int
    ) async throws -> (items: [VideoItem], nextMax: Int, nextViewAt: Int) {
        var params: [String: JSONValue] = ["ps": .number(Double(libraryPageSize))]
        if max > 0 {
            params["max"] = .number(Double(max))
        }
        if viewAt > 0 {
            params["view_at"] = .number(Double(viewAt))
        }
        let value = try await core.call("user.history", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<UserHistoryData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "历史记录加载失败")
        }
        let items = (response.data?.list ?? []).compactMap(VideoItem.init(history:))
        return (items, response.data?.cursor?.max ?? 0, response.data?.cursor?.viewAt ?? 0)
    }

    func loadWatchLater(force: Bool = false) async {
        guard hasAccount else {
            laterVideos = []
            laterTotal = 0
            laterError = nil
            laterPager.reset()
            return
        }
        guard force || laterVideos.isEmpty, !isLoadingLater else { return }
        isLoadingLater = true
        laterError = nil
        laterPager.reset()
        defer { isLoadingLater = false }

        do {
            let page = try await fetchLaterPage(page: 1)
            laterVideos = page.items
            laterTotal = page.total
            laterPager.nextPage = 2
            if page.total > 0 {
                laterPager.hasMore = page.items.count < page.total
            } else {
                laterPager.hasMore = page.items.count >= libraryPageSize
            }
        } catch {
            laterError = "稍后再看加载失败：\(describe(error))"
            laterPager.hasMore = false
        }
    }

    func loadMoreWatchLater() async {
        guard hasAccount,
              !isLoadingLater,
              !laterPager.isLoadingMore,
              laterPager.hasMore else { return }
        laterPager.isLoadingMore = true
        laterPager.failed = false
        defer { laterPager.isLoadingMore = false }

        let page = laterPager.nextPage
        do {
            let result = try await fetchLaterPage(page: page)
            laterPager.nextPage = page + 1
            if result.items.isEmpty {
                laterPager.stop()
                return
            }
            _ = appendUnique(result.items, to: &laterVideos)
            if laterTotal < result.total {
                laterTotal = result.total
            }
            if laterTotal > 0 {
                laterPager.hasMore = laterVideos.count < laterTotal
            } else {
                laterPager.hasMore = result.items.count >= libraryPageSize
            }
        } catch {
            laterPager.failed = true
        }
    }

    func removeFromWatchLater(_ video: VideoItem) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        guard let aid = video.aid, aid > 0 else {
            throw BBCoreError.upstream(code: -1, message: "无法识别该视频")
        }
        let value = try await core.call("user.later.del", params: [
            "aids": .string(String(aid)),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "移除失败")
        }
        laterVideos.removeAll { $0.bvid == video.bvid }
        laterTotal = max(0, laterTotal - 1)
        showToast("已从稍后再看移除")
    }

    func clearWatchLater() async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("user.later.clear")
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "清空失败")
        }
        laterVideos = []
        laterTotal = 0
        laterPager.stop()
        showToast("稍后再看已清空")
    }

    func fetchLaterPage(page: Int) async throws -> (items: [VideoItem], total: Int) {
        let value = try await core.call("user.later", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<LaterData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "稍后再看加载失败")
        }
        let items = (response.data?.list ?? []).compactMap(VideoItem.init(hot:))
        return (items, response.data?.count ?? items.count)
    }

    // MARK: - Downloads
}
