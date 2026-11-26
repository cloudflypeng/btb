package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class AccountRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun accounts(): AccountsData =
        json.decodeFromJsonElement(core.call("auth.accounts"))

    suspend fun profile(): NavProfile? {
        val response = json.decodeFromJsonElement<UpstreamResponse<NavProfile>>(
            core.call("auth.account.info"),
        )
        if (response.code != 0) return null
        return response.data
    }

    suspend fun useAccount(mid: Long) {
        core.call("auth.account.use", buildJsonObject { put("mid", mid) })
    }

    suspend fun removeAccount(mid: Long) {
        core.call("auth.account.remove", buildJsonObject { put("mid", mid) })
    }

    suspend fun logout() {
        core.call("auth.logout")
    }

    suspend fun qrGenerate(): QrPayload {
        val response = json.decodeFromJsonElement<UpstreamResponse<QrPayload>>(
            core.call("auth.qr.generate"),
        )
        if (response.code != 0 || response.data == null) {
            throw CoreException(response.code, response.message ?: "二维码生成失败")
        }
        return response.data
    }

    suspend fun qrPoll(authCode: String): QrPollResponse =
        json.decodeFromJsonElement(
            core.call(
                "auth.qr.poll",
                buildJsonObject {
                    put("auth_code", authCode)
                    put("make_active", true)
                },
            ),
        )

    suspend fun sendSms(tel: String, captcha: SmsCaptchaResult? = null): SmsSendResponse =
        json.decodeFromJsonElement(
            core.call(
                "auth.sms.send",
                buildJsonObject {
                    put("tel", tel)
                    put("cid", "86")
                    if (captcha != null) {
                        put("gee_challenge", captcha.challenge.challenge)
                        put("gee_validate", captcha.validate)
                        put("gee_seccode", captcha.seccode)
                        put("recaptcha_token", captcha.challenge.token)
                    }
                },
            ),
        )

    suspend fun loginSms(tel: String, code: String, captchaKey: String): SmsLoginResponse =
        json.decodeFromJsonElement(
            core.call(
                "auth.sms.login",
                buildJsonObject {
                    put("tel", tel)
                    put("cid", "86")
                    put("code", code)
                    put("captcha_key", captchaKey)
                    put("make_active", true)
                },
            ),
        )
}
