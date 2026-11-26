import SwiftUI

/// The cast picker: the TV list the core discovers, and the one action that
/// matters once something is playing — bringing it back to the phone.
struct MobileCastSheet: View {
    let video: VideoItem
    let playback: MobilePlaybackController
    let cast: MobileCastController
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)

            if let target = cast.target {
                connected(target)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            } else {
                deviceList
                    .padding(.top, 12)
            }

            if let error = cast.error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background(scheme))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            if cast.target == nil {
                await cast.discover()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("投屏")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            if cast.target == nil {
                Button {
                    Task { await cast.discover() }
                } label: {
                    if cast.isDiscovering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }
                .buttonStyle(.plain)
                .disabled(cast.isDiscovering)
                .accessibilityLabel("重新搜索")
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 30, height: 30)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
    }

    private func connected(_ target: MobileCastController.Target) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(target.isDirect
                 ? "电视正在直接从 B 站拉流，关掉手机也能继续播放"
                 : "电视通过这台手机取流，回到桌面后请保持 App 在后台运行")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))

            HStack(spacing: 14) {
                Image(systemName: "tv.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("正在投屏到 \(target.device.name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)
                    Text(target.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.brand.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                Task {
                    await cast.stop(playback: playback)
                }
            } label: {
                Text(cast.isBusy ? "正在停止…" : "停止投屏")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(cast.isBusy)
        }
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择一台电视或投影设备")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
                .padding(.horizontal, 20)

            if cast.devices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cast.isDiscovering ? "正在搜索附近的设备…" : "没有找到设备")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text("确认电视已开机、和手机连着同一个 WiFi；「云视听小电视」打开后即可被找到。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(cast.devices) { device in
                            Button {
                                Task {
                                    await cast.cast(to: device, video: video, playback: playback)
                                    if cast.target != nil { dismiss() }
                                }
                            } label: {
                                row(device)
                            }
                            .buttonStyle(.plain)
                            .disabled(cast.isBusy)
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    private func row(_ device: CastDeviceInfo) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "tv")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(AppTheme.secondary(scheme))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name.isEmpty ? "电视" : device.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                let subtitle = device.subtitle
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if cast.isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}
