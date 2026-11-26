#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func prepareDiscover() async {
        guard coreState == .ready else { return }
        switch discoverTab {
        case .ranking:
            await loadDiscoverRanking()
        case .weekly:
            await loadWeeklySeries()
        case .categories:
            break
        case .articles:
            await loadArticleRank()
        case .topics:
            if !topicSquareLoaded {
                await loadTopicSquare()
            }
        }
    }

    func selectDiscoverTab(_ tab: DiscoverTab) async {
        discoverTab = tab
        await prepareDiscover()
    }

    func refreshDiscover() async {
        switch discoverTab {
        case .ranking:
            await loadDiscoverRanking(force: true)
        case .weekly:
            await loadWeeklySeries(force: true)
        case .categories:
            break
        case .articles:
            await loadArticleRank(force: true)
        case .topics:
            await loadTopicSquare(force: true)
        }
    }

    func loadDiscoverRanking(force: Bool = false) async {
        guard coreState == .ready else { return }
        if !force, discoverRankingLoaded { return }
        guard !isLoadingDiscoverRanking else { return }

        let request = UUID()
        discoverRankingRequest = request
        isLoadingDiscoverRanking = true
        discoverRankingError = nil
        defer {
            if discoverRankingRequest == request {
                isLoadingDiscoverRanking = false
                discoverRankingLoaded = true
            }
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
            guard discoverRankingRequest == request else { return }
            discoverRanking = (response.data?.list ?? []).compactMap(VideoItem.init(hot:))
        } catch {
            guard discoverRankingRequest == request else { return }
            discoverRankingError = "排行榜加载失败：\(describe(error))"
        }
    }

    func loadWeeklySeries(force: Bool = false) async {
        guard coreState == .ready else { return }
        if !force, weeklySeriesLoaded { return }
        guard !isLoadingWeeklySeries else { return }

        isLoadingWeeklySeries = true
        weeklySeriesError = nil
        defer { isLoadingWeeklySeries = false }

        do {
            let value = try await core.call("video.weekly")
            let response = try CoreCoding.decode(UpstreamResponse<WeeklySeriesData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            weeklySeries = response.data?.list ?? []
            weeklySeriesLoaded = true
            guard !weeklySeries.isEmpty else {
                weeklySeriesError = "暂无每周必看内容"
                return
            }
            if let current = selectedWeeklyNumber,
               weeklySeries.contains(where: { $0.number == current }) {
                if force {
                    await loadWeeklyIssue(number: current, force: true)
                }
            } else if let first = weeklySeries.first {
                selectedWeeklyNumber = first.number
                weeklyIssue = nil
                weeklyVideos = []
                await loadWeeklyIssue(number: first.number)
            }
        } catch {
            weeklySeriesError = "每周必看加载失败：\(describe(error))"
        }
    }

    func selectWeekly(number: Int) async {
        guard number > 0 else { return }
        guard number != selectedWeeklyNumber || weeklyVideos.isEmpty else { return }
        selectedWeeklyNumber = number
        weeklyIssue = nil
        weeklyVideos = []
        weeklyIssueError = nil
        await loadWeeklyIssue(number: number)
    }

    func loadWeeklyIssue(number: Int, force: Bool = false) async {
        guard coreState == .ready, number > 0 else { return }
        if !force,
           weeklyIssue?.config?.number == number,
           !weeklyVideos.isEmpty {
            return
        }
        guard !isLoadingWeeklyIssue else { return }

        let request = UUID()
        weeklyIssueRequest = request
        isLoadingWeeklyIssue = true
        weeklyIssueError = nil
        defer {
            if weeklyIssueRequest == request {
                isLoadingWeeklyIssue = false
            }
        }

        do {
            let value = try await core.call("video.weekly", params: [
                "number": .number(Double(number)),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<WeeklyIssueData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            guard weeklyIssueRequest == request else { return }
            weeklyIssue = response.data
            weeklyVideos = (response.data?.list ?? []).compactMap(VideoItem.init(hot:))
        } catch {
            guard weeklyIssueRequest == request else { return }
            weeklyIssueError = "本期加载失败：\(describe(error))"
        }
    }

    func loadTopicSquare(force: Bool = false) async {
        guard coreState == .ready else { return }
        if !force, topicSquareLoaded { return }
        guard !isLoadingTopicSquare else { return }

        let request = UUID()
        topicSquareRequest = request
        isLoadingTopicSquare = true
        topicSquareError = nil
        defer {
            if topicSquareRequest == request {
                isLoadingTopicSquare = false
                topicSquareLoaded = true
            }
        }

        do {
            let value = try await core.call("topic.square", params: [
                "page_size": .number(30),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<TopicSquareData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            guard topicSquareRequest == request else { return }
            var seen = Set<Int64>()
            topicSquare = (response.data?.topicItems ?? []).filter { seen.insert($0.id).inserted }
        } catch {
            guard topicSquareRequest == request else { return }
            topicSquareError = "话题加载失败：\(describe(error))"
        }
    }

    func loadArticleRank(force: Bool = false) async {
        guard coreState == .ready else { return }
        if !force, articleRankLoaded { return }
        guard !isLoadingArticleRank else { return }

        let request = UUID()
        articleRankRequest = request
        isLoadingArticleRank = true
        articleRankError = nil
        defer {
            if articleRankRequest == request {
                isLoadingArticleRank = false
                articleRankLoaded = true
            }
        }

        do {
            let value = try await core.call("article.rank", params: [
                "page": .number(1),
                "page_size": .number(100),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<[ArticleRankItem]>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            guard articleRankRequest == request else { return }
            articleRank = (response.data ?? []).filter { $0.id > 0 }
        } catch {
            guard articleRankRequest == request else { return }
            articleRankError = "专栏加载失败：\(describe(error))"
        }
    }

    func openTopic(_ topic: TopicSquareItem) {
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        activeTopic = topic
        topicDetail = nil
        topicFeedCards = []
        topicFeedOffset = ""
        topicFeedHasMore = false
        topicFeedLoaded = false
        isLoadingTopicDetail = false
        isLoadingTopicFeed = false
        topicFeedError = nil
        topicFeedRequest = UUID()
        let id = topic.id
        Task {
            await loadTopicDetail(id: id)
            await loadTopicFeed(reset: true)
        }
    }

    func openTopic(id: Int64, name: String = "话题", description: String? = nil) {
        openTopic(TopicSquareItem(id: id, name: name, description: description))
    }

    func closeTopic() {
        activeTopic = nil
        topicDetail = nil
        topicFeedCards = []
        topicFeedOffset = ""
        topicFeedHasMore = false
        topicFeedLoaded = false
        isLoadingTopicDetail = false
        isLoadingTopicFeed = false
        topicFeedError = nil
        topicFeedRequest = UUID()
    }

    func refreshTopic() async {
        guard let id = activeTopic?.id else { return }
        topicDetail = nil
        await loadTopicDetail(id: id)
        await loadTopicFeed(reset: true)
    }

    func loadTopicDetail(id: Int64) async {
        guard coreState == .ready, activeTopic?.id == id else { return }
        isLoadingTopicDetail = true
        defer {
            if activeTopic?.id == id {
                isLoadingTopicDetail = false
            }
        }
        do {
            let value = try await core.call("topic.detail", params: [
                "topic_id": .integer(id),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<TopicDetailData>.self, from: value)
            guard response.code == 0 else { return }
            guard activeTopic?.id == id else { return }
            topicDetail = response.data?.topDetails?.topicItem
        } catch {
            // The topic square summary is enough to render the header.
        }
    }

    func loadTopicFeed(reset: Bool = false) async {
        guard coreState == .ready, let topic = activeTopic else { return }
        guard !isLoadingTopicFeed else { return }
        if reset {
            topicFeedRequest = UUID()
            topicFeedCards = []
            topicFeedOffset = ""
            topicFeedHasMore = true
            topicFeedLoaded = false
            topicFeedError = nil
        } else {
            guard topicFeedLoaded, topicFeedHasMore else { return }
        }

        let request = topicFeedRequest
        let topicID = topic.id
        isLoadingTopicFeed = true
        topicFeedError = nil
        defer {
            if topicFeedRequest == request {
                isLoadingTopicFeed = false
                topicFeedLoaded = true
            }
        }

        do {
            var params: [String: JSONValue] = [
                "topic_id": .integer(topicID),
                "page_size": .number(20),
            ]
            if !topicFeedOffset.isEmpty {
                params["offset"] = .string(topicFeedOffset)
            }
            if !topic.name.isEmpty {
                params["topic_name"] = .string(topic.name)
            }
            let value = try await core.call("topic.feed", params: params)
            let response = try CoreCoding.decode(UpstreamResponse<TopicFeedData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            guard topicFeedRequest == request, activeTopic?.id == topicID else { return }
            let list = response.data?.topicCardList
            let items = list?.items ?? []
            var seen = Set(topicFeedCards.map(\.id))
            for item in items {
                guard let raw = item.dynamicCardItem,
                      let card = DynamicModelParser.card(from: raw),
                      !seen.contains(card.id) else { continue }
                topicFeedCards.append(card)
                seen.insert(card.id)
            }
            topicFeedOffset = list?.offset ?? ""
            topicFeedHasMore = (list?.hasMore ?? false) && !topicFeedOffset.isEmpty
        } catch {
            guard topicFeedRequest == request else { return }
            topicFeedError = "话题动态加载失败：\(describe(error))"
        }
    }

    func loadMoreTopicFeed() async {
        await loadTopicFeed(reset: false)
    }

    func resetDiscover() {
        discoverTab = .ranking
        discoverRanking = []
        discoverRankingLoaded = false
        discoverRankingError = nil
        isLoadingDiscoverRanking = false
        discoverRankingRequest = UUID()
        weeklySeries = []
        weeklySeriesLoaded = false
        weeklySeriesError = nil
        selectedWeeklyNumber = nil
        weeklyIssue = nil
        weeklyVideos = []
        weeklyIssueError = nil
        isLoadingWeeklySeries = false
        isLoadingWeeklyIssue = false
        weeklyIssueRequest = UUID()
        topicSquare = []
        topicSquareLoaded = false
        topicSquareError = nil
        isLoadingTopicSquare = false
        topicSquareRequest = UUID()
        articleRank = []
        articleRankLoaded = false
        articleRankError = nil
        isLoadingArticleRank = false
        articleRankRequest = UUID()
        closeTopic()
    }
}
