import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @AppStorage("app.appearance") private var appearance = "system"
    @AppStorage("player.defaultQN") private var playerQN = 80
    @AppStorage("player.defaultCodec") private var playerCodec = "hevc"
    @AppStorage("player.defaultRate") private var playerRate = 1.0
    @AppStorage("player.autoplayNext") private var autoplayNext = true
    @AppStorage("player.danmakuEnabled") private var danmakuEnabled = true
    @AppStorage("danmaku.opacity") private var danmakuOpacity = 0.92
    @AppStorage("danmaku.speed") private var danmakuSpeed = 1.0
    @AppStorage("danmaku.fontScale") private var danmakuFontScale = 1.0
    @AppStorage("danmaku.blockWords") private var blockWords = ""
    @AppStorage("download.defaultQN") private var downloadQN = 80
    @AppStorage("download.defaultCodec") private var downloadCodec = "hevc"
    @AppStorage("download.concurrency") private var downloadConcurrency = 1
    @AppStorage("download.limitKbps") private var downloadLimit = 0

    private let qualities = [127, 126, 125, 120, 116, 112, 80, 74, 64, 32, 16]
    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    private let limitOptions = [0, 512, 1024, 2048, 5120]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    accountSection
                    appearanceSection
                    playbackSection
                    danmakuSection
                    downloadSection
                    aboutSection
                        .id("settings-about")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background(scheme))
            .overlay(alignment: .bottom) {
                toast
            }
            .animation(.easeOut(duration: 0.2), value: model.toastMessage)
            .task {
                await model.applyDownloadConfig()
#if DEBUG
                if ProcessInfo.processInfo.environment["BTB_SETTINGS_SCROLL"] == "bottom" {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    proxy.scrollTo("settings-about", anchor: .bottom)
                }
#endif
            }
            .onChange(of: downloadConcurrency) { _, _ in
                Task { await model.applyDownloadConfig() }
            }
            .onChange(of: downloadLimit) { _, _ in
                Task { await model.applyDownloadConfig() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("设置")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("外观、播放、弹幕、下载与账号")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
    }

    private var accountSection: some View {
        SettingsSection(title: "账号", subtitle: "账号与登录凭据只保存在本机的 bbcore 数据目录。") {
            if model.accounts.isEmpty {
                SettingsRow(title: model.activeAccount == nil ? "未登录" : "账号加载中",
                            subtitle: "扫码登录后可同步收藏、关注、历史与消息。") {
                    Button("扫码登录") {
                        model.presentLogin()
                    }
                    .buttonStyle(SettingsButtonStyle(prominent: true))
                }
            } else {
                ForEach(Array(model.accounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        SettingsDivider()
                    }
                    accountRow(account)
                }
                SettingsDivider()
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Text("添加账号")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.text(scheme))
                    Spacer(minLength: 12)
                    Button("扫码登录") {
                        model.presentLogin()
                    }
                    .buttonStyle(SettingsButtonStyle())
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
        }
    }

    private func accountRow(_ account: StoredAccount) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: account.avatarURL, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Text("UID \(account.mid)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer(minLength: 12)
            if account.active == true {
                Text("当前")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(AppTheme.chip(scheme), in: Capsule())
                Button("退出登录") {
                    Task { await model.logout(stayInPlace: true) }
                }
                .buttonStyle(SettingsButtonStyle(destructive: true))
            } else {
                Button("切换") {
                    Task { await model.useAccount(account.mid, stayInPlace: true) }
                }
                .buttonStyle(SettingsButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
    }

    private var appearanceSection: some View {
        SettingsSection(title: "外观") {
            SettingsRow(title: "主题", subtitle: "深色或浅色，也可以跟随系统。") {
                Picker("主题", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
        }
    }

    private var playbackSection: some View {
        SettingsSection(title: "播放", subtitle: "打开视频时默认选择的清晰度、编码与速度。") {
            SettingsRow(title: "默认清晰度", subtitle: "超出账号权限或源不提供时自动回退。") {
                Picker("默认清晰度", selection: $playerQN) {
                    ForEach(qualities, id: \.self) { qn in
                        Text(qnLabel(qn)).tag(qn)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)
            }
            SettingsDivider()
            SettingsRow(title: "默认编码") {
                Picker("默认编码", selection: $playerCodec) {
                    Text("HEVC").tag("hevc")
                    Text("AVC").tag("avc")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }
            SettingsDivider()
            SettingsRow(title: "默认倍速") {
                Picker("默认倍速", selection: $playerRate) {
                    ForEach(rates, id: \.self) { rate in
                        Text(rateLabel(rate)).tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
            }
            SettingsDivider()
            SettingsRow(title: "自动连播", subtitle: "播放结束后自动打开相关推荐的下一个视频。") {
                Toggle("自动连播", isOn: $autoplayNext)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var danmakuSection: some View {
        SettingsSection(title: "弹幕", subtitle: "新打开的播放器会使用这些默认值，也可以在播放器内临时调整。") {
            SettingsRow(title: "默认开启弹幕") {
                Toggle("默认开启弹幕", isOn: $danmakuEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            SettingsDivider()
            SettingsSliderRow(title: "不透明度", valueText: "\(Int(danmakuOpacity * 100))%", value: $danmakuOpacity, range: 0.2...1.0)
            SettingsDivider()
            SettingsSliderRow(title: "滚动速度", valueText: String(format: "%.1fx", danmakuSpeed), value: $danmakuSpeed, range: 0.5...2.0)
            SettingsDivider()
            SettingsSliderRow(title: "字号", valueText: "\(Int(danmakuFontScale * 100))%", value: $danmakuFontScale, range: 0.7...1.6)
            SettingsDivider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("屏蔽词")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text("命中任一关键词的弹幕会被隐藏。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                Spacer(minLength: 12)
                TextField("用逗号分隔", text: $blockWords)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.horizontal, 10)
                    .frame(width: 300, height: 30)
                    .background(AppTheme.field(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.divider(scheme), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
        }
    }

    private var downloadSection: some View {
        SettingsSection(title: "下载", subtitle: "下载任务在 bbcore 后台运行，关闭页面后继续。") {
            SettingsRow(title: "默认清晰度") {
                Picker("下载默认清晰度", selection: $downloadQN) {
                    ForEach(qualities, id: \.self) { qn in
                        Text(qnLabel(qn)).tag(qn)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)
            }
            SettingsDivider()
            SettingsRow(title: "默认编码") {
                Picker("下载默认编码", selection: $downloadCodec) {
                    Text("HEVC").tag("hevc")
                    Text("AVC").tag("avc")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }
            SettingsDivider()
            SettingsRow(title: "同时下载数", subtitle: "1–8 个任务并行，修改后立即生效。") {
                Picker("同时下载数", selection: $downloadConcurrency) {
                    ForEach(1...8, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }
            SettingsDivider()
            SettingsRow(title: "下载限速", subtitle: "限制所有下载任务的总速度。") {
                Picker("下载限速", selection: $downloadLimit) {
                    ForEach(limitOptions, id: \.self) { limit in
                        Text(limitLabel(limit)).tag(limit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
            }
            SettingsDivider()
            SettingsRow(title: "保存位置", subtitle: downloadDirectoryText) {
                Button("在访达中显示") {
                    guard !model.downloadDirectory.isEmpty else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([
                        URL(fileURLWithPath: model.downloadDirectory),
                    ])
                }
                .buttonStyle(SettingsButtonStyle())
                .disabled(model.downloadDirectory.isEmpty)
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "关于") {
            SettingsRow(title: "BTB", subtitle: "哔哩哔哩原生桌面客户端") {
                Text(appVersion)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .monospacedDigit()
            }
            SettingsDivider()
            SettingsRow(title: "bbcore", subtitle: coreSummary) {
                Text(coreVersion)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .monospacedDigit()
            }
            SettingsDivider()
            VStack(alignment: .leading, spacing: 6) {
                Text("隐私")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("登录 Cookie、access key 与观看记录只写入本机数据目录，不会发送给 BTB 以外的任何服务。下载内容仅保存在本机，播放不会上传本地文件。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
    }

    private var downloadDirectoryText: String {
        guard !model.downloadDirectory.isEmpty else { return "数据目录不可用" }
        return model.downloadDirectory.replacingOccurrences(
            of: NSHomeDirectory(),
            with: "~"
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private var coreVersion: String {
        guard let capabilities = model.eventHub.capabilities else { return "未连接" }
        return capabilities.version ?? "未知版本"
    }

    private var coreSummary: String {
        guard let capabilities = model.eventHub.capabilities else { return "核心尚未就绪" }
        var parts: [String] = []
        if let methods = capabilities.methods {
            parts.append("\(methods) 个方法")
        }
        if let protocolVersion = capabilities.protocolVersion {
            parts.append("协议 v\(protocolVersion)")
        }
        return parts.isEmpty ? "本机 Go 核心" : parts.joined(separator: " · ")
    }

    private func qnLabel(_ qn: Int) -> String {
        let label = DownloadJob.qualityLabel(qn)
        return label == "QN\(qn)" ? "\(qn)" : label
    }

    private func rateLabel(_ rate: Double) -> String {
        rate == floor(rate) ? "\(Int(rate)).0x" : String(format: "%.2gx", rate)
    }

    private func limitLabel(_ kbps: Int) -> String {
        if kbps <= 0 { return "不限速" }
        if kbps >= 1024 { return "\(kbps / 1024) MB/s" }
        return "\(kbps) KB/s"
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toastMessage {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.black.opacity(0.82), in: Capsule())
                .padding(.bottom, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(
                AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.divider(scheme), lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let control: Control

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }
}

private struct SettingsSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer(minLength: 12)
            Slider(value: $value, in: range)
                .frame(width: 180)
                .tint(AppTheme.brand)
            Text(valueText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

private struct SettingsDivider: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(AppTheme.divider(scheme))
            .frame(height: 1)
            .padding(.leading, 14)
    }
}

private struct SettingsButtonStyle: ButtonStyle {
    var prominent = false
    var destructive = false

    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        if prominent { return AppTheme.selectedText(scheme) }
        if destructive { return AppTheme.brand }
        return AppTheme.text(scheme)
    }

    private var background: Color {
        if prominent { return AppTheme.selected(scheme) }
        return AppTheme.chip(scheme)
    }
}
