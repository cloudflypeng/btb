import SwiftUI

enum MobileDiscoverRoute: String, Identifiable, Hashable {
    case ranking
    case weekly
    case partitions
    case articles
    case topics

    var id: String { rawValue }
}

struct MobileDiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showSearch = false
    @State private var showLive = false
    @State private var showAnime = false
    @State private var route: MobileDiscoverRoute?

    private let rows = [
        (MobileDiscoverRoute.ranking, "排行榜", "全站热门视频", "chart.bar.xaxis"),
        (.weekly, "每周必看", "每周精选合集", "calendar.badge.clock"),
        (.articles, "专栏", "排行榜与深度阅读", "doc.text"),
        (.topics, "话题", "热门话题与讨论", "number"),
        (.partitions, "分区", "按动画、游戏、知识等分区浏览", "square.grid.2x2"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("发现")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.top, 8)

                searchEntry

                exploreList

                MobileSectionHeader(title: "直播与番剧")

                liveAnimeList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSearch) {
            MobileSearchView()
        }
        .navigationDestination(isPresented: $showLive) {
            MobileLiveListView()
        }
        .navigationDestination(isPresented: $showAnime) {
            MobileAnimeView()
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .ranking:
                MobileRankingView()
            case .weekly:
                MobileWeeklyView()
            case .partitions:
                MobilePartitionsView()
            case .articles:
                MobileArticleRankView()
            case .topics:
                MobileTopicSquareView()
            }
        }
        .task {
            if model.hasAccount, !model.liveLoaded {
                await model.loadLiveFeed(reset: true)
            }
        }
    }

    private var searchEntry: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                Text("搜索视频、UP 主、番剧")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondary(scheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(AppTheme.chip(scheme), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("搜索")
    }

    private var exploreList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                discoverRow(
                    title: row.1,
                    subtitle: row.2,
                    icon: row.3,
                    iconColor: AppTheme.secondary(scheme)
                ) {
                    route = row.0
                }
                if index < rows.count - 1 {
                    rowDivider
                }
            }
        }
    }

    private var liveAnimeList: some View {
        VStack(spacing: 0) {
            discoverRow(
                title: "直播",
                subtitle: liveSubtitle,
                icon: "dot.radiowaves.left.and.right",
                iconColor: AppTheme.brand
            ) {
                showLive = true
            }
            rowDivider
            discoverRow(
                title: "番剧",
                subtitle: "新番时间表 · 排行榜 · 追番",
                icon: "play.tv",
                iconColor: AppTheme.secondary(scheme)
            ) {
                showAnime = true
            }
        }
    }

    private func discoverRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
            .padding(.horizontal, 2)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.6)
            .padding(.leading, 40)
    }

    private var liveSubtitle: String {
        if !model.hasAccount {
            return "登录后查看关注主播的直播间"
        }
        if model.liveFollowedLiveCount > 0 {
            return "\(model.liveFollowedLiveCount) 个关注正在直播"
        }
        if model.liveLoaded {
            return "关注的直播间与实时弹幕"
        }
        return "正在获取关注主播…"
    }
}
