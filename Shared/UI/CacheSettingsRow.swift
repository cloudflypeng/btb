import SwiftUI

/// Settings row: shows image + feed cache size and clears it.
struct BtbCacheSettingsRow: View {
    @Environment(\.colorScheme) private var scheme
    @State private var bytes: Int?
    @State private var isClearing = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("图片缓存")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("封面与头像缓存，上限 200 MB，超出后自动清理最旧的文件。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                Task { await clear() }
            } label: {
                Text(isClearing ? "清理中…" : "清除 \(sizeText)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .buttonStyle(.bordered)
            .disabled(isClearing || bytes == 0)
        }
        .padding(14)
        .task { await refresh() }
    }

    private var sizeText: String {
        guard let bytes else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func refresh() async {
        let value = await Task.detached(priority: .utility) {
            BtbImagePipeline.trimDisk()
            return BtbImagePipeline.diskUsageBytes()
        }.value
        withAnimation(BtbMotion.smooth) { bytes = value }
    }

    private func clear() async {
        isClearing = true
        BtbImageCache.shared.clearMemory()
        await Task.detached(priority: .utility) {
            BtbImagePipeline.clearDisk()
            FeedCache.clear()
        }.value
        isClearing = false
        await refresh()
    }
}
