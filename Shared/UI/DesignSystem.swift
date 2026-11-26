import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Three springs, and nothing else (C2).
///
/// - `snappy` — feedback that follows the finger: presses, toggles, control bars.
/// - `smooth` — content arriving or layout shifting: fades, expansions, page changes.
/// - `bouncy` — an occasional deliberate overshoot, for a moment worth noticing.
enum BtbMotion {
    static var snappy: Animation { resolve(.spring(response: 0.3, dampingFraction: 0.85)) }
    static var smooth: Animation { resolve(.spring(response: 0.45, dampingFraction: 1.0)) }
    static var bouncy: Animation { resolve(.spring(response: 0.5, dampingFraction: 0.7)) }

    static let fast: Double = 0.16
    static let base: Double = 0.22
    static let slow: Double = 0.34

    /// Honours the system "reduce motion" setting: movement becomes a plain fade.
    static var reduceMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    static func resolve(_ animation: Animation) -> Animation {
        reduceMotion ? .linear(duration: 0.14) : animation
    }

    // Kept for cross-fades where a spring reads as wobble rather than weight.
    static func curve(_ duration: Double = base) -> Animation {
        resolve(.timingCurve(0.23, 1, 0.32, 1, duration: duration))
    }

    static func animation(_ duration: Double = base, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : curve(duration)
    }
}

enum BtbHaptics {
    #if os(iOS)
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    #else
    static func tap() {}
    #endif
}

struct BtbPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var haptic: Bool = true
    /// Runs once when the finger lands, before the tap resolves. Used to start
    /// network work a tap will need (playback prewarm).
    var onPressDown: (() -> Void)?

    func makeBody(configuration: Configuration) -> some View {
        BtbPressableBody(
            configuration: configuration,
            scale: scale,
            haptic: haptic,
            onPressDown: onPressDown
        )
    }
}

private struct BtbPressableBody: View {
    let configuration: ButtonStyleConfiguration
    let scale: CGFloat
    let haptic: Bool
    var onPressDown: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var firedPressDown = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .brightness(configuration.isPressed ? 0.07 : 0)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(BtbMotion.snappy, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                pressed && haptic
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                guard let onPressDown else { return }
                if pressed {
                    guard !firedPressDown else { return }
                    firedPressDown = true
                    onPressDown()
                } else {
                    firedPressDown = false
                }
            }
    }
}

/// C6: a card fades and rises into place the first time it appears, offset by
/// 30 ms per position so a fresh list settles as a wave rather than a snap.
private struct StaggeredEntrance: ViewModifier {
    let index: Int

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                let delay = min(Double(index) * 0.03, 0.36)
                withAnimation(BtbMotion.smooth.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func staggeredEntrance(_ index: Int) -> some View {
        modifier(StaggeredEntrance(index: index))
    }
}

enum BtbDimens {
    static let radiusSmall: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let radiusPanel: CGFloat = 16
    static let radiusSheet: CGFloat = 20
    static let controlHeight: CGFloat = 32
}
