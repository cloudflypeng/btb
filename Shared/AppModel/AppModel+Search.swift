#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func submitSearch() async {
        let keyword = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        selectedFolder = nil
        section = .search
        searchTerm = keyword
        await search()
    }

    func search() async {
        let keyword = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            resetSearchState()
            return
        }
        guard coreState == .ready else { return }

        rememberSearchKeyword(keyword)
        cancelSearchLoads()
        activeSearchKeyword = keyword
        searchAttempted = true
        searchError = nil
        searchSuggestItems = []
        resetSearchCaches()
        isSearching = true
        let request = searchRequest
        defer {
            if searchRequest == request { isSearching = false }
        }
        await loadSearchFirstPage(tab: searchTab, request: request)
    }

    func selectSearchTab(_ tab: SearchTab) async {
        guard tab != searchTab else { return }
        searchTab = tab
        searchError = nil
        searchSuggestItems = []
        cancelSearchLoads()
        guard searchAttempted, !activeSearchKeyword.isEmpty else { return }
        guard !searchLoadedTabs.contains(tab) else { return }

        isSearching = true
        let request = searchRequest
        defer {
            if searchRequest == request { isSearching = false }
        }
        await loadSearchFirstPage(tab: tab, request: request)
    }

    func setSearchOrder(_ order: String) async {
        guard order != searchOrder else { return }
        searchOrder = order
        await reloadSearchVideoTab()
    }

    func setSearchDuration(_ duration: String) async {
        guard duration != searchDuration else { return }
        searchDuration = duration
        await reloadSearchVideoTab()
    }

    func setSearchTID(_ tid: String) async {
        guard tid != searchTID else { return }
        searchTID = tid
        await reloadSearchVideoTab()
    }

    func setSearchMediaKind(_ kind: SearchMediaKind) async {
        guard kind != searchMediaKind else { return }
        searchMediaKind = kind
        searchPagers[.media]?.reset()
        searchLoadedTabs.remove(.media)
        guard searchTab == .media, searchAttempted, !activeSearchKeyword.isEmpty else { return }

        cancelSearchLoads()
        searchMedia = []
        searchTotalResults = 0
        searchError = nil
        isSearching = true
        let request = searchRequest
        defer {
            if searchRequest == request { isSearching = false }
        }
        await loadSearchFirstPage(tab: .media, request: request)
    }

    func loadMoreSearchResults() async {
        let tab = searchTab
        guard tab != .all,
              searchAttempted,
              !activeSearchKeyword.isEmpty,
              !isSearching,
              let pager = searchPagers[tab],
              !pager.isLoadingMore,
              pager.hasMore else { return }

        let request = searchRequest
        pager.isLoadingMore = true
        pager.failed = false
        defer {
            if searchRequest == request { pager.isLoadingMore = false }
        }

        let page = pager.nextPage
        do {
            let chunk = try await fetchSearchChunk(tab: tab, page: page)
            guard searchRequest == request, searchTab == tab else { return }
            if chunk.isEmpty {
                pager.stop()
                return
            }
            applySearchChunk(chunk, to: tab, append: true)
            pager.nextPage = page + 1
            pager.hasMore = chunk.hasMore
        } catch {
            guard searchRequest == request, searchTab == tab else { return }
            pager.failed = true
        }
    }

    func scheduleSearchSuggestions() {
        searchSuggestTask?.cancel()
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, term != activeSearchKeyword else {
            searchSuggestItems = []
            isSearchSuggesting = false
            return
        }
        searchSuggestTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self else { return }
            await self.loadSearchSuggestions(term)
        }
    }

    func applySearchSuggestion(_ item: SearchSuggestItem) {
        searchTerm = item.query
        searchSuggestItems = []
        Task { await submitSearch() }
    }

    func loadSearchHotWords(force: Bool = false) async {
        guard coreState == .ready else { return }
        if !force, !searchHotWords.isEmpty { return }
        guard !isLoadingSearchHot else { return }
        isLoadingSearchHot = true
        defer { isLoadingSearchHot = false }

        if let words = try? await fetchSearchHotWords(method: "search.hot"), !words.isEmpty {
            searchHotWords = words
            return
        }
        if let words = try? await fetchSearchHotWords(method: "search.trending") {
            searchHotWords = words
        }
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }

    func loadSearchFirstPage(tab: SearchTab, request: UUID) async {
        do {
            if tab == .all {
                let result = try await fetchSearchAll(keyword: activeSearchKeyword)
                guard searchRequest == request, searchTab == tab else { return }
                searchAllVideos = result.videos
                searchAllBangumi = result.bangumi
                searchAllFilms = result.films
                searchAllUsers = result.users
                searchAllLiveRooms = result.liveRooms
                searchAllArticles = result.articles
                searchTotalResults = result.total
                searchLoadedTabs.insert(tab)
                return
            }

            let chunk = try await fetchSearchChunk(tab: tab, page: 1)
            guard searchRequest == request, searchTab == tab else { return }
            applySearchChunk(chunk, to: tab, append: false)
            searchTotalResults = chunk.total
            let pager = searchPagers[tab]!
            pager.nextPage = 2
            pager.hasMore = chunk.hasMore
            pager.failed = false
            searchLoadedTabs.insert(tab)
        } catch {
            guard searchRequest == request, searchTab == tab else { return }
            searchError = "搜索失败：\(describe(error))"
            searchPagers[tab]?.hasMore = false
        }
    }

    func reloadSearchVideoTab() async {
        guard searchAttempted, !activeSearchKeyword.isEmpty else { return }
        searchPagers[.video]?.reset()
        searchLoadedTabs.remove(.video)
        guard searchTab == .video else { return }

        cancelSearchLoads()
        searchResults = []
        searchTotalResults = 0
        searchError = nil
        isSearching = true
        let request = searchRequest
        defer {
            if searchRequest == request { isSearching = false }
        }
        await loadSearchFirstPage(tab: .video, request: request)
    }

    func clearSearch() {
        searchTerm = ""
        resetSearchState()
    }

    func resetSearchState() {
        cancelSearchLoads()
        activeSearchKeyword = ""
        searchAttempted = false
        searchError = nil
        searchTotalResults = 0
        searchSuggestItems = []
        resetSearchCaches()
    }

    func cancelSearchLoads() {
        searchRequest = UUID()
        isSearching = false
        for pager in searchPagers.values {
            pager.isLoadingMore = false
            pager.failed = false
        }
    }

    func resetSearchCaches() {
        searchResults = []
        searchAllVideos = []
        searchAllBangumi = []
        searchAllFilms = []
        searchAllUsers = []
        searchAllLiveRooms = []
        searchAllArticles = []
        searchUsers = []
        searchMedia = []
        searchLiveRooms = []
        searchArticles = []
        searchLoadedTabs = []
        for pager in searchPagers.values { pager.reset() }
    }

    func fetchSearchAll(keyword: String) async throws -> SearchAllResult {
        let value = try await core.call("search.all", params: [
            "keyword": .string(keyword),
            "page": .number(1),
            "page_size": .number(10),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<SearchAllData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "搜索失败")
        }
        if let voucher = response.data?.vVoucher, !voucher.isEmpty {
            throw BBCoreError.upstream(code: -412, message: "请求过于频繁，请稍后再试")
        }
        let groups = response.data?.result ?? []

        func groupItems(_ type: String) -> [JSONValue] {
            groups.first(where: { $0.resultType == type })?.data?.arrayValue ?? []
        }
        func decodeGroup<T: Decodable>(_ type: T.Type, _ name: String) -> [T] {
            groupItems(name).compactMap { try? CoreCoding.decode(type, from: $0) }
        }

        var result = SearchAllResult()
        result.videos = decodeGroup(SearchVideo.self, "video").compactMap(VideoItem.init(search:))
        result.bangumi = uniqueMedia(decodeGroup(SearchMedia.self, "media_bangumi"))
        result.films = uniqueMedia(decodeGroup(SearchMedia.self, "media_ft"))
        result.users = decodeGroup(SearchUser.self, "bili_user")
        result.liveRooms = decodeGroup(SearchLiveRoom.self, "live_room")
        result.articles = decodeGroup(SearchArticle.self, "article")
        result.total = response.data?.numResults ?? 0
        return result
    }

    func fetchSearchChunk(tab: SearchTab, page: Int) async throws -> SearchChunk {
        switch tab {
        case .all:
            return SearchChunk()
        case .video:
            let data = try await fetchSearchPage(SearchVideo.self, searchType: "video", page: page, filters: true)
            var chunk = SearchChunk(page: page, pageSize: feedPageSize)
            chunk.videos = (data.result ?? []).compactMap(VideoItem.init(search:))
            chunk.total = data.numResults ?? chunk.videos.count
            chunk.numPages = data.numPages ?? 0
            return chunk
        case .user:
            let data = try await fetchSearchPage(SearchUser.self, searchType: "bili_user", page: page, filters: false)
            var chunk = SearchChunk(page: page, pageSize: feedPageSize)
            chunk.users = data.result ?? []
            chunk.total = data.numResults ?? chunk.users.count
            chunk.numPages = data.numPages ?? 0
            return chunk
        case .media:
            let data = try await fetchSearchPage(
                SearchMedia.self,
                searchType: searchMediaKind.searchType,
                page: page,
                filters: false
            )
            var chunk = SearchChunk(page: page, pageSize: feedPageSize)
            chunk.media = uniqueMedia(data.result ?? [])
            chunk.total = data.numResults ?? chunk.media.count
            chunk.numPages = data.numPages ?? 0
            return chunk
        case .live:
            let data = try await fetchSearchPage(SearchLiveRoom.self, searchType: "live_room", page: page, filters: false)
            var chunk = SearchChunk(page: page, pageSize: feedPageSize)
            chunk.liveRooms = data.result ?? []
            chunk.total = data.numResults ?? chunk.liveRooms.count
            chunk.numPages = data.numPages ?? 0
            return chunk
        case .article:
            let data = try await fetchSearchPage(SearchArticle.self, searchType: "article", page: page, filters: false)
            var chunk = SearchChunk(page: page, pageSize: feedPageSize)
            chunk.articles = data.result ?? []
            chunk.total = data.numResults ?? chunk.articles.count
            chunk.numPages = data.numPages ?? 0
            return chunk
        }
    }

    func fetchSearchPage<T: Decodable>(
        _ type: T.Type,
        searchType: String,
        page: Int,
        filters: Bool
    ) async throws -> SearchPageData<T> {
        var params: [String: JSONValue] = [
            "keyword": .string(activeSearchKeyword),
            "search_type": .string(searchType),
            "page": .number(Double(page)),
            "page_size": .number(Double(feedPageSize)),
        ]
        if filters {
            params["order"] = .string(searchOrder)
            if !searchDuration.isEmpty {
                params["duration"] = .string(searchDuration)
            }
            if !searchTID.isEmpty {
                params["tids"] = .string(searchTID)
            }
        }
        let value = try await core.call("search.type", params: params)
        let response = try CoreCoding.decode(UpstreamResponse<SearchPageData<T>>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "搜索失败")
        }
        let data = response.data ?? SearchPageData()
        if let voucher = data.vVoucher, !voucher.isEmpty {
            throw BBCoreError.upstream(code: -412, message: "请求过于频繁，请稍后再试")
        }
        return data
    }

    func fetchSearchVideos(_ keyword: String, page: Int) async throws -> [VideoItem] {
        let value = try await core.call("search.type", params: [
            "keyword": .string(keyword),
            "search_type": .string("video"),
            "page": .number(Double(page)),
            "page_size": .number(Double(feedPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<SearchPageData<SearchVideo>>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
        }
        return (response.data?.result ?? []).compactMap(VideoItem.init(search:))
    }

    func applySearchChunk(_ chunk: SearchChunk, to tab: SearchTab, append: Bool) {
        switch tab {
        case .video:
            if append { appendSearchUnique(chunk.videos, to: &searchResults) } else { searchResults = chunk.videos }
        case .user:
            if append { appendSearchUnique(chunk.users, to: &searchUsers) } else { searchUsers = chunk.users }
        case .media:
            if append { appendSearchUnique(chunk.media, to: &searchMedia) } else { searchMedia = chunk.media }
        case .live:
            if append { appendSearchUnique(chunk.liveRooms, to: &searchLiveRooms) } else { searchLiveRooms = chunk.liveRooms }
        case .article:
            if append { appendSearchUnique(chunk.articles, to: &searchArticles) } else { searchArticles = chunk.articles }
        case .all:
            break
        }
    }

    func appendSearchUnique<T: Identifiable>(_ items: [T], to target: inout [T]) {
        var seen = Set(target.map(\.id))
        for item in items where seen.insert(item.id).inserted {
            target.append(item)
        }
    }

    func uniqueMedia(_ items: [SearchMedia]) -> [SearchMedia] {
        var seen = Set<Int64>()
        return items.filter { item in
            guard item.id > 0 else { return false }
            return seen.insert(item.id).inserted
        }
    }

    func loadSearchSuggestions(_ term: String) async {
        guard coreState == .ready else { return }
        guard term == searchTerm.trimmingCharacters(in: .whitespacesAndNewlines),
              term != activeSearchKeyword else { return }

        isSearchSuggesting = true
        defer { isSearchSuggesting = false }
        do {
            let value = try await core.call("search.suggest", params: ["term": .string(term)])
            let response = try CoreCoding.decode(SearchSuggestPayload.self, from: value)
            guard term == searchTerm.trimmingCharacters(in: .whitespacesAndNewlines),
                  term != activeSearchKeyword else { return }
            var seen = Set<String>()
            searchSuggestItems = (response.data?.result?.tag ?? []).filter { item in
                let query = item.query
                return !query.isEmpty && seen.insert(query).inserted
            }
        } catch {
            searchSuggestItems = []
        }
    }

    func fetchSearchHotWords(method: String) async throws -> [SearchHotWord] {
        let value = try await core.call(method, params: ["limit": .number(30)])
        let response = try CoreCoding.decode(SearchHotPayload.self, from: value)
        guard (response.code ?? 0) == 0 else {
            throw BBCoreError.upstream(code: response.code ?? -1, message: "热搜加载失败")
        }
        return (response.data?.list ?? []).filter { !$0.display.isEmpty }
    }

    func rememberSearchKeyword(_ keyword: String) {
        var items = searchHistory.filter { $0 != keyword }
        items.insert(keyword, at: 0)
        searchHistory = Array(items.prefix(10))
        UserDefaults.standard.set(searchHistory, forKey: searchHistoryKey)
    }
}
