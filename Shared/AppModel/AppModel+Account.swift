#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func refreshAccount() async {
        do {
            let value = try await core.call("auth.accounts")
            let data = try CoreCoding.decode(AccountsData.self, from: value)
            accounts = data.accounts
            if data.activeMid > 0 {
                await loadProfile(mid: data.activeMid)
            } else {
                clearProfile()
            }
        } catch {
            accounts = []
            clearProfile()
            profileError = "账号加载失败：\(describe(error))"
        }
        await loadRecentUPs()
    }

    func refreshProfile() async {
        if let active = activeAccount {
            await loadProfile(mid: active.mid)
        } else {
            await refreshAccount()
        }
    }

    func presentLogin() {
        qrPayload = nil
        loginState = .idle
        resetSMSLogin()
        isLoginSheetPresented = true
    }

    func beginQRLogin() async {
        guard coreState == .ready else { return }
        loginState = .loading
        qrPayload = nil
        do {
            let value = try await core.call("auth.qr.generate")
            let response = try CoreCoding.decode(QRGenerateResponse.self, from: value)
            guard response.code == 0, let payload = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "二维码生成失败")
            }
            qrPayload = payload
            loginState = .waiting
        } catch {
            loginState = .failed("二维码生成失败：\(describe(error))")
        }
    }

    func pollQRLogin() async -> LoginPollResult {
        guard let authCode = qrPayload?.authCode else {
            return .failed("二维码尚未就绪")
        }
        guard loginState == .waiting || loginState == .scanned else {
            return .expired
        }

        do {
            let value = try await core.call("auth.qr.poll", params: [
                "auth_code": .string(authCode),
                "make_active": .bool(true),
            ])
            let response = try CoreCoding.decode(QRPollResponse.self, from: value)
            switch response.code {
            case 0:
                loginState = .success
                isLoginSheetPresented = false
                navigationPath.removeAll()
                section = .profile
                await refreshAccount()
                return .success
            case 86039, 86101:
                loginState = .waiting
                return .waiting
            case 86090:
                loginState = .scanned
                return .scanned
            case 86038:
                loginState = .expired
                return .expired
            default:
                let message = "登录失败：\(response.message ?? "错误码 \(response.code)")"
                loginState = .failed(message)
                return .failed(message)
            }
        } catch {
            let message = "登录失败：\(describe(error))"
            loginState = .failed(message)
            return .failed(message)
        }
    }

    // MARK: Phone / SMS login

    var smsPhoneDigits: String { smsPhone.filter(\.isNumber) }
    var isSMSPhoneValid: Bool {
        let digits = smsPhoneDigits
        return digits.count == 11 && digits.hasPrefix("1")
    }

    func resetSMSLogin() {
        smsPhone = ""
        smsCode = ""
        smsCaptchaKey = nil
        smsCaptchaChallenge = nil
        smsCooldown = 0
        smsError = nil
        isSendingSMS = false
        isLoggingInSMS = false
        smsCooldownTask?.cancel()
        smsCooldownTask = nil
    }

    func sendSMSCode() async {
        await requestSMSCode(gee: nil)
    }

    func completeSMSCaptcha(validate: String, seccode: String) async {
        guard let challenge = smsCaptchaChallenge else { return }
        smsCaptchaChallenge = nil
        await requestSMSCode(gee: (challenge, validate, seccode))
    }

    func cancelSMSCaptcha() {
        smsCaptchaChallenge = nil
    }

    func requestSMSCode(gee: (challenge: SMSCaptchaChallenge, validate: String, seccode: String)?) async {
        guard coreState == .ready, !isSendingSMS else { return }
        let tel = smsPhoneDigits
        guard tel.count == 11 else {
            smsError = "请输入正确的手机号"
            return
        }
        isSendingSMS = true
        smsError = nil
        defer { isSendingSMS = false }

        var params: [String: JSONValue] = [
            "tel": .string(tel),
            "cid": .string("86"),
        ]
        if let gee {
            params["gee_challenge"] = .string(gee.challenge.challenge)
            params["gee_validate"] = .string(gee.validate)
            params["gee_seccode"] = .string(gee.seccode)
            params["recaptcha_token"] = .string(gee.challenge.token)
        }
        do {
            let value = try await core.call("auth.sms.send", params: params)
            let response = try CoreCoding.decode(SMSSendResponse.self, from: value)
            if response.code == 0 {
                smsCaptchaKey = response.data?.captchaKey
                smsCaptchaChallenge = nil
                startSMSCooldown()
                showToast("验证码已发送")
                return
            }
            if let url = response.data?.recaptchaURL,
               let challenge = SMSCaptchaChallenge(recaptchaURL: url) {
                smsCaptchaChallenge = challenge
                return
            }
            smsError = response.message ?? "验证码发送失败（\(response.code)）"
        } catch {
            smsError = "验证码发送失败：\(describe(error))"
        }
    }

    func loginWithSMS() async {
        guard coreState == .ready, !isLoggingInSMS else { return }
        let tel = smsPhoneDigits
        let code = smsCode.filter(\.isNumber)
        guard tel.count == 11 else {
            smsError = "请输入正确的手机号"
            return
        }
        guard !code.isEmpty else {
            smsError = "请输入验证码"
            return
        }
        guard let captchaKey = smsCaptchaKey else {
            smsError = "请先获取验证码"
            return
        }
        isLoggingInSMS = true
        smsError = nil
        defer { isLoggingInSMS = false }
        do {
            let value = try await core.call("auth.sms.login", params: [
                "tel": .string(tel),
                "cid": .string("86"),
                "code": .string(code),
                "captcha_key": .string(captchaKey),
                "make_active": .bool(true),
            ])
            let response = try CoreCoding.decode(SMSLoginResponse.self, from: value)
            guard response.code == 0 else {
                smsError = response.message ?? "登录失败（\(response.code)）"
                return
            }
            loginState = .success
            isLoginSheetPresented = false
            navigationPath.removeAll()
            section = .profile
            await refreshAccount()
            showToast("登录成功")
            resetSMSLogin()
        } catch {
            smsError = "登录失败：\(describe(error))"
        }
    }

    func startSMSCooldown() {
        smsCooldownTask?.cancel()
        smsCooldown = 60
        smsCooldownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.smsCooldown <= 1 {
                    self.smsCooldown = 0
                    return
                }
                self.smsCooldown -= 1
            }
        }
    }

    func useAccount(_ mid: Int64, stayInPlace: Bool = false) async {
        do {
            _ = try await core.call("auth.account.use", params: ["mid": .number(Double(mid))])
            closeLiveRoom()
            closeAnimeSeason()
            closeArticle()
            closeTopic()
            resetLiveFeed()
            resetAnimeFeed()
            resetSocial()
            resetMessages()
            await refreshAccount()
            await loadMessageUnread(force: true)
            navigationPath.removeAll()
            if !stayInPlace {
                section = .profile
            }
            isLoginSheetPresented = false
        } catch {
            loginState = .failed("切换账号失败：\(describe(error))")
            showToast("切换账号失败")
        }
    }

    func logout(stayInPlace: Bool = false) async {
        guard activeAccount != nil else { return }
        do {
            _ = try await core.call("auth.logout")
            await refreshAccount()
            navigationPath.removeAll()
            if !stayInPlace {
                section = .profile
            }
            qrPayload = nil
            loginState = .idle
            if isLoginSheetPresented {
                await beginQRLogin()
            }
        } catch {
            loginState = .failed("退出登录失败：\(describe(error))")
        }
    }

    func openSettings() {
        selectSection(.settings)
    }

    func retry() async {
        if let video = currentVideo {
            await loadWatchPage(for: video, force: true)
            return
        }
        if let mid = activeUPMid {
            await loadUP(mid: mid)
            return
        }
        if activeArticleID != nil {
            await loadArticle(force: true)
            return
        }
        if activeTopic != nil {
            await refreshTopic()
            return
        }
        switch section {
        case .home:
            await loadHome()
        case .dynamic:
            await loadDynamicFeed(reset: true)
        case .live:
            await loadLiveFeed(reset: true)
        case .anime:
            if let seasonID = activeAnimeSeasonID {
                await loadAnimeSeason(seasonID: seasonID, force: true)
            } else {
                await loadAnimeFeed(reset: true)
            }
        case .discover:
            await refreshDiscover()
        case .messages:
            await refreshMessages()
        case .search:
            await search()
        case .profile:
            await refreshProfile()
        case .uploads:
            await loadMyUploads(force: true)
        case .history:
            await loadHistoryVideos(force: true)
        case .playlists:
            if let folder = selectedFolder {
                await loadFolderVideos(folder)
            } else {
                await loadPlaylists(force: true)
            }
        case .watchLater:
            await loadWatchLater(force: true)
        case .downloads:
            await loadDownloads(force: true)
        case .settings:
            await applyDownloadConfig()
        }
    }

    func shutdown() {
        toastTask?.cancel()
        downloadEventsTask?.cancel()
        downloadEventsTask = nil
        eventHub.stop()
        Task { await core.stop() }
    }

    func restartCore() async {
        await core.stop()
        started = false
        videos = []
        resetSearchState()
        accounts = []
        recentUPs = []
        homePager.reset()
        searchPager.reset()
        upPager.reset()
        closeVideo()
        closeUP()
        closeDynamic()
        closeArticle()
        resetDiscover()
        closeFolder()
        closeDownload()
        clearProfile()
        await start()
    }

    func loadProfile(mid: Int64) async {
        isProfileLoading = true
        profileError = nil
        defer { isProfileLoading = false }

        let nav: NavData
        do {
            let value = try await core.call("user.me")
            let response = try CoreCoding.decode(UpstreamResponse<NavData>.self, from: value)
            guard response.code == 0, let data = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "未知错误")
            }
            nav = data
        } catch {
            clearProfile()
            profileError = "个人信息加载失败：\(describe(error))"
            return
        }

        guard nav.isLogin == true else {
            clearProfile()
            profileError = "登录状态已失效，请重新扫码登录"
            return
        }

        let profileMid = nav.mid ?? mid
        var info: UserInfoData?
        do {
            let value = try await core.call("user.info", params: ["mid": .number(Double(profileMid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserInfoData>.self, from: value)
            if response.code == 0 { info = response.data }
        } catch {
            // The nav payload is enough for the header when user.info is rejected.
        }

        var stat: UserStatData?
        do {
            let value = try await core.call("user.stat", params: ["mid": .number(Double(profileMid))])
            let response = try CoreCoding.decode(UpstreamResponse<UserStatData>.self, from: value)
            if response.code == 0 { stat = response.data }
        } catch {
            stat = nil
        }

        profile = UserProfile(
            mid: profileMid,
            name: info?.name ?? nav.uname ?? "B 站用户",
            avatarURL: MediaURL.normalize(info?.face ?? nav.face),
            sign: info?.sign ?? "",
            level: info?.level ?? nav.levelInfo?.currentLevel ?? 0,
            follower: stat?.follower ?? 0,
            following: stat?.following ?? 0
        )

        uploads = await fetchUploads(mid: profileMid)
        if !historyLoaded {
            history = await fetchHistory()
        }
    }

    func fetchUploads(mid: Int64) async -> [VideoItem] {
        do {
            let value = try await core.call("user.videos", params: [
                "mid": .number(Double(mid)),
                "pn": .number(1),
                "ps": .number(12),
            ])
            let response = try CoreCoding.decode(UpstreamResponse<UserVideosData>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data?.list?.vlist ?? []).compactMap(VideoItem.init(userVideo:))
        } catch {
            return []
        }
    }

    func fetchHistory() async -> [VideoItem] {
        do {
            let value = try await core.call("user.history", params: ["ps": .number(12)])
            let response = try CoreCoding.decode(UpstreamResponse<UserHistoryData>.self, from: value)
            guard response.code == 0 else { return [] }
            return (response.data?.list ?? []).compactMap(VideoItem.init(history:))
        } catch {
            return []
        }
    }

    func clearProfile() {
        profile = nil
        uploads = []
        history = []
        myUploads = []
        laterVideos = []
        laterTotal = 0
        favoriteFolders = []
        selectedFolder = nil
        folderVideos = []
        resetSocial()
        resetMessages()
        historyLoaded = false
        historyPaused = false
        historyStatusLoaded = false
        profileError = nil
        uploadsPager.reset()
        historyPager.reset()
        laterPager.reset()
        folderPager.reset()
        historyCursorMax = 0
        historyCursorViewAt = 0
        dynamicCards = []
        dynamicOffset = ""
        dynamicHasMore = false
        dynamicLoaded = false
        dynamicError = nil
        activeDynamic = nil
        dynamicRequest = UUID()
        resetLiveFeed()
        closeLiveRoom()
        resetAnimeFeed()
        closeAnimeSeason()
        closeArticle()
    }

    func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
