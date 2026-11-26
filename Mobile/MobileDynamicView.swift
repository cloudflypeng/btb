import SwiftUI

struct MobileDynamicView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedCard: DynamicCard?
    @State private var selectedUP: MobileUPRoute?
    @State private var selectedAnime: MobileAnimeRoute?
    @State private var selectedLive: LiveRoom?

    var body: some View {
        VStack(spacing: 0) {
            header
            feedTypeBar
            Divider().opacity(0.5)
            feed
        }
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedCard) { card in
            MobileDynamicDetailView(card: card)
        }
        .navigationDestination(item: $selectedUP) { route in
            MobileUPView(route: route)
        }
        .navigationDestination(item: $selectedAnime) { route in
            MobileAnimeSeasonView(seasonID: route.seasonID)
        }
        .navigationDestination(item: $selectedLive) { room in
            MobileLiveRoomView(room: room)
        }
        .task {
            if !model.dynamicLoaded || model.dynamicCards.isEmpty {
                await model.loadDynamicFeed(reset: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("动态")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            Button {
                Task { await model.loadDynamicFeed(reset: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingDynamic || !model.hasAccount)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var feedTypeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DynamicFeedType.allCases) { type in
                    MobilePill(title: type.title, isSelected: model.dynamicFeedType == type) {
                        guard model.dynamicFeedType != type else { return }
                        Task { await model.setDynamicFeedType(type) }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var feed: some View {
        ScrollView {
            if !model.hasAccount {
                loginState
            } else if model.isLoadingDynamic && model.dynamicCards.isEmpty {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        MobileDynamicSkeleton()
                    }
                }
                .padding(14)
            } else if let error = model.dynamicError, model.dynamicCards.isEmpty {
                MobileErrorBanner(text: error) {
                    Task { await model.loadDynamicFeed(reset: true) }
                }
                .padding(14)
            } else if model.dynamicCards.isEmpty {
                Text("还没有动态")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(model.dynamicCards) { card in
                        let isVideoPost = card.attachment.video != nil
                        MobileDynamicCardView(card: card, edgeToEdge: isVideoPost) {
                            selectedCard = card
                        } onOpenUP: { author in
                            guard let mid = author.mid else { return }
                            selectedUP = MobileUPRoute(mid: mid, name: author.name, avatarURL: author.avatarURL)
                        } onOpenPGC: { seasonID in
                            selectedAnime = MobileAnimeRoute(seasonID: seasonID)
                        } onOpenLive: { live in
                            selectedLive = LiveRoom(
                                roomID: live.roomID,
                                coverURL: live.coverURL,
                                title: live.title,
                                areaName: live.areaName
                            )
                        }
                        .padding(.horizontal, isVideoPost ? 0 : 14)
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingDynamic,
                        hasMore: model.dynamicHasMore,
                        failed: model.dynamicError != nil
                    ) {
                        Task { await model.loadMoreDynamic() }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 14)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadDynamicFeed(reset: true)
        }
    }

    private var loginState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("登录后查看关注动态")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Button {
                model.presentLogin()
            } label: {
                Text("登录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.selectedText(scheme))
                    .padding(.horizontal, 24)
                    .frame(height: 36)
                    .background(AppTheme.selected(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

struct MobileDynamicCardView: View {
    let card: DynamicCard
    var isDetail = false
    var edgeToEdge = false
    var onOpen: (() -> Void)?
    var onOpenUP: ((DynamicAuthor) -> Void)?
    var onOpenPGC: ((Int64) -> Void)?
    var onOpenLive: ((DynamicLiveAttachment) -> Void)?
    var onOpenImage: (([DynamicPicture], Int) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .padding(.horizontal, edgeToEdge ? 14 : 0)

            if !card.text.isEmpty {
                Text(card.text)
                    .font(.system(size: isDetail ? 14.5 : 14))
                    .lineSpacing(4)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(isDetail ? nil : 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, edgeToEdge ? 14 : 0)
            }

            attachment(card.attachment)

            if let orig = card.orig {
                quote(orig)
                    .padding(.horizontal, edgeToEdge ? 14 : 0)
            }

            actionBar
                .padding(.horizontal, edgeToEdge ? 14 : 0)
        }
        .padding(.horizontal, edgeToEdge ? 0 : 14)
        .padding(.vertical, edgeToEdge ? 8 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if edgeToEdge {
                Color.clear
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface(scheme))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen?()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                authorTap?()
            } label: {
                AvatarView(url: card.author.avatarURL, size: isDetail ? 42 : 38)
            }
            .buttonStyle(.plain)
            .disabled(authorTap == nil)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button {
                        authorTap?()
                    } label: {
                        Text(card.author.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .disabled(authorTap == nil)
                    if card.author.isTop {
                        Text("置顶")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if !card.author.pubAction.isEmpty {
                        Text(card.author.pubAction)
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    Text(card.author.pubTime)
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                .font(.system(size: 11))
            }

            Spacer(minLength: 8)

            ShareLink(item: webURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var webURL: URL {
        URL(string: "https://t.bilibili.com/\(card.id)") ?? URL(string: "https://t.bilibili.com")!
    }

    private var authorTap: (() -> Void)? {
        if let pgc = card.attachment.pgc,
           let seasonID = Int64(pgc.seasonID),
           let onOpenPGC {
            return { onOpenPGC(seasonID) }
        }
        guard let onOpenUP, card.author.mid != nil else { return nil }
        return { onOpenUP(card.author) }
    }

    @ViewBuilder
    private func attachment(_ attachment: DynamicAttachment) -> some View {
        if let video = attachment.video {
            if edgeToEdge {
                MobileFeedCard(video: VideoItem(
                    dynamicVideo: video,
                    ownerName: card.author.name,
                    ownerFaceURL: card.author.avatarURL,
                    ownerMid: card.author.mid
                ))
            } else {
                videoCard(video)
            }
        } else if !attachment.pictures.isEmpty {
            MobileDynamicImageGrid(pictures: attachment.pictures, onSelect: onOpenImage)
                .padding(.horizontal, edgeToEdge ? 14 : 0)
        } else if let pgc = attachment.pgc {
            Group {
                if let onOpenPGC, let seasonID = Int64(pgc.seasonID) {
                    Button {
                        onOpenPGC(seasonID)
                    } label: {
                        mediaCard(
                            cover: pgc.coverURL,
                            badge: pgc.badge,
                            title: pgc.title.isEmpty ? "番剧" : pgc.title,
                            subtitle: "番剧",
                            wide: false
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    mediaCard(
                        cover: pgc.coverURL,
                        badge: pgc.badge,
                        title: pgc.title.isEmpty ? "番剧" : pgc.title,
                        subtitle: "番剧",
                        wide: false
                    )
                }
            }
            .padding(.horizontal, edgeToEdge ? 14 : 0)
        } else if let live = attachment.live {
            Group {
                if let onOpenLive {
                    Button {
                        onOpenLive(live)
                    } label: {
                        mediaCard(
                            cover: live.coverURL,
                            badge: "直播中",
                            title: live.title,
                            subtitle: live.areaName,
                            wide: false
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    mediaCard(
                        cover: live.coverURL,
                        badge: "直播中",
                        title: live.title,
                        subtitle: live.areaName,
                        wide: false
                    )
                }
            }
            .padding(.horizontal, edgeToEdge ? 14 : 0)
        } else if let article = attachment.article {
            mediaCard(
                cover: article.coverURL,
                badge: "专栏",
                title: article.title,
                subtitle: article.summary,
                wide: false
            )
            .padding(.horizontal, edgeToEdge ? 14 : 0)
        }
    }

    private func videoCard(_ video: DynamicVideoAttachment) -> some View {
        Button {
            router.open(VideoItem(
                dynamicVideo: video,
                ownerName: card.author.name,
                ownerFaceURL: card.author.avatarURL,
                ownerMid: card.author.mid
            ))
        } label: {
            HStack(alignment: .top, spacing: 10) {
                RemoteImage(url: video.coverURL)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(width: isDetail ? 150 : 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if !video.durationText.isEmpty {
                            Text(video.durationText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3))
                                .padding(5)
                        }
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title.isEmpty ? "视频" : video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !video.desc.isEmpty {
                        Text(video.desc)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        if !video.playText.isEmpty {
                            Label(video.playText, systemImage: "play.rectangle")
                        }
                        Text(card.author.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func mediaCard(cover: URL?, badge: String, title: String, subtitle: String, wide: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(url: cover)
                .frame(width: 84, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(AppTheme.chip(scheme))

            VStack(alignment: .leading, spacing: 6) {
                if !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func quote(_ orig: DynamicOriginal) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                AvatarView(url: orig.author.avatarURL, size: 20)
                Text(orig.author.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                if !orig.author.pubTime.isEmpty {
                    Text(orig.author.pubTime)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }

            if !orig.text.isEmpty {
                Text(orig.text)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let video = orig.attachment.video {
                Button {
                    router.open(VideoItem(
                        dynamicVideo: video,
                        ownerName: orig.author.name,
                        ownerFaceURL: orig.author.avatarURL,
                        ownerMid: orig.author.mid
                    ))
                } label: {
                    HStack(spacing: 8) {
                        RemoteImage(url: video.coverURL)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .frame(width: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.text(scheme))
                                .lineLimit(2)
                            if !video.playText.isEmpty {
                                Text("\(video.playText) 播放")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(AppTheme.tertiary(scheme))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            } else if !orig.attachment.pictures.isEmpty {
                MobileDynamicImageGrid(pictures: orig.attachment.pictures, onSelect: onOpenImage)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionBar: some View {
        HStack(spacing: 22) {
            Button {
                Task { await model.toggleDynamicLike(card) }
            } label: {
                Label(
                    card.likeCount > 0 ? MobileFormat.count(card.likeCount) : "点赞",
                    systemImage: card.isLiked ? "heart.fill" : "heart"
                )
                .foregroundStyle(card.isLiked ? AppTheme.brand : AppTheme.secondary(scheme))
            }
            .buttonStyle(.plain)

            Label(
                card.commentCount > 0 ? MobileFormat.count(card.commentCount) : "评论",
                systemImage: "text.bubble"
            )
            .foregroundStyle(AppTheme.secondary(scheme))

            if card.forwardCount > 0 {
                Label(MobileFormat.count(card.forwardCount), systemImage: "arrowshape.turn.up.right")
                    .foregroundStyle(AppTheme.secondary(scheme))
            }

            Spacer(minLength: 0)
        }
        .font(.system(size: 12.5, weight: .medium))
    }
}

private struct MobileDynamicImageGrid: View {
    let pictures: [DynamicPicture]
    var onSelect: (([DynamicPicture], Int) -> Void)? = nil

    var body: some View {
        if pictures.count == 1, let picture = pictures.first {
            tile(picture, index: 0)
                .aspectRatio(aspectRatio(picture), contentMode: .fit)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(pictures.count, 3)),
                spacing: 4
            ) {
                ForEach(Array(pictures.enumerated()), id: \.element.id) { index, picture in
                    tile(picture, index: index)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ picture: DynamicPicture, index: Int) -> some View {
        if let onSelect {
            Button {
                onSelect(pictures, index)
            } label: {
                RemoteImage(url: picture.url)
            }
            .buttonStyle(.plain)
        } else {
            RemoteImage(url: picture.url)
        }
    }

    private func aspectRatio(_ picture: DynamicPicture) -> CGFloat {
        guard picture.width > 0, picture.height > 0 else { return 16.0 / 9.0 }
        return CGFloat(picture.width) / CGFloat(picture.height)
    }
}

struct MobileDynamicDetailView: View {
    let card: DynamicCard

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    @State private var imageViewer: DynamicImageViewerSelection?
    @State private var selectedUP: MobileUPRoute?
    @State private var selectedAnime: MobileAnimeRoute?
    @State private var selectedLive: LiveRoom?
    @FocusState private var isComposerFocused: Bool

    private var liveCard: DynamicCard {
        if let active = model.activeDynamic, active.id == card.id { return active }
        return model.dynamicCards.first { $0.id == card.id } ?? card
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MobileDynamicCardView(
                    card: liveCard,
                    isDetail: true,
                    onOpenUP: { author in
                        guard let mid = author.mid else { return }
                        selectedUP = MobileUPRoute(mid: mid, name: author.name, avatarURL: author.avatarURL)
                    },
                    onOpenPGC: { seasonID in
                        selectedAnime = MobileAnimeRoute(seasonID: seasonID)
                    },
                    onOpenLive: { live in
                        selectedLive = LiveRoom(
                            roomID: live.roomID,
                            coverURL: live.coverURL,
                            title: live.title,
                            areaName: live.areaName
                        )
                    },
                    onOpenImage: { pictures, index in
                        imageViewer = DynamicImageViewerSelection(pictures: pictures, index: index)
                    }
                )

                comments
            }
            .padding(14)
            .padding(.bottom, 70)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .fullScreenCover(item: $imageViewer) { selection in
            DynamicImageViewer(selection: selection)
        }
        .navigationDestination(item: $selectedUP) { route in
            MobileUPView(route: route)
        }
        .navigationDestination(item: $selectedAnime) { route in
            MobileAnimeSeasonView(seasonID: route.seasonID)
        }
        .navigationDestination(item: $selectedLive) { room in
            MobileLiveRoomView(room: room)
        }
        .task(id: card.id) {
            model.openDynamic(card)
            await model.loadDynamicComments(for: card, reset: true)
        }
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("评论")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if model.dynamicCommentTotal > 0 {
                    Text(MobileFormat.count(model.dynamicCommentTotal))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }

            if liveCard.commentType <= 0 {
                Text("该动态暂不支持评论")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            } else if model.isLoadingDynamicComments && model.dynamicComments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if model.dynamicComments.isEmpty {
                Text(model.dynamicCommentsError ?? (model.hasAccount ? "还没有评论" : "登录后查看评论"))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(model.dynamicComments) { comment in
                        commentRow(comment)
                    }
                    if model.dynamicComments.count < model.dynamicCommentTotal {
                        InfiniteScrollFooter(
                            isLoading: model.isLoadingDynamicComments,
                            hasMore: true,
                            failed: model.dynamicCommentsError != nil
                        ) {
                            Task { await model.loadDynamicComments(for: liveCard) }
                        }
                    }
                }
            }
        }
    }

    private func commentRow(_ comment: VideoComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: comment.avatarURL, size: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(comment.author)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    if !comment.timeText.isEmpty {
                        Text(comment.timeText)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }
                    Spacer(minLength: 6)
                    Button {
                        Task { await model.toggleDynamicCommentLike(comment, card: liveCard) }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            if comment.likeCount > 0 {
                                Text(MobileFormat.count(comment.likeCount))
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(comment.isLiked ? AppTheme.brand : AppTheme.tertiary(scheme))
                    }
                    .buttonStyle(.plain)
                }

                Text(comment.message)
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                if !comment.replies.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(comment.replies.prefix(2)) { reply in
                            Text("\(reply.author)：\(reply.message)")
                                .font(.system(size: 12.5))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .lineLimit(3)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("发一条友善的评论", text: $draft, axis: .vertical)
                .focused($isComposerFocused)
                .font(.system(size: 13.5))
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                let text = draft
                draft = ""
                isComposerFocused = false
                Task { _ = await model.postDynamicComment(text, card: liveCard) }
            } label: {
                if model.isPostingDynamicComment {
                    ProgressView().controlSize(.small)
                        .frame(width: 34, height: 34)
                } else {
                    Text("发送")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(AppTheme.brand, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isPostingDynamicComment)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private struct MobileDynamicSkeleton: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.chip(scheme))
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(AppTheme.chip(scheme)).frame(width: 110, height: 10)
                    Capsule().fill(AppTheme.chip(scheme)).frame(width: 70, height: 8)
                }
                Spacer()
            }
            Capsule().fill(AppTheme.chip(scheme)).frame(height: 10)
            Capsule().fill(AppTheme.chip(scheme)).frame(height: 10)
            Capsule().fill(AppTheme.chip(scheme)).frame(width: 200, height: 10)
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.chip(scheme))
                .frame(height: 120)
        }
        .padding(14)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DynamicImageViewerSelection: Identifiable {
    let id = UUID()
    let pictures: [DynamicPicture]
    let index: Int
}

private struct DynamicImageViewer: View {
    let selection: DynamicImageViewerSelection

    @Environment(\.dismiss) private var dismiss
    @State private var current: Int
    @State private var dragOffset: CGFloat = 0

    init(selection: DynamicImageViewerSelection) {
        self.selection = selection
        _current = State(initialValue: selection.index)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(Array(selection.pictures.enumerated()), id: \.element.id) { index, picture in
                    AsyncImage(url: picture.url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.white.opacity(0.5))
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .scaleEffect(dragOffset > 0 ? max(0.85, 1 - dragOffset / 900) : 1)

            VStack {
                HStack {
                    if selection.pictures.count > 1 {
                        Text("\(current + 1) / \(selection.pictures.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .statusBarHidden(true)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}
