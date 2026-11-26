import SwiftUI

enum BtbNoticeKind {
    case info
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info: return AppTheme.accent
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct BtbNoticeBanner: View {
    let text: String
    var kind: BtbNoticeKind = .warning
    var retryTitle: String? = "重试"
    var retry: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 13))
                .foregroundStyle(kind.tint)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
                .lineLimit(3)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            if let retry, let retryTitle {
                Button(retryTitle, action: retry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                    .buttonStyle(.plain)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(kind.tint.opacity(0.24), lineWidth: 0.5)
        }
    }
}

struct BtbStateView: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var iconSize: CGFloat = 38
    var verticalPadding: CGFloat = 56

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.vertical, verticalPadding)
        .multilineTextAlignment(.center)
    }
}
