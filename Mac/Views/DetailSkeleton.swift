import SwiftUI

struct DetailContentSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBar(height: 22)
                SkeletonBar(width: 320, height: 22)
            }

            HStack(spacing: 12) {
                SkeletonCircle(size: 42)

                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBar(width: 130, height: 12)
                    SkeletonBar(width: 58, height: 10)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    SkeletonCapsule(width: 86)
                    SkeletonCapsule(width: 112)
                    SkeletonCapsule(width: 86)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(width: 170, height: 12, fill: AppTheme.surfaceHover(scheme))
                SkeletonBar(height: 10, fill: AppTheme.surfaceHover(scheme))
                SkeletonBar(height: 10, fill: AppTheme.surfaceHover(scheme))
                SkeletonBar(width: 260, height: 10, fill: AppTheme.surfaceHover(scheme))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 14) {
                SkeletonBar(width: 120, height: 18)

                ForEach(0..<3, id: \.self) { _ in
                    CommentRowSkeleton()
                }
            }
            .padding(.top, 10)
        }
        .skeletonPulse()
    }

    @Environment(\.colorScheme) private var scheme
}

struct DetailSkeletonRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBar(width: 100, height: 16)

            ForEach(0..<5, id: \.self) { _ in
                RelatedVideoSkeleton()
            }
        }
        .accessibilityHidden(true)
    }
}

struct TransitionSkeletonView: View {
    let playerFrame: CGRect

    @Environment(PlayerTransitionController.self) private var transition

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 1120

            ZStack(alignment: .topLeading) {
                if transition.isHeroVisible {
                    Color.black

                    VStack(alignment: .leading, spacing: 24) {
                        if isWide {
                            HStack(alignment: .top, spacing: 24) {
                                mainColumn
                                DetailSkeletonRail()
                                    .frame(width: 342)
                            }
                        } else {
                            mainColumn
                            DetailSkeletonRail()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                    .frame(maxWidth: 1600, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .opacity(transition.backdropOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Color.clear
                .frame(height: playerFrame.height)

            DetailContentSkeleton()
        }
        .frame(width: playerFrame.width, alignment: .leading)
    }
}

private struct CommentRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SkeletonCircle(size: 36)

            VStack(alignment: .leading, spacing: 7) {
                SkeletonBar(width: 110, height: 11)
                SkeletonBar(height: 10)
                SkeletonBar(height: 10)
                SkeletonBar(width: 240, height: 10)
            }
        }
    }
}
