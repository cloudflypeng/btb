import AppKit
import SwiftUI

struct VideoThumbnail: View {
    let url: URL?
    var durationText: String = ""
    var cornerRadius: CGFloat = 12
    var transitionID: String? = nil

    @Environment(\.colorScheme) private var scheme
    @Environment(PlayerTransitionController.self) private var transition

    var body: some View {
        thumbnailContent
            .background {
                if transitionID != nil {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { report(proxy) }
                            .onChange(of: proxy.frame(in: .named("appRoot"))) { _, _ in
                                report(proxy)
                            }
                    }
                }
            }
    }

    private func report(_ proxy: GeometryProxy) {
        guard let transitionID else { return }
        transition.registerSourceFrame(
            proxy.frame(in: .named("appRoot")),
            for: transitionID
        )
    }

    private var thumbnailContent: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                ZStack {
                    Rectangle()
                        .fill(AppTheme.surface(scheme))
                    RemoteImage(url: url)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !durationText.isEmpty {
                    Text(durationText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct VideoCard: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VideoThumbnail(url: video.coverURL, durationText: video.durationText, transitionID: video.bvid)
                .overlay {
                    if isHovering {
                        ZStack {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.26)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            Image(systemName: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.black.opacity(0.52), in: Circle())
                        }
                        .transition(.opacity)
                    }
                }
                .animation(BtbMotion.snappy, value: isHovering)

            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: video.ownerFaceURL, size: 36)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineSpacing(1.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(video.ownerName)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)

                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("播放") {
                model.openVideo(video)
            }
            Button("在浏览器中打开") {
                NSWorkspace.shared.open(video.pageURL)
            }
            Button("复制链接") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(video.pageURL.absoluteString, forType: .string)
            }
        }
    }

    private var metadata: String {
        var parts: [String] = []
        if video.viewCount > 0 {
            parts.append("\(video.viewText)次观看")
        }
        if !video.publishedAgoText.isEmpty {
            parts.append(video.publishedAgoText)
        }
        return parts.joined(separator: " · ")
    }
}

struct VideoCardSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            HStack(alignment: .top, spacing: 12) {
                SkeletonCircle(size: 36)
                VStack(alignment: .leading, spacing: 7) {
                    SkeletonBar(height: 14)
                    SkeletonBar(width: 160, height: 11)
                    SkeletonBar(width: 210, height: 11)
                }
            }
        }
        .skeletonPulse()
    }
}

struct SearchResultRow: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VideoThumbnail(url: video.coverURL, durationText: video.durationText, transitionID: video.bvid)
                .frame(width: 320)
                .overlay {
                    if isHovering {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black.opacity(0.16))
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                    }
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(video.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(metadata)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    AvatarView(url: video.ownerFaceURL, size: 24)
                    Text(video.ownerName)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
                .padding(.top, 2)

                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 3)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            isHovering ? AppTheme.hover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("播放") {
                model.openVideo(video)
            }
            Button("在浏览器中打开") {
                NSWorkspace.shared.open(video.pageURL)
            }
            Button("复制链接") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(video.pageURL.absoluteString, forType: .string)
            }
        }
    }

    private var metadata: String {
        var parts: [String] = []
        if video.viewCount > 0 {
            parts.append("\(video.viewText)次观看")
        }
        if !video.publishedAgoText.isEmpty {
            parts.append(video.publishedAgoText)
        }
        return parts.joined(separator: " · ")
    }
}

struct RankingRow: View {
    let video: VideoItem
    let rank: Int

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? AppTheme.brand : AppTheme.secondary(scheme))
                .frame(width: 34, alignment: .trailing)

            VideoThumbnail(url: video.coverURL, durationText: video.durationText, transitionID: video.bvid)
                .frame(width: 196)

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(video.ownerName)
                    Text("·")
                    Text(video.viewText)
                    Text("次播放")
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))

                if !video.publishedAgoText.isEmpty {
                    Text(video.publishedAgoText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            isHovering ? AppTheme.hover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

struct HistoryRow: View {
    let video: VideoItem

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            VideoThumbnail(
                url: video.coverURL,
                durationText: video.durationText,
                cornerRadius: 9,
                transitionID: video.bvid
            )
                .frame(width: 168)

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                Text(video.ownerName)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                if let publishedAt = video.publishedAt {
                    Text("观看于 \(publishedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(10)
        .background(
            isHovering ? AppTheme.hover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
