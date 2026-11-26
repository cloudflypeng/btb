import AppKit
import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let videoColumns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 20, alignment: .top),
    ]
    private let mediaColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 200), spacing: 18, alignment: .top),
    ]
    private let liveColumns = [
        GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 14, alignment: .top),
    ]
    private let userColumns = [
        GridItem(.adaptive(minimum: 320, maximum: 520), spacing: 12, alignment: .top),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 42)
                    .frame(maxWidth: 1240, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
        .task {
            await model.loadSearchHotWords()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                ForEach(SearchTab.allCases) { tab in
                    TagChip(title: tab.title, isSelected: model.searchTab == tab) {
                        Task { await model.selectSearchTab(tab) }
                    }
                }

                Spacer(minLength: 12)

                if model.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
                if model.searchAttempted, model.searchTotalResults > 0 {
                    Text("约 \(SearchFormat.count(model.searchTotalResults)) 个结果")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .monospacedDigit()
                }
            }

            if model.searchTab == .media {
                HStack(spacing: 6) {
                    ForEach(SearchMediaKind.allCases) { kind in
                        TagChip(title: kind.title, isSelected: model.searchMediaKind == kind) {
                            Task { await model.setSearchMediaKind(kind) }
                        }
                    }
                    Spacer()
                }
            }

            if model.searchTab == .video {
                HStack(spacing: 8) {
                    SearchFilterMenu(
                        options: SearchFilterCatalog.orders,
                        selection: model.searchOrder
                    ) { value in
                        Task { await model.setSearchOrder(value) }
                    }
                    SearchFilterMenu(
                        options: SearchFilterCatalog.durations,
                        selection: model.searchDuration
                    ) { value in
                        Task { await model.setSearchDuration(value) }
                    }
                    SearchFilterMenu(
                        options: SearchFilterCatalog.partitions,
                        selection: model.searchTID
                    ) { value in
                        Task { await model.setSearchTID(value) }
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppTheme.background(scheme))
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if showsSuggestions {
            suggestions
        } else if !model.searchAttempted || model.activeSearchKeyword.isEmpty {
            landing
        } else if model.isSearching && currentIsEmpty {
            loading
        } else if let error = model.searchError {
            VStack(alignment: .leading, spacing: 18) {
                ErrorBanner(text: error) {
                    Task { await model.search() }
                }
                if !currentIsEmpty { results }
            }
        } else if currentIsEmpty {
            EmptyHint(
                icon: emptyIcon,
                title: emptyTitle,
                message: "换一个关键词或筛选条件试试。"
            )
            .padding(.top, 80)
        } else {
            results
        }
    }

    @ViewBuilder
    private var results: some View {
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
        LazyVStack(spacing: 6) {
            ForEach(model.searchResults) { video in
                Button {
                    model.openVideo(video)
                } label: {
                    SearchResultRow(video: video)
                }
                .buttonStyle(.plain)
            }
            searchFooter
        }
    }

    private var userResults: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: userColumns, spacing: 12) {
                ForEach(model.searchUsers) { user in
                    SearchUserRow(user: user) {
                        openUser(user)
                    }
                }
            }
            searchFooter
        }
    }

    private var mediaResults: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: mediaColumns, spacing: 22) {
                ForEach(model.searchMedia) { media in
                    SearchMediaCard(media: media) {
                        openMedia(media)
                    }
                }
            }
            searchFooter
        }
    }

    private var liveResults: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: liveColumns, spacing: 20) {
                ForEach(model.searchLiveRooms) { room in
                    liveCard(room)
                }
            }
            searchFooter
        }
    }

    private var articleResults: some View {
        LazyVStack(spacing: 6) {
            ForEach(model.searchArticles) { article in
                SearchArticleRow(article: article) {
                    model.openArticle(id: article.id)
                }
            }
            searchFooter
        }
    }

    private var allResults: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !model.searchAllVideos.isEmpty {
                resultSection("视频", openTab: .video) {
                    LazyVGrid(columns: videoColumns, spacing: 20) {
                        ForEach(Array(model.searchAllVideos.prefix(6))) { video in
                            Button {
                                model.openVideo(video)
                            } label: {
                                VideoCard(video: video)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !model.searchAllBangumi.isEmpty {
                resultSection("番剧", openTab: .media, mediaKind: .bangumi) {
                    mediaGrid(model.searchAllBangumi)
                }
            }

            if !model.searchAllFilms.isEmpty {
                resultSection("影视", openTab: .media, mediaKind: .film) {
                    mediaGrid(model.searchAllFilms)
                }
            }

            if !model.searchAllUsers.isEmpty {
                resultSection("用户", openTab: .user) {
                    LazyVGrid(columns: userColumns, spacing: 12) {
                        ForEach(Array(model.searchAllUsers.prefix(4))) { user in
                            SearchUserRow(user: user) {
                                openUser(user)
                            }
                        }
                    }
                }
            }

            if !model.searchAllLiveRooms.isEmpty {
                resultSection("直播", openTab: .live) {
                    LazyVGrid(columns: liveColumns, spacing: 20) {
                        ForEach(Array(model.searchAllLiveRooms.prefix(4))) { room in
                            liveCard(room)
                        }
                    }
                }
            }

            if !model.searchAllArticles.isEmpty {
                resultSection("专栏", openTab: .article) {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(model.searchAllArticles.prefix(4))) { article in
                            SearchArticleRow(article: article) {
                                model.openArticle(id: article.id)
                            }
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Button("查看全部") {
                    Task {
                        if let mediaKind {
                            await model.setSearchMediaKind(mediaKind)
                        }
                        await model.selectSearchTab(openTab)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.brand)
            }
            content()
        }
    }

    private func mediaGrid(_ items: [SearchMedia]) -> some View {
        LazyVGrid(columns: mediaColumns, spacing: 22) {
            ForEach(Array(items.prefix(6))) { media in
                SearchMediaCard(media: media) {
                    openMedia(media)
                }
            }
        }
    }

    @ViewBuilder
    private func liveCard(_ room: SearchLiveRoom) -> some View {
        if let live = LiveRoom(search: room) {
            Button {
                model.openLiveRoom(live)
            } label: {
                LiveRoomCard(room: live)
            }
            .buttonStyle(.plain)
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
        Group {
            if model.searchTab == .video {
                LazyVGrid(columns: videoColumns, spacing: 20) {
                    ForEach(0..<6, id: \.self) { _ in
                        VideoCardSkeleton()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在搜索…")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 90)
            }
        }
    }

    // MARK: Landing

    private var landing: some View {
        VStack(alignment: .leading, spacing: 30) {
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
                Button("清空") {
                    model.clearSearchHistory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84, maximum: 180), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(model.searchHistory, id: \.self) { keyword in
                    SearchKeywordChip(title: keyword) {
                        model.searchTerm = keyword
                        Task { await model.submitSearch() }
                    }
                }
            }
        }
    }

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("哔哩哔哩热搜")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                if model.isLoadingSearchHot && model.searchHotWords.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button {
                    Task { await model.loadSearchHotWords(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 26, height: 26)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingSearchHot)
                .help("刷新热搜")
            }

            if !model.searchHotWords.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16, alignment: .leading),
                        GridItem(.flexible(), spacing: 16, alignment: .leading),
                    ],
                    alignment: .leading,
                    spacing: 2
                ) {
                    ForEach(Array(model.searchHotWords.prefix(20).enumerated()), id: \.offset) { index, word in
                        SearchHotRow(index: index, word: word) {
                            model.searchTerm = word.display
                            Task { await model.submitSearch() }
                        }
                    }
                }
            } else if !model.isLoadingSearchHot {
                Text("热搜暂时不可用，直接输入关键词搜索。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
        }
    }

    // MARK: Suggestions

    private var showsSuggestions: Bool {
        let term = model.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        return !model.searchSuggestItems.isEmpty
            && !term.isEmpty
            && term != model.activeSearchKeyword
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(model.searchSuggestItems) { item in
                SearchSuggestionRow(item: item) {
                    model.applySearchSuggestion(item)
                }
            }
        }
        .padding(.top, 4)
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

    private func openUser(_ user: SearchUser) {
        guard user.mid > 0 else { return }
        model.openUP(mid: user.mid, name: user.uname, avatarURL: user.avatarURL)
    }

    private func openMedia(_ media: SearchMedia) {
        if media.seasonID > 0 {
            model.openAnimeSeason(media.seasonID)
        } else if let url = media.pageURL {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Components

private struct SearchFilterMenu: View {
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
            HStack(spacing: 4) {
                Text(SearchFilterCatalog.title(options, for: selection))
                    .font(.system(size: 12.5, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? AppTheme.text(scheme) : AppTheme.secondary(scheme))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(AppTheme.chip(scheme), in: Capsule())
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var isActive: Bool {
        !selection.isEmpty && selection != "totalrank"
    }
}

private struct SearchKeywordChip: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    isHovering ? AppTheme.hover(scheme) : AppTheme.chip(scheme),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchHotRow: View {
    let index: Int
    let word: SearchHotWord
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 12.5, weight: index < 3 ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(index < 3 ? AppTheme.brand : AppTheme.tertiary(scheme))
                    .frame(width: 20, alignment: .trailing)

                Text(word.display)
                    .font(.system(size: 13.5, weight: index < 3 ? .semibold : .regular))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let icon = MediaURL.normalize(word.icon) {
                    RemoteImage(url: icon)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                isHovering ? AppTheme.hover(scheme) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchSuggestionRow: View {
    let item: SearchSuggestItem
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                Text(item.display)
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                isHovering ? AppTheme.hover(scheme) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchUserRow: View {
    let user: SearchUser
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
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
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)

                    if !user.statsText.isEmpty {
                        Text(user.statsText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
            .padding(11)
            .background(
                isHovering ? AppTheme.hover(scheme) : AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchMediaCard: View {
    let media: SearchMedia
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay {
                        ZStack {
                            Rectangle()
                                .fill(AppTheme.surface(scheme))
                            RemoteImage(url: media.coverURL)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let badge = media.badgeText {
                            Text(badge)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(Color(hex: 0xFF6699), in: RoundedRectangle(cornerRadius: 5))
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(media.scoreText)
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 19)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(isHovering ? 0.18 : 0), lineWidth: 1)
                    }

                Text(media.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !media.infoText.isEmpty {
                    Text(media.infoText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchArticleRow: View {
    let article: SearchArticle
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = article.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        Text(article.author ?? "未知作者")
                            .foregroundStyle(AppTheme.secondary(scheme))
                        if !article.publishedText.isEmpty {
                            Text("·")
                                .foregroundStyle(AppTheme.tertiary(scheme))
                            Text(article.publishedText)
                                .foregroundStyle(AppTheme.tertiary(scheme))
                        }
                        if !article.statsText.isEmpty {
                            Text("·")
                                .foregroundStyle(AppTheme.tertiary(scheme))
                            Text(article.statsText)
                                .foregroundStyle(AppTheme.tertiary(scheme))
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .padding(.top, 2)
                }

                Spacer(minLength: 12)

                if let cover = article.coverURL {
                    Color.clear
                        .frame(width: 150, height: 96)
                        .overlay {
                            RemoteImage(url: cover)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .padding(11)
            .background(
                isHovering ? AppTheme.hover(scheme) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
