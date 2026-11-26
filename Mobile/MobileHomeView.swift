import SwiftUI

private struct BarsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 56
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Reports how far the feed has scrolled, on iOS 18+ via `ScrollGeometry`.
/// On iOS 17 there is no reliable offset feed, so the bars simply stay put.
private struct FeedScrollOffsetObserver: ViewModifier {
    let onChange: (_ old: CGFloat, _ new: CGFloat) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, new in
                onChange(old, new)
            }
        } else {
            content
        }
    }
}

/// Lives apart from the feed so tucking the bars away invalidates only the
/// bar row — re-running the feed's body over a 1000+ item list is what made
/// the old height-collapse stutter (#1).
@MainActor
@Observable
final class HomeBarsState {
    var hidden = false
}

/// The logo row, tab pills and (on 分区) the filter pills. Kept in its own
/// view so hiding it doesn't re-render the feed.
private struct HomeBars: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    let bars: HomeBarsState
    let height: CGFloat
    let onTop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                tabBar
                if model.homeTab == .categories {
                    filterBar
                }
            }
            .padding(.top, MobileSafeArea.top)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: BarsHeightKey.self, value: proxy.size.height)
                }
            )
            Divider()
        }
        .background(AppTheme.background(scheme))
        .offset(y: bars.hidden ? -(height + 1) : 0)
        .opacity(bars.hidden ? 0 : 1)
        // An invisible overlay still eats taps, which would kill the first
        // card's press while the bars are tucked away.
        .allowsHitTesting(!bars.hidden)
        .animation(BtbMotion.snappy, value: bars.hidden)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppMark(size: 26)
            Text("BTB")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            if let account = model.activeAccount {
                Button {
                    model.presentLogin()
                } label: {
                    AvatarView(url: account.avatarURL, size: 30)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    model.presentLogin()
                } label: {
                    Text("登录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(AppTheme.chip(scheme), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        // Double tap the logo for "back to the top".
        .onTapGesture(count: 2) { onTop() }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeTab.allCases) { tab in
                    // YouTube's rule: tapping the tab you are already on takes
                    // you back to the top. Refreshing stays on pull-to-refresh.
                    MobilePill(title: tab.title, isSelected: model.homeTab == tab) {
                        guard model.homeTab != tab else {
                            onTop()
                            return
                        }
                        Task { await model.selectHomeTab(tab) }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeFilter.allCases) { filter in
                    MobilePill(title: filter.title, isSelected: model.homeFilter == filter) {
                        guard model.homeFilter != filter else {
                            onTop()
                            return
                        }
                        Task { await model.selectHomeFilter(filter) }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 9)
    }
}

struct MobileHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    /// #1: the header and tab bar slip away while the list scrolls down.
    @State private var bars = HomeBarsState()
    @State private var barsHeight: CGFloat = 56
    /// #2: one scroll anchor per (tab, filter), so coming back lands where you left.
    @State private var topIDs: [String: String] = [:]
    @State private var currentTopID: String?
    /// #3: bumping this scrolls the list back to the top.
    @State private var scrollToTopToken = 0
    /// Restoring a tab's anchor moves the offset in one jump; that jump must
    /// not be read as "the user scrolled down" (#2).
    @State private var suppressBarTracking = false
    /// Cards stagger in only while the first screen settles; afterwards the
    /// list must appear instantly as it is scrolled.
    @State private var entranceActive = true
    @Environment(MobileRouter.self) private var router

    private var tabKey: String { model.homeSnapshotKey }

    var body: some View {
        // Full-bleed top: cards scroll away under the status bar instead of
        // stopping below it, so the list really does vanish into the phone's
        // top edge once the bars have tucked away.
        //
        // The bars float above the feed rather than sharing a VStack with it:
        // collapsing a row's height re-lays out the whole list, while sliding
        // one overlay layer costs nothing.
        ZStack(alignment: .top) {
            feed
                // Reserve the bars' room so the first card starts below them
                // at rest, and content slides under them while scrolling.
                .contentMargins(.top, barsHeight, for: .scrollContent)

            HomeBars(bars: bars, height: barsHeight, onTop: scrollToTopAndRefresh)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        // The bottom bar is drawn at the root now; it follows the header out.
        .onChange(of: bars.hidden) { _, hidden in
            router.tabBarHidden = hidden
        }
        .animation(BtbMotion.smooth, value: model.homeTab)
        .onPreferenceChange(BarsHeightKey.self) { height in
            if height > 20 { barsHeight = height }
        }
        .onChange(of: currentTopID) { _, newValue in
            topIDs[tabKey] = newValue
        }
        // #3: re-tapping the selected bottom tab brings the feed back to the
        // top, the way YouTube's home tab does.
        .onChange(of: router.retapToken) { _, _ in
            scrollToTopAndRefresh()
        }
        .onChange(of: tabKey) { _, _ in
            currentTopID = topIDs[tabKey]
            bars.hidden = false
            entranceActive = true
            suppressBarTracking = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                suppressBarTracking = false
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                entranceActive = false
            }
        }
    }

    private func scrollToTopAndRefresh() {
        if bars.hidden {
            withAnimation(BtbMotion.snappy) { bars.hidden = false }
        }
        scrollToTopToken += 1
        topIDs[tabKey] = nil
        currentTopID = nil
        // The list may be lazily realised, so nudge once more after the jump.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            scrollToTopToken += 1
        }
    }

    /// The rows that stagger in: only the first screenful, and only once.
    private func entranceIndex(for video: VideoItem) -> Int? {
        guard entranceActive else { return nil }
        guard let index = model.videos.firstIndex(where: { $0.id == video.id }), index < 4 else { return nil }
        return index
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id("home.feed.top")
                    feedContent
                }
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .modifier(FeedScrollOffsetObserver { old, new in
                guard !suppressBarTracking else { return }
                // Direction-driven: scrolling down tucks the bars away,
                // scrolling up (anywhere in the list) brings them back, so a
                // tab switch is reachable from deep inside a feed (#1, #2).
                let moved = new - old
                if new <= 12, bars.hidden {
                    withAnimation(BtbMotion.snappy) { bars.hidden = false }
                } else if moved > 6, new > 60, !bars.hidden {
                    withAnimation(BtbMotion.snappy) { bars.hidden = true }
                } else if moved < -6, bars.hidden {
                    withAnimation(BtbMotion.snappy) { bars.hidden = false }
                }
            })
            .scrollPosition(id: $currentTopID, anchor: .top)
            .onChange(of: scrollToTopToken) { _, _ in
                proxy.scrollTo("home.feed.top", anchor: .top)
            }
            .id(model.homeTab)
            // C6: switching tabs slides the new list in from the side.
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            )
            .refreshable {
                await model.refreshHome()
            }
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        LazyVStack(spacing: 24) {
            if let error = model.errorMessage, model.videos.isEmpty {
                MobileErrorBanner(text: error) {
                    Task { await model.loadHome() }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            if model.isLoading && model.videos.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    MobileFeedSkeleton()
                }
                .transition(.opacity)
            } else if model.videos.isEmpty && !model.isLoading {
                emptyState
                    .transition(.opacity)
            } else {
                ForEach(model.videos) { video in
                    MobileFeedCard(video: video)
                        .prefetchCovers(model.videos, after: video, lookahead: 4)
                        .staggeredEntrance(entranceIndex(for: video))
                }

                InfiniteScrollFooter(
                    isLoading: model.isLoading || model.homePager.isLoadingMore,
                    hasMore: model.homePager.hasMore,
                    failed: model.homePager.failed
                ) {
                    Task { await model.loadHomeMore() }
                }
            }
        }
        .scrollTargetLayout()
    }

    private var emptyState: some View {
        BtbStateView(
            icon: "tray",
            title: "这里还没有内容",
            message: "下拉刷新试试",
            iconSize: 32,
            verticalPadding: 90
        )
    }
}

struct MobileFeedCard: View {
    let video: VideoItem

    @Environment(\.colorScheme) private var scheme
    @Environment(AppModel.self) private var model

    var body: some View {
        MobileVideoLink(video: video) {
            VStack(alignment: .leading, spacing: 10) {
                cover
                VStack(alignment: .leading, spacing: 10) {
                    Text(video.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    metadata
                }
                .padding(.horizontal, 14)
            }
            .contentShape(Rectangle())
        }
    }

    private var cover: some View {
        RemoteImage(url: video.coverURL)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .resumeProgress(for: video.bvid)
            .overlay(alignment: .bottomTrailing) {
                if !video.durationText.isEmpty {
                    Text(video.durationText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 19)
                        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(8)
                }
            }
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            AvatarView(url: video.ownerFaceURL, size: 22)
            Text(video.ownerName)
                .lineLimit(1)
            if !video.viewText.isEmpty {
                Text("· \(video.viewText)次观看")
                    .lineLimit(1)
            }
            if !video.publishedAgoText.isEmpty {
                Text("· \(video.publishedAgoText)")
                    .lineLimit(1)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(AppTheme.secondary(scheme))
    }
}

struct MobileFeedSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // C7: same metrics as MobileFeedCard, so the swap never shifts the list.
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(AppTheme.surface(scheme))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBar(height: 15)
                SkeletonBar(width: 210, height: 15)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.surface(scheme))
                        .frame(width: 22, height: 22)
                    SkeletonBar(width: 130, height: 12)
                }
            }
            .padding(.horizontal, 14)
        }
        .skeletonPulse()
    }
}
