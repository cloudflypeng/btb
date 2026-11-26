import AppKit
import SwiftUI

struct DownloadView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 460), spacing: 16, alignment: .top)
    ]

    private var activeJobs: [DownloadJob] {
        model.downloadJobs.filter { !$0.isCompleted }
    }

    private var completedJobs: [DownloadJob] {
        model.downloadJobs.filter(\.isCompleted)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                if let error = model.downloadError {
                    ErrorBanner(text: error) {
                        Task { await model.loadDownloads(force: true) }
                    }
                }

                if model.isLoadingDownloads && model.downloadJobs.isEmpty {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(0..<4, id: \.self) { _ in
                            DownloadSkeletonCard()
                        }
                    }
                    .allowsHitTesting(false)
                } else if model.downloadJobs.isEmpty {
                    EmptyHint(
                        icon: "arrow.down.circle",
                        title: "还没有下载",
                        message: "在视频详情页点击「下载」，保存到本机后断网也能继续观看。"
                    )
                    .padding(.top, 40)
                } else {
                    if !activeJobs.isEmpty {
                        section(title: "下载中", jobs: activeJobs)
                    }
                    if !completedJobs.isEmpty {
                        section(title: "已完成", jobs: completedJobs)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 48)
            .frame(maxWidth: 1600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .overlay(alignment: .bottom) {
            toast
        }
        .animation(.easeOut(duration: 0.2), value: model.toastMessage)
        .task {
            await model.loadDownloads()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("下载")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }

            Spacer(minLength: 12)

            Button {
                Task { await model.loadDownloads(force: true) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("刷新")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(AppTheme.surface(scheme), in: Capsule())
                .overlay(Capsule().stroke(AppTheme.divider(scheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingDownloads)
            .help("刷新下载列表")
        }
    }

    private var subtitle: String {
        guard model.downloadDiskBytes > 0 else {
            return model.downloadJobs.isEmpty ? "离线观看" : "\(model.downloadJobs.count) 个任务"
        }
        if model.downloadJobs.isEmpty {
            return "可用空间 \(DownloadJob.byteText(model.downloadFreeBytes))"
        }
        return "已用 \(DownloadJob.byteText(model.downloadUsedBytes)) · 可用 \(DownloadJob.byteText(model.downloadFreeBytes))"
    }

    private func section(title: String, jobs: [DownloadJob]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("\(jobs.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(AppTheme.chip(scheme), in: Capsule())
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(jobs) { job in
                    DownloadCard(job: job)
                }
            }
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toastMessage {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.black.opacity(0.82), in: Capsule())
                .padding(.bottom, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private struct DownloadCard: View {
    let job: DownloadJob

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isRemovePresented = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            VStack(alignment: .leading, spacing: 8) {
                Text(job.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(job.statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text("·")
                        .foregroundStyle(AppTheme.tertiary(scheme))
                    Text(job.qualityText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Spacer(minLength: 4)
                    Text(job.sizeText)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }

                if job.isDownloading || job.isPaused || job.isFailed {
                    VStack(alignment: .leading, spacing: 5) {
                        progressBar
                        HStack(spacing: 6) {
                            Text(job.downloadedText)
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundStyle(AppTheme.tertiary(scheme))
                            Spacer(minLength: 4)
                            if let owner = job.owner, !owner.isEmpty {
                                Text(owner)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(AppTheme.tertiary(scheme))
                                    .lineLimit(1)
                            }
                        }
                    }
                } else if let owner = job.owner, !owner.isEmpty {
                    Text(owner)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .lineLimit(1)
                }

                actions
            }
            .padding(12)
        }
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovering ? AppTheme.divider(scheme) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .contextMenu {
            if job.isCompleted {
                Button("播放") { model.openDownload(job) }
                Button("在浏览器中打开") {
                    NSWorkspace.shared.open(pageURL)
                }
                Divider()
            }
            if job.isDownloading {
                Button("暂停下载") { Task { await model.pauseDownload(job) } }
            }
            if job.isPaused || job.isFailed {
                Button("继续下载") { Task { await model.resumeDownload(job) } }
            }
            Button("删除下载", role: .destructive) { isRemovePresented = true }
        }
        .confirmationDialog(
            "删除「\(job.title)」的下载？",
            isPresented: $isRemovePresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await model.removeDownload(job) }
            }
        } message: {
            Text("将同时删除本地文件，释放 \(job.sizeText) 空间。")
        }
    }

    private var cover: some View {
        Button {
            if job.isCompleted {
                model.openDownload(job)
            }
        } label: {
            ZStack {
                AppTheme.chip(scheme)
                RemoteImage(url: job.coverURL)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                if job.isCompleted {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(isHovering ? 0.95 : 0))
                        .shadow(color: .black.opacity(0.35), radius: 8)
                }
                VStack {
                    HStack {
                        statusBadge
                        Spacer()
                        if let duration = job.durationText.nonEmpty {
                            Text(duration)
                                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(.black.opacity(0.62), in: Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(height: 148)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12,
                style: .continuous
            )
        )
    }

    private var statusBadge: some View {
        Text(badgeText)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(badgeColor.opacity(0.9), in: Capsule())
    }

    private var badgeText: String {
        switch job.status {
        case "completed": return "已完成"
        case "paused": return "已暂停"
        case "failed": return "失败"
        default: return "下载中"
        }
    }

    private var badgeColor: Color {
        switch job.status {
        case "completed": return .green
        case "paused": return .orange
        case "failed": return .red
        default: return AppTheme.brand
        }
    }

    private var statusColor: Color {
        switch job.status {
        case "completed": return .green
        case "paused": return .orange
        case "failed": return .red
        default: return AppTheme.brand
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.chip(scheme))
                Capsule()
                    .fill(statusColor)
                    .frame(width: max(3, geo.size.width * job.progress))
            }
        }
        .frame(height: 4)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if job.isCompleted {
                Button {
                    model.openDownload(job)
                } label: {
                    actionLabel("播放", systemName: "play.fill", prominent: true)
                }
                .buttonStyle(.plain)
            } else if job.isDownloading {
                Button {
                    Task { await model.pauseDownload(job) }
                } label: {
                    actionLabel("暂停", systemName: "pause.fill", prominent: false)
                }
                .buttonStyle(.plain)
                .disabled(model.downloadActionIDs.contains(job.id))
            } else {
                Button {
                    Task { await model.resumeDownload(job) }
                } label: {
                    actionLabel(job.isFailed ? "重试" : "继续", systemName: "play.fill", prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(model.downloadActionIDs.contains(job.id))
            }

            Spacer(minLength: 4)

            Menu {
                if job.isCompleted {
                    Button("在浏览器中打开") {
                        NSWorkspace.shared.open(pageURL)
                    }
                }
                if job.isDownloading {
                    Button("暂停下载") { Task { await model.pauseDownload(job) } }
                }
                if job.isPaused || job.isFailed {
                    Button("继续下载") { Task { await model.resumeDownload(job) } }
                }
                Divider()
                Button("删除下载", role: .destructive) { isRemovePresented = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 30, height: 28)
                    .background(AppTheme.chip(scheme), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func actionLabel(_ title: String, systemName: String, prominent: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(prominent ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            prominent ? AppTheme.selected(scheme) : AppTheme.chip(scheme),
            in: Capsule()
        )
    }

    private var pageURL: URL {
        URL(string: "https://www.bilibili.com/video/\(job.bvid)")!
    }
}

private struct DownloadSkeletonCard: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppTheme.chip(scheme))
                .frame(height: 148)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.chip(scheme))
                    .frame(height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.chip(scheme))
                    .frame(width: 120, height: 10)
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.chip(scheme))
                    .frame(height: 4)
            }
            .padding(12)
        }
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct DownloadDetailView: View {
    let job: DownloadJob

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isTheater = false
    @State private var source: LocalPlaybackSource?
    @State private var loadError: String?
    @State private var isPreparing = true
    @State private var isRemovePresented = false

    var body: some View {
        GeometryReader { proxy in
            let theaterSize = isTheater ? theaterPlayerSize(in: proxy.size) : nil

            ScrollView {
                VStack(alignment: .leading, spacing: isTheater ? 0 : 20) {
                    player(theaterSize: theaterSize)
                    if !isTheater {
                        infoCard
                    }
                }
                .padding(.horizontal, isTheater ? 0 : 24)
                .padding(.top, isTheater ? 0 : 16)
                .padding(.bottom, isTheater ? 0 : 48)
                .frame(maxWidth: isTheater ? CGFloat.infinity : 1600, alignment: isTheater ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isTheater)
        }
        .background(isTheater ? Color.black : AppTheme.background(scheme))
        .toolbar(isTheater ? .hidden : .visible, for: .windowToolbar)
        .task(id: job.id) {
            await prepare()
        }
        .overlay(alignment: .bottom) {
            toast
        }
        .animation(.easeOut(duration: 0.2), value: model.toastMessage)
        .confirmationDialog(
            "删除「\(job.title)」的下载？",
            isPresented: $isRemovePresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await model.removeDownload(job) }
            }
        } message: {
            Text("将同时删除本地文件，释放 \(job.sizeText) 空间。")
        }
    }

    @ViewBuilder
    private func player(theaterSize: CGSize?) -> some View {
        if let source {
            InlinePlayerView(video: job.videoItem, local: source, isTheater: $isTheater)
                .id(job.id)
                .frame(width: theaterSize?.width, height: theaterSize?.height)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if isPreparing {
            ZStack {
                Color.black
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在准备离线播放…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(width: theaterSize?.width, height: theaterSize?.height)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: isTheater ? 0 : 12, style: .continuous))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.orange)
                Text(loadError ?? "无法播放该下载")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Button("重试") {
                    Task { await prepare() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(job.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("已完成")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Color.green, in: Capsule())
                if let owner = job.owner, !owner.isEmpty {
                    Text(owner)
                }
                Text("·")
                Text(job.qualityText)
                if let duration = job.durationText.nonEmpty {
                    Text("·")
                    Text(duration)
                }
                Text("·")
                Text(job.sizeText)
            }
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.secondary(scheme))

            if let error = job.error, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            Divider()
                .overlay(AppTheme.divider(scheme))

            HStack(spacing: 10) {
                Label("已保存到本机，断网也能播放", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))

                Spacer(minLength: 12)

                Button("在浏览器中打开") {
                    NSWorkspace.shared.open(pageURL)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.text(scheme))

                Button {
                    isRemovePresented = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("删除下载")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(AppTheme.surface(scheme), in: Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pageURL: URL {
        URL(string: "https://www.bilibili.com/video/\(job.bvid)")!
    }

    private func prepare() async {
        guard job.isCompleted else {
            isPreparing = false
            loadError = "下载尚未完成"
            return
        }
        isPreparing = true
        loadError = nil
        if let url = await model.downloadPlaybackURL(for: job) {
            source = LocalPlaybackSource(masterURL: url, durationMS: job.durationMS)
        } else {
            source = nil
            loadError = "离线播放列表不可用，请返回下载页重试"
        }
        isPreparing = false
    }

    private func theaterPlayerSize(in size: CGSize) -> CGSize {
        let width = max(1, size.width)
        let fittedHeight = width * 9 / 16
        if fittedHeight <= size.height {
            return CGSize(width: width, height: fittedHeight)
        }
        let height = max(1, size.height)
        return CGSize(width: height * 16 / 9, height: height)
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toastMessage {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.black.opacity(0.82), in: Capsule())
                .padding(.bottom, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
