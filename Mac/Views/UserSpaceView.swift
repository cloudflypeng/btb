import AppKit
import SwiftUI

struct UserSpaceView: View {
    let mid: Int64

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var isBlockConfirmPresented = false

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                if let error = model.upError {
                    ErrorBanner(text: error) {
                        Task { await model.loadUP(mid: mid) }
                    }
                }

                content

                if !model.upVideos.isEmpty {
                    InfiniteScrollFooter(
                        isLoading: model.isLoadingUP || model.upPager.isLoadingMore,
                        hasMore: model.upPager.hasMore,
                        failed: model.upPager.failed
                    ) {
                        Task { await model.loadMoreUP() }
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
        .task(id: mid) {
            await model.loadUP(mid: mid)
        }
        .confirmationDialog(
            "拉黑「\(model.activeUP?.name ?? "该用户")」？",
            isPresented: $isBlockConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("拉黑", role: .destructive) {
                Task { await model.setUPBlocked(true) }
            }
        } message: {
            Text("拉黑后你们将无法互相关注、评论或发送消息。")
        }
    }

    @ViewBuilder
    private var header: some View {
        if let up = model.activeUP {
            VStack(alignment: .leading, spacing: 14) {
                banner(for: up)

                HStack(alignment: .top, spacing: 16) {
                    AvatarView(url: up.avatarURL, size: 84)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(up.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.text(scheme))
                                .lineLimit(1)

                            if up.isBlocked {
                                Text("已拉黑")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 7)
                                    .frame(height: 18)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                            }
                        }

                        if !up.sign.isEmpty {
                            Text(up.sign)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .lineLimit(2)
                        }

                        Text(metadata(for: up))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.open(up.spaceURL)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.text(scheme))
                                .frame(width: 36, height: 36)
                                .background(AppTheme.chip(scheme), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("在浏览器中打开")

                        Button {
                            Task { await model.toggleUPFollow() }
                        } label: {
                            Text(up.isFollowed ? "已关注" : "关注")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(up.isFollowed ? AppTheme.text(scheme) : .white)
                                .padding(.horizontal, 18)
                                .frame(height: 36)
                                .background(
                                    up.isFollowed ? AppTheme.chip(scheme) : AppTheme.brand,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isUpFollowBusy)

                        Menu {
                            if up.isBlocked {
                                Button("解除拉黑") {
                                    Task { await model.setUPBlocked(false) }
                                }
                            } else {
                                Button("拉黑该 UP 主", role: .destructive) {
                                    isBlockConfirmPresented = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .frame(width: 36, height: 36)
                                .background(AppTheme.chip(scheme), in: Circle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("更多操作")
                    }
                }
            }
            .padding(18)
            .background(
                AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        } else {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载 UP 主…")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    private func banner(for up: UPProfile) -> some View {
        ZStack {
            if let url = up.topPhotoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        bannerGradient
                    }
                }
            } else {
                bannerGradient
            }
        }
        .frame(height: 128)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var bannerGradient: some View {
        AppTheme.surface(scheme)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingUP && model.upVideos.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                ForEach(0..<8, id: \.self) { _ in
                    VideoCardSkeleton()
                }
            }
            .allowsHitTesting(false)
        } else if model.upVideos.isEmpty {
            EmptyHint(
                icon: "video",
                title: "还没有投稿",
                message: "这个 UP 主暂时没有可展示的视频。"
            )
            .padding(.top, 40)
        } else {
            HStack {
                Text("投稿")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                ForEach(model.upVideos) { video in
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

    private func metadata(for up: UPProfile) -> String {
        var parts: [String] = []
        if up.follower > 0 {
            parts.append("\(formatCount(up.follower)) 粉丝")
        }
        if up.following > 0 {
            parts.append("\(up.following) 关注")
        }
        if up.archiveCount > 0 {
            parts.append("\(up.archiveCount) 投稿")
        }
        if up.level > 0 {
            parts.append("Lv\(up.level)")
        }
        return parts.joined(separator: " · ")
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }
}
