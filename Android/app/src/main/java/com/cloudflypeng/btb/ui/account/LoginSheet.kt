package com.cloudflypeng.btb.ui.account

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cloudflypeng.btb.data.SmsCaptchaChallenge
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginSheet(
    viewModel: AccountViewModel,
    onDismiss: () -> Unit,
) {
    val login by viewModel.login.collectAsStateWithLifecycle()

    LaunchedEffect(login.completed) {
        if (login.completed) onDismiss()
    }

    LaunchedEffect(login.qrAuthCode) {
        if (login.qrAuthCode == null) return@LaunchedEffect
        while (isActive) {
            delay(2_000)
            val status = viewModel.login.value.qrStatus
            if (status != QrStatus.Waiting && status != QrStatus.Scanned) break
            viewModel.pollQrLogin()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
        ) {
            Text(
                text = "登录 BTB",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "登录后可同步观看进度、收藏与稍后再看。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LoginMethod.entries.forEach { method ->
                    FilterChip(
                        selected = login.method == method,
                        onClick = { viewModel.selectMethod(method) },
                        label = { Text(method.label) },
                        shape = RoundedCornerShape(50),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.onBackground,
                            selectedLabelColor = MaterialTheme.colorScheme.background,
                        ),
                    )
                }
            }

            Spacer(Modifier.height(18.dp))

            if (login.method == LoginMethod.Phone) {
                PhoneLoginSection(viewModel = viewModel)
            } else {
                QrLoginSection(viewModel = viewModel)
            }

            login.error?.let { message ->
                Spacer(Modifier.height(12.dp))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }

    login.captchaChallenge?.let { challenge ->
        GeetestCaptchaDialog(
            challenge = challenge,
            onResult = { validate, seccode ->
                viewModel.completeCaptcha(challenge, validate, seccode)
            },
            onDismiss = viewModel::cancelCaptcha,
        )
    }
}

@Composable
private fun PhoneLoginSection(viewModel: AccountViewModel) {
    val login by viewModel.login.collectAsStateWithLifecycle()

    Column {
        OutlinedTextField(
            value = login.phone,
            onValueChange = viewModel::updatePhone,
            label = { Text("手机号") },
            prefix = { Text("+86 ") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            OutlinedTextField(
                value = login.code,
                onValueChange = viewModel::updateCode,
                label = { Text("验证码") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.weight(1f),
            )
            TextButton(
                onClick = viewModel::sendSmsCode,
                enabled = login.cooldown == 0 && !login.isSending,
            ) {
                when {
                    login.isSending -> CircularProgressIndicator(
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(18.dp),
                    )

                    login.cooldown > 0 -> Text("${login.cooldown}s")
                    login.captchaKey != null -> Text("重新获取")
                    else -> Text("获取验证码")
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = viewModel::loginWithSms,
            enabled = !login.isLoggingIn,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (login.isLoggingIn) {
                CircularProgressIndicator(
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(18.dp),
                )
            } else {
                Text("登录")
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = "未注册的手机号将自动创建账号。",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun QrLoginSection(viewModel: AccountViewModel) {
    val login by viewModel.login.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val qrSize = with(density) { 220.dp.roundToPx() }
    val qrBitmap = remember(login.qrUrl, qrSize) {
        login.qrUrl?.let { url ->
            runCatching { encodeQr(url, qrSize) }.getOrNull()
        }
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Surface(
            color = androidx.compose.ui.graphics.Color.White,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.size(248.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                when {
                    login.qrStatus == QrStatus.Loading || (login.qrUrl != null && qrBitmap == null) ->
                        CircularProgressIndicator(strokeWidth = 2.dp)

                    qrBitmap != null -> Image(
                        bitmap = qrBitmap,
                        contentDescription = "登录二维码",
                        filterQuality = FilterQuality.None,
                        modifier = Modifier
                            .size(220.dp)
                            .padding(8.dp),
                    )

                    else -> Text(
                        text = "二维码不可用",
                        style = MaterialTheme.typography.bodySmall,
                        color = androidx.compose.ui.graphics.Color(0xFF606060),
                    )
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        Text(
            text = qrStatusText(login),
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        if (login.qrStatus == QrStatus.Expired || login.qrStatus == QrStatus.Failed) {
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = viewModel::beginQrLogin) {
                Text("刷新二维码")
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = "请在哔哩哔哩客户端中扫码并确认。",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun qrStatusText(login: LoginUiState): String = when (login.qrStatus) {
    QrStatus.Idle, QrStatus.Loading -> "正在生成二维码…"
    QrStatus.Waiting -> "等待扫码"
    QrStatus.Scanned -> "已扫码，请在手机上确认"
    QrStatus.Expired -> "二维码已过期"
    QrStatus.Failed -> "二维码加载失败"
    QrStatus.Success -> "登录成功"
}

private fun encodeQr(content: String, sizePx: Int): ImageBitmap {
    val hints = mapOf(
        EncodeHintType.MARGIN to 1,
        EncodeHintType.CHARACTER_SET to "UTF-8",
    )
    val matrix = QRCodeWriter().encode(
        content,
        BarcodeFormat.QR_CODE,
        sizePx,
        sizePx,
        hints,
    )
    val pixels = IntArray(sizePx * sizePx)
    for (y in 0 until sizePx) {
        for (x in 0 until sizePx) {
            pixels[y * sizePx + x] = if (matrix.get(x, y)) {
                android.graphics.Color.BLACK
            } else {
                android.graphics.Color.WHITE
            }
        }
    }
    val bitmap = Bitmap.createBitmap(pixels, sizePx, sizePx, Bitmap.Config.ARGB_8888)
    return bitmap.asImageBitmap()
}

@Composable
private fun GeetestCaptchaDialog(
    challenge: SmsCaptchaChallenge,
    onResult: (validate: String, seccode: String) -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .heightIn(max = 620.dp),
        ) {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 20.dp, end = 8.dp, top = 8.dp),
                ) {
                    Text(
                        text = "安全验证",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "关闭")
                    }
                }
                GeetestWebView(
                    challenge = challenge,
                    onResult = onResult,
                    onError = onDismiss,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(480.dp),
                )
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun GeetestWebView(
    challenge: SmsCaptchaChallenge,
    onResult: (validate: String, seccode: String) -> Unit,
    onError: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var webView by remember { mutableStateOf<WebView?>(null) }
    DisposableEffect(Unit) {
        onDispose {
            webView?.removeJavascriptInterface("BTBCaptcha")
            webView?.destroy()
            webView = null
        }
    }
    AndroidView(
        factory = { context ->
            val handler = Handler(Looper.getMainLooper())
            WebView(context).apply {
                webView = this
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(
                        view: WebView,
                        request: WebResourceRequest,
                    ): Boolean {
                        val host = request.url.host.orEmpty()
                        val trusted = host.endsWith("bilibili.com") || host.endsWith("geetest.com")
                        return !trusted
                    }
                }
                addJavascriptInterface(
                    object {
                        @JavascriptInterface
                        fun success(validate: String, seccode: String) {
                            if (validate.isBlank() || seccode.isBlank()) return
                            handler.post { onResult(validate, seccode) }
                        }

                        @JavascriptInterface
                        fun error(message: String) {
                            handler.post { onError() }
                        }
                    },
                    "BTBCaptcha",
                )
                loadDataWithBaseURL(
                    "https://passport.bilibili.com",
                    geetestHtml(challenge),
                    "text/html",
                    "utf-8",
                    null,
                )
            }
        },
        modifier = modifier,
    )
}

private fun geetestHtml(challenge: SmsCaptchaChallenge): String {
    val gt = jsEscape(challenge.gt)
    val code = jsEscape(challenge.challenge)
    val stamp = System.currentTimeMillis()
    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
html,body{margin:0;padding:0;background:transparent;font-family:sans-serif}
#tip{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;color:#909090;font-size:14px}
</style>
</head>
<body>
<div id="tip">正在加载安全验证…</div>
<script>
var R=function(ok,a,b){try{if(ok){window.BTBCaptcha.success(a,b)}else{window.BTBCaptcha.error(String(a))}}catch(e){}};
var C,S,T,t;
T=function(){if(C&&S&&!t){t=Geetest(C).onSuccess(function(){var v=t.getValidate();R(true,v.geetest_validate,v.geetest_seccode)}).onError(function(o){R(false,JSON.stringify(o))}).onClose(function(o){R(false,JSON.stringify(o))});t.onReady(function(){t.verify()})}};
window.geetest_$stamp=function(d){
  if(!d||d.status!='success'){R(false,JSON.stringify(d));return}
  C=Object.assign({gt:"$gt",challenge:"$code",offline:false,new_captcha:true,product:"bind",width:"100%",https:true,protocol:"https://"},d.data);
  T()
};
window.G=function(){S=1;T()};
window.E=function(){document.getElementById("tip").textContent="验证码加载失败，请稍后重试"};
</script>
<script src="https://static.geetest.com/static/js/fullpage.0.0.0.js" onload="G()" onerror="E()"></script>
<script src="https://api.geetest.com/gettype.php?gt=$gt&callback=geetest_$stamp" onerror="E()"></script>
</body>
</html>
""".trimIndent()
}

private fun jsEscape(value: String): String = buildString(value.length) {
    value.forEach { char ->
        when (char) {
            '\\', '"', '\'', '<', '>' -> append('\\').append(char)
            else -> append(char)
        }
    }
}
