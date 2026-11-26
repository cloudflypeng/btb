import SwiftUI
#if os(iOS)
import UIKit
#endif

enum BtbMotion {
    static let fast: Double = 0.16
    static let base: Double = 0.22
    static let slow: Double = 0.34

    // Strong ease-out; built-in .easeOut is too weak for UI feedback.
    static func curve(_ duration: Double = base) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
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
    var scale: CGFloat = 0.98
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
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(BtbMotion.curve(BtbMotion.fast), value: configuration.isPressed)
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

enum BtbDimens {
    static let radiusSmall: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let radiusPanel: CGFloat = 16
    static let radiusSheet: CGFloat = 20
    static let controlHeight: CGFloat = 32
}
