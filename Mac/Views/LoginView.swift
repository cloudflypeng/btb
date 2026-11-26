import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let text: String

    var body: some View {
        Group {
            if let image = Self.makeImage(text) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func makeImage(_ string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("账号")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !model.accounts.isEmpty {
                        accountSection
                        Divider()
                    }
                    qrSection
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if model.qrPayload == nil {
                await model.beginQRLogin()
            }
        }
        .task(id: model.qrPayload?.authCode) {
            await pollLoop()
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已登录账号")
                    .font(.headline)
                Spacer()
                if model.activeAccount != nil {
                    Button(role: .destructive) {
                        Task { await model.logout() }
                    } label: {
                        Text("退出当前账号")
                    }
                    .buttonStyle(.link)
                }
            }

            ForEach(model.accounts) { account in
                HStack(spacing: 10) {
                    AvatarView(url: account.avatarURL, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.displayName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text("UID \(account.mid)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if account.active == true {
                        Label("当前", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Button("切换") {
                            Task { await model.useAccount(account.mid) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.accounts.isEmpty ? "扫码登录" : "扫码添加账号")
                .font(.headline)
            Text("使用哔哩哔哩手机客户端扫描二维码")
                .font(.caption)
                .foregroundStyle(.secondary)

            qrContent
        }
    }

    @ViewBuilder
    private var qrContent: some View {
        switch model.loginState {
        case .idle, .loading:
            ProgressView("正在生成二维码…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
        case .expired:
            VStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 58))
                    .foregroundStyle(.secondary)
                Text("二维码已过期")
                    .font(.callout)
                Button("刷新二维码") {
                    Task { await model.beginQRLogin() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Button("重新生成") {
                    Task { await model.beginQRLogin() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        case .waiting, .scanned, .success:
            if let qr = model.qrPayload {
                VStack(spacing: 10) {
                    QRCodeView(text: qr.url)
                        .frame(width: 220, height: 220)
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))

                    status

                    Button("刷新二维码") {
                        Task { await model.beginQRLogin() }
                    }
                    .buttonStyle(.link)
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
            .font(.callout)
            .foregroundStyle(.secondary)
        case .scanned:
            Label("已扫码，请在手机上确认", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .success:
            Label("登录成功", systemImage: "checkmark.circle.fill")
                .font(.callout)
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
