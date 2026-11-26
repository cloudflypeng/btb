import SwiftUI

struct SkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat
    var fill: Color?

    @Environment(\.colorScheme) private var scheme

    init(width: CGFloat? = nil, height: CGFloat, fill: Color? = nil) {
        self.width = width
        self.height = height
        self.fill = fill
    }

    var body: some View {
        Group {
            if let width {
                shape.frame(width: width, height: height)
            } else {
                shape.frame(maxWidth: .infinity).frame(height: height)
            }
        }
        .accessibilityHidden(true)
    }

    private var shape: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(fill ?? AppTheme.surface(scheme))
    }
}

struct SkeletonCircle: View {
    let size: CGFloat

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Circle()
            .fill(AppTheme.surface(scheme))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct SkeletonCapsule: View {
    let width: CGFloat
    var height: CGFloat = 36

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Capsule()
            .fill(AppTheme.surface(scheme))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct SkeletonPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.45 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear {
                pulsing = !reduceMotion
            }
            .onChange(of: reduceMotion) { _, reduced in
                pulsing = !reduced
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func skeletonPulse() -> some View {
        modifier(SkeletonPulse())
    }
}
