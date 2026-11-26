import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

/// D1: the gesture layer over the video.
///
/// - tap: show / hide the controls
/// - double tap: play / pause
/// - horizontal drag: scrub, with the target time in a HUD
/// - vertical drag on the left half: screen brightness; right half: volume
/// - long press: 2× speed while held
/// - pinch in / out: switch between fit and fill
struct PlayerGestureOverlay: View {
    let playback: MobilePlaybackController
    @Binding var showControls: Bool
    @Binding var isFill: Bool
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void
    /// Portrait: the picture itself is the way out — drag it down, the page
    /// follows the finger and closes past the threshold. Landscape keeps the
    /// vertical drags for brightness and volume, so fullscreen leaves through
    /// a horizontal swipe from the left edge instead.
    var allowsDismissDrag = false
    /// Landscape only: a swipe starting at the left edge closes the player.
    var allowsEdgeDismiss = false
    @Binding var dismissOffset: CGFloat
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: DragMode = .none
    @State private var startValue: Double = 0
    @State private var hud: HUD?
    @State private var hudTask: Task<Void, Never>?
    @State private var isBoosting = false
    @State private var boostStartTime: Double = 0
    @State private var restoreRate: Double = 1
    @State private var boostTask: Task<Void, Never>?

    private enum DragMode: Equatable {
        case none, seek, brightness, volume, dismiss, edgeDismiss
    }

    private struct HUD: Equatable {
        let icon: String
        let text: String
        var detail: String? = nil
    }

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2)
                        .onEnded { onDoubleTap() }
                        .exclusively(before: TapGesture().onEnded { onSingleTap() })
                )
                .simultaneousGesture(drag(in: geo.size))
                .simultaneousGesture(magnify)
                .onLongPressGesture(minimumDuration: 0.8, maximumDistance: 14) {
                } onPressingChanged: { pressing in
                    handleBoostPressing(pressing)
                }
        }
        .overlay {
            if let hud {
                hudView(hud)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(BtbMotion.snappy, value: hud)
    }

    // MARK: - Drag

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                guard playback.isReady, !isBoosting else { return }
                if mode == .none {
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    if horizontal {
                        // Fullscreen has no pull-down to leave; the left edge
                        // is the back gesture there, and it must win over the
                        // seek drag it would otherwise start.
                        if allowsEdgeDismiss,
                           value.startLocation.x <= Self.edgeDismissZone,
                           value.translation.width > 0 {
                            mode = .edgeDismiss
                            showControls = false
                            hud = HUD(icon: "chevron.left", text: "松手退出")
                        } else {
                            mode = .seek
                            startValue = playback.currentTime
                            playback.isScrubbing = true
                            showControls = true
                        }
                    } else if allowsDismissDrag {
                        // Pull down on the picture to leave the page, as the
                        // player page has no chrome of its own any more.
                        mode = .dismiss
                    } else {
                        let leftHalf = value.startLocation.x < size.width / 2
                        mode = leftHalf ? .brightness : .volume
                        startValue = leftHalf
                            ? Double(UIScreen.main.brightness)
                            : Double(SystemVolume.shared.value)
                    }
                }
                switch mode {
                case .seek:
                    let span = max(playback.duration, 1)
                    let delta = Double(value.translation.width / max(size.width, 1)) * span
                    let target = min(max(startValue + delta, 0), span)
                    playback.scrubTime = target
                    hud = HUD(icon: "timeline.selection", text: Self.timeText(target), detail: Self.timeText(span))
                case .brightness:
                    let level = min(max(startValue + Double(value.translation.height) / -300, 0.02), 1)
                    UIScreen.main.brightness = CGFloat(level)
                    hud = HUD(icon: "sun.max.fill", text: "\(Int(level * 100))%")
                case .volume:
                    let level = min(max(startValue + Double(value.translation.height) / -300, 0), 1)
                    SystemVolume.shared.set(Float(level))
                    hud = HUD(icon: level == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", text: "\(Int(level * 100))%")
                case .dismiss:
                    // Rubber-bands above the top, never drags up past it.
                    let pull = max(value.translation.height, 0)
                    dismissOffset = pull
                case .edgeDismiss:
                    // No page slide in landscape: the picture fills the
                    // screen, so only the hint follows the finger.
                    let progress = min(max(value.translation.width / Self.edgeDismissDistance, 0), 1)
                    hud = HUD(
                        icon: "chevron.left",
                        text: progress >= 1 ? "松手退出" : "继续右滑退出"
                    )
                case .none:
                    break
                }
            }
            .onEnded { value in
                switch mode {
                case .seek:
                    playback.finishScrub()
                    scheduleHUDHide()
                case .brightness, .volume:
                    scheduleHUDHide()
                case .dismiss:
                    let pull = max(value.translation.height, 0)
                    let projected = max(value.predictedEndTranslation.height, pull)
                    if pull > 110 || projected > 240 {
                        withAnimation(.easeIn(duration: 0.18)) { dismissOffset = 1_000 }
                        onDismiss()
                    } else {
                        withAnimation(reduceMotion ? nil : BtbMotion.snappy) { dismissOffset = 0 }
                    }
                case .edgeDismiss:
                    let travelled = max(
                        value.translation.width,
                        value.predictedEndTranslation.width
                    )
                    hud = nil
                    if travelled > Self.edgeDismissDistance {
                        onDismiss()
                    }
                case .none:
                    break
                }
                mode = .none
            }
    }

    /// How wide a strip along the left edge starts the back swipe, and how far
    /// it has to travel before the release counts.
    private static let edgeDismissZone: CGFloat = 28
    private static let edgeDismissDistance: CGFloat = 90

    // MARK: - Long press (2× while held)

    /// A real 2× hold starts only after the finger has been still for 0.8s
    /// (long enough that a slow vertical swipe for volume never trips it),
    /// and always ends on release, so a drag can never leave it stuck on.
    private func handleBoostPressing(_ pressing: Bool) {
        if pressing {
            boostTask?.cancel()
            boostTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                startBoost()
            }
        } else {
            boostTask?.cancel()
            boostTask = nil
            endBoost()
        }
    }

    private func startBoost() {
        guard !isBoosting, playback.isReady, playback.isPlaying, !playback.isScrubbing else { return }
        isBoosting = true
        boostStartTime = playback.currentTime
        restoreRate = playback.playbackRate
        playback.playbackRate = max(2.0, restoreRate)
        hud = HUD(icon: "forward.fill", text: "\(String(format: "%.1f", playback.playbackRate))× 快进中")
        showControls = false
    }

    private func endBoost() {
        guard isBoosting else { return }
        isBoosting = false
        playback.playbackRate = restoreRate
        hud = nil
    }

    // MARK: - Pinch (fit / fill)

    private var magnify: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                guard playback.isReady else { return }
                let shouldFill = value.magnification > 1.05 ? true
                    : (value.magnification < 0.95 ? false : !isFill)
                withAnimation(reduceMotion ? nil : BtbMotion.snappy) { isFill = shouldFill }
            }
    }

    // MARK: - HUD

    private func hudView(_ hud: HUD) -> some View {
        VStack(spacing: 6) {
            Image(systemName: hud.icon)
                .font(.system(size: 22, weight: .semibold))
            HStack(spacing: 4) {
                Text(hud.text)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                if let detail = hud.detail {
                    Text("/ \(detail)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func scheduleHUDHide() {
        hudTask?.cancel()
        hudTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            hud = nil
        }
    }

    /// Called by the canvas when the finger lifts after a 2× hold.
    static func timeText(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

/// Sets the system output volume through the hidden `MPVolumeView` slider;
/// `AVAudioSession.outputVolume` is read-only.
@MainActor
final class SystemVolume {
    static let shared = SystemVolume()

    private let slider: UISlider?

    private init() {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        slider = view.subviews.compactMap { $0 as? UISlider }.first
    }

    var value: Float { AVAudioSession.sharedInstance().outputVolume }

    func set(_ value: Float) {
        slider?.value = min(max(value, 0), 1)
    }
}
