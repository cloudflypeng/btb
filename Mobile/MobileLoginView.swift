import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let text: String

    var body: some View {
        Group {
            if let image = Self.makeImage(text) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 70))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func makeImage(_ string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct MobileLoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var mode: LoginMode = .phone
    @State private var isAddingAccount = false
    @FocusState private var focusedField: Field?

    private enum LoginMode: Hashable {
        case phone
        case qr
    }

    private enum Field: Hashable {
        case phone
        case code
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !model.accounts.isEmpty {
                        accountSection
                        Divider()
                    }
                    // #10: with an account already signed in, the login form
                    // stays out of the way until "添加账号" asks for it.
                    if model.accounts.isEmpty || isAddingAccount {
                        modePicker
                        switch mode {
                        case .phone:
                            phoneSection
                        case .qr:
                            qrSection
                        }
                    } else {
                        Button {
                            isAddingAccount = true
                            if mode == .qr, model.qrPayload == nil {
                                Task { await model.beginQRLogin() }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("添加账号")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.brand)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background(scheme))
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if mode == .qr, model.qrPayload == nil {
                await model.beginQRLogin()
            }
        }
        .task(id: model.qrPayload?.authCode) {
            await pollLoop()
        }
        .sheet(isPresented: captchaPresented) {
            if let challenge = model.smsCaptchaChallenge {
                GeetestCaptchaSheet(challenge: challenge) { validate, seccode in
                    Task { await model.completeSMSCaptcha(validate: validate, seccode: seccode) }
                }
            }
        }
    }

    private var captchaPresented: Binding<Bool> {
        Binding(
            get: { model.smsCaptchaChallenge != nil },
            set: { shown in
                if !shown { model.cancelSMSCaptcha() }
            }
        )
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            MobilePill(title: "手机号登录", isSelected: mode == .phone) {
                withAnimation(.snappy(duration: 0.2)) { mode = .phone }
            }
            MobilePill(title: "扫码登录", isSelected: mode == .qr) {
                focusedField = nil
                withAnimation(.snappy(duration: 0.2)) {
                    mode = .qr
                    model.resetSMSLogin()
                }
                if model.qrPayload == nil {
                    Task { await model.beginQRLogin() }
                }
            }
            Spacer()
        }
    }

    private var phoneSection: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            Text("手机号登录")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("未注册的手机号将自动创建账号")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))

            HStack(spacing: 10) {
                Text("+86")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(width: 52, height: 48)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("手机号", text: Binding(
                    get: { model.smsPhone },
                    set: { model.smsPhone = String($0.filter(\.isNumber).prefix(11)) }
                ))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($focusedField, equals: .phone)
            }

            HStack(spacing: 10) {
                TextField("短信验证码", text: Binding(
                    get: { model.smsCode },
                    set: { model.smsCode = String($0.filter(\.isNumber).prefix(8)) }
                ))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($focusedField, equals: .code)

                Button {
                    focusedField = .code
                    Task { await model.sendSMSCode() }
                } label: {
                    Group {
                        if model.isSendingSMS {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(sendCodeTitle)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(canSendCode ? AppTheme.text(scheme) : AppTheme.tertiary(scheme))
                    .frame(width: 104, height: 48)
                    .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSendCode)
            }

            if let error = model.smsError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                focusedField = nil
                Task { await model.loginWithSMS() }
            } label: {
                HStack(spacing: 6) {
                    if model.isLoggingInSMS {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text("登录")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(smsFormReady ? Color.white : AppTheme.tertiary(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(smsFormReady ? AppTheme.brand : AppTheme.chip(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canLogin)

            Text("登录代表同意哔哩哔哩的用户协议与隐私政策")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.tertiary(scheme))
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
    }

    private var sendCodeTitle: String {
        if model.smsCooldown > 0 { return "\(model.smsCooldown)s 后重发" }
        return model.smsCaptchaKey == nil ? "获取验证码" : "重新获取"
    }

    private var canSendCode: Bool {
        model.isSMSPhoneValid && model.smsCooldown == 0 && !model.isSendingSMS
    }

    private var smsFormReady: Bool {
        model.isSMSPhoneValid
            && !model.smsCode.isEmpty
            && model.smsCaptchaKey != nil
    }

    private var canLogin: Bool {
        smsFormReady && !model.isLoggingInSMS
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已登录账号")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                if model.activeAccount != nil {
                    Button(role: .destructive) {
                        Task { await model.logout() }
                    } label: {
                        Text("退出当前账号")
                            .font(.system(size: 12.5))
                    }
                }
            }

            ForEach(model.accounts) { account in
                HStack(spacing: 10) {
                    AvatarView(url: account.avatarURL, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text(verbatim: "UID \(account.mid)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    Spacer()
                    if account.active == true {
                        Label("当前", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.green)
                    } else {
                        Button("切换") {
                            Task { await model.useAccount(account.mid) }
                        }
                        .font(.system(size: 12.5, weight: .medium))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.accounts.isEmpty ? "扫码登录" : "扫码添加账号")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("使用哔哩哔哩手机客户端扫描二维码")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))

            qrContent
        }
    }

    @ViewBuilder
    private var qrContent: some View {
        switch model.loginState {
        case .idle, .loading:
            ProgressView("正在生成二维码…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
        case .expired:
            VStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                Text("二维码已过期")
                Button("刷新二维码") {
                    Task { await model.beginQRLogin() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 42))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .multilineTextAlignment(.center)
                Button("重新生成") {
                    Task { await model.beginQRLogin() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        case .waiting, .scanned, .success:
            if let qr = model.qrPayload {
                VStack(spacing: 12) {
                    QRCodeView(text: qr.url)
                        .frame(width: 210, height: 210)
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))

                    status

                    Button("刷新二维码") {
                        Task { await model.beginQRLogin() }
                    }
                    .font(.system(size: 12.5))
                }
                .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.loginState {
        case .waiting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("等待扫码")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(AppTheme.secondary(scheme))
        case .scanned:
            Label("已扫码，请在手机上确认", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12.5))
                .foregroundStyle(.green)
        case .success:
            Label("登录成功", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12.5))
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    private func pollLoop() async {
        guard let payload = model.qrPayload else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            guard model.qrPayload?.authCode == payload.authCode else { return }
            let result = await model.pollQRLogin()
            switch result {
            case .waiting, .scanned:
                continue
            case .expired, .success, .failed:
                return
            }
        }
    }
}
