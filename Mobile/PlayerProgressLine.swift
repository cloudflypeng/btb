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
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard playback.duration > 0 else { return }
                        if !playback.isScrubbing {
                            playback.isScrubbing = true
                        }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        playback.scrubTime = Double(x / max(geo.size.width, 1)) * playback.duration
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
