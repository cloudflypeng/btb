import AppKit
import SwiftUI

struct GlassSurface<Content: View>: View {
    let shape: AnyShape
    let tint: Color?
    let content: Content

    init(
        shape: AnyShape = AnyShape(Capsule()),
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.shape = shape
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                }
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        if let tint {
            return .regular.tint(tint)
        }
        return .regular
    }
}

struct AppMark: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .fill(AppTheme.brand)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: size * 0.36, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
    }
}

struct ChromeIconButton: View {
    let systemName: String
    var help: String = ""
    var isActive = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? AppTheme.text(scheme) : AppTheme.secondary(scheme))
                .frame(width: 38, height: 38)
                .background(
                    isHovering ? AppTheme.hover(scheme) : Color.clear,
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

struct ActionPill: View {
    let systemName: String
    let title: String
    var countText: String?
    var isActive = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
                if let countText {
                    Text(countText)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isActive ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                isActive ? AppTheme.selected(scheme) : AppTheme.chip(scheme),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(
                    isSelected ? AppTheme.selected(scheme) : AppTheme.chip(scheme),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SurfaceCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
