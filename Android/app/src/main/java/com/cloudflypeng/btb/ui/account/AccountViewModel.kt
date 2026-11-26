package com.cloudflypeng.btb.ui.account

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.data.AccountRepository
import com.cloudflypeng.btb.data.NavProfile
import com.cloudflypeng.btb.data.SmsCaptchaChallenge
import com.cloudflypeng.btb.data.SmsCaptchaResult
import com.cloudflypeng.btb.data.StoredAccount
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class LoginMethod(val label: String) {
    Phone("手机号登录"),
    Qr("扫码登录"),
}

enum class QrStatus {
    Idle,
    Loading,
    Waiting,
    Scanned,
    Expired,
    Failed,
    Success,
}

data class AccountUiState(
    val isLoading: Boolean = true,
    val accounts: List<StoredAccount> = emptyList(),
    val profile: NavProfile? = null,
    val error: String? = null,
) {
    val active: StoredAccount? get() = accounts.firstOrNull { it.active == true }
}

data class LoginUiState(
    val method: LoginMethod = LoginMethod.Phone,
    val qrStatus: QrStatus = QrStatus.Idle,
    val qrUrl: String? = null,
    val qrAuthCode: String? = null,
    val phone: String = "",
    val code: String = "",
    val captchaKey: String? = null,
    val captchaChallenge: SmsCaptchaChallenge? = null,
    val cooldown: Int = 0,
    val isSending: Boolean = false,
    val isLoggingIn: Boolean = false,
    val error: String? = null,
    val completed: Boolean = false,
)

class AccountViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository: AccountRepository = container.accountRepository

    private val _state = MutableStateFlow(AccountUiState())
    val state = _state.asStateFlow()

    private val _login = MutableStateFlow(LoginUiState())
    val login = _login.asStateFlow()

    private val _accountChanges = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val accountChanges = _accountChanges.asSharedFlow()

    private var reloadJob: Job? = null
    private var cooldownJob: Job? = null
    private var polling = false

    fun refresh() {
        reloadJob?.cancel()
        reloadJob = viewModelScope.launch { reload(showLoading = _state.value.accounts.isEmpty()) }
    }

    fun prepareLogin() {
        cooldownJob?.cancel()
        _login.value = LoginUiState()
    }

    fun selectMethod(method: LoginMethod) {
        if (_login.value.method == method) return
        _login.update { it.copy(method = method, error = null) }
        if (method == LoginMethod.Qr && _login.value.qrUrl == null) {
            beginQrLogin()
        }
    }

    fun beginQrLogin() {
        _login.update {
            it.copy(
                method = LoginMethod.Qr,
                qrStatus = QrStatus.Loading,
                qrUrl = null,
                qrAuthCode = null,
                error = null,
            )
        }
        viewModelScope.launch {
            try {
                container.core.start()
                val payload = repository.qrGenerate()
                _login.update {
                    it.copy(
                        qrStatus = QrStatus.Waiting,
                        qrUrl = payload.url,
                        qrAuthCode = payload.authCode,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _login.update {
                    it.copy(
                        qrStatus = QrStatus.Failed,
                        error = "二维码生成失败：${error.accountMessage()}",
                    )
                }
            }
        }
    }

    fun pollQrLogin() {
        val current = _login.value
        val authCode = current.qrAuthCode ?: return
        if (current.qrStatus != QrStatus.Waiting && current.qrStatus != QrStatus.Scanned) return
        if (polling) return
        polling = true
        viewModelScope.launch {
            try {
                val response = repository.qrPoll(authCode)
                when (response.code) {
                    0 -> {
                        _login.update { it.copy(qrStatus = QrStatus.Success, error = null) }
                        finishLogin()
                    }

                    86039, 86101 -> _login.update {
                        it.copy(qrStatus = QrStatus.Waiting, error = null)
                    }

                    86090 -> _login.update {
                        it.copy(qrStatus = QrStatus.Scanned, error = null)
                    }
                    86038 -> _login.update { it.copy(qrStatus = QrStatus.Expired) }
                    else -> _login.update {
                        it.copy(
                            qrStatus = QrStatus.Failed,
                            error = "登录失败：${response.message ?: "错误码 ${response.code}"}",
                        )
                    }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _login.update { it.copy(error = "登录状态查询失败：${error.accountMessage()}") }
            } finally {
                polling = false
            }
        }
    }

    fun updatePhone(value: String) {
        val digits = value.filter { it.isDigit() }.take(11)
        _login.update { it.copy(phone = digits, error = null) }
    }

    fun updateCode(value: String) {
        val digits = value.filter { it.isDigit() }.take(6)
        _login.update { it.copy(code = digits, error = null) }
    }

    fun sendSmsCode() {
        if (_login.value.isSending) return
        requestSmsCode(captcha = null)
    }

    fun completeCaptcha(challenge: SmsCaptchaChallenge, validate: String, seccode: String) {
        _login.update { it.copy(captchaChallenge = null) }
        requestSmsCode(SmsCaptchaResult(challenge, validate, seccode))
    }

    fun cancelCaptcha() {
        _login.update { it.copy(captchaChallenge = null) }
    }

    private fun requestSmsCode(captcha: SmsCaptchaResult?) {
        val tel = _login.value.phone
        if (tel.length != 11 || !tel.startsWith("1")) {
            _login.update { it.copy(error = "请输入正确的手机号") }
            return
        }
        if (_login.value.isSending) return
        _login.update { it.copy(isSending = true, error = null) }
        viewModelScope.launch {
            try {
                container.core.start()
                val response = repository.sendSms(tel, captcha)
                val data = response.data
                val challenge = data?.recaptchaUrl?.let(SmsCaptchaChallenge::parse)
                when {
                    response.code == 0 && data?.captchaKey != null -> {
                        _login.update {
                            it.copy(
                                captchaKey = data.captchaKey,
                                captchaChallenge = null,
                            )
                        }
                        startCooldown()
                    }

                    challenge != null -> _login.update {
                        it.copy(captchaChallenge = challenge, error = null)
                    }

                    else -> _login.update {
                        it.copy(
                            error = response.message
                                ?: "验证码发送失败（${response.code}）",
                        )
                    }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _login.update { it.copy(error = "验证码发送失败：${error.accountMessage()}") }
            } finally {
                _login.update { it.copy(isSending = false) }
            }
        }
    }

    fun loginWithSms() {
        if (_login.value.isLoggingIn) return
        val current = _login.value
        if (current.phone.length != 11 || !current.phone.startsWith("1")) {
            _login.update { it.copy(error = "请输入正确的手机号") }
            return
        }
        if (current.code.isEmpty()) {
            _login.update { it.copy(error = "请输入验证码") }
            return
        }
        val captchaKey = current.captchaKey
        if (captchaKey == null) {
            _login.update { it.copy(error = "请先获取验证码") }
            return
        }
        _login.update { it.copy(isLoggingIn = true, error = null) }
        viewModelScope.launch {
            try {
                val response = repository.loginSms(current.phone, current.code, captchaKey)
                if (response.code != 0) {
                    _login.update {
                        it.copy(
                            error = "登录失败：${response.message ?: "错误码 ${response.code}"}",
                        )
                    }
                    return@launch
                }
                finishLogin()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _login.update { it.copy(error = "登录失败：${error.accountMessage()}") }
            } finally {
                _login.update { it.copy(isLoggingIn = false) }
            }
        }
    }

    fun useAccount(mid: Long) {
        viewModelScope.launch {
            try {
                repository.useAccount(mid)
                reload(showLoading = false)
                _accountChanges.tryEmit(Unit)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _state.update { it.copy(error = "切换账号失败：${error.accountMessage()}") }
            }
        }
    }

    fun removeAccount(mid: Long) {
        viewModelScope.launch {
            try {
                repository.removeAccount(mid)
                reload(showLoading = false)
                _accountChanges.tryEmit(Unit)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _state.update { it.copy(error = "删除账号失败：${error.accountMessage()}") }
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            try {
                repository.logout()
                reload(showLoading = false)
                _accountChanges.tryEmit(Unit)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _state.update { it.copy(error = "退出登录失败：${error.accountMessage()}") }
            }
        }
    }

    fun dismissError() {
        _state.update { it.copy(error = null) }
    }

    private fun finishLogin() {
        cooldownJob?.cancel()
        _login.update { it.copy(completed = true) }
        viewModelScope.launch {
            reload(showLoading = false)
            _accountChanges.tryEmit(Unit)
        }
    }

    private suspend fun reload(showLoading: Boolean) {
        if (showLoading) {
            _state.update { it.copy(isLoading = true, error = null) }
        }
        try {
            container.core.start()
            val data = repository.accounts()
            val hasActive = data.accounts.any { it.active == true }
            val profile = if (hasActive) repository.profile() else null
            _state.value = AccountUiState(
                isLoading = false,
                accounts = data.accounts,
                profile = profile,
            )
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            _state.update {
                it.copy(isLoading = false, error = "账号信息加载失败：${error.accountMessage()}")
            }
        }
    }

    private fun startCooldown() {
        cooldownJob?.cancel()
        _login.update { it.copy(cooldown = 60) }
        cooldownJob = viewModelScope.launch {
            while (true) {
                delay(1_000)
                val next = _login.value.cooldown - 1
                _login.update { it.copy(cooldown = next.coerceAtLeast(0)) }
                if (next <= 0) return@launch
            }
        }
    }
}

internal fun Throwable.accountMessage(): String = when (this) {
    is CoreException -> message ?: "核心调用失败"
    else -> message?.takeIf { it.isNotBlank() } ?: "未知错误"
}
