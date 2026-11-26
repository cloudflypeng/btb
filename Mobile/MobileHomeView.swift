import SwiftUI

struct MobileHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            if model.homeTab == .categories {
                filterBar
            }
            Divider().opacity(0.5)
            feed
        }
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
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
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeTab.allCases) { tab in
                    MobilePill(title: tab.title, isSelected: model.homeTab == tab) {
                        guard model.homeTab != tab else { return }
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
                        guard model.homeFilter != filter else { return }
                        Task { await model.selectHomeFilter(filter) }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 9)
    }

    private var feed: some View {
        ScrollView {
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
                } else if model.videos.isEmpty && !model.isLoading {
                    emptyState
                } else {
                    ForEach(model.videos) { video in
                        MobileFeedCard(video: video)
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
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadHome()
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(AppTheme.surface(scheme))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBar(height: 15)
                SkeletonBar(width: 210, height: 12)
            }
            .padding(.horizontal, 14)
        }
        .skeletonPulse()
    }
}
