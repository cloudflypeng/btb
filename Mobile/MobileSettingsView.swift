import SwiftUI

struct MobileSettingsView: View {
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

    @State private var accountToLogout: StoredAccount?

    private let qualities = [127, 126, 125, 120, 116, 112, 80, 74, 64, 32, 16]
    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    private let limitOptions = [0, 512, 1024, 2048, 5120]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                accountSection
                appearanceSection
                playbackSection
                danmakuSection
                downloadSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await model.applyDownloadConfig()
        }
        .onChange(of: downloadConcurrency) { _, _ in
            Task { await model.applyDownloadConfig() }
        }
        .onChange(of: downloadLimit) { _, _ in
            Task { await model.applyDownloadConfig() }
        }
        .confirmationDialog(
            "退出当前账号？",
            isPresented: Binding(
                get: { accountToLogout != nil },
                set: { if !$0 { accountToLogout = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task { await model.logout(stayInPlace: true) }
                accountToLogout = nil
            }
            Button("取消", role: .cancel) { accountToLogout = nil }
        } message: {
            Text("退出后仍会保留本机下载与设置。")
        }
    }

    private var accountSection: some View {
        settingsSection(title: "账号", subtitle: "登录凭据只保存在本机 bbcore 数据目录。") {
            if model.accounts.isEmpty {
                settingsRow(title: "未登录", subtitle: "登录后可同步收藏、关注、历史与消息。") {
                    Button("手机号登录") {
                        model.presentLogin()
                    }
                    .buttonStyle(MobileSettingsButtonStyle(prominent: true))
                }
            } else {
                ForEach(Array(model.accounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 { settingsDivider }
                    accountRow(account)
                }
                settingsDivider
                settingsRow(title: "添加账号", subtitle: nil) {
                    Button("登录") {
                        model.presentLogin()
                    }
                    .buttonStyle(MobileSettingsButtonStyle())
                }
            }
        }
    }

    private func accountRow(_ account: StoredAccount) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: account.avatarURL, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Text(verbatim: "UID \(account.mid)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer(minLength: 8)
            if account.active == true {
                Text("当前")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(AppTheme.chip(scheme), in: Capsule())
                Button("退出") {
                    accountToLogout = account
                }
                .buttonStyle(MobileSettingsButtonStyle(destructive: true))
            } else {
                Button("切换") {
                    Task { await model.useAccount(account.mid, stayInPlace: true) }
                }
                .buttonStyle(MobileSettingsButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
    }

    private var appearanceSection: some View {
        settingsSection(title: "外观") {
            settingsRow(title: "主题", subtitle: "深色、浅色或跟随系统。") {
                Picker("主题", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var playbackSection: some View {
        settingsSection(title: "播放", subtitle: "打开视频时默认使用的清晰度、编码与速度。") {
            settingsRow(title: "默认清晰度", subtitle: "超出权限时自动回退。") {
                Picker("默认清晰度", selection: $playerQN) {
                    ForEach(qualities, id: \.self) { qn in
                        Text(qnLabel(qn)).tag(qn)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingsDivider
            settingsRow(title: "默认编码", subtitle: nil) {
                Picker("默认编码", selection: $playerCodec) {
                    Text("HEVC").tag("hevc")
                    Text("AVC").tag("avc")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 128)
            }
            settingsDivider
            settingsRow(title: "默认倍速", subtitle: nil) {
                Picker("默认倍速", selection: $playerRate) {
                    ForEach(rates, id: \.self) { rate in
                        Text(rateLabel(rate)).tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingsDivider
            settingsRow(title: "自动连播", subtitle: "播放结束后自动打开相关推荐。") {
                Toggle("自动连播", isOn: $autoplayNext)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.brand)
            }
        }
    }

    private var danmakuSection: some View {
        settingsSection(title: "弹幕", subtitle: "新打开的播放器会使用这些默认值。") {
            settingsRow(title: "默认开启弹幕", subtitle: nil) {
                Toggle("默认开启弹幕", isOn: $danmakuEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.brand)
            }
            settingsDivider
            sliderRow(title: "不透明度", valueText: "\(Int(danmakuOpacity * 100))%", value: $danmakuOpacity, range: 0.2...1.0)
            settingsDivider
            sliderRow(title: "滚动速度", valueText: String(format: "%.1fx", danmakuSpeed), value: $danmakuSpeed, range: 0.5...2.0)
            settingsDivider
            sliderRow(title: "字号", valueText: "\(Int(danmakuFontScale * 100))%", value: $danmakuFontScale, range: 0.7...1.6)
            settingsDivider
            VStack(alignment: .leading, spacing: 8) {
                Text("屏蔽词")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("命中任一关键词的弹幕会被隐藏，用逗号分隔。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
                TextField("例如：剧透, 打卡", text: $blockWords)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(14)
        }
    }

    private var downloadSection: some View {
        settingsSection(title: "下载", subtitle: "任务在后台运行，离线也能观看。") {
            settingsRow(title: "默认清晰度", subtitle: nil) {
                Picker("下载默认清晰度", selection: $downloadQN) {
                    ForEach(qualities, id: \.self) { qn in
                        Text(qnLabel(qn)).tag(qn)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingsDivider
            settingsRow(title: "默认编码", subtitle: nil) {
                Picker("下载默认编码", selection: $downloadCodec) {
                    Text("HEVC").tag("hevc")
                    Text("AVC").tag("avc")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 128)
            }
            settingsDivider
            settingsRow(title: "同时下载数", subtitle: "1–8 个任务并行。") {
                Picker("同时下载数", selection: $downloadConcurrency) {
                    ForEach(1...8, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingsDivider
            settingsRow(title: "下载限速", subtitle: "限制所有任务的总速度。") {
                Picker("下载限速", selection: $downloadLimit) {
                    ForEach(limitOptions, id: \.self) { limit in
                        Text(limitLabel(limit)).tag(limit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingsDivider
            settingsRow(title: "保存位置", subtitle: "下载内容保存在本机应用数据目录。") {
                Text("本机")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
        }
    }

    private var aboutSection: some View {
        settingsSection(title: "关于") {
            settingsRow(title: "BTB", subtitle: "哔哩哔哩原生客户端") {
                Text(appVersion)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .monospacedDigit()
            }
            settingsDivider
            settingsRow(title: "bbcore", subtitle: coreSummary) {
                Text(coreVersion)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .monospacedDigit()
            }
            settingsDivider
            VStack(alignment: .leading, spacing: 6) {
                Text("隐私")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("登录 Cookie、access key 与观看记录只写入本机数据目录，不会发送给 BTB 以外的任何服务。下载内容仅保存在本机，播放不会上传本地文件。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private var settingsDivider: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 14)
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func settingsRow<Control: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    private func sliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Text(valueText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .tint(AppTheme.brand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
}

private struct MobileSettingsButtonStyle: ButtonStyle {
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
