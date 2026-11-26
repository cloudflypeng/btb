import SwiftUI

struct MobileRankingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

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
            await model.loadDiscoverRanking()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("排行榜")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            if !model.discoverRanking.isEmpty {
                Text("\(model.discoverRanking.count) 个视频")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer()
            Button {
                Task { await model.loadDiscoverRanking(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingDiscoverRanking)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if let error = model.discoverRankingError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadDiscoverRanking(force: true) }
                    }
                    .padding(.bottom, 6)
                }

                if model.isLoadingDiscoverRanking && model.discoverRanking.isEmpty {
                    ProgressView()
                        .tint(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if model.discoverRanking.isEmpty {
                    if model.discoverRankingError == nil {
                        MobileEmptyState(
                            icon: "chart.bar.xaxis",
                            title: "暂无排行榜",
                            message: "稍后刷新试试"
                        )
                    }
                } else {
                    ForEach(Array(model.discoverRanking.enumerated()), id: \.element.id) { index, video in
                        MobileVideoLink(video: video) {
                            MobileRankingRow(video: video, rank: index + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadDiscoverRanking(force: true)
        }
    }
}

private struct MobileRankingRow: View {
    let video: VideoItem
    let rank: Int

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? AppTheme.brand : AppTheme.tertiary(scheme))
                .frame(width: 27, alignment: .leading)

            RemoteImage(url: video.coverURL)
                .frame(width: 118, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(5)
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text(video.ownerName)
                        .lineLimit(1)
                    if !video.viewText.isEmpty {
                        Text("· \(video.viewText)观看")
                            .lineLimit(1)
                    }
                    if !video.publishedAgoText.isEmpty {
                        Text("· \(video.publishedAgoText)")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.secondary(scheme))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
