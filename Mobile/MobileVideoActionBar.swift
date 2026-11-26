import SwiftUI

/// Fixed action bar pinned directly under the video. It never scrolls with the
/// detail content, so like / coin / favorite stay one thumb-reach away.
struct MobileVideoActionBar: View {
    let video: VideoItem
    let detail: VideoInfoData?

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    /// Relation as first reported by the server, used to derive live counts
    /// (server count + local delta) without waiting for a refetch.
    @State private var baseline: VideoRelationData?
    @State private var isTriplePressing = false
    @State private var tripleTick = 0

    private let downloadQualities = [127, 126, 125, 120, 116, 112, 80, 74, 64, 32, 16]

    var body: some View {
        HStack(spacing: 0) {
            likeButton
            coinMenu
            favoriteMenu
            watchLaterButton
            downloadAction
            ShareLink(item: video.pageURL) {
                ActionCell(icon: "arrowshape.turn.up.right", label: shareLabel)
            }
            .buttonStyle(BtbPressableStyle(scale: 0.9))
        }
        .padding(.horizontal, 6)
        .frame(height: 58)
        .background(AppTheme.background(scheme))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.divider(scheme)).frame(height: 0.5)
        }
        .sensoryFeedback(.success, trigger: tripleTick)
        // C4: quiet confirmation for the actions that change server state.
        .sensoryFeedback(.success, trigger: coined) { _, new in new > 0 }
        .sensoryFeedback(.success, trigger: favorited) { _, new in new }
        .sensoryFeedback(.selection, trigger: model.watchLaterVideos.contains(video.bvid)) { _, saved in saved }
        .onChange(of: model.relation == nil) { _, isNil in
            if !isNil, baseline == nil { baseline = model.relation }
        }
        .onAppear {
            if baseline == nil { baseline = model.relation }
        }
        .task {
            if model.hasAccount, model.favoriteFolders.isEmpty {
                await model.loadPlaylists()
            }
        }
    }

    // MARK: - Like (tap) / Triple (long press)

    private var liked: Bool { model.relation?.like == true }

    private var likeButton: some View {
        ActionCell(
            icon: liked ? "hand.thumbsup.fill" : "hand.thumbsup",
            label: countLabel(stat?.like ?? video.likeCount, delta: delta(\.like), fallback: "点赞"),
            isActive: liked,
            progress: isTriplePressing ? 1 : 0
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await model.toggleLike() }
        }
        .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 24) {
            isTriplePressing = false
            tripleTick += 1
            Task { await model.tripleVideo() }
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: 0.6) : .spring(duration: 0.25)) {
                isTriplePressing = pressing
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: liked)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("长按一键三连")
    }

    // MARK: - Coin

    private var coined: Int { model.relation?.coin ?? 0 }

    private var coinMenu: some View {
        Menu {
            Button("投 1 枚硬币") { Task { await model.addCoin(multiply: 1) } }
            Button("投 2 枚硬币") { Task { await model.addCoin(multiply: 2) } }
                .disabled(coined >= 2)
        } label: {
            ActionCell(
                icon: coined > 0 ? "bitcoinsign.circle.fill" : "bitcoinsign.circle",
                label: countLabel(stat?.coin ?? 0, delta: coined - (baseline?.coin ?? 0), fallback: "投币"),
                isActive: coined > 0
            )
        }
        .disabled(coined >= 2)
        .buttonStyle(BtbPressableStyle(scale: 0.9))
    }

    // MARK: - Favorite

    private var favorited: Bool { model.relation?.favorite == true }

    private var favoriteMenu: some View {
        Menu {
            if !model.hasAccount {
                Button("登录后收藏") { model.presentLogin() }
            } else if model.favoriteFolders.isEmpty {
                Button("加载收藏夹…") { Task { await model.loadPlaylists(force: true) } }
            } else {
                Section("收藏到") {
                    ForEach(model.favoriteFolders) { folder in
                        Button(folder.title) {
                            Task { await model.addToFavorite(folderID: folder.id) }
                        }
                    }
                }
            }
        } label: {
            ActionCell(
                icon: favorited ? "star.fill" : "star",
                label: countLabel(stat?.favorite ?? 0, delta: delta(\.favorite), fallback: "收藏"),
                isActive: favorited
            )
        }
        .buttonStyle(BtbPressableStyle(scale: 0.9))
    }

    // MARK: - Watch later

    private var isSaved: Bool { model.watchLaterVideos.contains(video.bvid) }

    private var watchLaterButton: some View {
        Button {
            Task { await model.addToWatchLater() }
        } label: {
            ActionCell(
                icon: isSaved ? "clock.fill" : "clock",
                label: isSaved ? "已添加" : "稍后看",
                isActive: isSaved
            )
        }
        .buttonStyle(BtbPressableStyle(scale: 0.9))
    }

    // MARK: - Download

    @ViewBuilder
    private var downloadAction: some View {
        if let job = model.downloadJob(for: video) {
            Button {
                Task { await handleDownloadTap(job) }
            } label: {
                ActionCell(
                    icon: downloadIcon(job),
                    label: downloadLabel(job),
                    isActive: job.isCompleted
                )
            }
            .buttonStyle(BtbPressableStyle(scale: 0.9))
        } else {
            Menu {
                Section("下载清晰度") {
                    ForEach(downloadQualities, id: \.self) { qn in
                        Button(DownloadJob.qualityLabel(qn)) {
                            Task { await model.startDownload(for: video, detail: detail, qn: Int64(qn)) }
                        }
                    }
                }
            } label: {
                ActionCell(icon: "arrow.down.circle", label: "缓存")
            }
            .buttonStyle(BtbPressableStyle(scale: 0.9))
        }
    }

    private func downloadLabel(_ job: DownloadJob) -> String {
        if job.isCompleted { return "已缓存" }
        if job.isPaused { return "已暂停" }
        if job.isFailed { return "重试" }
        return "\(Int(job.progress * 100))%"
    }

    private func downloadIcon(_ job: DownloadJob) -> String {
        if job.isCompleted { return "checkmark.circle.fill" }
        if job.isPaused || job.isFailed { return "arrow.clockwise.circle" }
        return "pause.circle"
    }

    private func handleDownloadTap(_ job: DownloadJob) async {
        if job.isCompleted {
            model.showToast("已缓存，可在「我的 · 下载」离线观看")
        } else if job.isDownloading {
            await model.pauseDownload(job)
        } else {
            await model.resumeDownload(job)
        }
    }

    // MARK: - Helpers

    private var stat: VideoStatInfo? { detail?.stat }

    private var shareLabel: String {
        let count = stat?.share ?? 0
        return count > 0 ? MobileFormat.count(count) : "分享"
    }

    private func delta(_ keyPath: KeyPath<VideoRelationData, Bool?>) -> Int {
        let now = model.relation?[keyPath: keyPath] == true ? 1 : 0
        let before = baseline?[keyPath: keyPath] == true ? 1 : 0
        return now - before
    }

    private func countLabel(_ base: Int, delta: Int, fallback: String) -> String {
        let value = max(0, base + delta)
        return value > 0 ? MobileFormat.count(value) : fallback
    }
}

private struct ActionCell: View {
    let icon: String
    let label: String
    var isActive = false
    /// 0...1 ring drawn around the icon while a long-press is building up.
    var progress: CGFloat = 0

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .symbolEffect(.bounce, value: isActive)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 26)
                .overlay {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 34, height: 34)
                        .opacity(progress > 0 ? 1 : 0)
                }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .foregroundStyle(isActive ? AppTheme.brand : AppTheme.secondary(scheme))
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .contentShape(Rectangle())
        .animation(BtbMotion.snappy, value: label)
        .animation(BtbMotion.snappy, value: isActive)
    }
}
