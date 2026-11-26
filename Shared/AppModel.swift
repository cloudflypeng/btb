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
    var dynamicCommentNextOffset = 0
    var dynamicOffset = ""
    var dynamicRequest = UUID()

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
    var livePage = 1
    var liveRequest = UUID()
    @ObservationIgnored var liveEventsTask: Task<Void, Never>?

    var animeTab: AnimeTab = .timeline
    var animeTimeline: [AnimeTimelineDay] = []
    var animeSelectedDay: String?
    var animeRankItems: [AnimeRankItem] = []
    var animeRankNote: String?
    var isLoadingAnime = false
    var animeLoaded = false
    var animeError: String?
    var animeRequest = UUID()

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
    var animeReviewCursor = ""
    var animeReviewMediaID: Int64?

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
    var specialFollowMids: Set<Int64> = []
    var specialFollowMidsLoaded = false
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
    var messageUnreadRequest = UUID()
    var messageRequest = UUID()

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
    var historyStatusLoaded = false

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
    var downloadEventsTask: Task<Void, Never>?

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
    var discoverRankingRequest = UUID()
    var weeklyIssueRequest = UUID()
    var topicSquareRequest = UUID()
    var articleRankRequest = UUID()
    var topicFeedRequest = UUID()

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
    var smsCooldownTask: Task<Void, Never>?

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

    let core: any CoreTransport
    @ObservationIgnored let eventHub: EventHub
    /// Resolve/stream results prepared while a video card is pressed (B1).
    @ObservationIgnored let playbackPrewarm = PlaybackPrewarmCache()
    /// Local per-video playback positions (B4).
    @ObservationIgnored let playbackProgress = PlaybackProgressStore.shared
    @ObservationIgnored var playbackPrewarmTask: Task<Void, Never>?
    var started = false
    var homeRequest = UUID()
    var followingRequest = UUID()
    var followersRequest = UUID()
    var followTagsRequest = UUID()
    var searchRequest = UUID()
    var searchLoadedTabs: Set<SearchTab> = []
    var searchSuggestTask: Task<Void, Never>?
    var historyCursorMax = 0
    var historyCursorViewAt = 0
    let feedPageSize = 20
    let libraryPageSize = 30
    let searchHistoryKey = "btb.search.history"
    var toastTask: Task<Void, Never>?

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
            // Replays the press → open path so tap-to-first-frame can be
            // measured on a device with `devicectl ... --console`.
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

}
