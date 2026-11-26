import SwiftUI

struct MobileDownloadView: View {
    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.colorScheme) private var scheme

    @State private var jobToRemove: DownloadJob?

    private var activeJobs: [DownloadJob] {
        model.downloadJobs.filter { !$0.isCompleted }
    }

    private var completedJobs: [DownloadJob] {
        model.downloadJobs.filter(\.isCompleted)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                summary

                if let error = model.downloadError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadDownloads(force: true) }
                    }
                }

                if model.isLoadingDownloads && model.downloadJobs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if model.downloadJobs.isEmpty {
                    emptyState
                } else {
                    if !activeJobs.isEmpty {
                        jobSection(title: "下载中", jobs: activeJobs)
                    }
                    if !completedJobs.isEmpty {
                        jobSection(title: "已完成", jobs: completedJobs)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("下载")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable {
            await model.loadDownloads(force: true)
        }
        .task {
            await model.loadDownloads()
        }
        .confirmationDialog(
            "删除这个下载？",
            isPresented: Binding(
                get: { jobToRemove != nil },
                set: { if !$0 { jobToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let job = jobToRemove {
                Button("删除", role: .destructive) {
                    Task { await model.removeDownload(job) }
                    jobToRemove = nil
                }
            }
            Button("取消", role: .cancel) { jobToRemove = nil }
        } message: {
            Text("已下载的文件会从本机删除。")
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            Image(systemName: "internaldrive")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
            Text(summaryText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
            Spacer()
            Button {
                Task { await model.loadDownloads(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(width: 30, height: 30)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingDownloads)
        }
    }

    private var summaryText: String {
        guard model.downloadDiskBytes > 0 else {
            return model.downloadJobs.isEmpty ? "下载后可离线观看" : "\(model.downloadJobs.count) 个任务"
        }
        if model.downloadJobs.isEmpty {
            return "可用空间 \(DownloadJob.byteText(model.downloadFreeBytes))"
        }
        return "已用 \(DownloadJob.byteText(model.downloadUsedBytes)) · 可用 \(DownloadJob.byteText(model.downloadFreeBytes))"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("还没有下载")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("在视频详情页点击「下载」，保存到本机后断网也能继续观看。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func jobSection(title: String, jobs: [DownloadJob]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(jobs.enumerated()), id: \.element.id) { index, job in
                    jobRow(job)
                    if index < jobs.count - 1 {
                        Divider()
                            .opacity(0.4)
                            .padding(.leading, 144)
                    }
                }
            }
        }
    }

    private func jobRow(_ job: DownloadJob) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                play(job)
            } label: {
                ZStack {
                    RemoteImage(url: job.coverURL)
                        .frame(width: 132, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    if job.isCompleted {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(radius: 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!job.isCompleted)

            VStack(alignment: .leading, spacing: 5) {
                Text(job.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)

                Text(jobSubtitle(job))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)

                if job.isDownloading || job.isPaused || job.isFailed {
                    MobileProgressBar(progress: job.progress, tint: job.isFailed ? .orange : AppTheme.brand)
                        .padding(.top, 2)
                    Text(job.downloadedText)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .lineLimit(1)
                }

                actionRow(job)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            contextMenu(job)
        }
    }

    private func jobSubtitle(_ job: DownloadJob) -> String {
        var parts: [String] = [job.statusText, job.qualityText]
        if job.isCompleted {
            parts.append(job.sizeText)
        }
        if let owner = job.owner, !owner.isEmpty {
            parts.append(owner)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func actionRow(_ job: DownloadJob) -> some View {
        HStack(spacing: 8) {
            if job.isCompleted {
                actionButton("播放", icon: "play.fill") { play(job) }
            } else if job.isPaused || job.isFailed {
                actionButton("继续", icon: "play.fill") {
                    Task { await model.resumeDownload(job) }
                }
            } else if job.isDownloading {
                actionButton("暂停", icon: "pause.fill") {
                    Task { await model.pauseDownload(job) }
                }
            }
            actionButton("删除", icon: "trash") {
                jobToRemove = job
            }
            if model.downloadActionIDs.contains(job.id) {
                ProgressView().controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .disabled(model.downloadActionIDs.contains(job.id))
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(AppTheme.text(scheme))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(AppTheme.chip(scheme), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenu(_ job: DownloadJob) -> some View {
        if job.isCompleted {
            Button("播放") { play(job) }
        } else if job.isPaused || job.isFailed {
            Button("继续下载") { Task { await model.resumeDownload(job) } }
        } else if job.isDownloading {
            Button("暂停下载") { Task { await model.pauseDownload(job) } }
        }
        Button("删除下载", role: .destructive) { jobToRemove = job }
    }

    private func play(_ job: DownloadJob) {
        guard job.isCompleted else { return }
        router.open(job.videoItem)
    }
}

struct MobileProgressBar: View {
    let progress: Double
    var tint: Color = AppTheme.brand
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.chip(scheme))
                Capsule()
                    .fill(tint)
                    .frame(width: max(3, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}
