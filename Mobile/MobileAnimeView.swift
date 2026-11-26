import AVKit
import Combine
import SwiftUI

struct MobileAnimeRoute: Hashable, Identifiable {
    let seasonID: Int64

    var id: Int64 { seasonID }
}

struct MobileAnimeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedSeason: MobileAnimeRoute?

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selectedSeason) { route in
            MobileAnimeSeasonView(seasonID: route.seasonID)
        }
        .task {
            if !model.animeLoaded {
                await model.loadAnimeFeed(reset: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("番剧")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            Button {
                Task { await model.loadAnimeFeed(reset: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingAnime)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(AnimeTab.allCases) { tab in
                MobilePill(title: tab.title, isSelected: model.animeTab == tab) {
                    Task { await model.setAnimeTab(tab) }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if model.isLoadingAnime && model.animeTimeline.isEmpty && model.animeRankItems.isEmpty {
                ProgressView()
                    .tint(AppTheme.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let error = model.animeError,
                      model.animeTimeline.isEmpty && model.animeRankItems.isEmpty {
                MobileErrorBanner(text: error) {
                    Task { await model.loadAnimeFeed(reset: true) }
                }
                .padding(14)
            } else {
                switch model.animeTab {
                case .timeline:
                    timelineContent
                case .rank:
                    rankContent
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadAnimeFeed(reset: true)
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        if model.animeTimeline.isEmpty {
            emptyHint(icon: "calendar", title: "暂无更新时间表", message: "稍后刷新试试")
        } else {
            dayPicker
                .padding(.top, 2)
            if let day = model.animeActiveDay, !day.episodes.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(day.episodes) { episode in
                        Button {
                            selectedSeason = MobileAnimeRoute(seasonID: episode.seasonID)
                        } label: {
                            MobileAnimeTimelineCard(episode: episode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 24)
            } else {
                emptyHint(icon: "moon.zzz", title: "当天没有番剧更新", message: "换一天看看吧")
            }
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.animeTimeline) { day in
                    Button {
                        model.selectAnimeDay(day.date)
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.isTodayDay ? "今天" : day.weekdayTitle)
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(shortDate(day.date))
                                .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                        }
                        .foregroundStyle(
                            model.animeActiveDay?.date == day.date
                                ? AppTheme.selectedText(scheme)
                                : AppTheme.secondary(scheme)
                        )
                        .frame(width: 58, height: 46)
                        .background(
                            model.animeActiveDay?.date == day.date
                                ? AppTheme.selected(scheme)
                                : AppTheme.chip(scheme),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var rankContent: some View {
        if model.animeRankItems.isEmpty {
            emptyHint(icon: "chart.bar", title: "暂无排行榜数据", message: "稍后刷新试试")
        } else {
            LazyVStack(spacing: 2) {
                ForEach(model.animeRankItems) { item in
                    Button {
                        selectedSeason = MobileAnimeRoute(seasonID: item.seasonID)
                    } label: {
                        MobileAnimeRankRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func emptyHint(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[1])-\(parts[2])"
    }
}

private struct MobileAnimeTimelineCard: View {
    let episode: AnimeTimelineEpisode

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 11) {
            RemoteImage(url: episode.coverURL)
                .frame(width: 104, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if !episode.isPublished {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.45))
                        Text("未开播")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 19)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let index = episode.pubIndex, !index.isEmpty {
                        Text(index)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                    if let time = episode.pubTime, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MobileAnimeRankRow: View {
    let item: AnimeRankItem

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 11) {
            Text(item.rank.map(String.init) ?? "–")
                .font(.system(size: 16, weight: .heavy).monospacedDigit())
                .foregroundStyle(rankColor)
                .frame(width: 26)

            RemoteImage(url: item.coverURL)
                .frame(width: 48, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)

                HStack(spacing: 7) {
                    if let rating = item.rating, !rating.isEmpty {
                        Text(rating)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    if let plays = item.iconText, !plays.isEmpty, plays != "-" {
                        Text("\(plays)播放")
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }

                if let line = item.newEp?.indexShow ?? item.newEp?.desc, !line.isEmpty {
                    Text(line)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var rankColor: Color {
        switch item.rank ?? 0 {
        case 1: return Color(hex: 0xF28C26)
        case 2: return Color(hex: 0x9EA8B8)
        case 3: return Color(hex: 0xC77A47)
        default: return AppTheme.tertiary(scheme)
        }
    }
}

struct MobileAnimeSeasonView: View {
    let seasonID: Int64

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var playerEpisode: AnimeEpisode?
    @State private var showsFullDescription = false

    private var season: AnimeSeason? {
        model.animeSeason?.seasonID == seasonID ? model.animeSeason : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let season {
                    hero(season)
                    actionRow(season)
                    episodesSection(season)
                    infoSection(season)
                    reviewsSection
                } else if let error = model.animeSeasonError {
                    MobileErrorBanner(text: error) {
                        model.openAnimeSeason(seasonID)
                    }
                    .padding(.horizontal, 14)
                } else {
                    loadingPlaceholder
                }
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            .padding(.top, 8)
            .accessibilityLabel("返回")
        }
        .sheet(item: $playerEpisode) { episode in
            MobileAnimePlayerSheet(episode: episode)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(16)
                .presentationBackground(AppTheme.background(scheme))
        }
        .task {
            if model.activeAnimeSeasonID != seasonID {
                model.openAnimeSeason(seasonID)
            }
        }
        .onDisappear {
            if playerEpisode == nil, model.activeAnimeSeasonID == seasonID {
                model.closeAnimeSeason()
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.brand)
            Text("正在加载番剧信息…")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    private func hero(_ season: AnimeSeason) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: season.backgroundURL)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.08), .black.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            HStack(alignment: .bottom, spacing: 12) {
                RemoteImage(url: season.coverURL)
                    .frame(width: 88, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(season.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 9) {
                        if let rating = season.rating, (rating.score ?? 0) > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                Text(rating.text)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        if !season.areaText.isEmpty {
                            Text(season.areaText)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    .font(.system(size: 11))

                    if let desc = season.newEp?.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    if let followText = season.stat?.followText, !followText.isEmpty {
                        Text(followText)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 13)
        }
        .frame(height: 190)
        .clipped()
    }

    private func actionRow(_ season: AnimeSeason) -> some View {
        HStack(spacing: 9) {
            Button {
                if let episode = model.animeSelectedEpisode ?? season.episodes?.first {
                    playerEpisode = episode
                }
            } label: {
                Label(playLabel(season), systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(season.episodes?.isEmpty ?? true)

            Button {
                Task { await model.toggleAnimeFollow() }
            } label: {
                Label(
                    season.isFollowing ? "已追番" : "追番",
                    systemImage: season.isFollowing ? "checkmark" : "plus"
                )
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(AppTheme.chip(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.isTogglingAnimeFollow)

            ShareLink(item: URL(string: "https://www.bilibili.com/bangumi/play/ss\(season.seasonID)")!) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 38, height: 38)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
    }

    private func playLabel(_ season: AnimeSeason) -> String {
        if let episode = model.animeSelectedEpisode ?? season.episodes?.first {
            return episode.title.isEmpty ? "播放" : "播放 第\(episode.title)话"
        }
        return "播放"
    }

    private func episodesSection(_ season: AnimeSeason) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("选集")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("共 \(season.episodeCount) 集")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 7)], spacing: 7) {
                ForEach(season.episodes ?? []) { episode in
                    Button {
                        playerEpisode = episode
                    } label: {
                        VStack(spacing: 2) {
                            Text(episode.title.isEmpty ? "正片" : episode.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                            if let badge = episode.badge, !badge.isEmpty {
                                Text(badge)
                                    .font(.system(size: 8.5, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(
                            model.animeSelectedEpisode?.epID == episode.epID
                                ? AppTheme.selectedText(scheme)
                                : AppTheme.text(scheme)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            model.animeSelectedEpisode?.epID == episode.epID
                                ? AppTheme.selected(scheme)
                                : AppTheme.chip(scheme),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
        .padding(.horizontal, 14)
    }

    private func infoSection(_ season: AnimeSeason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("简介")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                if let evaluate = season.evaluate, evaluate.count > 120 {
                    Button(showsFullDescription ? "收起" : "展开") {
                        withAnimation(BtbMotion.snappy) {
                            showsFullDescription.toggle()
                        }
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.brand)
                }
            }
            Text(season.evaluate?.isEmpty == false ? season.evaluate! : "暂无简介")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))
                .lineSpacing(3)
                .lineLimit(showsFullDescription ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
        .padding(.horizontal, 14)
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("短评")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if model.animeReviewTotal > 0 {
                    Text("共 \(model.animeReviewTotal) 条")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                Spacer()
            }

            if let error = model.animeReviewsError, model.animeReviews.isEmpty {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
            } else if model.animeReviews.isEmpty {
                if model.isLoadingAnimeReviews {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("暂无短评")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .padding(.vertical, 6)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.animeReviews) { review in
                        MobileAnimeReviewRow(review: review)
                    }
                }

                InfiniteScrollFooter(
                    isLoading: model.isLoadingAnimeReviews,
                    hasMore: model.animeReviewsHasMore,
                    failed: model.animeReviewsError != nil,
                    endText: "没有更多短评了"
                ) {
                    Task { await model.loadAnimeReviews() }
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
        .padding(.horizontal, 14)
    }
}

private struct MobileAnimeReviewRow: View {
    let review: AnimeReview

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            AvatarView(url: review.author?.avatarURL, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(review.authorName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                    if let score = review.score, score > 0 {
                        Text("\(score) 分")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    if let time = review.pushTimeStr, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    Spacer(minLength: 0)
                }

                Text(review.content)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 9) {
                    if let progress = review.progress, !progress.isEmpty {
                        Text(progress)
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    if let likes = review.stat?.likes, likes > 0 {
                        Label("\(likes)", systemImage: "hand.thumbsup")
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                }
                .font(.system(size: 10))
            }
        }
    }
}

struct MobileAnimePlayerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var episode: AnimeEpisode

    init(episode: AnimeEpisode) {
        _episode = State(initialValue: episode)
    }

    private var season: AnimeSeason? { model.animeSeason }
    private var episodes: [AnimeEpisode] { season?.episodes ?? [] }
    private var currentIndex: Int? {
        episodes.firstIndex(where: { $0.epID == episode.epID })
    }
    private var nextEpisode: AnimeEpisode? {
        guard let currentIndex, currentIndex + 1 < episodes.count else { return nil }
        return episodes[currentIndex + 1]
    }
    private var previousEpisode: AnimeEpisode? {
        guard let currentIndex, currentIndex > 0 else { return nil }
        return episodes[currentIndex - 1]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                MobileAnimePlayerPane(episode: $episode)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)

                VStack(alignment: .leading, spacing: 14) {
                    titleBlock
                    transportRow
                    episodeStrip
                    if let evaluate = season?.evaluate, !evaluate.isEmpty {
                        Text(evaluate)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineSpacing(2)
                            .lineLimit(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .task(id: episode.epID) {
            await model.playAnime(episode)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")

            VStack(alignment: .leading, spacing: 1) {
                Text(season?.title ?? "番剧")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Text(episodeLine)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if model.animeSeason != nil {
                ShareLink(item: URL(string: "https://www.bilibili.com/bangumi/play/ep\(episode.epID)")!) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 32, height: 32)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var episodeLine: String {
        var parts: [String] = []
        if !episode.title.isEmpty {
            parts.append("第\(episode.title)话")
        }
        if let long = episode.longTitle, !long.isEmpty {
            parts.append(long)
        }
        let seasonTag = season?.seasonTitle
        if let seasonTag, !seasonTag.isEmpty, seasonTag != season?.title {
            parts.append(seasonTag)
        }
        return parts.isEmpty ? "剧集" : parts.joined(separator: " · ")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episodeLine)
                .font(.system(size: 15.5, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let season {
                    if (season.rating?.score ?? 0) > 0 {
                        Text("\(season.rating?.text ?? "") 分")
                            .foregroundStyle(.orange)
                    }
                    if !season.areaText.isEmpty {
                        Text(season.areaText)
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    if let desc = season.newEp?.desc, !desc.isEmpty {
                        Text(desc)
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }
                if model.animePlayback?.isPreview == true {
                    Text("试看")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(AppTheme.brand.opacity(0.12), in: Capsule())
                }
            }
            .font(.system(size: 11))
        }
    }

    private var transportRow: some View {
        HStack(spacing: 9) {
            Button {
                if let previousEpisode {
                    episode = previousEpisode
                }
            } label: {
                Label("上一集", systemImage: "backward.end.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(previousEpisode == nil)

            Button {
                if let nextEpisode {
                    episode = nextEpisode
                }
            } label: {
                Label("下一集", systemImage: "forward.end.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(nextEpisode == nil)
        }
    }

    private var episodeStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("选集")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(episodes) { item in
                        Button {
                            guard item.epID != episode.epID else { return }
                            episode = item
                        } label: {
                            Text(item.title.isEmpty ? "正片" : item.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(
                                    item.epID == episode.epID
                                        ? AppTheme.selectedText(scheme)
                                        : AppTheme.text(scheme)
                                )
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(
                                    item.epID == episode.epID
                                        ? AppTheme.selected(scheme)
                                        : AppTheme.chip(scheme),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct MobileAnimePlayerPane: View {
    @Binding var episode: AnimeEpisode

    @Environment(AppModel.self) private var model
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var isReady = false
    @State private var loadFailed = false
    @State private var statusCancellable: AnyCancellable?
    @State private var fullscreenHost: LandscapePlayerHost?

    private var playbackURL: URL? {
        guard model.animePlayback?.playable == true else { return nil }
        return model.animePlayback?.playbackURL
    }

    private var playbackError: String? {
        model.animePlayError ?? model.animePlayback?.unavailableText
    }

    var body: some View {
        ZStack {
            Color.black

            if playbackURL != nil {
                VideoSurface(player: player, playback: nil)
                    .opacity(isReady ? 1 : 0)

                if !isReady && !loadFailed {
                    RemoteImage(url: model.animePlayback?.episode?.coverURL ?? episode.coverURL)
                        .opacity(0.35)
                    ProgressView()
                        .tint(.white)
                }

                MobileAnimeControls(
                    player: player,
                    isPlaying: $isPlaying,
                    isFullscreen: false,
                    onFullscreen: enterFullscreen
                )

                if loadFailed {
                    failureOverlay
                }
            } else if model.isLoadingAnimePlay {
                VStack(spacing: 9) {
                    ProgressView()
                        .tint(.white)
                    Text("正在加载剧集…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.75))
                }
            } else {
                unavailableState
            }
        }
        .clipped()
        .onChange(of: playbackURL, initial: true) { _, _ in
            applyPlayback()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
            guard let item = note.object as? AVPlayerItem, item === player.currentItem else { return }
            playAdjacentEpisode(offset: 1)
        }
        .onChange(of: model.animeSelectedEpisode?.epID) { _, selected in
            guard let selected, selected != episode.epID,
                  let match = model.animeSeason?.episodes?.first(where: { $0.epID == selected })
            else { return }
            episode = match
        }
        .onDisappear {
            if fullscreenHost == nil {
                player.pause()
            }
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 9) {
            Image(systemName: "play.slash")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text(playbackError ?? "剧集暂不可播放")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            Button {
                Task { await model.playAnime(episode) }
            } label: {
                Text("重试")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var failureOverlay: some View {
        VStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(.orange)
            Text("剧集播放失败")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Button {
                Task { await model.playAnime(episode) }
            } label: {
                Text("重试")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applyPlayback() {
        statusCancellable = nil
        loadFailed = false
        guard let url = playbackURL else {
            isReady = false
            player.pause()
            isPlaying = false
            return
        }
        if (player.currentItem?.asset as? AVURLAsset)?.url != url {
            isReady = false
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            statusCancellable = item.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .sink { status in
                    switch status {
                    case .readyToPlay:
                        isReady = true
                    case .failed:
                        loadFailed = true
                        isPlaying = false
                    default:
                        break
                    }
                }
        }
        player.play()
        isPlaying = true
    }

    private func playAdjacentEpisode(offset: Int) {
        guard let episodes = model.animeSeason?.episodes,
              let index = episodes.firstIndex(where: { $0.epID == episode.epID })
        else { return }
        let next = index + offset
        guard episodes.indices.contains(next) else { return }
        episode = episodes[next]
    }

    @MainActor
    private func enterFullscreen() {
        guard fullscreenHost == nil else { return }
        guard let top = UIApplication.shared.topViewController() else { return }
        let canvas = ZStack {
            Color.black.ignoresSafeArea()
            VideoSurface(player: player, playback: nil)
            MobileAnimeControls(
                player: player,
                isPlaying: $isPlaying,
                isFullscreen: true,
                onFullscreen: exitFullscreen
            )
        }
        .environment(model)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)

        let host = LandscapePlayerHost(rootView: AnyView(canvas))
        host.modalPresentationStyle = .fullScreen
        host.modalTransitionStyle = .crossDissolve
        fullscreenHost = host
        top.present(host, animated: false) {
            requestVideoOrientation(.landscapeRight)
        }
    }

    @MainActor
    private func exitFullscreen() {
        guard let host = fullscreenHost else { return }
        fullscreenHost = nil
        host.dismiss(animated: false) {
            requestVideoOrientation(.portrait)
        }
    }
}

private struct MobileAnimeControls: View {
    @Environment(AppModel.self) private var model

    let player: AVPlayer
    @Binding var isPlaying: Bool
    let isFullscreen: Bool
    let onFullscreen: () -> Void

    private var qualities: [AnimeQuality] { model.animePlayback?.qualities ?? [] }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 14) {
                Button {
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")

                Spacer()

                if !qualities.isEmpty {
                    Menu {
                        ForEach(qualities) { quality in
                            Button {
                                Task { await model.selectAnimeQuality(quality.qn) }
                            } label: {
                                if quality.qn == model.animeSelectedQN {
                                    Label(quality.label, systemImage: "checkmark")
                                } else {
                                    Text(quality.label)
                                }
                            }
                        }
                    } label: {
                        Text(qualities.first(where: { $0.qn == model.animeSelectedQN })?.label ?? "清晰度")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(.black.opacity(0.35), in: Capsule())
                    }
                    .accessibilityLabel("清晰度")
                }

                Button(action: onFullscreen) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, isFullscreen ? 22 : 10)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 90)
            .allowsHitTesting(false)
        }
    }
}
