import AppKit
import SwiftUI

typealias RemoteImage = BtbRemoteImage
typealias InfiniteScrollFooter = BtbInfiniteScrollFooter

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 32

    var body: some View {
        BtbAvatar(url: url, size: size)
    }
}

struct ErrorBanner: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        BtbNoticeBanner(text: text, kind: .warning, retry: retry)
    }
}

struct CoreFailureView: View {
    let message: String
    let retry: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            BtbStateView(
                icon: "exclamationmark.circle",
                title: "服务启动失败",
                message: "请检查数据目录权限或可用空间，然后重试。",
                actionTitle: "重试",
                action: retry,
                iconSize: 52,
                verticalPadding: 0
            )
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.tertiary(scheme))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(AppTheme.background(scheme))
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        BtbSectionHeader(title: title, systemImage: icon)
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        BtbStateView(
            icon: icon,
            title: title,
            message: message,
            iconSize: 40,
            verticalPadding: 16
        )
    }
}
