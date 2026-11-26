import AppKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    private let categoryColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 210), spacing: 9, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if model.homeTab == .categories {
                        categoryPicker
                    }

                    if let error = model.errorMessage {
                        ErrorBanner(text: error) {
                            Task { await model.loadHome() }
                        }
                    }

                    if model.isLoading && model.videos.isEmpty {
                        skeletonGrid
                    } else if model.videos.isEmpty {
                        EmptyHint(
                            icon: "play.rectangle",
                            title: "这里还没有内容",
                            message: "换一个分类，或者点击工具栏的刷新按钮。"
                        )
                        .padding(.top, 80)
                    } else {
                        if let title = feedTitle {
                            Text(title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.text(scheme))
                        }

                        if model.homeTab == .ranking {
                            rankingList
                        } else {
                            videoGrid

                            InfiniteScrollFooter(
                                isLoading: model.isLoading || model.homePager.isLoadingMore,
                                hasMore: model.homePager.hasMore,
                                failed: model.homePager.failed
                            ) {
                                Task { await model.loadHomeMore() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 42)
                .frame(maxWidth: 1600, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
    }

    private var tabBar: some View {
        HStack(spacing: 28) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    Task { await model.selectHomeTab(tab) }
                } label: {
                    VStack(spacing: 7) {
                        Text(tab.title)
                            .font(.system(size: 15, weight: tab == model.homeTab ? .semibold : .medium))
                            .foregroundStyle(
                                tab == model.homeTab
                                    ? AppTheme.text(scheme)
                                    : AppTheme.secondary(scheme)
                            )
                        Rectangle()
                            .fill(tab == model.homeTab ? AppTheme.brand : Color.clear)
                            .frame(width: 22, height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if model.isLoading && !model.videos.isEmpty {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 48)
        .background(AppTheme.background(scheme))
    }

    private var feedTitle: String? {
        switch model.homeTab {
        case .recommend:
            return nil
        case .hot:
            return "全站热门"
        case .ranking:
            return "全站排行榜"
        case .categories:
            if model.homeFilter == .all { return nil }
            if model.homeFilter == .hot { return "全站热门" }
            return "\(model.homeFilter.title)分区"
        }
    }

    private var categoryPicker: some View {
        LazyVGrid(columns: categoryColumns, alignment: .leading, spacing: 10) {
            ForEach(HomeFilter.allCases) { filter in
                CategoryTile(
                    filter: filter,
                    isSelected: model.homeFilter == filter
                ) {
                    Task { await model.selectHomeFilter(filter) }
                }
            }
        }
    }

    private var videoGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(model.videos) { video in
                Button {
                    model.openVideo(video)
                } label: {
                    VideoCard(video: video)
                }
                .buttonStyle(.plain)
                .prefetchCovers(model.videos, after: video, lookahead: 12)
            }
        }
    }

    private var rankingList: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(model.videos.enumerated()), id: \.element.id) { index, video in
                Button {
                    model.openVideo(video)
                } label: {
                    RankingRow(video: video, rank: index + 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(0..<8, id: \.self) { _ in
                VideoCardSkeleton()
            }
        }
        .allowsHitTesting(false)
    }
}

struct CategoryTile: View {
    let filter: HomeFilter
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.secondary(scheme))
                    .frame(width: 30, height: 30)
                    .background(
                        isSelected ? Color.white.opacity(0.14) : AppTheme.chip(scheme),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(filter.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(height: 50)
            .background(
                isSelected
                    ? AppTheme.selected(scheme)
                    : (isHovering ? AppTheme.surfaceHover(scheme) : AppTheme.surface(scheme)),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
