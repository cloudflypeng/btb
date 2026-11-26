import SwiftUI

struct AppMark: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let image = Self.appIcon {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(AppTheme.brand)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: size * 0.38, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: size * 0.02)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }

    private static let appIcon: UIImage? = {
        if let url = Bundle.main.url(forResource: "AppMark", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: "AppMark")
    }()
}

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        BtbAvatar(url: url, size: size)
    }
}

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        BtbRemoteImage(
            url: url,
            contentMode: contentMode,
            placeholderIcon: "play.rectangle",
            showsLoadingIndicator: true
        )
    }
}

typealias InfiniteScrollFooter = BtbInfiniteScrollFooter

struct MobileErrorBanner: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        BtbNoticeBanner(text: text, kind: .warning, retry: retry)
    }
}

struct MobileSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        BtbSectionHeader(title: title, actionTitle: actionTitle, action: action)
    }
}

struct MobileEmptyState: View {
    let icon: String
    let title: String
    var message: String?

    var body: some View {
        BtbStateView(
            icon: icon,
            title: title,
            message: message,
            iconSize: 32,
            verticalPadding: 80
        )
    }
}

struct MobilePill: View {
    let title: String
    let isSelected: Bool
    var badge: String?
    let action: () -> Void

    var body: some View {
        BtbPill(title: title, isSelected: isSelected, badge: badge, action: action)
    }
}

enum MobileFormat {
    static func count(_ count: Int) -> String {
        let value = Double(count)
        if value >= 100_000_000 {
            return String(format: "%.1f亿", value / 100_000_000)
        }
        if value >= 10_000 {
            return String(format: "%.1f万", value / 10_000)
        }
        return "\(count)"
    }

    static func seconds(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
