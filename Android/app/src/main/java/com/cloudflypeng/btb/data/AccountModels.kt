package com.cloudflypeng.btb.data

import android.net.Uri
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StoredAccount(
    val mid: Long,
    val name: String? = null,
    val avatar: String? = null,
    val active: Boolean? = null,
    @SerialName("has_access_key") val hasAccessKey: Boolean? = null,
) {
    val displayName: String
        get() = name?.takeIf { it.isNotBlank() } ?: "UID $mid"

    val avatarUrl: String?
        get() = normalizeMediaUrl(avatar)
}

@Serializable
data class AccountsData(
    @SerialName("active_mid") val activeMid: Long = 0,
    val accounts: List<StoredAccount> = emptyList(),
)

@Serializable
data class QrPayload(
    val url: String,
    @SerialName("auth_code") val authCode: String,
)

@Serializable
data class QrPollResponse(
    val code: Int = 0,
    val message: String? = null,
    val account: StoredAccount? = null,
)

@Serializable
data class SmsSendResponse(
    val code: Int = 0,
    val message: String? = null,
    val data: SmsSendData? = null,
)

@Serializable
data class SmsSendData(
    @SerialName("captcha_key") val captchaKey: String? = null,
    @SerialName("recaptcha_url") val recaptchaUrl: String? = null,
)

@Serializable
data class SmsLoginResponse(
    val code: Int = 0,
    val message: String? = null,
    val account: StoredAccount? = null,
)

@Serializable
data class NavProfile(
    val isLogin: Boolean? = null,
    val mid: Long? = null,
    val uname: String? = null,
    val face: String? = null,
    @SerialName("level_info") val levelInfo: NavLevelInfo? = null,
    val vipStatus: Int? = null,
    val coins: Int? = null,
) {
    val level: Int get() = levelInfo?.currentLevel ?: 0
    val avatarUrl: String? get() = normalizeMediaUrl(face)
}

@Serializable
data class NavLevelInfo(
    @SerialName("current_level") val currentLevel: Int? = null,
)

data class SmsCaptchaChallenge(
    val gt: String,
    val challenge: String,
    val token: String,
) {
    companion object {
        fun parse(recaptchaUrl: String): SmsCaptchaChallenge? {
            val uri = runCatching { Uri.parse(recaptchaUrl) }.getOrNull() ?: return null
            val gt = uri.getQueryParameter("gee_gt")?.takeIf { it.isNotBlank() } ?: return null
            val challenge = uri.getQueryParameter("gee_challenge")?.takeIf { it.isNotBlank() } ?: return null
            val token = uri.getQueryParameter("recaptcha_token")?.takeIf { it.isNotBlank() } ?: return null
            return SmsCaptchaChallenge(gt = gt, challenge = challenge, token = token)
        }
    }
}

data class SmsCaptchaResult(
    val challenge: SmsCaptchaChallenge,
    val validate: String,
    val seccode: String,
)
