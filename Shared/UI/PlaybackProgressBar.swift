import SwiftUI

/// Thin resume indicator pinned to the bottom edge of a cover (B4).
/// Drawn only when the video has been opened before and is not finished.
struct PlaybackProgressBar: View {
    let fraction: Double
    var height: CGFloat = 2.5

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.black.opacity(0.28))
                Rectangle()
                    .fill(AppTheme.brand)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                    .animation(reduceMotion ? nil : BtbMotion.smooth, value: fraction)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Adds the local resume bar to a cover. No-op for videos never opened.
    func resumeProgress(for bvid: String, cornerRadius: CGFloat = 0) -> some View {
        modifier(ResumeProgressOverlay(bvid: bvid, cornerRadius: cornerRadius))
    }
}

private struct ResumeProgressOverlay: ViewModifier {
    let bvid: String
    let cornerRadius: CGFloat

    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            let fraction = model.playbackProgress.fraction(for: bvid)
            if fraction > 0 {
                PlaybackProgressBar(fraction: fraction)
                    .clipShape(
                        .rect(
                            bottomLeadingRadius: cornerRadius,
                            bottomTrailingRadius: cornerRadius
                        )
                    )
            }
        }
    }
}
