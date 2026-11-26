#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Observation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home
    case dynamic
    case live
    case anime
    case discover
    case messages
    case search
    case profile
    case uploads
    case history
    case playlists
    case watchLater
    case downloads
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .dynamic: return "动态"
        case .live: return "直播"
        case .anime: return "番剧"
        case .discover: return "发现"
        case .messages: return "消息"
        case .search: return "搜索"
        case .profile: return "我的主页"
        case .uploads: return "我的投稿"
        case .history: return "历史记录"
        case .playlists: return "播放列表"
        case .watchLater: return "稍后再看"
        case .downloads: return "下载"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .dynamic: return "bolt.horizontal"
        case .live: return "dot.radiowaves.left.and.right"
        case .anime: return "play.tv"
        case .discover: return "safari"
        case .messages: return "bell"
        case .search: return "magnifyingglass"
        case .profile: return "person.crop.circle"
        case .uploads: return "video"
        case .history: return "clock.arrow.circlepath"
        case .playlists: return "list.bullet.rectangle"
        case .watchLater: return "bookmark"
        case .downloads: return "arrow.down.circle"
        case .settings: return "gearshape"
        }
    }
}

enum HomeTab: String, CaseIterable, Identifiable {
    case recommend
    case hot
    case ranking
    case categories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommend: return "推荐"
        case .hot: return "热门"
        case .ranking: return "排行榜"
        case .categories: return "分区"
        }
    }
}

enum HomeFilter: String, CaseIterable, Identifiable {
    case all
    case hot
    case bangumi
    case movie
    case guochuang
    case tvSeries
    case variety
    case documentary
    case animation
    case games
    case guichu
    case music
    case dance
    case film
    case entertainment
    case knowledge
    case tech
    case news
    case food
    case miniTheater
    case cars
    case fashion
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .hot: return "热门"
        case .bangumi: return "番剧"
        case .movie: return "电影"
        case .guochuang: return "国创"
        case .tvSeries: return "电视剧"
        case .variety: return "综艺"
        case .documentary: return "纪录片"
        case .animation: return "动画"
        case .games: return "游戏"
        case .guichu: return "鬼畜"
        case .music: return "音乐"
        case .dance: return "舞蹈"
        case .film: return "影视"
        case .entertainment: return "娱乐"
        case .knowledge: return "知识"
        case .tech: return "科技数码"
        case .news: return "资讯"
        case .food: return "美食"
        case .miniTheater: return "小剧场"
        case .cars: return "汽车"
        case .fashion: return "时尚美妆"
        case .sports: return "体育运动"
        }
    }

    var query: String? {
        switch self {
        case .all, .hot: return nil
        case .tech: return "科技"
        case .sports: return "运动"
        default: return title
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .hot: return "flame"
        case .bangumi: return "tv"
        case .movie: return "film"
        case .guochuang: return "sparkles.tv"
        case .tvSeries: return "play.tv"
        case .variety: return "mic"
        case .documentary: return "globe"
        case .animation: return "sparkles"
        case .games: return "gamecontroller"
        case .guichu: return "repeat"
        case .music: return "music.note"
        case .dance: return "figure.dance"
        case .film: return "film.stack"
        case .entertainment: return "star"
        case .knowledge: return "book"
        case .tech: return "cpu"
        case .news: return "newspaper"
        case .food: return "fork.knife"
        case .miniTheater: return "theatermasks"
        case .cars: return "car"
        case .fashion: return "paintbrush"
        case .sports: return "figure.run"
        }
    }
}

enum CoreState: Equatable {
    case starting
    case ready
    case failed(String)
}

enum LoginState: Equatable {
    case idle
    case loading
    case waiting
    case scanned
    case expired
    case success
    case failed(String)
}

enum LoginPollResult: Equatable {
    case waiting
    case scanned
    case expired
    case success
    case failed(String)
}

@MainActor
@Observable
final class AppModel {
    var section: SidebarSection = .home
    var navigationPath: [VideoItem] = []
    var homeTab: HomeTab = .recommend
    var homeFilter: HomeFilter = .all
    var focusSearchToken = 0

    var videos: [VideoItem] = []
    var isLoading = false
    var errorMessage: String?

    var recentUPs: [RecentUP] = []
    var isLoadingRecentUPs = false

    var dynamicCards: [DynamicCard] = []
    var dynamicFeedType: DynamicFeedType = .all
    var activeDynamic: DynamicCard?
    var isLoadingDynamic = false
    var dynamicHasMore = false
    var dynamicLoaded = false
    var dynamicError: String?
    var dynamicComments: [VideoComment] = []
    var dynamicCommentTotal = 0
    var isLoadingDynamicComments = false
    var isPostingDynamicComment = false
    var dynamicCommentsError: String?
    var dynamicCommentPage = 0
    private var dynamicCommentNextOffset = 0
    private var dynamicOffset = ""
    private var dynamicRequest = UUID()

    var liveRooms: [LiveRoom] = []
    var liveFeedFilter: LiveFeedFilter = .live
    var activeLiveRoom: LiveRoom?
    var liveRoomInfo: LiveRoomInfo?
    var livePlayback: LivePlayResult?
    var liveQualities: [LiveQuality] = []
    var liveSelectedQN: Int?
    var livePlayError: String?
    var isLoadingLivePlay = false
    var liveChatMessages: [LiveChatMessage] = []
    var liveConnected = false
    var livePopularity = 0
    var liveWatched = 0
    var liveAttention = 0
    var liveIsFollowing = false
    var isSendingLiveMessage = false
    var isLoadingLive = false
    var liveHasMore = false
    var liveLoaded = false
    var liveError: String?
    var liveFollowedLiveCount = 0
    private var livePage = 1
    private var liveRequest = UUID()
    @ObservationIgnored private var liveEventsTask: Task<Void, Never>?

    var animeTab: AnimeTab = .timeline
    var animeTimeline: [AnimeTimelineDay] = []
    var animeSelectedDay: String?
    var animeRankItems: [AnimeRankItem] = []
    var animeRankNote: String?
    var isLoadingAnime = false
    var animeLoaded = false
    var animeError: String?
    private var animeRequest = UUID()

    var activeAnimeSeasonID: Int64?
    var animeSeason: AnimeSeason?
    var animeSelectedEpisode: AnimeEpisode?
    var animePlayback: AnimePlayResult?
    var animeSelectedQN: Int?
    var animePlayError: String?
    var isLoadingAnimePlay = false
    var isLoadingAnimeSeason = false
    var animeSeasonError: String?
    var animeReviews: [AnimeReview] = []
    var animeReviewTotal = 0
    var isLoadingAnimeReviews = false
    var animeReviewsError: String?
    var animeReviewsLoaded = false
    var isTogglingAnimeFollow = false
    private var animeReviewCursor = ""
    private var animeReviewMediaID: Int64?

    var followingUPs: [FollowingUP] = []
    var followingTotal = 0
    var isLoadingFollowing = false
    var followingError: String?
    var followingLoaded = false
    var followTags: [FollowTag] = []
    var followTagsLoaded = false
    var isLoadingFollowTags = false
    var followTagsError: String?
    var selectedFollowTagID: Int64?
    var followSearchInput = ""
    var followSearchKeyword = ""
    private var specialFollowMids: Set<Int64> = []
    private var specialFollowMidsLoaded = false
    var followers: [FollowingUP] = []
    var followersTotal = 0
    var isLoadingFollowers = false
    var followersError: String?
    var followersLoaded = false

    var messageTab: MessageTab = .replies
    var messageUnread: MessageUnread?
    var messageReplies = MessageFeed<MessageReplyEntry>()
    var messageAts = MessageFeed<MessageAtEntry>()
    var messageLikes = MessageFeed<MessageLikeEntry>()
    var messageSystem = MessageFeed<SystemMessage>()
    private var messageUnreadRequest = UUID()
    private var messageRequest = UUID()

    var activeUPMid: Int64?
    var activeUP: UPProfile?
    var upVideos: [VideoItem] = []
    var isLoadingUP = false
    var upError: String?
    var isUpFollowBusy = false

    var myUploads: [VideoItem] = []
    var isLoadingMyUploads = false
    var myUploadsError: String?

    var isLoadingHistory = false
    var historyError: String?
    var historyLoaded = false
    var historyPaused = false
    private var historyStatusLoaded = false

    var laterVideos: [VideoItem] = []
    var laterTotal = 0
    var isLoadingLater = false
    var laterError: String?

    var downloadJobs: [DownloadJob] = []
    var isLoadingDownloads = false
    var downloadError: String?
    var downloadLoaded = false
    var downloadUsedBytes: Int64 = 0
    var downloadFreeBytes: Int64 = 0
    var downloadDiskBytes: Int64 = 0
    var downloadDirectory = ""
    var activeDownloadID: String?
    var downloadActionIDs: Set<String> = []
    private var downloadEventsTask: Task<Void, Never>?

    var favoriteFolders: [FavFolder] = []
    var isLoadingPlaylists = false
    var playlistsError: String?
    var selectedFolder: FavFolder?
    var folderVideos: [VideoItem] = []
    var isLoadingFolderVideos = false
    var folderError: String?

    var searchTerm = ""
    var searchTab: SearchTab = .all
    var searchMediaKind: SearchMediaKind = .bangumi
    var searchOrder = "totalrank"
    var searchDuration = ""
    var searchTID = ""
    var searchResults: [VideoItem] = []
    var searchAllVideos: [VideoItem] = []
    var searchAllBangumi: [SearchMedia] = []
    var searchAllFilms: [SearchMedia] = []
    var searchAllUsers: [SearchUser] = []
    var searchAllLiveRooms: [SearchLiveRoom] = []
    var searchAllArticles: [SearchArticle] = []
    var searchUsers: [SearchUser] = []
    var searchMedia: [SearchMedia] = []
    var searchLiveRooms: [SearchLiveRoom] = []
    var searchArticles: [SearchArticle] = []
    var searchTotalResults = 0
    var searchHotWords: [SearchHotWord] = []
    var searchSuggestItems: [SearchSuggestItem] = []
    var searchHistory: [String] = []
    var isSearchSuggesting = false
    var isLoadingSearchHot = false
    var isSearching = false
    var searchError: String?
    var searchAttempted = false
    var activeSearchKeyword = ""

    var activeArticleID: Int64?
    var articleDetail: ArticleDetail?
    var isLoadingArticle = false
    var articleError: String?

    var discoverTab: DiscoverTab = .ranking
    var discoverRanking: [VideoItem] = []
    var isLoadingDiscoverRanking = false
    var discoverRankingError: String?
    var discoverRankingLoaded = false
    var weeklySeries: [WeeklySeries] = []
    var isLoadingWeeklySeries = false
    var weeklySeriesError: String?
    var weeklySeriesLoaded = false
    var selectedWeeklyNumber: Int?
    var weeklyIssue: WeeklyIssueData?
    var weeklyVideos: [VideoItem] = []
    var isLoadingWeeklyIssue = false
    var weeklyIssueError: String?
    var topicSquare: [TopicSquareItem] = []
    var isLoadingTopicSquare = false
    var topicSquareError: String?
    var topicSquareLoaded = false
    var articleRank: [ArticleRankItem] = []
    var isLoadingArticleRank = false
    var articleRankError: String?
    var articleRankLoaded = false

    var activeTopic: TopicSquareItem?
    var topicDetail: TopicDetailItem?
    var topicFeedCards: [DynamicCard] = []
    var topicFeedOffset = ""
    var topicFeedHasMore = false
    var topicFeedLoaded = false
    var isLoadingTopicDetail = false
    var isLoadingTopicFeed = false
    var topicFeedError: String?
    private var discoverRankingRequest = UUID()
    private var weeklyIssueRequest = UUID()
    private var topicSquareRequest = UUID()
    private var articleRankRequest = UUID()
    private var topicFeedRequest = UUID()

    var profile: UserProfile?
    var accounts: [StoredAccount] = []
    var uploads: [VideoItem] = []
    var history: [VideoItem] = []
    var isProfileLoading = false
    var profileError: String?

    var detail: VideoInfoData?
    var detailBVID: String?
    var relatedVideos: [VideoItem] = []
    var comments: [VideoComment] = []
    var commentTotal = 0
    var commentPage = 0
    var commentNextOffset = 0
    var commentSort = 0
    var relation: VideoRelationData?
    var videoTags: [String] = []
    var aiConclusion: AIConclusionResult?
    var isLoadingAI = false
    var isLoadingDetail = false
    var isLoadingRelated = false
    var isLoadingComments = false
    var isPostingComment = false
    var detailError: String?
    var commentsError: String?
    var watchLaterVideos: Set<String> = []
    var toastMessage: String?
    var isTheaterActive = false

    var isLoginSheetPresented = false
    var qrPayload: QRPayload?
    var loginState: LoginState = .idle

    var smsPhone = ""
    var smsCode = ""
    var smsCaptchaKey: String?
    var smsCooldown = 0
    var isSendingSMS = false
    var isLoggingInSMS = false
    var smsError: String?
    var smsCaptchaChallenge: SMSCaptchaChallenge?
    private var smsCooldownTask: Task<Void, Never>?

    var activeDownload: DownloadJob? {
        guard let id = activeDownloadID else { return nil }
        return downloadJobs.first(where: { $0.id == id })
    }

    var coreState: CoreState = .starting

    let homePager = Pager()
    let searchPagers: [SearchTab: Pager] = [
        .all: Pager(),
        .video: Pager(),
        .user: Pager(),
        .media: Pager(),
        .live: Pager(),
        .article: Pager(),
    ]
    let upPager = Pager()
    let uploadsPager = Pager()
    let historyPager = Pager()
    let laterPager = Pager()
    let folderPager = Pager()
    let followingPager = Pager()
    let followersPager = Pager()

    var searchPager: Pager { searchPagers[searchTab] ?? searchPagers[.all]! }

    private let core: any CoreTransport
    @ObservationIgnored let eventHub: EventHub
    private var started = false
    private var homeRequest = UUID()
    private var followingRequest = UUID()
    private var followersRequest = UUID()
    private var followTagsRequest = UUID()
    private var searchRequest = UUID()
    private var searchLoadedTabs: Set<SearchTab> = []
    private var searchSuggestTask: Task<Void, Never>?
    private var historyCursorMax = 0
    private var historyCursorViewAt = 0
    private let feedPageSize = 20
    private let libraryPageSize = 30
    private let searchHistoryKey = "btb.search.history"
    private var toastTask: Task<Void, Never>?

    init(transport: any CoreTransport) {
        core = transport
        eventHub = EventHub(transport: transport)
        searchHistory = UserDefaults.standard.stringArray(forKey: "btb.search.history") ?? []
    }

    var isLoggedIn: Bool { profile != nil }
    var hasAccount: Bool { activeAccount != nil }
    var currentVideo: VideoItem? { navigationPath.first }

    var activeAccount: StoredAccount? {
        accounts.first(where: { $0.active == true }) ?? accounts.first
    }

    func start() async {
        guard !started else { return }
        started = true
        Perf.milestone("launch.startCalled")
        coreState = .starting
        errorMessage = nil
        // A5: render the last feed immediately; the network refresh replaces it.
        if videos.isEmpty, homeTab == .recommend {
            let cached = FeedCache.load()
            if !cached.isEmpty {
                videos = cached
                homePager.hasMore = false
                Perf.milestone("launch.firstFeed", "source=cache count=\(cached.count)")
            }
        }

        do {
            try await core.start()
            eventHub.start()
            await eventHub.refreshCapabilities()
            _ = try await core.call("core.ping")
            coreState = .ready
            await loadHome()
            await refreshAccount()
            await loadMessageUnread()
            startDownloadEventStream()
            await loadDownloads(force: true)
            await applyDownloadConfig()
#if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BTB_SECTION"],
               let section = SidebarSection(rawValue: raw) {
                selectSection(section)
            }
            if let bvid = ProcessInfo.processInfo.environment["BTB_OPEN_BVID"], !bvid.isEmpty {
                openVideo(VideoItem(bvid: bvid))
            }
            if let raw = ProcessInfo.processInfo.environment["BTB_OPEN_UP_MID"],
               let upMid = Int64(raw), upMid > 0 {
                openUP(mid: upMid)
            }
            if let raw = ProcessInfo.processInfo.environment["BTB_OPEN_SEASON"],
               let seasonID = Int64(raw), seasonID > 0 {
                openAnimeSeason(seasonID)
            }
            if let day = ProcessInfo.processInfo.environment["BTB_ANIME_DAY"], !day.isEmpty {
                animeSelectedDay = day
            }
            if let input = ProcessInfo.processInfo.environment["BTB_SEARCH_INPUT"], !input.isEmpty {
                section = .search
                searchTerm = input
                scheduleSearchSuggestions()
            }
            if let keyword = ProcessInfo.processInfo.environment["BTB_SEARCH"], !keyword.isEmpty {
                if let raw = ProcessInfo.processInfo.environment["BTB_SEARCH_TAB"],
                   let tab = SearchTab(rawValue: raw) {
                    searchTab = tab
                }
                if let raw = ProcessInfo.processInfo.environment["BTB_SEARCH_MEDIA"],
                   let kind = SearchMediaKind(rawValue: raw) {
                    searchMediaKind = kind
                }
                if let order = ProcessInfo.processInfo.environment["BTB_SEARCH_ORDER"], !order.isEmpty {
                    searchOrder = order
                }
                if let duration = ProcessInfo.processInfo.environment["BTB_SEARCH_DURATION"], !duration.isEmpty {
                    searchDuration = duration
                }
                if let tid = ProcessInfo.processInfo.environment["BTB_SEARCH_TID"], !tid.isEmpty {
                    searchTID = tid
                }
                searchTerm = keyword
                await submitSearch()
            }
            if let raw = ProcessInfo.processInfo.environment["BTB_OPEN_ARTICLE"],
               let articleID = Int64(raw), articleID > 0 {
                openArticle(id: articleID)
            }
            if let raw = ProcessInfo.processInfo.environment["BTB_DISCOVER_TAB"],
               let tab = DiscoverTab(rawValue: raw) {
                discoverTab = tab
            }
            if let raw = ProcessInfo.processInfo.environment["BTB_OPEN_TOPIC"],
               let topicID = Int64(raw), topicID > 0 {
                let name = ProcessInfo.processInfo.environment["BTB_TOPIC_NAME"] ?? "话题"
                openTopic(id: topicID, name: name)
            }
            if let bvid = ProcessInfo.processInfo.environment["BTB_DOWNLOAD_BVID"], !bvid.isEmpty {
                let qn = Int64(ProcessInfo.processInfo.environment["BTB_DOWNLOAD_QN"] ?? "") ?? 80
                let codec = ProcessInfo.processInfo.environment["BTB_DOWNLOAD_CODEC"] ?? "hevc"
                if let info = try? await fetchVideoInfo(bvid: bvid) {
                    await startDownload(
                        bvid: bvid,
                        cid: info.cid.map(Int64.init),
                        title: info.title ?? bvid,
                        cover: info.pic,
                        owner: info.owner?.name,
                        durationMS: Int64(info.duration ?? 0) * 1000,
                        qn: qn,
                        codec: codec
                    )
                }
                if ProcessInfo.processInfo.environment["BTB_DOWNLOAD_WAIT"] == "1" {
                    for _ in 0..<120 {
                        await loadDownloads(force: true)
                        if downloadJobs.contains(where: { $0.isCompleted || $0.isFailed }) {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            if ProcessInfo.processInfo.environment["BTB_OPEN_DOWNLOAD"] == "1",
               let job = downloadJobs.first(where: { $0.isCompleted }) {
                openDownload(job)
            }
#endif
        } catch {
            let message = describe(error)
            coreState = .failed(message)
            errorMessage = message
        }
    }

    func loadHome() async {
        let request = UUID()
        homeRequest = request
        homePager.reset()
        switch homeTab {
        case .recommend:
            await loadRecommend(request: request, freshIndex: 0)
        case .hot:
            await loadHotFeed(request: request, page: 1)
        case .ranking:
            await loadRanking(request: request)
        case .categories:
            if homeFilter == .hot {
                await loadHotFeed(request: request, page: 1)
            } else if let query = homeFilter.query {
                await loadCategory(query, request: request, page: 1)
            } else {
                await loadRecommend(request: request, freshIndex: 0)
            }
        }
    }

    func loadHomeMore() async {
        guard coreState == .ready,
              !isLoading,
              !homePager.isLoadingMore,
              homePager.hasMore else { return }
        let request = homeRequest
        homePager.isLoadingMore = true
        homePager.failed = false
        defer {
            if homeRequest == request { homePager.isLoadingMore = false }
        }

        switch homeTab {
        case .recommend:
            await loadRecommendMore(request: request)
        case .hot:
            await loadHotFeedMore(request: request)
        case .ranking:
            homePager.stop()
        case .categories:
            if homeFilter == .hot {
                await loadHotFeedMore(request: request)
            } else if let query = homeFilter.query {
                await loadCategoryMore(query, request: request)
            } else {
                await loadRecommendMore(request: request)
            }
        }
    }

    func selectHomeTab(_ tab: HomeTab) async {
        homeTab = tab
        section = .home
        closeVideo()
        closeUP()
        await loadHome()
    }

    func selectHomeFilter(_ filter: HomeFilter) async {
        homeFilter = filter
        homeTab = .categories
        section = .home
        closeVideo()
        closeUP()
        await loadHome()
    }

    func selectSection(_ newSection: SidebarSection) {
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        closeDownload()
        if newSection != .playlists {
            selectedFolder = nil
        }
        section = newSection
        if newSection == .messages {
            Task { await loadMessageUnread(force: true) }
        }
    }

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

    private func appendUniqueDynamic(_ cards: [DynamicCard]) {
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

    private func appendUniqueLiveRooms(_ rooms: [LiveRoom]) {
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

    private func failLivePlayback(_ message: String) {
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

    private func startLiveEventStream() {
        liveEventsTask?.cancel()
        let stream = eventHub.subscribe(topics: ["live.*"])
        liveEventsTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.handleLiveEvent(event)
            }
        }
    }

    private func handleLiveEvent(_ event: CoreEvent) {
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

    private func appendLiveChat(_ messages: [LiveChatMessage]) {
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

    private func resetLiveFeed() {
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

    func selectAnimeDay(_ date: String) {
        animeSelectedDay = date
    }

    func setAnimeTab(_ tab: AnimeTab) async {
        guard tab != animeTab else { return }
        animeTab = tab
        await loadAnimeFeed(reset: true)
    }

    func loadAnimeFeed(reset: Bool = false) async {
        guard coreState == .ready else { return }
        if reset {
            animeRequest = UUID()
            animeTimeline = []
            animeRankItems = []
            animeRankNote = nil
            animeSelectedDay = nil
            animeLoaded = false
            animeError = nil
            // A reset supersedes any in-flight load; its late response is
            // dropped by the request check and must not keep the spinner up.
            isLoadingAnime = false
        } else {
            guard !animeLoaded else { return }
        }
        guard !isLoadingAnime else { return }

        let request = animeRequest
        isLoadingAnime = true
        animeError = nil
        defer {
            if animeRequest == request {
                isLoadingAnime = false
                animeLoaded = true
            }
        }

        do {
            switch animeTab {
            case .timeline:
                let value = try await core.call("pgc.timeline", params: [
                    "types": .number(1),
                    "before": .number(3),
                    "after": .number(3),
                ])
                let response = try CoreCoding.decode(UpstreamResultResponse<[AnimeTimelineDay]>.self, from: value)
                guard animeRequest == request else { return }
                guard response.code == 0 else {
                    throw BBCoreError.upstream(code: response.code, message: response.message ?? "时间表加载失败")
                }
                animeTimeline = response.result ?? []
                if animeSelectedDay == nil {
                    animeSelectedDay = animeTimeline.first(where: \.isTodayDay)?.date ?? animeTimeline.first?.date
                }
            case .rank:
                let value = try await core.call("pgc.rank", params: [
                    "day": .number(3),
                    "season_type": .number(1),
                ])
                let response = try CoreCoding.decode(UpstreamResultResponse<AnimeRankData>.self, from: value)
                guard animeRequest == request else { return }
                guard response.code == 0 else {
                    throw BBCoreError.upstream(code: response.code, message: response.message ?? "排行榜加载失败")
                }
                animeRankItems = response.result?.list ?? []
            }
        } catch {
            guard animeRequest == request else { return }
            animeError = "番剧加载失败：\(describe(error))"
        }
    }

    func openAnimeSeason(_ seasonID: Int64) {
        guard seasonID > 0, activeAnimeSeasonID != seasonID else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        section = .anime
        activeAnimeSeasonID = seasonID
        animeSeason = nil
        animeSelectedEpisode = nil
        animePlayback = nil
        animeSelectedQN = nil
        animePlayError = nil
        animeSeasonError = nil
        animeReviews = []
        animeReviewCursor = ""
        animeReviewTotal = 0
        animeReviewsLoaded = false
        animeReviewsError = nil
        animeReviewMediaID = nil
        Task { await loadAnimeSeason(seasonID: seasonID) }
    }

    func closeAnimeSeason() {
        let sessionID = animePlayback?.sessionID
        activeAnimeSeasonID = nil
        animeSeason = nil
        animeSelectedEpisode = nil
        animePlayback = nil
        animeSelectedQN = nil
        animePlayError = nil
        animeSeasonError = nil
        animeReviews = []
        animeReviewCursor = ""
        animeReviewTotal = 0
        animeReviewsLoaded = false
        animeReviewsError = nil
        if let sessionID {
            Task { await stopStream(sessionID: sessionID) }
        }
    }

    func loadAnimeSeason(seasonID: Int64, force: Bool = false) async {
        guard activeAnimeSeasonID == seasonID else { return }
        if !force, animeSeason?.seasonID == seasonID { return }
        isLoadingAnimeSeason = true
        animeSeasonError = nil
        defer {
            if activeAnimeSeasonID == seasonID {
                isLoadingAnimeSeason = false
            }
        }

        do {
            let value = try await core.call("pgc.info", params: ["season_id": .number(Double(seasonID))])
            let response = try CoreCoding.decode(UpstreamResultResponse<AnimeSeason>.self, from: value)
            guard activeAnimeSeasonID == seasonID else { return }
            guard response.code == 0, let season = response.result, season.seasonID > 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "番剧信息加载失败")
            }
            animeSeason = season
            if animeSelectedEpisode == nil {
                animeSelectedEpisode = defaultAnimeEpisode(for: season)
            }
            animeReviewMediaID = season.mediaID
            await loadAnimeReviews(reset: true)
#if DEBUG
            if let mode = ProcessInfo.processInfo.environment["BTB_ANIME_PLAY"], !mode.isEmpty, mode != "0" {
                let episode = mode == "newest"
                    ? animeSelectedEpisode
                    : animeSeason?.episodes?.first
                if let episode {
                    await playAnime(episode)
                }
            }
#endif
        } catch {
            guard activeAnimeSeasonID == seasonID else { return }
            animeSeasonError = "番剧信息加载失败：\(describe(error))"
        }
    }

    private func defaultAnimeEpisode(for season: AnimeSeason) -> AnimeEpisode? {
        let episodes = season.episodes ?? []
        if let newest = season.newEp?.title,
           let match = episodes.first(where: { $0.title == newest || $0.longTitle == newest }) {
            return match
        }
        return episodes.first
    }

    func playAnime(_ episode: AnimeEpisode, qn: Int? = nil) async {
        guard let seasonID = activeAnimeSeasonID else { return }
        animeSelectedEpisode = episode
        await prepareAnimePlayback(seasonID: seasonID, episode: episode, qn: qn)
    }

    func selectAnimeQuality(_ qn: Int) async {
        guard let episode = animeSelectedEpisode, qn != animeSelectedQN else { return }
        await prepareAnimePlayback(seasonID: activeAnimeSeasonID ?? 0, episode: episode, qn: qn)
    }

    private func prepareAnimePlayback(seasonID: Int64, episode: AnimeEpisode, qn: Int?) async {
        guard seasonID > 0, activeAnimeSeasonID == seasonID else { return }
        isLoadingAnimePlay = true
        animePlayError = nil
        defer {
            if activeAnimeSeasonID == seasonID {
                isLoadingAnimePlay = false
            }
        }

        var params: [String: JSONValue] = [
            "season_id": .number(Double(seasonID)),
            "ep_id": .number(Double(episode.epID)),
            "try_look": .bool(true),
        ]
        if let cid = episode.cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        }
        if let qn {
            params["qn"] = .number(Double(qn))
        }

        do {
            let value = try await core.call("pgc.play", params: params)
            let result = try CoreCoding.decode(AnimePlayResult.self, from: value)
            guard activeAnimeSeasonID == seasonID else {
                if let sessionID = result.sessionID {
                    await stopStream(sessionID: sessionID)
                }
                return
            }
            guard result.playable else {
                if qn != nil, animePlayback != nil {
                    showToast(result.unavailableText)
                } else {
                    animePlayback = nil
                    animeSelectedQN = nil
                    animePlayError = result.unavailableText
                }
                return
            }
            let previous = animePlayback?.sessionID
            if let previous, previous != result.sessionID {
                await stopStream(sessionID: previous)
            }
            animePlayback = result
            animeSelectedQN = result.quality?.qn
            if let returned = result.episode, returned.epID > 0 {
                animeSelectedEpisode = returned
            }
        } catch {
            guard activeAnimeSeasonID == seasonID else { return }
            animePlayError = "剧集加载失败：\(describe(error))"
        }
    }

    func toggleAnimeFollow() async {
        guard let season = animeSeason else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard !isTogglingAnimeFollow else { return }
        isTogglingAnimeFollow = true
        defer { isTogglingAnimeFollow = false }
        let target = !season.isFollowing
        do {
            _ = try await core.call("pgc.follow", params: [
                "season_id": .number(Double(season.seasonID)),
                "follow": .bool(target),
            ])
            showToast(target ? "已追番" : "已取消追番")
            await loadAnimeSeason(seasonID: season.seasonID, force: true)
        } catch {
            showToast("操作失败：\(describe(error))")
        }
    }

    var animeReviewsHasMore: Bool { !animeReviewCursor.isEmpty }

    func loadAnimeReviews(reset: Bool = false) async {
        guard let mediaID = animeReviewMediaID ?? animeSeason?.mediaID, mediaID > 0 else { return }
        if reset {
            animeReviews = []
            animeReviewCursor = ""
            animeReviewTotal = 0
            animeReviewsLoaded = false
            animeReviewsError = nil
        } else if animeReviewsLoaded, animeReviewsHasMore == false {
            return
        }
        guard !isLoadingAnimeReviews else { return }

        isLoadingAnimeReviews = true
        defer { isLoadingAnimeReviews = false }

        var params: [String: JSONValue] = [
            "media_id": .number(Double(mediaID)),
            "type": .string("short"),
            "ps": .number(12),
            "sort": .number(0),
        ]
        if !animeReviewCursor.isEmpty {
            params["cursor"] = .string(animeReviewCursor)
        }

        do {
            let value = try await core.call("pgc.review", params: params)
            let response = try CoreCoding.decode(UpstreamResponse<AnimeReviewData>.self, from: value)
            guard animeReviewMediaID == mediaID else { return }
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "短评加载失败")
            }
            let data = response.data
            let list = data?.list ?? []
            if reset {
                animeReviews = list
            } else {
                animeReviews.append(contentsOf: list)
            }
            animeReviewCursor = data?.next ?? ""
            animeReviewTotal = data?.total ?? animeReviewTotal
            animeReviewsLoaded = true
        } catch {
            guard animeReviewMediaID == mediaID else { return }
            animeReviewsError = "短评加载失败：\(describe(error))"
        }
    }

    private func resetAnimeFeed() {
        animeRequest = UUID()
        animeTimeline = []
        animeRankItems = []
        animeSelectedDay = nil
        animeLoaded = false
        animeError = nil
        animeReviewMediaID = nil
        isLoadingAnime = false
    }

    private func loadRecommend(request: UUID, freshIndex: Int) async {
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

    private func loadRecommendMore(request: UUID) async {
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

    private func fetchRecommend(freshIndex: Int) async throws -> [VideoItem] {
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

    private func loadRanking(request: UUID) async {
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

    private func loadHotFeed(request: UUID, page: Int) async {
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

    private func loadHotFeedMore(request: UUID) async {
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

    private func fetchHotVideos(page: Int) async throws -> [VideoItem] {
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

    private func loadCategory(_ keyword: String, request: UUID, page: Int) async {
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

    private func loadCategoryMore(_ keyword: String, request: UUID) async {
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
    private func appendUnique(_ items: [VideoItem], to target: inout [VideoItem]) -> Int {
        var seen = Set(target.map(\.bvid))
        var added = 0
        for item in items where seen.insert(item.bvid).inserted {
            target.append(item)
            added += 1
        }
        return added
    }

    func loadRecentUPs() async {
        guard coreState == .ready else { return }
        isLoadingRecentUPs = true
        defer { isLoadingRecentUPs = false }

        if hasAccount {
            do {
                let value = try await core.call("dynamic.feed", params: ["type": .string("video")])
                let response = try CoreCoding.decode(UpstreamResponse<DynamicFeedResult>.self, from: value)
                if response.code == 0, let items = response.data?.items, !items.isEmpty {
                    var seen = Set<Int64>()
                    var result: [RecentUP] = []
                    for item in items {
                        guard let card = DynamicModelParser.card(from: item),
                              let mid = card.author.mid, mid > 0,
                              seen.insert(mid).inserted else { continue }
                        result.append(RecentUP(
                            mid: mid,
                            name: card.author.name,
                            avatarURL: card.author.avatarURL,
                            updateText: card.author.pubTime,
                            latestTitle: card.attachment.video?.title ?? card.text
                        ))
                        if result.count >= 8 { break }
                    }
                    if !result.isEmpty {
                        recentUPs = result
                        return
                    }
                }
            } catch {
                // Fall back to the owners of the current feed.
            }
        }

        var seen = Set<Int64>()
        var result: [RecentUP] = []
        for video in videos {
            guard let mid = video.ownerMid, mid > 0, seen.insert(mid).inserted else { continue }
            result.append(RecentUP(
                mid: mid,
                name: video.ownerName,
                avatarURL: video.ownerFaceURL,
                updateText: video.publishedAgoText,
                latestTitle: video.title
            ))
            if result.count >= 8 { break }
        }
        recentUPs = result
    }

    func loadFollowing(force: Bool = false) async {
        guard hasAccount else {
            followingUPs = []
            followingTotal = 0
            followingError = nil
            followingLoaded = false
            followingPager.reset()
            return
        }
        guard force || !followingLoaded, !isLoadingFollowing else { return }
        if force { specialFollowMidsLoaded = false }

        let request = UUID()
        followingRequest = request
        isLoadingFollowing = true
        followingError = nil
        followingPager.reset()
        defer {
            if followingRequest == request {
                isLoadingFollowing = false
            }
        }

        do {
            let page = try await fetchFollowingPage(page: 1)
            guard hasAccount, followingRequest == request else { return }
            followingUPs = page.items
            followingTotal = page.total
            followingLoaded = true
            followingPager.nextPage = 2
            if page.total > 0 {
                followingPager.hasMore = page.items.count < page.total
            } else {
                followingPager.hasMore = page.items.count >= libraryPageSize
            }
        } catch {
            guard hasAccount, followingRequest == request else { return }
            followingError = "关注列表加载失败：\(describe(error))"
            followingPager.hasMore = false
        }
    }

    func loadMoreFollowing() async {
        guard hasAccount,
              !isLoadingFollowing,
              !followingPager.isLoadingMore,
              followingPager.hasMore else { return }
        let request = followingRequest
        followingPager.isLoadingMore = true
        followingPager.failed = false
        defer {
            if followingRequest == request {
                followingPager.isLoadingMore = false
            }
        }

        let page = followingPager.nextPage
        do {
            let result = try await fetchFollowingPage(page: page)
            guard hasAccount, followingRequest == request else { return }
            followingPager.nextPage = page + 1
            if result.items.isEmpty {
                followingPager.stop()
                return
            }
            var seen = Set(followingUPs.map(\.mid))
            for item in result.items where seen.insert(item.mid).inserted {
                followingUPs.append(item)
            }
            if result.total > followingTotal {
                followingTotal = result.total
            }
            if followingTotal > 0 {
                followingPager.hasMore = followingUPs.count < followingTotal
            } else {
                followingPager.hasMore = result.items.count >= libraryPageSize
            }
        } catch {
            guard followingRequest == request else { return }
            followingPager.failed = true
        }
    }

    func loadFollowTags(force: Bool = false) async {
        guard hasAccount else {
            followTags = []
            followTagsLoaded = false
            followTagsError = nil
            return
        }
        guard force || !followTagsLoaded, !isLoadingFollowTags else { return }

        let request = UUID()
        followTagsRequest = request
        isLoadingFollowTags = true
        followTagsError = nil
        defer {
            if followTagsRequest == request {
                isLoadingFollowTags = false
            }
        }

        do {
            let value = try await core.call("user.follow_tags")
            let response = try CoreCoding.decode(UpstreamResponse<[FollowTag]>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注分组加载失败")
            }
            guard hasAccount, followTagsRequest == request else { return }
            followTags = response.data ?? []
            followTagsLoaded = true
        } catch {
            guard followTagsRequest == request else { return }
            followTagsError = "关注分组加载失败：\(describe(error))"
        }
    }

    func selectFollowTag(_ tagID: Int64?) async {
        if selectedFollowTagID == tagID && followSearchKeyword.isEmpty {
            return
        }
        selectedFollowTagID = tagID
        followSearchInput = ""
        followSearchKeyword = ""
        await reloadFollowingList()
    }

    func searchFollowing() async {
        let keyword = followSearchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            await clearFollowingSearch()
            return
        }
        if keyword == followSearchKeyword && selectedFollowTagID == nil {
            return
        }
        selectedFollowTagID = nil
        followSearchKeyword = keyword
        await reloadFollowingList()
    }

    func clearFollowingSearch() async {
        guard !followSearchKeyword.isEmpty || !followSearchInput.isEmpty else { return }
        followSearchInput = ""
        followSearchKeyword = ""
        selectedFollowTagID = nil
        await reloadFollowingList()
    }

    private func reloadFollowingList() async {
        followingRequest = UUID()
        isLoadingFollowing = false
        followingPager.reset()
        followingUPs = []
        followingTotal = 0
        followingLoaded = false
        followingError = nil
        await loadFollowing(force: true)
    }

    func loadFollowers(force: Bool = false) async {
        guard hasAccount else {
            followers = []
            followersTotal = 0
            followersError = nil
            followersLoaded = false
            followersPager.reset()
            return
        }
        guard force || !followersLoaded, !isLoadingFollowers else { return }

        let request = UUID()
        followersRequest = request
        isLoadingFollowers = true
        followersError = nil
        followersPager.reset()
        defer {
            if followersRequest == request {
                isLoadingFollowers = false
            }
        }

        do {
            let page = try await fetchFollowersPage(page: 1)
            guard hasAccount, followersRequest == request else { return }
            followers = page.items
            followersTotal = page.total
            followersLoaded = true
            followersPager.nextPage = 2
            if page.total > 0 {
                followersPager.hasMore = page.items.count < page.total
            } else {
                followersPager.hasMore = page.items.count >= libraryPageSize
            }
        } catch {
            guard hasAccount, followersRequest == request else { return }
            followersError = "粉丝列表加载失败：\(describe(error))"
            followersPager.hasMore = false
        }
    }

    func loadMoreFollowers() async {
        guard hasAccount,
              !isLoadingFollowers,
              !followersPager.isLoadingMore,
              followersPager.hasMore else { return }
        let request = followersRequest
        followersPager.isLoadingMore = true
        followersPager.failed = false
        defer {
            if followersRequest == request {
                followersPager.isLoadingMore = false
            }
        }

        let page = followersPager.nextPage
        do {
            let result = try await fetchFollowersPage(page: page)
            guard hasAccount, followersRequest == request else { return }
            followersPager.nextPage = page + 1
            if result.items.isEmpty {
                followersPager.stop()
                return
            }
            var seen = Set(followers.map(\.mid))
            for item in result.items where seen.insert(item.mid).inserted {
                followers.append(item)
            }
            if result.total > followersTotal {
                followersTotal = result.total
            }
            if followersTotal > 0 {
                followersPager.hasMore = followers.count < followersTotal
            } else {
                followersPager.hasMore = result.items.count >= libraryPageSize
            }
        } catch {
            guard followersRequest == request else { return }
            followersPager.failed = true
        }
    }


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

    private func loadMessageReplies(force: Bool) async {
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

    private func loadMoreMessageReplies() async {
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

    private func loadMessageAts(force: Bool) async {
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

    private func loadMoreMessageAts() async {
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

    private func loadMessageLikes(force: Bool) async {
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

    private func loadMoreMessageLikes() async {
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

    private func loadMessageSystem(force: Bool) async {
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

    private func loadMoreMessageSystem() async {
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

    private func fetchMessageReplies(
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

    private func fetchMessageAts(
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

    private func fetchMessageLikes(
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

    private func fetchMessageSystem(
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

    private func openMessageVideo(aid: Int64) async {
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

    private func resetMessages() {
        messageUnreadRequest = UUID()
        messageRequest = UUID()
        messageUnread = nil
        messageReplies = MessageFeed()
        messageAts = MessageFeed()
        messageLikes = MessageFeed()
        messageSystem = MessageFeed()
    }

    private func fetchFollowingPage(
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let keyword = followSearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            return try await fetchFollowingSearchPage(page: page, keyword: keyword)
        }
        if let tagID = selectedFollowTagID {
            return try await fetchFollowingGroupPage(tagID: tagID, page: page)
        }

        let value = try await core.call("user.followings", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "关注列表加载失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(response.data?.list ?? [], specialMids: specials)
        return (items, response.data?.total ?? items.count)
    }

    private func fetchFollowingGroupPage(
        tagID: Int64,
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.follow_tag_members", params: [
            "tagid": .number(Double(tagID)),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<[FollowingUser]>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "分组加载失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(
            response.data ?? [],
            markingSpecial: tagID == -10,
            specialMids: specials
        )
        let total = followTags.first(where: { $0.tagid == tagID })?.count ?? items.count
        return (items, total)
    }

    private func fetchFollowingSearchPage(
        page: Int,
        keyword: String
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.follow_search", params: [
            "name": .string(keyword),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "搜索关注失败")
        }
        let specials = await specialFollowMidsForBadges()
        let items = mapFollowing(response.data?.list ?? [], specialMids: specials)
        return (items, response.data?.total ?? items.count)
    }

    private func fetchFollowersPage(
        page: Int
    ) async throws -> (items: [FollowingUP], total: Int) {
        let value = try await core.call("user.followers", params: [
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FollowingsData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "粉丝列表加载失败")
        }
        let items = mapFollowing(response.data?.list ?? [])
        return (items, response.data?.total ?? items.count)
    }

    private func mapFollowing(
        _ users: [FollowingUser],
        markingSpecial: Bool = false,
        specialMids: Set<Int64> = []
    ) -> [FollowingUP] {
        users.compactMap { user in
            guard let mid = user.mid, mid > 0 else { return nil }
            return FollowingUP(
                mid: mid,
                name: user.uname ?? "UP 主",
                avatarURL: MediaURL.normalize(user.face),
                officialDesc: user.officialVerify?.desc ?? "",
                sign: user.sign ?? "",
                isSpecial: markingSpecial
                    || specialMids.contains(mid)
                    || (user.special ?? 0) == 1
                    || (user.tags?.contains(-10) ?? false),
                relationAttribute: user.attribute ?? 0
            )
        }
    }

    private func specialFollowMidsForBadges() async -> Set<Int64> {
        if specialFollowMidsLoaded { return specialFollowMids }
        let value = try? await core.call("user.follow_tag_members", params: [
            "tagid": .number(-10),
            "pn": .number(1),
            "ps": .number(50),
        ])
        guard let value,
              let response = try? CoreCoding.decode(UpstreamResponse<[FollowingUser]>.self, from: value),
              response.code == 0 else {
            return []
        }
        let mids = Set((response.data ?? []).compactMap { $0.mid })
        specialFollowMids = mids
        specialFollowMidsLoaded = true
        return mids
    }

    private func resetSocial() {
        followingRequest = UUID()
        isLoadingFollowing = false
        followingUPs = []
        followingTotal = 0
        followingLoaded = false
        followingError = nil
        followingPager.reset()
        followTags = []
        followTagsLoaded = false
        followTagsError = nil
        isLoadingFollowTags = false
        followTagsRequest = UUID()
        selectedFollowTagID = nil
        followSearchInput = ""
        followSearchKeyword = ""
        specialFollowMids = []
        specialFollowMidsLoaded = false
        followersRequest = UUID()
        isLoadingFollowers = false
        followers = []
        followersTotal = 0
        followersLoaded = false
        followersError = nil
        followersPager.reset()
    }

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

    private func fetchUPRelation(mid: Int64) async -> UPRelationData? {
        do {
            let value = try await core.call("user.relation", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UPRelationData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    private func fetchUPInfo(mid: Int64) async throws -> UserInfoData {
        let value = try await core.call("user.info", params: ["mid": .number(Double(mid))])
        let response = try CoreCoding.decode(UpstreamResponse<UserInfoData>.self, from: value)
        guard response.code == 0, let data = response.data else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "UP 主信息加载失败")
        }
        return data
    }

    private func fetchUPStat(mid: Int64) async -> UserStatData? {
        do {
            let value = try await core.call("user.stat", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserStatData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    private func fetchUPCard(mid: Int64) async -> UPCardData? {
        do {
            let value = try await core.call("user.card", params: ["mid": .number(Double(mid))])
            let response = try CoreCoding.decode(UpstreamResponse<UPCardData>.self, from: value)
            guard response.code == 0 else { return nil }
            return response.data
        } catch {
            return nil
        }
    }

    private func fetchUPVideos(mid: Int64, page: Int) async throws -> [VideoItem] {
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

    func openArticle(id: Int64) {
        guard id > 0 else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeTopic()
        activeArticleID = id
        articleDetail = nil
        articleError = nil
        isLoadingArticle = false
        Task { await loadArticle(id: id) }
    }

    func closeArticle() {
        activeArticleID = nil
        articleDetail = nil
        articleError = nil
        isLoadingArticle = false
    }

    func loadArticle(id: Int64? = nil, force: Bool = false) async {
        guard let target = id ?? activeArticleID else { return }
        guard coreState == .ready else { return }
        if !force, articleDetail?.id == target { return }
        guard !isLoadingArticle else { return }

        isLoadingArticle = true
        articleError = nil
        defer {
            if activeArticleID == target { isLoadingArticle = false }
        }
        do {
            let value = try await core.call("article.view", params: [
                "article_id": .integer(target),
            ])
            let response = try CoreCoding.decode(ArticleDetailResponse.self, from: value)
            guard response.code == 0, let detail = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "专栏加载失败")
            }
            guard activeArticleID == target else { return }
            articleDetail = detail
        } catch {
            guard activeArticleID == target else { return }
            articleError = "专栏加载失败：\(describe(error))"
        }
    }

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

    private func loadTopicDetail(id: Int64) async {
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

    private func resetDiscover() {
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

    private func loadSearchFirstPage(tab: SearchTab, request: UUID) async {
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

    private func reloadSearchVideoTab() async {
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

    private func resetSearchState() {
        cancelSearchLoads()
        activeSearchKeyword = ""
        searchAttempted = false
        searchError = nil
        searchTotalResults = 0
        searchSuggestItems = []
        resetSearchCaches()
    }

    private func cancelSearchLoads() {
        searchRequest = UUID()
        isSearching = false
        for pager in searchPagers.values {
            pager.isLoadingMore = false
            pager.failed = false
        }
    }

    private func resetSearchCaches() {
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

    private func fetchSearchAll(keyword: String) async throws -> SearchAllResult {
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

    private func fetchSearchChunk(tab: SearchTab, page: Int) async throws -> SearchChunk {
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

    private func fetchSearchPage<T: Decodable>(
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

    private func fetchSearchVideos(_ keyword: String, page: Int) async throws -> [VideoItem] {
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

    private func applySearchChunk(_ chunk: SearchChunk, to tab: SearchTab, append: Bool) {
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

    private func appendSearchUnique<T: Identifiable>(_ items: [T], to target: inout [T]) {
        var seen = Set(target.map(\.id))
        for item in items where seen.insert(item.id).inserted {
            target.append(item)
        }
    }

    private func uniqueMedia(_ items: [SearchMedia]) -> [SearchMedia] {
        var seen = Set<Int64>()
        return items.filter { item in
            guard item.id > 0 else { return false }
            return seen.insert(item.id).inserted
        }
    }

    private func loadSearchSuggestions(_ term: String) async {
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

    private func fetchSearchHotWords(method: String) async throws -> [SearchHotWord] {
        let value = try await core.call(method, params: ["limit": .number(30)])
        let response = try CoreCoding.decode(SearchHotPayload.self, from: value)
        guard (response.code ?? 0) == 0 else {
            throw BBCoreError.upstream(code: response.code ?? -1, message: "热搜加载失败")
        }
        return (response.data?.list ?? []).filter { !$0.display.isEmpty }
    }

    private func rememberSearchKeyword(_ keyword: String) {
        var items = searchHistory.filter { $0 != keyword }
        items.insert(keyword, at: 0)
        searchHistory = Array(items.prefix(10))
        UserDefaults.standard.set(searchHistory, forKey: searchHistoryKey)
    }

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

    private func fetchUserVideos(mid: Int64, page: Int) async throws -> [VideoItem] {
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

    private func historyDeleteKey(for video: VideoItem) -> String? {
        guard let kid = video.historyKid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !kid.isEmpty else { return nil }
        if kid.contains("_") { return kid }
        let business = video.historyBusiness?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(business.isEmpty ? "archive" : business)_\(kid)"
    }

    private func fetchHistoryPage(
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

    private func fetchLaterPage(page: Int) async throws -> (items: [VideoItem], total: Int) {
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

    func downloadJob(for video: VideoItem) -> DownloadJob? {
        downloadJob(bvid: video.bvid, cid: video.cid.map(Int64.init))
    }

    func downloadJob(bvid: String, cid: Int64? = nil) -> DownloadJob? {
        let matches = downloadJobs.filter { $0.bvid == bvid }
        guard !matches.isEmpty else { return nil }
        if let cid {
            let exact = matches.filter { $0.cid == cid }
            if let completed = exact.first(where: { $0.isCompleted }) {
                return completed
            }
            if let first = exact.first {
                return first
            }
        }
        return matches.first(where: { $0.isCompleted }) ?? matches.first
    }

    func loadDownloads(force: Bool = false) async {
        guard coreState == .ready else { return }
        guard force || !downloadLoaded else { return }
        guard !isLoadingDownloads else { return }
        isLoadingDownloads = true
        downloadError = nil
        defer {
            isLoadingDownloads = false
            downloadLoaded = true
        }
        do {
            let value = try await core.call("download.list")
            let result = try CoreCoding.decode(DownloadListResult.self, from: value)
            downloadJobs = sortedDownloads(result.items ?? [])
            downloadUsedBytes = result.usedBytes ?? 0
            downloadFreeBytes = result.freeBytes ?? 0
            downloadDiskBytes = result.diskBytes ?? 0
            if let id = activeDownloadID, !downloadJobs.contains(where: { $0.id == id }) {
                activeDownloadID = nil
            }
        } catch {
            downloadError = "下载列表加载失败：\(describe(error))"
        }
    }

    func applyDownloadConfig() async {
        guard coreState == .ready else { return }
        let defaults = UserDefaults.standard
        let storedConcurrency = defaults.integer(forKey: "download.concurrency")
        let concurrency = storedConcurrency > 0 ? min(max(storedConcurrency, 1), 8) : 1
        let limitKbps = max(0, defaults.integer(forKey: "download.limitKbps"))
        do {
            let value = try await core.call("download.config", params: [
                "concurrency": .number(Double(concurrency)),
                "limit_kbps": .number(Double(limitKbps)),
            ])
            let result = try CoreCoding.decode(DownloadConfigResult.self, from: value)
            if let dir = result.downloadDir, !dir.isEmpty {
                downloadDirectory = dir
            }
        } catch {
            downloadDirectory = ""
        }
    }

    func startDownload(
        for video: VideoItem,
        detail: VideoInfoData?,
        qn: Int64? = nil,
        codec: String? = nil
    ) async {
        if let existing = downloadJob(for: video), !existing.isFailed {
            showToast(existing.isCompleted ? "该视频已下载" : "该视频已在下载列表中")
            return
        }
        let defaults = UserDefaults.standard
        let defaultQN = defaults.integer(forKey: "download.defaultQN")
        let resolvedQN = qn ?? Int64(defaultQN > 0 ? defaultQN : 80)
        let resolvedCodec = codec ?? defaults.string(forKey: "download.defaultCodec") ?? "hevc"
        let cid = detail?.cid.map(Int64.init) ?? video.cid.map(Int64.init)
        let seconds = Int64(detail?.duration ?? 0)
        await startDownload(
            bvid: video.bvid,
            cid: cid,
            title: detail?.title ?? video.title,
            cover: detail?.pic ?? video.coverURL?.absoluteString,
            owner: detail?.owner?.name ?? video.ownerName,
            durationMS: seconds > 0 ? seconds * 1000 : nil,
            qn: resolvedQN,
            codec: resolvedCodec
        )
    }

    func startDownload(
        bvid: String,
        cid: Int64?,
        title: String,
        cover: String?,
        owner: String?,
        durationMS: Int64?,
        qn: Int64 = 80,
        codec: String = "hevc"
    ) async {
        guard coreState == .ready else { return }
        if let existing = downloadJob(bvid: bvid), !existing.isFailed {
            showToast(existing.isCompleted ? "该视频已下载" : "该视频已在下载列表中")
            return
        }
        var params: [String: JSONValue] = [
            "bvid": .string(bvid),
            "qn": .number(Double(qn)),
            "codec": .string(codec),
            "title": .string(title),
        ]
        if let cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        }
        if let cover, !cover.isEmpty {
            params["cover"] = .string(cover)
        }
        if let owner, !owner.isEmpty {
            params["owner"] = .string(owner)
        }
        if let durationMS, durationMS > 0 {
            params["duration_ms"] = .number(Double(durationMS))
        }
        do {
            let value = try await core.call("download.start", params: params)
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("已开始下载")
        } catch {
            showToast("下载失败：\(describe(error))")
        }
    }

    func pauseDownload(_ job: DownloadJob) async {
        guard job.isDownloading, !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            let value = try await core.call("download.pause", params: ["id": .string(job.id)])
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("已暂停下载")
            await loadDownloads(force: true)
        } catch {
            showToast("暂停失败：\(describe(error))")
        }
    }

    func resumeDownload(_ job: DownloadJob) async {
        guard job.isPaused || job.isFailed, !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            let value = try await core.call("download.resume", params: ["id": .string(job.id)])
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("继续下载")
            await loadDownloads(force: true)
        } catch {
            showToast("继续下载失败：\(describe(error))")
        }
    }

    func removeDownload(_ job: DownloadJob) async {
        guard !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            _ = try await core.call("download.remove", params: ["id": .string(job.id)])
            downloadJobs.removeAll { $0.id == job.id }
            if activeDownloadID == job.id {
                activeDownloadID = nil
            }
            downloadUsedBytes = downloadJobs.reduce(0) { $0 + $1.downloadedBytes }
            showToast("已删除下载")
            await loadDownloads(force: true)
        } catch {
            showToast("删除失败：\(describe(error))")
        }
    }

    func downloadPlaybackURL(for job: DownloadJob) async -> URL? {
        if let raw = job.masterURL, let url = URL(string: raw) {
            return url
        }
        guard job.isCompleted else { return nil }
        do {
            let value = try await core.call("download.url", params: ["id": .string(job.id)])
            let result = try CoreCoding.decode(DownloadURLResult.self, from: value)
            return URL(string: result.masterURL)
        } catch {
            showToast("无法播放该下载：\(describe(error))")
            return nil
        }
    }

    func openDownload(_ job: DownloadJob) {
        guard job.isCompleted else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        activeDownloadID = job.id
        section = .downloads
    }

    func closeDownload() {
        activeDownloadID = nil
    }

    private func sortedDownloads(_ jobs: [DownloadJob]) -> [DownloadJob] {
        jobs.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id > rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func startDownloadEventStream() {
        downloadEventsTask?.cancel()
        let stream = eventHub.subscribe(topics: ["download.*"])
        downloadEventsTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.handleDownloadEvent(event)
            }
        }
    }

    private func handleDownloadEvent(_ event: CoreEvent) {
        guard let job = try? CoreCoding.decode(DownloadJob.self, from: event.data) else { return }
        upsertDownload(job)
        switch event.topic {
        case "download.completed":
            showToast("下载完成：\(job.title)")
        case "download.failed":
            showToast("下载失败：\(job.title)")
        default:
            break
        }
    }

    private func upsertDownload(_ job: DownloadJob) {
        if let index = downloadJobs.firstIndex(where: { $0.id == job.id }) {
            downloadJobs[index] = job
        } else {
            downloadJobs.append(job)
        }
        downloadJobs = sortedDownloads(downloadJobs)
        downloadUsedBytes = downloadJobs.reduce(0) { $0 + $1.downloadedBytes }
    }

    func loadPlaylists(force: Bool = false) async {
        guard hasAccount else {
            favoriteFolders = []
            playlistsError = nil
            return
        }
        guard force || favoriteFolders.isEmpty, !isLoadingPlaylists else { return }
        isLoadingPlaylists = true
        playlistsError = nil
        defer { isLoadingPlaylists = false }

        do {
            let value = try await core.call("fav.folders")
            let response = try CoreCoding.decode(UpstreamResponse<FavFoldersData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "播放列表加载失败")
            }
            favoriteFolders = (response.data?.list ?? []).compactMap { FavFolder(raw: $0) }
            if let selected = selectedFolder,
               let refreshed = favoriteFolders.first(where: { $0.id == selected.id }) {
                selectedFolder = refreshed
            }
        } catch {
            playlistsError = "播放列表加载失败：\(describe(error))"
        }
    }

    func createFavoriteFolder(
        title: String,
        intro: String,
        privacy: Int,
        cover: String
    ) async throws -> FavFolder? {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.create_folder", params: [
            "title": .string(title),
            "intro": .string(intro),
            "privacy": .number(Double(privacy)),
            "cover": .string(cover),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavFolderRaw>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "创建收藏夹失败")
        }
        guard let folder = response.data.flatMap({ FavFolder(raw: $0) }) else {
            await loadPlaylists(force: true)
            showToast("收藏夹已创建")
            return nil
        }
        favoriteFolders.append(folder)
        showToast("收藏夹已创建")
        return folder
    }

    func updateFavoriteFolder(
        _ folder: FavFolder,
        title: String,
        intro: String,
        privacy: Int,
        cover: String
    ) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.edit_folder", params: [
            "media_id": .number(Double(folder.id)),
            "title": .string(title),
            "intro": .string(intro),
            "privacy": .number(Double(privacy)),
            "cover": .string(cover),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavFolderRaw>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "保存收藏夹失败")
        }
        if let raw = response.data, let updated = FavFolder(raw: raw) {
            replaceFolder(updated)
        } else {
            var updated = folder
            updated.title = title
            updated.intro = intro
            updated.isPrivate = privacy == 1
            replaceFolder(updated)
        }
        showToast("收藏夹已更新")
    }

    func deleteFavoriteFolder(_ folder: FavFolder) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.delete_folder", params: [
            "media_ids": .string(String(folder.id)),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "删除收藏夹失败")
        }
        favoriteFolders.removeAll { $0.id == folder.id }
        if selectedFolder?.id == folder.id {
            closeFolder()
        }
        showToast("收藏夹已删除")
    }

    func cleanFavoriteFolder(_ folder: FavFolder) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.clean", params: [
            "media_id": .number(Double(folder.id)),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "清空收藏夹失败")
        }
        adjustFolderCount(folder.id, delta: -folder.count)
        if selectedFolder?.id == folder.id {
            folderVideos = []
            folderPager.stop()
        }
        showToast("收藏夹已清空")
    }

    func removeFavoriteVideos(_ videos: [VideoItem], from folder: FavFolder) async throws {
        let resources = favoriteResources(for: videos)
        guard !resources.isEmpty else {
            throw BBCoreError.upstream(code: -1, message: "无法识别所选视频")
        }
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.remove", params: [
            "media_id": .number(Double(folder.id)),
            "resources": .string(resources.joined(separator: ",")),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "取消收藏失败")
        }
        let removed = Set(videos.map(\.bvid))
        if selectedFolder?.id == folder.id {
            folderVideos.removeAll { removed.contains($0.bvid) }
        }
        adjustFolderCount(folder.id, delta: -videos.count)
        showToast("已取消收藏 \(videos.count) 个视频")
    }

    func moveFavoriteVideos(
        _ videos: [VideoItem],
        from folder: FavFolder,
        to target: FavFolder
    ) async throws {
        let resources = favoriteResources(for: videos)
        guard !resources.isEmpty else {
            throw BBCoreError.upstream(code: -1, message: "无法识别所选视频")
        }
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let joined = resources.joined(separator: ",")

        let addValue = try await core.call("fav.add", params: [
            "resources": .string(joined),
            "add_media_ids": .string(String(target.id)),
        ])
        let addResponse = try CoreCoding.decode(BasicResponse.self, from: addValue)
        guard addResponse.code == 0 else {
            throw BBCoreError.upstream(code: addResponse.code, message: addResponse.message ?? "移动到目标收藏夹失败")
        }

        let removeValue = try await core.call("fav.remove", params: [
            "media_id": .number(Double(folder.id)),
            "resources": .string(joined),
        ])
        let removeResponse = try CoreCoding.decode(BasicResponse.self, from: removeValue)
        guard removeResponse.code == 0 else {
            throw BBCoreError.upstream(
                code: removeResponse.code,
                message: "视频已加入目标收藏夹，但移出原收藏夹失败"
            )
        }

        let moved = Set(videos.map(\.bvid))
        if selectedFolder?.id == folder.id {
            folderVideos.removeAll { moved.contains($0.bvid) }
        }
        adjustFolderCount(folder.id, delta: -videos.count)
        adjustFolderCount(target.id, delta: videos.count)
        showToast("已移动 \(videos.count) 个视频")
    }

    private func favoriteResources(for videos: [VideoItem]) -> [String] {
        videos.compactMap { video in
            guard let aid = video.aid, aid > 0 else { return nil }
            return "\(aid):2"
        }
    }

    private func replaceFolder(_ folder: FavFolder) {
        if let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) {
            favoriteFolders[index] = folder
        }
        if selectedFolder?.id == folder.id {
            selectedFolder = folder
        }
    }

    private func adjustFolderCount(_ mediaID: Int64, delta: Int) {
        guard delta != 0 else { return }
        if let index = favoriteFolders.firstIndex(where: { $0.id == mediaID }) {
            favoriteFolders[index].count = max(0, favoriteFolders[index].count + delta)
        }
        if let selected = selectedFolder, selected.id == mediaID {
            selectedFolder?.count = max(0, selected.count + delta)
        }
    }

    func loadFolderVideos(_ folder: FavFolder) async {
        guard hasAccount else { return }
        if selectedFolder?.id != folder.id {
            selectedFolder = folder
            folderVideos = []
            folderPager.reset()
        }
        guard !isLoadingFolderVideos else { return }
        isLoadingFolderVideos = true
        folderError = nil
        folderPager.reset()
        defer { isLoadingFolderVideos = false }

        do {
            let page = try await fetchFolderPage(folder.id, page: 1)
            guard selectedFolder?.id == folder.id else { return }
            folderVideos = page.items
            if let info = page.info {
                replaceFolder(info)
            }
            folderPager.nextPage = 2
            folderPager.hasMore = folderHasMore(
                page: page,
                loadedCount: folderVideos.count,
                total: page.info?.count ?? folder.count
            )
        } catch {
            guard selectedFolder?.id == folder.id else { return }
            folderError = "播放列表加载失败：\(describe(error))"
            folderPager.hasMore = false
        }
    }

    func loadMoreFolderVideos() async {
        guard let folder = selectedFolder,
              !isLoadingFolderVideos,
              !folderPager.isLoadingMore,
              folderPager.hasMore else { return }
        folderPager.isLoadingMore = true
        folderPager.failed = false
        defer {
            if selectedFolder?.id == folder.id { folderPager.isLoadingMore = false }
        }

        let page = folderPager.nextPage
        do {
            let result = try await fetchFolderPage(folder.id, page: page)
            guard selectedFolder?.id == folder.id else { return }
            folderPager.nextPage = page + 1
            if result.items.isEmpty {
                folderPager.stop()
                return
            }
            _ = appendUnique(result.items, to: &folderVideos)
            folderPager.hasMore = folderHasMore(
                page: result,
                loadedCount: folderVideos.count,
                total: selectedFolder?.count ?? folder.count
            )
        } catch {
            guard selectedFolder?.id == folder.id else { return }
            folderPager.failed = true
        }
    }

    private func fetchFolderPage(
        _ mediaID: Int64,
        page: Int
    ) async throws -> (items: [VideoItem], hasMore: Bool?, info: FavFolder?) {
        let value = try await core.call("fav.list", params: [
            "media_id": .number(Double(mediaID)),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavListData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "播放列表加载失败")
        }
        let items = (response.data?.medias ?? []).compactMap(VideoItem.init(fav:))
        let info = response.data?.info.flatMap { FavFolder(raw: $0) }
        return (items, response.data?.hasMore, info)
    }

    private func folderHasMore(
        page: (items: [VideoItem], hasMore: Bool?, info: FavFolder?),
        loadedCount: Int,
        total: Int
    ) -> Bool {
        if let hasMore = page.hasMore { return hasMore }
        if total > 0 { return loadedCount < total }
        return page.items.count >= libraryPageSize
    }

    func closeFolder() {
        selectedFolder = nil
        folderVideos = []
        folderError = nil
        isLoadingFolderVideos = false
        folderPager.reset()
    }

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

    private func startStream(params: [String: JSONValue]) async throws -> StreamSession {
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

    private func fetchVideoTags(bvid: String) async -> [String] {
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

    private func fetchAIConclusion(bvid: String, cid: Int?, upMid: Int64?) async -> AIConclusionResult? {
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

    private func fetchVideoInfo(bvid: String) async throws -> VideoInfoData {
        let value = try await core.call("video.info", params: ["bvid": .string(bvid)])
        let response = try CoreCoding.decode(UpstreamResponse<VideoInfoData>.self, from: value)
        guard response.code == 0, let data = response.data else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "无法获取视频信息")
        }
        return data
    }

    private func fetchRelatedVideos(bvid: String) async -> [VideoItem] {
        do {
            let value = try await core.call("video.related", params: ["bvid": .string(bvid)])
            let response = try CoreCoding.decode(UpstreamResponse<[RelatedVideo]>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data ?? []).compactMap(VideoItem.init(related:))
        } catch {
            return []
        }
    }

    private func fetchComments(
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

    private func fetchComments(
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

    private func fetchRelation(bvid: String) async -> VideoRelationData? {
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

    func refreshAccount() async {
        do {
            let value = try await core.call("auth.accounts")
            let data = try CoreCoding.decode(AccountsData.self, from: value)
            accounts = data.accounts
            if data.activeMid > 0 {
                await loadProfile(mid: data.activeMid)
            } else {
                clearProfile()
            }
        } catch {
            accounts = []
            clearProfile()
            profileError = "账号加载失败：\(describe(error))"
        }
        await loadRecentUPs()
    }

    func refreshProfile() async {
        if let active = activeAccount {
            await loadProfile(mid: active.mid)
        } else {
            await refreshAccount()
        }
    }

    func presentLogin() {
        qrPayload = nil
        loginState = .idle
        resetSMSLogin()
        isLoginSheetPresented = true
    }

    func beginQRLogin() async {
        guard coreState == .ready else { return }
        loginState = .loading
        qrPayload = nil
        do {
            let value = try await core.call("auth.qr.generate")
            let response = try CoreCoding.decode(QRGenerateResponse.self, from: value)
            guard response.code == 0, let payload = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "二维码生成失败")
            }
            qrPayload = payload
            loginState = .waiting
        } catch {
            loginState = .failed("二维码生成失败：\(describe(error))")
        }
    }

    func pollQRLogin() async -> LoginPollResult {
        guard let authCode = qrPayload?.authCode else {
            return .failed("二维码尚未就绪")
        }
        guard loginState == .waiting || loginState == .scanned else {
            return .expired
        }

        do {
            let value = try await core.call("auth.qr.poll", params: [
                "auth_code": .string(authCode),
                "make_active": .bool(true),
            ])
            let response = try CoreCoding.decode(QRPollResponse.self, from: value)
            switch response.code {
            case 0:
                loginState = .success
                isLoginSheetPresented = false
                navigationPath.removeAll()
                section = .profile
                await refreshAccount()
                return .success
            case 86039, 86101:
                loginState = .waiting
                return .waiting
            case 86090:
                loginState = .scanned
                return .scanned
            case 86038:
                loginState = .expired
                return .expired
            default:
                let message = "登录失败：\(response.message ?? "错误码 \(response.code)")"
                loginState = .failed(message)
                return .failed(message)
            }
        } catch {
            let message = "登录失败：\(describe(error))"
            loginState = .failed(message)
            return .failed(message)
        }
    }

    // MARK: Phone / SMS login

    var smsPhoneDigits: String { smsPhone.filter(\.isNumber) }
    var isSMSPhoneValid: Bool {
        let digits = smsPhoneDigits
        return digits.count == 11 && digits.hasPrefix("1")
    }

    func resetSMSLogin() {
        smsPhone = ""
        smsCode = ""
        smsCaptchaKey = nil
        smsCaptchaChallenge = nil
        smsCooldown = 0
        smsError = nil
        isSendingSMS = false
        isLoggingInSMS = false
        smsCooldownTask?.cancel()
        smsCooldownTask = nil
    }

    func sendSMSCode() async {
        await requestSMSCode(gee: nil)
    }

    func completeSMSCaptcha(validate: String, seccode: String) async {
        guard let challenge = smsCaptchaChallenge else { return }
        smsCaptchaChallenge = nil
        await requestSMSCode(gee: (challenge, validate, seccode))
    }

    func cancelSMSCaptcha() {
        smsCaptchaChallenge = nil
    }

    private func requestSMSCode(gee: (challenge: SMSCaptchaChallenge, validate: String, seccode: String)?) async {
        guard coreState == .ready, !isSendingSMS else { return }
        let tel = smsPhoneDigits
        guard tel.count == 11 else {
            smsError = "请输入正确的手机号"
            return
        }
        isSendingSMS = true
        smsError = nil
        defer { isSendingSMS = false }

        var params: [String: JSONValue] = [
            "tel": .string(tel),
            "cid": .string("86"),
        ]
        if let gee {
            params["gee_challenge"] = .string(gee.challenge.challenge)
            params["gee_validate"] = .string(gee.validate)
            params["gee_seccode"] = .string(gee.seccode)
            params["recaptcha_token"] = .string(gee.challenge.token)
        }
        do {
            let value = try await core.call("auth.sms.send", params: params)
            let response = try CoreCoding.decode(SMSSendResponse.self, from: value)
            if response.code == 0 {
                smsCaptchaKey = response.data?.captchaKey
                smsCaptchaChallenge = nil
                startSMSCooldown()
                showToast("验证码已发送")
                return
            }
            if let url = response.data?.recaptchaURL,
               let challenge = SMSCaptchaChallenge(recaptchaURL: url) {
                smsCaptchaChallenge = challenge
                return
            }
            smsError = response.message ?? "验证码发送失败（\(response.code)）"
        } catch {
            smsError = "验证码发送失败：\(describe(error))"
        }
    }

    func loginWithSMS() async {
        guard coreState == .ready, !isLoggingInSMS else { return }
        let tel = smsPhoneDigits
        let code = smsCode.filter(\.isNumber)
        guard tel.count == 11 else {
            smsError = "请输入正确的手机号"
            return
        }
        guard !code.isEmpty else {
            smsError = "请输入验证码"
            return
        }
        guard let captchaKey = smsCaptchaKey else {
            smsError = "请先获取验证码"
            return
        }
        isLoggingInSMS = true
        smsError = nil
        defer { isLoggingInSMS = false }
        do {
            let value = try await core.call("auth.sms.login", params: [
                "tel": .string(tel),
                "cid": .string("86"),
                "code": .string(code),
                "captcha_key": .string(captchaKey),
                "make_active": .bool(true),
            ])
            let response = try CoreCoding.decode(SMSLoginResponse.self, from: value)
            guard response.code == 0 else {
                smsError = response.message ?? "登录失败（\(response.code)）"
                return
            }
            loginState = .success
            isLoginSheetPresented = false
            navigationPath.removeAll()
            section = .profile
            await refreshAccount()
            showToast("登录成功")
            resetSMSLogin()
        } catch {
            smsError = "登录失败：\(describe(error))"
        }
    }

    private func startSMSCooldown() {
        smsCooldownTask?.cancel()
        smsCooldown = 60
        smsCooldownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.smsCooldown <= 1 {
                    self.smsCooldown = 0
                    return
                }
                self.smsCooldown -= 1
            }
        }
    }

    func useAccount(_ mid: Int64, stayInPlace: Bool = false) async {
        do {
            _ = try await core.call("auth.account.use", params: ["mid": .number(Double(mid))])
            closeLiveRoom()
            closeAnimeSeason()
            closeArticle()
            closeTopic()
            resetLiveFeed()
            resetAnimeFeed()
            resetSocial()
            resetMessages()
            await refreshAccount()
            await loadMessageUnread(force: true)
            navigationPath.removeAll()
            if !stayInPlace {
                section = .profile
            }
            isLoginSheetPresented = false
        } catch {
            loginState = .failed("切换账号失败：\(describe(error))")
            showToast("切换账号失败")
        }
    }

    func logout(stayInPlace: Bool = false) async {
        guard activeAccount != nil else { return }
        do {
            _ = try await core.call("auth.logout")
            await refreshAccount()
            navigationPath.removeAll()
            if !stayInPlace {
                section = .profile
            }
            qrPayload = nil
            loginState = .idle
            if isLoginSheetPresented {
                await beginQRLogin()
            }
        } catch {
            loginState = .failed("退出登录失败：\(describe(error))")
        }
    }

    func openSettings() {
        selectSection(.settings)
    }

    func retry() async {
        if let video = currentVideo {
            await loadWatchPage(for: video, force: true)
            return
        }
        if let mid = activeUPMid {
            await loadUP(mid: mid)
            return
        }
        if activeArticleID != nil {
            await loadArticle(force: true)
            return
        }
        if activeTopic != nil {
            await refreshTopic()
            return
        }
        switch section {
        case .home:
            await loadHome()
        case .dynamic:
            await loadDynamicFeed(reset: true)
        case .live:
            await loadLiveFeed(reset: true)
        case .anime:
            if let seasonID = activeAnimeSeasonID {
                await loadAnimeSeason(seasonID: seasonID, force: true)
            } else {
                await loadAnimeFeed(reset: true)
            }
        case .discover:
            await refreshDiscover()
        case .messages:
            await refreshMessages()
        case .search:
            await search()
        case .profile:
            await refreshProfile()
        case .uploads:
            await loadMyUploads(force: true)
        case .history:
            await loadHistoryVideos(force: true)
        case .playlists:
            if let folder = selectedFolder {
                await loadFolderVideos(folder)
            } else {
                await loadPlaylists(force: true)
            }
        case .watchLater:
            await loadWatchLater(force: true)
        case .downloads:
            await loadDownloads(force: true)
        case .settings:
            await applyDownloadConfig()
        }
    }

    func shutdown() {
        toastTask?.cancel()
        downloadEventsTask?.cancel()
        downloadEventsTask = nil
        eventHub.stop()
        Task { await core.stop() }
    }

    func restartCore() async {
        await core.stop()
        started = false
        videos = []
        resetSearchState()
        accounts = []
        recentUPs = []
        homePager.reset()
        searchPager.reset()
        upPager.reset()
        closeVideo()
        closeUP()
        closeDynamic()
        closeArticle()
        resetDiscover()
        closeFolder()
        closeDownload()
        clearProfile()
        await start()
    }

    private func loadProfile(mid: Int64) async {
        isProfileLoading = true
        profileError = nil
        defer { isProfileLoading = false }

        let nav: NavData
        do {
            let value = try await core.call("user.me")
            let response = try CoreCoding.decode(UpstreamResponse<NavData>.self, from: value)
            guard response.code == 0, let data = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            nav = data
        } catch {
            clearProfile()
            profileError = "个人信息加载失败：\(describe(error))"
            return
        }

        guard nav.isLogin == true else {
            clearProfile()
            profileError = "登录状态已失效，请重新扫码登录"
            return
        }

        let profileMid = nav.mid ?? mid
        var info: UserInfoData?
        do {
            let value = try await core.call("user.info", params: ["mid": .number(Double(profileMid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserInfoData>.self, from: value)
            if response.code == 0 { info = response.data }
        } catch {
            // The nav payload is enough for the header when user.info is rejected.
        }

        var stat: UserStatData?
        do {
            let value = try await core.call("user.stat", params: ["mid": .number(Double(profileMid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserStatData>.self, from: value)
            if response.code == 0 { stat = response.data }
        } catch {
            stat = nil
        }

        profile = UserProfile(
            mid: profileMid,
            name: info?.name ?? nav.uname ?? "B 站用户",
            avatarURL: MediaURL.normalize(info?.face ?? nav.face),
            sign: info?.sign ?? "",
            level: info?.level ?? nav.levelInfo?.currentLevel ?? 0,
            follower: stat?.follower ?? 0,
            following: stat?.following ?? 0
        )

        uploads = await fetchUploads(mid: profileMid)
        if !historyLoaded {
            history = await fetchHistory()
        }
    }

    private func fetchUploads(mid: Int64) async -> [VideoItem] {
        do {
            let value = try await core.call("user.videos", params: [
                "mid": .number(Double(mid)),
                "pn": .number(1),
                "ps": .number(12),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<UserVideosData>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data?.list?.vlist ?? []).compactMap(VideoItem.init(userVideo:))
        } catch {
            return []
        }
    }

    private func fetchHistory() async -> [VideoItem] {
        do {
            let value = try await core.call("user.history", params: ["ps": .number(12)])
            let response = try CoreCoding.decode(UpstreamResponse<UserHistoryData>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data?.list ?? []).compactMap(VideoItem.init(history:))
        } catch {
            return []
        }
    }

    private func clearProfile() {
        profile = nil
        uploads = []
        history = []
        myUploads = []
        laterVideos = []
        laterTotal = 0
        favoriteFolders = []
        selectedFolder = nil
        folderVideos = []
        resetSocial()
        resetMessages()
        historyLoaded = false
        historyPaused = false
        historyStatusLoaded = false
        profileError = nil
        uploadsPager.reset()
        historyPager.reset()
        laterPager.reset()
        folderPager.reset()
        historyCursorMax = 0
        historyCursorViewAt = 0
        dynamicCards = []
        dynamicOffset = ""
        dynamicHasMore = false
        dynamicLoaded = false
        dynamicError = nil
        activeDynamic = nil
        dynamicRequest = UUID()
        resetLiveFeed()
        closeLiveRoom()
        resetAnimeFeed()
        closeAnimeSeason()
        closeArticle()
    }

    private func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
