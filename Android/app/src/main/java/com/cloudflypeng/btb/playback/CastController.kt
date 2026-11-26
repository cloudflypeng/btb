package com.cloudflypeng.btb.playback

import android.content.Context
import android.net.wifi.WifiManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.cloudflypeng.btb.data.CastDevice
import com.cloudflypeng.btb.data.CastPlayResponse
import com.cloudflypeng.btb.data.CastRepository
import com.cloudflypeng.btb.data.CastTarget
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

data class CastUiState(
    val discovering: Boolean = false,
    val busy: Boolean = false,
    val devices: List<CastDevice> = emptyList(),
    val target: CastTarget? = null,
    val error: String? = null,
    val notice: String? = null,
)

/**
 * App-scoped casting state. The stream the TV plays is served by the embedded
 * core inside this process, so the foreground [CastService] keeps the process
 * (and the cast) alive after the UI is closed.
 */
class CastController(context: Context, private val repository: CastRepository) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    var state by mutableStateOf(CastUiState())
        private set

    fun refresh() {
        if (state.discovering || state.busy) return
        state = state.copy(discovering = true, error = null)
        scope.launch {
            // SSDP answers are unicast, but some Wi-Fi stacks only deliver UDP
            // multicast traffic while a multicast lock is held.
            val lock = acquireMulticastLock()
            try {
                val devices = repository.discover()
                state = state.copy(discovering = false, devices = devices)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(discovering = false, error = error.castMessage("搜索附近设备失败"))
            } finally {
                runCatching { lock?.release() }
            }
        }
    }

    fun castVideo(
        device: CastDevice,
        bvid: String,
        cid: Long?,
        page: Int,
        qn: Long,
        codec: String?,
        title: String,
        positionMs: Long,
        onStarted: () -> Unit,
    ) {
        startCast(device, title, "video", onStarted) {
            repository.playVideo(device, bvid, cid, page, qn, codec, title, positionMs)
        }
    }

    fun castPgc(
        device: CastDevice,
        seasonId: Long,
        episodeId: Long?,
        qn: Long?,
        title: String,
        positionMs: Long,
        onStarted: () -> Unit,
    ) {
        startCast(device, title, "pgc", onStarted) {
            repository.playPgc(device, seasonId, episodeId, qn, title, positionMs)
        }
    }

    fun castLive(
        device: CastDevice,
        roomId: Long,
        title: String,
        onStarted: () -> Unit,
    ) {
        startCast(device, title, "live", onStarted) {
            repository.playLive(device, roomId, title)
        }
    }

    fun stop() {
        if (state.busy && state.target != null) return
        state = state.copy(busy = true)
        scope.launch {
            runCatching { repository.stop() }
            state = state.copy(
                busy = false,
                target = null,
                error = null,
                notice = "已停止投屏",
            )
            CastService.stop(appContext)
        }
    }

    fun consumeNotice() {
        if (state.notice != null) {
            state = state.copy(notice = null)
        }
    }

    fun clearError() {
        if (state.error != null) {
            state = state.copy(error = null)
        }
    }

    private fun startCast(
        device: CastDevice,
        title: String,
        kind: String,
        onStarted: () -> Unit,
        block: suspend () -> CastPlayResponse,
    ) {
        if (state.busy) return
        state = state.copy(busy = true, error = null)
        scope.launch {
            try {
                val result = block()
                if (!result.playing) {
                    state = state.copy(
                        busy = false,
                        error = result.message?.takeIf { it.isNotBlank() } ?: "投屏失败",
                    )
                    return@launch
                }
                val active = result.device?.let { mergeDevice(device, it) } ?: device
                val activeTitle = result.title?.takeIf { it.isNotBlank() } ?: title
                state = state.copy(
                    busy = false,
                    error = null,
                    target = CastTarget(
                        device = active,
                        title = activeTitle,
                        kind = result.kind ?: kind,
                        mode = result.mode,
                    ),
                    notice = "已投屏到${active.name}",
                )
                onStarted()
                CastService.start(appContext, active.name, activeTitle)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(busy = false, error = error.castMessage("投屏失败"))
            }
        }
    }

    private fun mergeDevice(requested: CastDevice, returned: CastDevice): CastDevice = CastDevice(
        id = returned.id.ifBlank { requested.id },
        name = returned.name.ifBlank { requested.name },
        model = returned.model?.takeIf { it.isNotBlank() } ?: requested.model,
        manufacturer = returned.manufacturer?.takeIf { it.isNotBlank() } ?: requested.manufacturer,
        host = returned.host?.takeIf { it.isNotBlank() } ?: requested.host,
        location = returned.location?.takeIf { it.isNotBlank() } ?: requested.location,
        avTransportUrl = returned.avTransportUrl.ifBlank { requested.avTransportUrl },
    )

    private fun acquireMulticastLock(): WifiManager.MulticastLock? = runCatching {
        val wifi = appContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        wifi?.createMulticastLock("btb-cast")?.apply {
            setReferenceCounted(false)
            acquire()
        }
    }.getOrNull()
}

private fun Throwable.castMessage(fallback: String): String {
    val text = message?.trim().orEmpty()
    return text.ifEmpty { fallback }.take(160)
}
