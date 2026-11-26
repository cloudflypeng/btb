import AVKit
import AppKit
import Combine
import SwiftUI

struct AnimeFeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = model.animeError {
                        ErrorBanner(text: error) {
                            Task { await model.loadAnimeFeed(reset: true) }
                        }
                    }

                    if model.isLoadingAnime && model.animeTimeline.isEmpty && model.animeRankItems.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在加载番剧…")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondary(scheme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if model.animeTab == .timeline {
                        timelineContent
                    } else {
                        rankContent
                    }
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
            await model.loadAnimeFeed()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SectionHeader(title: "番剧", icon: "play.tv")

            HStack(spacing: 6) {
                ForEach(AnimeTab.allCases) { tab in
                    TagChip(title: tab.title, isSelected: model.animeTab == tab) {
                        Task { await model.setAnimeTab(tab) }
                    }
                }
            }

            Spacer()

            if model.animeTab == .timeline, let day = model.animeActiveDay {
                Text("\(day.date) \(day.weekdayTitle) · \(day.episodes.count) 部更新")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }

            Button {
                Task { await model.loadAnimeFeed(reset: true) }
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

    @ViewBuilder
    private var timelineContent: some View {
        if model.animeTimeline.isEmpty {
            EmptyHint(
                icon: "calendar",
                title: "暂无更新时间表",
                message: "稍后刷新试试。"
            )
            .padding(.top, 80)
        } else {
            dayPicker
            let day = model.animeActiveDay
            if let day, !day.episodes.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(day.episodes) { episode in
                        Button {
                            model.openAnimeSeason(episode.seasonID)
                        } label: {
                            AnimeTimelineCard(episode: episode)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyHint(
                    icon: "moon.zzz",
                    title: "当天没有番剧更新",
                    message: "换一天看看吧。"
                )
                .padding(.top, 60)
            }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(model.animeTimeline) { day in
                Button {
                    model.selectAnimeDay(day.date)
                } label: {
                    VStack(spacing: 3) {
                        Text(day.isTodayDay ? "今天" : day.weekdayTitle)
                            .font(.system(size: 11, weight: .semibold))
                        Text(day.date)
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(
                        model.animeActiveDay?.date == day.date
                            ? AppTheme.selectedText(scheme)
                            : AppTheme.secondary(scheme)
                    )
                    .frame(width: 66, height: 48)
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
    }

    @ViewBuilder
    private var rankContent: some View {
        if model.animeRankItems.isEmpty {
            EmptyHint(
                icon: "chart.bar",
                title: "暂无排行榜数据",
                message: "稍后刷新试试。"
            )
            .padding(.top, 80)
        } else {
            LazyVStack(spacing: 6) {
                ForEach(model.animeRankItems) { item in
                    Button {
                        model.openAnimeSeason(item.seasonID)
                    } label: {
                        AnimeRankRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AnimeTimelineCard: View {
    let episode: AnimeTimelineEpisode

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: episode.coverURL)
                .frame(width: 112, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if !episode.isPublished {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.42))
                        Text("未开播")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let index = episode.pubIndex, !index.isEmpty {
                        Text(index)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                    if let time = episode.pubTime, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            isHovering ? AppTheme.surfaceHover(scheme) : AppTheme.surface(scheme),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

private struct AnimeRankRow: View {
    let item: AnimeRankItem

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Text(item.rank.map(String.init) ?? "–")
                .font(.system(size: 17, weight: .heavy).monospacedDigit())
                .foregroundStyle(rankColor)
                .frame(width: 30, alignment: .center)

            RemoteImage(url: item.coverURL)
                .frame(width: 54, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let rating = item.rating, !rating.isEmpty {
                        Text(rating)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    if let plays = item.iconText, !plays.isEmpty, plays != "-" {
                        Text("\(plays)播放")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    if let badge = item.badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                }

                if let newEp = item.newEp?.displayLine {
                    Text(newEp)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isHovering ? AppTheme.surfaceHover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var rankColor: Color {
        switch item.rank ?? 0 {
        case 1: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case 2: return Color(red: 0.62, green: 0.66, blue: 0.72)
        case 3: return Color(red: 0.78, green: 0.48, blue: 0.28)
        default: return AppTheme.tertiary(scheme)
        }
    }
}

private extension AnimeNewEp {
    var displayLine: String? {
        let value = indexShow ?? desc
        return value?.isEmpty == false ? value : nil
    }
}

struct AnimeSeasonView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isTheater = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, min(proxy.size.width, 1240) - (isTheater ? 0 : 48))
            ScrollView {
                VStack(alignment: .leading, spacing: isTheater ? 0 : 18) {
                    if isTheater {
                        AnimePlayerView(isTheater: $isTheater)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    } else {
                        if let season = model.animeSeason {
                            AnimeSeasonHero(season: season)
                        } else {
                            seasonPlaceholder
                        }

                        if let error = model.animeSeasonError {
                            ErrorBanner(text: error) {
                                let seasonID = model.activeAnimeSeasonID ?? 0
                                Task { await model.loadAnimeSeason(seasonID: seasonID, force: true) }
                            }
                        }

                        if showsPlayer, let episode = model.animeSelectedEpisode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(episodeHeader(episode))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.text(scheme))
                                AnimePlayerView(isTheater: $isTheater)
                                    .frame(width: min(width, 960))
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        episodesSection
                        infoSection
                        reviewsSection
                    }
                }
                .padding(.horizontal, isTheater ? 0 : 24)
                .padding(.top, isTheater ? 0 : 18)
                .padding(.bottom, isTheater ? 0 : 44)
                .frame(maxWidth: isTheater ? CGFloat.infinity : 1240, alignment: isTheater ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isTheater ? Color.black : Color.clear)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isTheater)
        }
        .background(AppTheme.background(scheme))
        .toolbar(isTheater ? .hidden : .visible, for: .windowToolbar)
        .onDisappear {
            model.isTheaterActive = false
        }
        .task(id: model.activeAnimeSeasonID) {
            if let seasonID = model.activeAnimeSeasonID {
                await model.loadAnimeSeason(seasonID: seasonID)
            }
        }
    }

    private var showsPlayer: Bool {
        model.animePlayback != nil || model.isLoadingAnimePlay || model.animePlayError != nil
    }

    private var seasonPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isLoadingAnimeSeason {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载番剧信息…")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 80)
            } else {
                EmptyHint(
                    icon: "play.tv",
                    title: "没有找到这部番剧",
                    message: "可能已下架或需要登录。"
                )
                .padding(.top, 60)
            }
        }
    }

    private func episodeHeader(_ episode: AnimeEpisode) -> String {
        var parts: [String] = []
        if !episode.title.isEmpty {
            parts.append("第\(episode.title)话")
        }
        if let long = episode.longTitle, !long.isEmpty {
            parts.append(long)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var episodesSection: some View {
        if let season = model.animeSeason {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("选集")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text("共 \(season.episodeCount) 集")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                    ForEach(season.episodes ?? []) { episode in
                        Button {
                            Task { await model.playAnime(episode) }
                        } label: {
                            VStack(spacing: 3) {
                                Text(episode.title.isEmpty ? "正片" : episode.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                if let badge = episode.badge, !badge.isEmpty {
                                    Text(badge)
                                        .font(.system(size: 9, weight: .medium))
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(
                                model.animeSelectedEpisode?.epID == episode.epID
                                    ? AppTheme.selectedText(scheme)
                                    : AppTheme.text(scheme)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                model.animeSelectedEpisode?.epID == episode.epID
                                    ? AppTheme.selected(scheme)
                                    : AppTheme.chip(scheme),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(episode.displayTitle)
                    }
                }
            }
            .padding(14)
            .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        if let season = model.animeSeason {
            VStack(alignment: .leading, spacing: 8) {
                Text("简介")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text(season.evaluate?.isEmpty == false ? season.evaluate! : "暂无简介")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
            }
        }
    }

    @ViewBuilder
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("短评")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if model.animeReviewTotal > 0 {
                    Text("共 \(model.animeReviewTotal) 条")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                Spacer()
            }

            if let error = model.animeReviewsError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }

            if model.animeReviews.isEmpty && !model.isLoadingAnimeReviews {
                Text("暂无短评")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.animeReviews) { review in
                        AnimeReviewRow(review: review)
                    }
                }

                if model.animeReviewsHasMore {
                    Button {
                        Task { await model.loadAnimeReviews() }
                    } label: {
                        HStack(spacing: 8) {
                            if model.isLoadingAnimeReviews {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Text(model.isLoadingAnimeReviews ? "正在加载…" : "加载更多短评")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.secondary(scheme))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoadingAnimeReviews)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
    }
}

private struct AnimeSeasonHero: View {
    let season: AnimeSeason

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: season.backgroundURL)
                .frame(maxWidth: .infinity)
                .frame(height: 235)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.12), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            HStack(alignment: .bottom, spacing: 16) {
                RemoteImage(url: season.coverURL)
                    .frame(width: 118, height: 158)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 7) {
                    Text(season.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        if let rating = season.rating {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.orange)
                                Text(rating.text)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                        }
                        if !season.areaText.isEmpty {
                            Text(season.areaText)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.74))
                        }
                        if let desc = season.newEp?.desc, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.74))
                                .lineLimit(1)
                        }
                    }

                    if let followText = season.stat?.followText, !followText.isEmpty {
                        Text(followText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    HStack(spacing: 8) {
                        Button {
                            if let episode = model.animeSelectedEpisode ?? season.episodes?.first {
                                Task { await model.playAnime(episode) }
                            }
                        } label: {
                            Label("播放", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(AppTheme.brand, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await model.toggleAnimeFollow() }
                        } label: {
                            Label(
                                season.isFollowing ? "已追番" : "追番",
                                systemImage: season.isFollowing ? "checkmark" : "plus"
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(.white.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isTogglingAnimeFollow)

                        Button {
                            NSWorkspace.shared.open(URL(string: "https://www.bilibili.com/bangumi/play/ss\(season.seasonID)")!)
                        } label: {
                            Image(systemName: "safari")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(.white.opacity(0.16), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("在浏览器中打开")
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(height: 235)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AnimeReviewRow: View {
    let review: AnimeReview

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: review.author?.avatarURL, size: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(review.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                    if let score = review.score, score > 0 {
                        Text("\(score) 分")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    if let time = review.pushTimeStr, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    Spacer(minLength: 0)
                }

                Text(review.content)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let progress = review.progress, !progress.isEmpty {
                        Text(progress)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    if let likes = review.stat?.likes, likes > 0 {
                        Label("\(likes)", systemImage: "hand.thumbsup")
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                }
            }
        }
    }
}

struct AnimePlayerView: View {
    @Binding var isTheater: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var player: AVPlayer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isReady = false
    @State private var isMuted = false
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var progressTask: Task<Void, Never>?
    @State private var cancellables: Set<AnyCancellable> = []

    var body: some View {
        ZStack {
            Color.black

            if let player {
                PlayerSurface(player: player)
                    .opacity(isReady ? 1 : 0)
            }

            if !isReady {
                poster
            }

            if model.isLoadingAnimePlay && player == nil {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在加载剧集…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            if let error = model.animePlayError, player == nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let episode = model.animeSelectedEpisode {
                        Button("重试") {
                            Task { await model.playAnime(episode) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.brand)
                    }
                }
                .padding(24)
                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
            }

            if model.isLoadingAnimePlay && player != nil {
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在切换…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let playback = model.animePlayback, playback.isPreview == true, isReady {
                VStack {
                    HStack {
                        Text("试看")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(Color.orange.opacity(0.92), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isTheater ? 0 : 12, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            guard let player else { return .ignored }
            togglePlayback(player)
            return .handled
        }
        .onKeyPress(KeyEquivalent("f")) {
            isTheater.toggle()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            seekBy(-5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            seekBy(5)
            return .handled
        }
        .onExitCommand {
            guard isTheater else { return }
            isTheater = false
        }
        .onChange(of: isTheater) { _, value in
            model.isTheaterActive = value
        }
        .onAppear {
            model.isTheaterActive = isTheater
        }
        .onDisappear {
            teardown()
            model.isTheaterActive = false
        }
        .overlay(alignment: .bottom) {
            if isReady, let player {
                controls(player)
                    .opacity(showControls ? 1 : 0)
                    .allowsHitTesting(showControls)
                    .animation(.easeOut(duration: 0.18), value: showControls)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 880)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showControls = true
                scheduleControlsHide()
            case .ended:
                scheduleControlsHide()
            }
        }
        .onChange(of: isReady) { _, ready in
            guard ready else { return }
            showControls = true
            scheduleControlsHide()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else { return }
            isPlaying = false
            showControls = true
            hideControlsTask?.cancel()
            playNextIfAvailable()
        }
        .task(id: model.animePlayback?.playbackURLString) {
            rebuildPlayer()
            startProgressLoop()
        }
    }

    private var poster: some View {
        ZStack {
            Color.black
            if let cover = model.animeSelectedEpisode?.coverURL ?? model.animeSeason?.coverURL {
                RemoteImage(url: cover)
                    .overlay(.black.opacity(0.35))
            }
        }
        .clipped()
    }

    private func rebuildPlayer() {
        cancellables.removeAll()
        guard let url = model.animePlayback?.playbackURL else {
            player?.pause()
            player = nil
            isReady = false
            return
        }
        let resume = max(0, currentTime)
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        player = newPlayer
        isReady = false
        currentTime = 0
        duration = 0

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak newPlayer] status in
                guard newPlayer === player else { return }
                switch status {
                case .readyToPlay:
                    isReady = true
                    newPlayer?.play()
                case .failed:
                    model.animePlayError = item.error?.localizedDescription ?? "播放失败"
                default:
                    break
                }
            }
            .store(in: &cancellables)

        newPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak newPlayer] status in
                guard newPlayer === player else { return }
                isPlaying = status == .playing
            }
            .store(in: &cancellables)

        if resume > 1 {
            newPlayer.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }
    }

    private func startProgressLoop() {
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                if let player, !isScrubbing {
                    let seconds = player.currentTime().seconds
                    if seconds.isFinite {
                        currentTime = max(0, seconds)
                    }
                    if let itemDuration = player.currentItem?.duration.seconds,
                       itemDuration.isFinite, itemDuration > 0 {
                        duration = itemDuration
                    }
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    private func teardown() {
        progressTask?.cancel()
        progressTask = nil
        hideControlsTask?.cancel()
        cancellables.removeAll()
        player?.pause()
        player = nil
    }

    private func playNextIfAvailable() {
        guard let season = model.animeSeason,
              let episodes = season.episodes,
              let current = model.animeSelectedEpisode,
              let index = episodes.firstIndex(where: { $0.epID == current.epID }),
              index + 1 < episodes.count else { return }
        let next = episodes[index + 1]
        currentTime = 0
        Task { await model.playAnime(next) }
    }

    private func controls(_ player: AVPlayer) -> some View {
        HStack(spacing: 9) {
            Button {
                togglePlayback(player)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(timeText(currentTime))
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 44, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(duration, 0.1),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubTime = currentTime
                        showControls = true
                        hideControlsTask?.cancel()
                    } else {
                        player.seek(to: CMTime(seconds: scrubTime, preferredTimescale: 600))
                        currentTime = scrubTime
                        isScrubbing = false
                        scheduleControlsHide()
                    }
                }
            )
            .controlSize(.mini)
            .tint(.white)
            .disabled(duration <= 0)

            Text(timeText(duration))
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 44, alignment: .leading)

            Button {
                isMuted.toggle()
                player.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let qualities = model.animePlayback?.qualities, qualities.count > 1 {
                Menu {
                    ForEach(qualities) { quality in
                        Button {
                            Task { await model.selectAnimeQuality(quality.qn) }
                        } label: {
                            if model.animeSelectedQN == quality.qn {
                                Label(quality.label, systemImage: "checkmark")
                            } else {
                                Text(quality.label)
                            }
                        }
                    }
                } label: {
                    Text(currentQualityLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            Button {
                isTheater.toggle()
            } label: {
                Image(systemName: isTheater ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isTheater ? "退出影院模式 (F)" : "影院模式 (F)")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onHover { hovering in
            if hovering {
                showControls = true
                hideControlsTask?.cancel()
            } else {
                scheduleControlsHide()
            }
        }
    }

    private var currentQualityLabel: String {
        if let qn = model.animeSelectedQN,
           let quality = model.animePlayback?.qualities?.first(where: { $0.qn == qn }) {
            return quality.label
        }
        return model.animePlayback?.quality?.label ?? "清晰度"
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func togglePlayback(_ player: AVPlayer) {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        showControls = true
        scheduleControlsHide()
    }

    private func seekBy(_ delta: Double) {
        guard let player else { return }
        let target = min(max(0, currentTime + delta), max(duration, 0))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        showControls = true
        scheduleControlsHide()
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled, isPlaying, !isScrubbing else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showControls = false
            }
        }
    }
}
