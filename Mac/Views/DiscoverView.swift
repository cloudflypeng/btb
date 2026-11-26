import AppKit
import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let categoryColumns = [GridItem(.adaptive(minimum: 176), spacing: 10)]
    private let videoColumns = [GridItem(.adaptive(minimum: 250), spacing: 22)]
    private let topicColumns = [GridItem(.adaptive(minimum: 254), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 42)
                .frame(maxWidth: 1240, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
        .task {
            await model.prepareDiscover()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SectionHeader(title: "发现", icon: "safari")

            HStack(spacing: 6) {
                ForEach(DiscoverTab.allCases) { tab in
                    TagChip(title: tab.title, isSelected: model.discoverTab == tab) {
                        Task { await model.selectDiscoverTab(tab) }
                    }
                }
            }

            Spacer()

            if model.discoverTab != .categories {
                Button {
                    Task { await model.refreshDiscover() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 30, height: 30)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .help("刷新")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.discoverTab {
        case .ranking:
            rankingContent
        case .weekly:
            weeklyContent
        case .categories:
            categoryContent
        case .articles:
            articleContent
        case .topics:
            topicContent
        }
    }

    @ViewBuilder
    private var rankingContent: some View {
        if let error = model.discoverRankingError {
            ErrorBanner(text: error) {
                Task { await model.loadDiscoverRanking(force: true) }
            }
        }

        if model.isLoadingDiscoverRanking && model.discoverRanking.isEmpty {
            loadingHint("正在加载排行榜…")
        } else if model.discoverRanking.isEmpty {
            if model.discoverRankingError == nil {
                EmptyHint(icon: "chart.bar.xaxis", title: "暂无排行榜", message: "稍后刷新试试。")
                    .padding(.top, 60)
            }
        } else {
            HStack(spacing: 10) {
                Text("全站排行榜")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("\(model.discoverRanking.count) 个视频")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                Spacer()
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(model.discoverRanking.enumerated()), id: \.element.id) { index, video in
                    Button {
                        model.openVideo(video)
                    } label: {
                        RankingRow(video: video, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyContent: some View {
        if let error = model.weeklySeriesError {
            ErrorBanner(text: error) {
                Task { await model.loadWeeklySeries(force: true) }
            }
        }

        if model.isLoadingWeeklySeries && model.weeklySeries.isEmpty {
            loadingHint("正在加载每周必看…")
        } else if model.weeklySeries.isEmpty {
            if model.weeklySeriesError == nil {
                EmptyHint(icon: "calendar", title: "暂无每周必看", message: "稍后刷新试试。")
                    .padding(.top, 60)
            }
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(model.weeklySeries) { series in
                        TagChip(
                            title: "第\(series.number)期",
                            isSelected: model.selectedWeeklyNumber == series.number
                        ) {
                            Task { await model.selectWeekly(number: series.number) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            if let config = model.weeklyIssue?.config {
                weeklyIssueHeader(config)
            }

            if let error = model.weeklyIssueError {
                ErrorBanner(text: error) {
                    if let number = model.selectedWeeklyNumber {
                        Task { await model.loadWeeklyIssue(number: number, force: true) }
                    }
                }
            }

            if model.isLoadingWeeklyIssue && model.weeklyVideos.isEmpty {
                loadingHint("正在加载本期视频…")
            } else if model.weeklyVideos.isEmpty {
                if model.weeklyIssueError == nil {
                    EmptyHint(icon: "film.stack", title: "本期暂无视频", message: "换一期看看吧。")
                        .padding(.top, 40)
                }
            } else {
                LazyVGrid(columns: videoColumns, alignment: .leading, spacing: 26) {
                    ForEach(model.weeklyVideos) { video in
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
    }

    private func weeklyIssueHeader(_ config: WeeklyConfig) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(config.name ?? "每周必看")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if let label = config.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 7)
                        .frame(height: 19)
                        .background(AppTheme.brand.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 0)
            }

            if let subject = config.subject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme).opacity(0.86))
            }
            if let subtitle = config.shareSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.chip(scheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var categoryContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选择一个分区，前往首页浏览该分区的内容。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))

            LazyVGrid(columns: categoryColumns, alignment: .leading, spacing: 10) {
                ForEach(partitions) { filter in
                    CategoryTile(filter: filter, isSelected: false) {
                        Task { await model.selectHomeFilter(filter) }
                    }
                }
            }
        }
    }

    private var partitions: [HomeFilter] {
        HomeFilter.allCases.filter { $0 != .all && $0 != .hot }
    }

    @ViewBuilder
    private var articleContent: some View {
        if let error = model.articleRankError {
            ErrorBanner(text: error) {
                Task { await model.loadArticleRank(force: true) }
            }
        }

        if model.isLoadingArticleRank && model.articleRank.isEmpty {
            loadingHint("正在加载专栏…")
        } else if model.articleRank.isEmpty {
            if model.articleRankError == nil {
                EmptyHint(icon: "doc.text", title: "暂无专栏", message: "稍后刷新试试。")
                    .padding(.top, 60)
            }
        } else {
            HStack(spacing: 10) {
                Text("专栏排行榜")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("\(model.articleRank.count) 篇")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                Spacer()
            }

            LazyVStack(spacing: 2) {
                ForEach(Array(model.articleRank.enumerated()), id: \.element.id) { index, article in
                    ArticleRankRow(article: article, rank: index + 1) {
                        model.openArticle(id: article.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topicContent: some View {
        if let error = model.topicSquareError, model.topicSquare.isEmpty {
            ErrorBanner(text: error) {
                Task { await model.loadTopicSquare(force: true) }
            }
        }

        if model.isLoadingTopicSquare && model.topicSquare.isEmpty {
            loadingHint("正在加载话题…")
        } else if model.topicSquare.isEmpty && model.topicSquareLoaded {
            EmptyHint(icon: "number", title: "暂无话题", message: "稍后刷新试试。")
                .padding(.top, 60)
        } else if !model.topicSquare.isEmpty {
            LazyVGrid(columns: topicColumns, alignment: .leading, spacing: 12) {
                ForEach(Array(model.topicSquare.enumerated()), id: \.element.id) { index, topic in
                    TopicSquareCard(topic: topic, paletteIndex: index) {
                        model.openTopic(topic)
                    }
                }
            }
        }
    }

    private func loadingHint(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

private struct TopicSquareCard: View {
    let topic: TopicSquareItem
    let paletteIndex: Int
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var scheme

    private static let palettes: [[Color]] = [
        [Color(hex: 0xFF5A7A), Color(hex: 0xB3154F)],
        [Color(hex: 0x5B8CFF), Color(hex: 0x2F35A8)],
        [Color(hex: 0xFFA24D), Color(hex: 0xD94A22)],
        [Color(hex: 0x43C6AC), Color(hex: 0x157C7C)],
        [Color(hex: 0x9D6BFF), Color(hex: 0x5924A8)],
        [Color(hex: 0x3EA6FF), Color(hex: 0x0A5AA8)],
    ]

    private var accent: Color {
        Self.palettes[abs(paletteIndex) % Self.palettes.count][0]
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "number")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }

                Text(topic.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = topic.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(topic.summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(
                isHovering ? AppTheme.surfaceHover(scheme) : AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
    }
}

private struct ArticleRankRow: View {
    let article: ArticleRankItem
    let rank: Int
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text("\(rank)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(rank <= 3 ? AppTheme.brand : AppTheme.tertiary(scheme))
                    .frame(width: 30, alignment: .leading)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !article.summaryText.isEmpty {
                        Text(article.summaryText)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        Text(article.authorName)
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
                    .padding(.top, 1)
                }

                Spacer(minLength: 10)

                if let cover = article.coverURL {
                    Color.clear
                        .frame(width: 140, height: 88)
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

struct TopicView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    let topic: TopicSquareItem

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    feed
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 42)
                .frame(maxWidth: 960, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.topicDetail?.name ?? topic.name)
                        .font(.system(size: 25, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = headerDescription {
                        Text(description)
                            .font(.system(size: 13))
                            .opacity(0.86)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                Button {
                    Task { await model.refreshTopic() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .help("刷新")
            }

            HStack(spacing: 16) {
                if let discuss = model.topicDetail?.discuss ?? topic.discuss, discuss > 0 {
                    headerStat("讨论", discuss)
                }
                if let view = model.topicDetail?.view ?? topic.view, view > 0 {
                    headerStat("浏览", view)
                }
                if let dynamics = model.topicDetail?.dynamics, dynamics > 0 {
                    headerStat("动态", dynamics)
                }

                Spacer()

                if model.isLoadingTopicDetail {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                if let jump = jumpURL {
                    Link(destination: jump) {
                        HStack(spacing: 4) {
                            Text("在浏览器打开")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(18)
        .foregroundStyle(.white)
        .background(
            headerColor,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var headerDescription: String? {
        let text = model.topicDetail?.description ?? topic.description
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private var jumpURL: URL? {
        guard let raw = model.topicDetail?.jumpURL,
              let url = URL(string: raw),
              url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    private var headerColor: Color {
        guard let raw = model.topicDetail?.backColor else { return AppTheme.brand }
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return AppTheme.brand }
        return Color(hex: hex)
    }

    private func headerStat(_ title: String, _ value: Int) -> some View {
        HStack(spacing: 5) {
            Text(SearchFormat.count(value))
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 11))
                .opacity(0.68)
        }
    }

    @ViewBuilder
    private var feed: some View {
        HStack(spacing: 8) {
            Text("最新动态")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            if let count = model.topicDetail?.dynamics, count > 0 {
                Text("\(SearchFormat.count(count))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer()
        }

        if let error = model.topicFeedError {
            ErrorBanner(text: error) {
                Task { await model.loadTopicFeed(reset: true) }
            }
        }

        if !model.topicFeedLoaded && model.topicFeedCards.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载话题动态…")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
        } else if model.topicFeedCards.isEmpty {
            if model.topicFeedError == nil {
                EmptyHint(icon: "text.bubble", title: "暂无动态", message: "这个话题下还没有内容。")
                    .padding(.top, 40)
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(model.topicFeedCards) { card in
                    DynamicCardView(card: card)
                }
            }

            InfiniteScrollFooter(
                isLoading: model.isLoadingTopicFeed,
                hasMore: model.topicFeedHasMore,
                failed: model.topicFeedError != nil,
                endText: "没有更多动态了"
            ) {
                Task { await model.loadMoreTopicFeed() }
            }
        }
    }
}
