import SwiftUI
import UIKit

struct MobileSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var selectedLive: LiveRoom?

    private let mediaColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
    private let liveColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            searchBar

            if showsSuggestions {
                suggestionList
            } else {
                header
                Divider().opacity(0.5)
                content
            }
        }
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await model.loadSearchHotWords()
        }
        .onAppear {
            if model.searchTerm.isEmpty {
                if model.searchAttempted, !model.activeSearchKeyword.isEmpty {
                    model.searchTerm = model.activeSearchKeyword
                } else {
                    isFocused = true
                }
            }
        }
        .onChange(of: model.searchTerm) { _, _ in
            model.scheduleSearchSuggestions()
        }
        .navigationDestination(item: $selectedLive) { room in
            MobileLiveRoomView(room: room)
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        @Bindable var model = model

        return HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(width: 30, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))

                TextField("搜索视频、UP 主", text: $model.searchTerm)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.text(scheme))
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit {
                        isFocused = false
                        Task { await model.submitSearch() }
                    }

                if !model.searchTerm.isEmpty {
                    Button {
                        model.clearSearch()
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(AppTheme.chip(scheme), in: Capsule())

            Button {
                isFocused = false
                Task { await model.submitSearch() }
            } label: {
                Text("搜索")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(model.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AppTheme.tertiary(scheme)
                        : AppTheme.brand)
            }
            .buttonStyle(.plain)
            .disabled(model.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.leading, 4)
        .padding(.trailing, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchTab.allCases) { tab in
                        MobilePill(title: tab.title, isSelected: model.searchTab == tab) {
                            Task { await model.selectSearchTab(tab) }
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            if model.searchTab == .media {
                HStack(spacing: 8) {
                    ForEach(SearchMediaKind.allCases) { kind in
                        MobilePill(title: kind.title, isSelected: model.searchMediaKind == kind) {
                            Task { await model.setSearchMediaKind(kind) }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }

            if model.searchTab == .video {
                HStack(spacing: 8) {
                    MobileSearchFilterMenu(
                        options: SearchFilterCatalog.orders,
                        selection: model.searchOrder
                    ) { value in
                        Task { await model.setSearchOrder(value) }
                    }
                    MobileSearchFilterMenu(
                        options: SearchFilterCatalog.durations,
                        selection: model.searchDuration
                    ) { value in
                        Task { await model.setSearchDuration(value) }
                    }
                    MobileSearchFilterMenu(
                        options: SearchFilterCatalog.partitions,
                        selection: model.searchTID
                    ) { value in
                        Task { await model.setSearchTID(value) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
            }

            if model.searchAttempted, !model.activeSearchKeyword.isEmpty {
                HStack(spacing: 8) {
                    if model.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.brand)
                    }
                    if model.searchTotalResults > 0 {
                        Text("约 \(SearchFormat.count(model.searchTotalResults)) 个结果")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !model.searchAttempted || model.activeSearchKeyword.isEmpty {
            ScrollView {
                landing
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let error = model.searchError {
                        MobileErrorBanner(text: error) {
                            Task { await model.search() }
                        }
                    }

                    if model.isSearching && currentIsEmpty {
                        loading
                    } else if currentIsEmpty {
                        if model.searchError == nil {
                            MobileEmptyState(
                                icon: emptyIcon,
                                title: emptyTitle,
                                message: "换一个关键词或筛选条件试试。"
                            )
                        }
                    } else {
                        resultsContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await model.search()
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        switch model.searchTab {
        case .all:
            allResults
        case .video:
            videoResults
        case .user:
            userResults
        case .media:
            mediaResults
        case .live:
            liveResults
        case .article:
            articleResults
        }
    }

    private var videoResults: some View {
        VStack(spacing: 12) {
            ForEach(model.searchResults) { video in
                MobileVideoLink(video: video) {
                    MobileVideoRow(video: video)
                }
            }
            searchFooter
        }
    }

    private var userResults: some View {
        LazyVStack(spacing: 0) {
            ForEach(model.searchUsers) { user in
                MobileSearchUserLink(user: user) {
                    MobileSearchUserRow(user: user)
                }
                Divider()
                    .opacity(0.35)
                    .padding(.leading, 60)
            }
            searchFooter
        }
    }

    private var mediaResults: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: mediaColumns, alignment: .leading, spacing: 16) {
                ForEach(model.searchMedia) { media in
                    MobileSearchMediaLink(media: media) {
                        MobileSearchMediaCard(media: media)
                    }
                }
            }
            searchFooter
        }
    }

    private var liveResults: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: liveColumns, alignment: .leading, spacing: 16) {
                ForEach(model.searchLiveRooms) { room in
                    liveCard(room)
                }
            }
            searchFooter
        }
    }

    @ViewBuilder
    private func liveCard(_ room: SearchLiveRoom) -> some View {
        if let live = LiveRoom(search: room) {
            MobileLiveRoomCard(room: live) {
                selectedLive = live
            }
        }
    }

    private var articleResults: some View {
        LazyVStack(spacing: 0) {
            ForEach(model.searchArticles) { article in
                MobileSearchArticleLink(article: article) {
                    MobileSearchArticleRow(article: article)
                }
                Divider()
                    .opacity(0.35)
            }
            searchFooter
        }
    }

    private var allResults: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !model.searchAllVideos.isEmpty {
                resultSection("视频", openTab: .video) {
                    VStack(spacing: 12) {
                        ForEach(Array(model.searchAllVideos.prefix(4))) { video in
                            MobileVideoLink(video: video) {
                                MobileVideoRow(video: video)
                            }
                        }
                    }
                }
            }

            if !model.searchAllBangumi.isEmpty {
                resultSection("番剧", openTab: .media, mediaKind: .bangumi) {
                    mediaGrid(Array(model.searchAllBangumi.prefix(4)))
                }
            }

            if !model.searchAllFilms.isEmpty {
                resultSection("影视", openTab: .media, mediaKind: .film) {
                    mediaGrid(Array(model.searchAllFilms.prefix(4)))
                }
            }

            if !model.searchAllUsers.isEmpty {
                resultSection("用户", openTab: .user) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.searchAllUsers.prefix(3))) { user in
                            MobileSearchUserLink(user: user) {
                                MobileSearchUserRow(user: user)
                            }
                            Divider()
                                .opacity(0.35)
                                .padding(.leading, 60)
                        }
                    }
                }
            }

            if !model.searchAllLiveRooms.isEmpty {
                resultSection("直播", openTab: .live) {
                    LazyVGrid(columns: liveColumns, alignment: .leading, spacing: 16) {
                        ForEach(Array(model.searchAllLiveRooms.prefix(2))) { room in
                            liveCard(room)
                        }
                    }
                }
            }

            if !model.searchAllArticles.isEmpty {
                resultSection("专栏", openTab: .article) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.searchAllArticles.prefix(3))) { article in
                            MobileSearchArticleLink(article: article) {
                                MobileSearchArticleRow(article: article)
                            }
                            Divider()
                                .opacity(0.35)
                        }
                    }
                }
            }
        }
    }

    private func resultSection<Content: View>(
        _ title: String,
        openTab: SearchTab,
        mediaKind: SearchMediaKind? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Button {
                    Task {
                        if let mediaKind {
                            await model.setSearchMediaKind(mediaKind)
                        }
                        await model.selectSearchTab(openTab)
                    }
                } label: {
                    Text("查看全部")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                }
                .buttonStyle(.plain)
            }
            content()
        }
    }

    private func mediaGrid(_ items: [SearchMedia]) -> some View {
        LazyVGrid(columns: mediaColumns, alignment: .leading, spacing: 16) {
            ForEach(items) { media in
                MobileSearchMediaLink(media: media) {
                    MobileSearchMediaCard(media: media)
                }
            }
        }
    }

    private var searchFooter: some View {
        InfiniteScrollFooter(
            isLoading: model.isSearching || model.searchPager.isLoadingMore,
            hasMore: model.searchPager.hasMore,
            failed: model.searchPager.failed
        ) {
            Task { await model.loadMoreSearchResults() }
        }
    }

    private var loading: some View {
        ProgressView("正在搜索…")
            .font(.system(size: 13))
            .tint(AppTheme.brand)
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
    }

    // MARK: Suggestions

    private var showsSuggestions: Bool {
        let term = model.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        return !model.searchSuggestItems.isEmpty
            && !term.isEmpty
            && term != model.activeSearchKeyword
    }

    private var suggestionList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(model.searchSuggestItems) { item in
                    Button {
                        isFocused = false
                        model.applySearchSuggestion(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.tertiary(scheme))
                            Text(item.display)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.text(scheme))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.tertiary(scheme))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .opacity(0.35)
                        .padding(.leading, 36)
                }
            }
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
    }

    // MARK: Landing

    private var landing: some View {
        VStack(alignment: .leading, spacing: 26) {
            if !model.searchHistory.isEmpty {
                historySection
            }
            hotSection
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搜索历史")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Button {
                    model.clearSearchHistory()
                } label: {
                    Text("清空")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84, maximum: 180), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(model.searchHistory, id: \.self) { keyword in
                    Button {
                        isFocused = false
                        model.searchTerm = keyword
                        Task { await model.submitSearch() }
                    } label: {
                        Text(keyword)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(AppTheme.chip(scheme), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("哔哩哔哩热搜")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                if model.isLoadingSearchHot && model.searchHotWords.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.brand)
                }

                Spacer()

                Button {
                    Task { await model.loadSearchHotWords(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingSearchHot)
            }

            if !model.searchHotWords.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .leading),
                        GridItem(.flexible(), spacing: 12, alignment: .leading),
                    ],
                    alignment: .leading,
                    spacing: 2
                ) {
                    ForEach(Array(model.searchHotWords.prefix(20).enumerated()), id: \.offset) { index, word in
                        Button {
                            isFocused = false
                            model.searchTerm = word.display
                            Task { await model.submitSearch() }
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12.5, weight: index < 3 ? .bold : .medium).monospacedDigit())
                                    .foregroundStyle(index < 3 ? AppTheme.brand : AppTheme.tertiary(scheme))
                                    .frame(width: 20, alignment: .trailing)

                                Text(word.display)
                                    .font(.system(size: 13, weight: index < 3 ? .semibold : .regular))
                                    .foregroundStyle(AppTheme.text(scheme))
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                if let icon = MediaURL.normalize(word.icon) {
                                    RemoteImage(url: icon)
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                            .padding(.horizontal, 4)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !model.isLoadingSearchHot {
                Text("热搜暂时不可用，直接输入关键词搜索。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
        }
    }

    // MARK: State helpers

    private var currentIsEmpty: Bool {
        switch model.searchTab {
        case .all:
            return model.searchAllVideos.isEmpty
                && model.searchAllBangumi.isEmpty
                && model.searchAllFilms.isEmpty
                && model.searchAllUsers.isEmpty
                && model.searchAllLiveRooms.isEmpty
                && model.searchAllArticles.isEmpty
        case .video:
            return model.searchResults.isEmpty
        case .user:
            return model.searchUsers.isEmpty
        case .media:
            return model.searchMedia.isEmpty
        case .live:
            return model.searchLiveRooms.isEmpty
        case .article:
            return model.searchArticles.isEmpty
        }
    }

    private var emptyIcon: String {
        switch model.searchTab {
        case .all: return "magnifyingglass"
        case .video: return "play.rectangle"
        case .user: return "person.crop.circle"
        case .media: return "play.tv"
        case .live: return "dot.radiowaves.left.and.right"
        case .article: return "doc.text"
        }
    }

    private var emptyTitle: String {
        switch model.searchTab {
        case .all: return "没有找到相关内容"
        case .video: return "没有找到相关视频"
        case .user: return "没有找到相关用户"
        case .media: return model.searchMediaKind == .bangumi ? "没有找到相关番剧" : "没有找到相关影视"
        case .live: return "没有找到相关直播"
        case .article: return "没有找到相关专栏"
        }
    }
}

// MARK: - Filters

private struct MobileSearchFilterMenu: View {
    let options: [SearchFilterOption]
    let selection: String
    let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option.id)
                } label: {
                    if option.id == selection {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(SearchFilterCatalog.title(options, for: selection))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(isActive ? AppTheme.brand : AppTheme.secondary(scheme))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(AppTheme.chip(scheme), in: Capsule())
            .contentShape(Capsule())
        }
    }

    private var isActive: Bool {
        !selection.isEmpty && selection != "totalrank"
    }
}

// MARK: - Result rows

private struct MobileSearchUserLink<Content: View>: View {
    let user: SearchUser
    @ViewBuilder let content: () -> Content

    var body: some View {
        if user.mid > 0 {
            NavigationLink {
                MobileUPView(route: MobileUPRoute(mid: user.mid, name: user.uname, avatarURL: user.avatarURL))
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

private struct MobileSearchUserRow: View {
    let user: SearchUser
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarURL, size: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.uname.isEmpty ? "未知用户" : user.uname)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)

                    if user.isLiveNow {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                            Text("直播中")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 16)
                        .background(Color(hex: 0xFF3B5C), in: Capsule())
                    }
                }

                Text(user.detailText.isEmpty ? " " : user.detailText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)

                if !user.statsText.isEmpty {
                    Text(user.statsText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct MobileSearchMediaLink<Content: View>: View {
    let media: SearchMedia
    @ViewBuilder let content: () -> Content

    var body: some View {
        if media.seasonID > 0 {
            NavigationLink {
                MobileAnimeSeasonView(seasonID: media.seasonID)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else if let url = media.pageURL {
            Button {
                UIApplication.shared.open(url)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

private struct MobileSearchMediaCard: View {
    let media: SearchMedia
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: media.coverURL)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if let badge = media.badgeText {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Color(hex: 0xFF6699), in: RoundedRectangle(cornerRadius: 5))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(media.scoreText)
                        .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 18)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                        .padding(6)
                }

            Text(media.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !media.infoText.isEmpty {
                Text(media.infoText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct MobileSearchArticleLink<Content: View>: View {
    let article: SearchArticle
    @ViewBuilder let content: () -> Content

    var body: some View {
        if article.id > 0 {
            NavigationLink {
                MobileArticleView(articleID: article.id)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

private struct MobileSearchArticleRow: View {
    let article: SearchArticle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let desc = article.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(articleMeta)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let cover = article.coverURL {
                RemoteImage(url: cover)
                    .frame(width: 106, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var articleMeta: String {
        var parts: [String] = []
        if let author = article.author, !author.isEmpty {
            parts.append(author)
        }
        if !article.publishedText.isEmpty {
            parts.append(article.publishedText)
        }
        if !article.statsText.isEmpty {
            parts.append(article.statsText)
        }
        return parts.joined(separator: " · ")
    }
}
