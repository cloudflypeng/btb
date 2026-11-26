#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func loadRecommend(request: UUID, freshIndex: Int) async {
        guard coreState == .ready else { return }
        let isInitial = freshIndex == 0
        if isInitial {
            isLoading = true
            errorMessage = nil
        }
        defer {
            if isInitial, homeRequest == request { isLoading = false }
        }

        if isInitial { Perf.begin("feed.load") }
        do {
            let items = try await fetchRecommend(freshIndex: freshIndex)
            guard homeRequest == request else { return }
            if isInitial {
                videos = items
                homePager.nextPage = 1
                homePager.hasMore = !items.isEmpty
                Perf.end("feed.load", "tab=recommend count=\(items.count)")
                Perf.milestone("launch.firstFeed", "source=network count=\(items.count)")
                FeedCache.save(items)
            } else {
                _ = appendUnique(items, to: &videos)
                homePager.nextPage = freshIndex + 1
                homePager.hasMore = !items.isEmpty
            }
        } catch {
            guard homeRequest == request else { return }
            if isInitial {
                errorMessage = "推荐加载失败：\(describe(error))"
                homePager.hasMore = false
            } else {
                homePager.failed = true
            }
        }
    }

    func loadRecommendMore(request: UUID) async {
        var freshIndex = homePager.nextPage
        for _ in 0..<3 {
            do {
                let items = try await fetchRecommend(freshIndex: freshIndex)
                guard homeRequest == request else { return }
                freshIndex += 1
                homePager.nextPage = freshIndex
                if items.isEmpty {
                    homePager.stop()
                    return
                }
                let added = appendUnique(items, to: &videos)
                if added > 0 {
                    homePager.hasMore = true
                    return
                }
            } catch {
                guard homeRequest == request else { return }
                homePager.failed = true
                return
            }
        }
        homePager.stop()
    }

    func fetchRecommend(freshIndex: Int) async throws -> [VideoItem] {
        let value = try await core.call("video.recommend", params: [
            "ps": .number(Double(feedPageSize)),
            "desktop": .bool(true),
            "fresh_idx": .number(Double(freshIndex)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<RecommendData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
        }
        return (response.data?.item ?? []).compactMap(VideoItem.init(hot:))
    }

    func loadRanking(request: UUID) async {
        guard coreState == .ready else { return }
        isLoading = true
        errorMessage = nil
        defer {
            if homeRequest == request { isLoading = false }
        }

        do {
            let value = try await core.call("video.rank", params: [
                "rid": .number(0),
                "type": .string("all"),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<HotData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            guard homeRequest == request else { return }
            videos = (response.data?.list ?? []).compactMap(VideoItem.init(hot:))
            homePager.stop()
        } catch {
            guard homeRequest == request else { return }
            errorMessage = "排行榜加载失败：\(describe(error))"
        }
    }

    func loadHotFeed(request: UUID, page: Int) async {
        guard coreState == .ready else { return }
        let isInitial = page == 1
        if isInitial {
            isLoading = true
            errorMessage = nil
        }
        defer {
            if isInitial, homeRequest == request { isLoading = false }
        }

        do {
            let items = try await fetchHotVideos(page: page)
            guard homeRequest == request else { return }
            if isInitial {
                videos = items
            } else {
                _ = appendUnique(items, to: &videos)
            }
            homePager.nextPage = page + 1
            homePager.hasMore = items.count >= feedPageSize
        } catch {
            guard homeRequest == request else { return }
            if isInitial {
                errorMessage = "内容加载失败：\(describe(error))"
                homePager.hasMore = false
            } else {
                homePager.failed = true
            }
        }
    }

    func loadHotFeedMore(request: UUID) async {
        let page = homePager.nextPage
        do {
            let items = try await fetchHotVideos(page: page)
            guard homeRequest == request else { return }
            homePager.nextPage = page + 1
            if items.isEmpty {
                homePager.stop()
                return
            }
            _ = appendUnique(items, to: &videos)
            homePager.hasMore = items.count >= feedPageSize
        } catch {
            guard homeRequest == request else { return }
            homePager.failed = true
        }
    }

    func fetchHotVideos(page: Int) async throws -> [VideoItem] {
        let value = try await core.call("video.hot", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(feedPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<HotData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
        }
        return (response.data?.list ?? []).compactMap(VideoItem.init(hot:))
    }

    func loadCategory(_ keyword: String, request: UUID, page: Int) async {
        guard coreState == .ready else { return }
        let isInitial = page == 1
        if isInitial {
            isLoading = true
            errorMessage = nil
        }
        defer {
            if isInitial, homeRequest == request { isLoading = false }
        }

        do {
            let items = try await fetchSearchVideos(keyword, page: page)
            guard homeRequest == request else { return }
            if isInitial {
                videos = items
            } else {
                _ = appendUnique(items, to: &videos)
            }
            homePager.nextPage = page + 1
            homePager.hasMore = items.count >= feedPageSize
        } catch {
            guard homeRequest == request else { return }
            if isInitial {
                errorMessage = "\(homeFilter.title)内容加载失败：\(describe(error))"
                homePager.hasMore = false
            } else {
                homePager.failed = true
            }
        }
    }

    func loadCategoryMore(_ keyword: String, request: UUID) async {
        let page = homePager.nextPage
        do {
            let items = try await fetchSearchVideos(keyword, page: page)
            guard homeRequest == request else { return }
            homePager.nextPage = page + 1
            if items.isEmpty {
                homePager.stop()
                return
            }
            _ = appendUnique(items, to: &videos)
            homePager.hasMore = items.count >= feedPageSize
        } catch {
            guard homeRequest == request else { return }
            homePager.failed = true
        }
    }

    @discardableResult
    func appendUnique(_ items: [VideoItem], to target: inout [VideoItem]) -> Int {
        var seen = Set(target.map(\.bvid))
        var added = 0
        for item in items where seen.insert(item.bvid).inserted {
            target.append(item)
            added += 1
        }
        return added
    }
}
