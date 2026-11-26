import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum AppTheme {
    static let brand = Color(hex: 0xFF0033)
    static let accent = Color(hex: 0x3EA6FF)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0F0F0F) : Color(hex: 0xFFFFFF)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x212121) : Color(hex: 0xF2F2F2)
    }

    static func surfaceHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x303030) : Color(hex: 0xE5E5E5)
    }

    static func chip(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x272727) : Color(hex: 0xF2F2F2)
    }

    static func selected(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: 0x0F0F0F)
    }

    static func selectedText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0F0F0F) : Color.white
    }

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: 0x0F0F0F)
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xAAAAAA) : Color(hex: 0x606060)
    }

    static func tertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x717171) : Color(hex: 0x909090)
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    static func hover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    static func field(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x121212) : Color(hex: 0xFFFFFF)
    }
}
