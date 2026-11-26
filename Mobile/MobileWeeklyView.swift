import SwiftUI

struct MobileWeeklyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await model.loadWeeklySeries()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("每周必看")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            Button {
                Task { await model.loadWeeklySeries(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingWeeklySeries)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = model.weeklySeriesError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadWeeklySeries(force: true) }
                    }
                }

                if model.isLoadingWeeklySeries && model.weeklySeries.isEmpty {
                    ProgressView()
                        .tint(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if model.weeklySeries.isEmpty {
                    if model.weeklySeriesError == nil {
                        MobileEmptyState(
                            icon: "calendar",
                            title: "暂无每周必看",
                            message: "稍后刷新试试"
                        )
                    }
                } else {
                    issuePicker

                    if let config = model.weeklyIssue?.config {
                        issueHeader(config)
                    }

                    if let error = model.weeklyIssueError {
                        MobileErrorBanner(text: error) {
                            if let number = model.selectedWeeklyNumber {
                                Task { await model.loadWeeklyIssue(number: number, force: true) }
                            }
                        }
                    }

                    if model.isLoadingWeeklyIssue && model.weeklyVideos.isEmpty {
                        ProgressView()
                            .tint(AppTheme.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                    } else if model.weeklyVideos.isEmpty {
                        if model.weeklyIssueError == nil {
                            MobileEmptyState(
                                icon: "film.stack",
                                title: "本期暂无视频",
                                message: "换一期看看吧"
                            )
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(model.weeklyVideos) { video in
                                MobileVideoLink(video: video) {
                                    MobileWeeklyCard(video: video)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadWeeklySeries(force: true)
        }
    }

    private var issuePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.weeklySeries) { series in
                    MobilePill(
                        title: "第\(series.number)期",
                        isSelected: model.selectedWeeklyNumber == series.number
                    ) {
                        Task { await model.selectWeekly(number: series.number) }
                    }
                }
            }
        }
    }

    private func issueHeader(_ config: WeeklyConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(config.name ?? "每周必看")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if let label = config.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(AppTheme.brand.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 0)
            }

            if let subject = config.subject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme).opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle = config.shareSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MobileWeeklyCard: View {
    let video: VideoItem

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RemoteImage(url: video.coverURL)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(6)
                    }
                }

            Text(video.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text(video.ownerName)
                    .lineLimit(1)
                if !video.viewText.isEmpty {
                    Text("· \(video.viewText)")
                        .lineLimit(1)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.secondary(scheme))
        }
        .contentShape(Rectangle())
    }
}
