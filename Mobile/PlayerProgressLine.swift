import SwiftUI

/// #6: the hairline progress bar pinned under the video.
///
/// It carries the whole seeking job — drag anywhere along it — so the control
/// bar inside the picture is free for the other functions.
struct PlayerProgressLine: View {
    let playback: MobilePlaybackController

    @Environment(\.colorScheme) private var scheme

    private var fraction: Double {
        guard playback.duration > 0 else { return 0 }
        let seconds = playback.isScrubbing ? playback.scrubTime : playback.currentTime
        return min(max(seconds / playback.duration, 0), 1)
    }

    private var chapters: [PlaybackChapter] {
        playback.duration > 0 ? playback.resolved?.chapterList ?? [] : []
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppTheme.divider(scheme))
                Rectangle()
                    .fill(AppTheme.brand)
                    .frame(width: geo.size.width * fraction)
            }
            .frame(height: 3)
            // D2: chapter starts, so a long video shows where its sections
            // begin while the bar is being dragged.
            .overlay(alignment: .leading) {
                ForEach(chapters) { chapter in
                    if chapter.from > 0, chapter.from < playback.duration {
                        Rectangle()
                            .fill(.black.opacity(0.45))
                            .frame(width: 1)
                            .offset(x: geo.size.width * chapter.from / playback.duration)
                    }
                }
            }
            // Flush with the video above it: the whole 16pt strip is touch
            // area, but the visible line sits on its top edge (no gap).
            .frame(maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard playback.duration > 0 else { return }
                        if !playback.isScrubbing {
                            playback.isScrubbing = true
                        }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        let ratio = Double(x / max(geo.size.width, 1))
                        playback.scrubTime = ratio * playback.duration
                    }
                    .onEnded { _ in
                        playback.finishScrub()
                    }
            )
        }
        .frame(height: 16)
        .background(AppTheme.background(scheme))
        // C4: the thumb lands where the picture does.
        .sensoryFeedback(.impact(weight: .light), trigger: playback.isScrubbing)
        .accessibilityLabel("播放进度")
    }
}

/// D2: the frame under the finger while the scrub bar is being dragged.
///
/// It lives inside the player canvas rather than in the progress line: the
/// video is a UIKit layer, and anything drawn over it from a sibling view can
/// slip behind it as soon as the canvas redraws mid-scrub.
struct ScrubPreview: View {
    let playback: MobilePlaybackController
    var thumbnails: VideoThumbnails?

    private let cardWidth: CGFloat = 152
    private let gap: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let image = thumbnails?.image(at: playback.scrubTime)
            let chapter = chapterTitle
            let labelHeight = chapter == nil ? 18.0 : 32.0
            let height = cardHeight(image, labelHeight: labelHeight)
            let fraction = playback.duration > 0
                ? min(max(playback.scrubTime / playback.duration, 0), 1)
                : 0
            let center = min(
                max(geo.size.width * CGFloat(fraction), cardWidth / 2),
                max(geo.size.width - cardWidth / 2, cardWidth / 2)
            )
            card(image: image, height: height, labelHeight: labelHeight, chapter: chapter)
                .frame(width: cardWidth, height: height)
                .position(x: center, y: max(geo.size.height - height / 2 - gap, height / 2))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The chapter the finger is over, when the uploader marked any.
    private var chapterTitle: String? {
        guard playback.duration > 0 else { return nil }
        return playback.resolved?.chapterList.first { chapter in
            playback.scrubTime >= chapter.from && playback.scrubTime < chapter.to
        }?.title
    }

    private func cardHeight(_ image: CGImage?, labelHeight: CGFloat) -> CGFloat {
        let aspect = image.map { CGFloat($0.height) / CGFloat(max($0.width, 1)) } ?? (9.0 / 16.0)
        return cardWidth * aspect + labelHeight
    }

    private func card(image: CGImage?, height: CGFloat, labelHeight: CGFloat, chapter: String?) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(white: 0.18)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: cardWidth, height: height - labelHeight)
            .clipped()
            VStack(spacing: 1) {
                if let chapter {
                    Text(chapter)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                Text(timeLabel(playback.scrubTime))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: labelHeight)
            .background(.black.opacity(0.72))
        }
        .frame(width: cardWidth)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
    }

    private func timeLabel(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
