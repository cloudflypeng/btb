package com.cloudflypeng.btb.playback

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.data.CastDevice
import com.cloudflypeng.btb.data.DanmakuItem
import com.cloudflypeng.btb.data.DanmakuRepository
import com.cloudflypeng.btb.data.PlaybackQuality
import com.cloudflypeng.btb.data.PlaybackRepository
import com.cloudflypeng.btb.data.PlaybackSubtitle
import com.cloudflypeng.btb.data.PlayerResolveResult
import com.cloudflypeng.btb.data.StreamSession
import com.cloudflypeng.btb.data.SubtitleCue
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.WebVttParser
import com.cloudflypeng.btb.data.assignDanmakuLanes
import com.cloudflypeng.btb.data.playbackMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class PlaybackUiState(
    val isLoading: Boolean = true,
    val isReady: Boolean = false,
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = false,
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val title: String? = null,
    val resolve: PlayerResolveResult? = null,
    val selectedPage: Int = 1,
    val selectedQuality: PlaybackQuality? = null,
    val sessionId: String? = null,
    val error: String? = null,
    val notice: String? = null,
    val danmakuEnabled: Boolean = true,
    val danmakuItems: List<DanmakuItem> = emptyList(),
    val subtitles: List<PlaybackSubtitle> = emptyList(),
    val selectedSubtitle: PlaybackSubtitle? = null,
    val subtitleText: String? = null,
    val playbackRate: Float = 1f,
    val autoplayNext: Boolean = true,
    val nextVideo: VideoItem? = null,
    val autoplayCountdown: Int? = null,
    val danmakuOpacity: Float = 0.92f,
    val danmakuSpeed: Float = 1f,
    val danmakuFontScale: Float = 1f,
    val danmakuBlockWords: String = "",
)

class PlaybackController(
    context: Context,
    private val video: VideoItem,
    private val repository: PlaybackRepository,
    private val danmakuRepository: DanmakuRepository,
    private val settings: com.cloudflypeng.btb.data.PlaybackSettings? = null,
    private val castController: CastController? = null,
) {
    val player: ExoPlayer = ExoPlayer.Builder(context.applicationContext)
        .build()
        .apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                true,
            )
            setHandleAudioBecomingNoisy(true)
        }

    private val prefs = context.applicationContext
        .getSharedPreferences("btb.player", Context.MODE_PRIVATE)

    var state by mutableStateOf(
        PlaybackUiState(
            title = video.title,
            playbackRate = prefs.getFloat(KEY_RATE, 1f).coerceIn(0.5f, 3f),
            autoplayNext = settings?.autoplayNext ?: prefs.getBoolean(KEY_AUTOPLAY, true),
            danmakuEnabled = settings?.danmakuEnabled ?: prefs.getBoolean(KEY_DANMAKU_ENABLED, true),
            danmakuOpacity = settings?.danmakuOpacity ?: prefs.getFloat(KEY_DANMAKU_OPACITY, 0.92f),
            danmakuSpeed = settings?.danmakuSpeed ?: prefs.getFloat(KEY_DANMAKU_SPEED, 1f),
            danmakuFontScale = settings?.danmakuFontScale ?: prefs.getFloat(KEY_DANMAKU_FONT_SCALE, 1f),
            danmakuBlockWords = settings?.danmakuBlockWords ?: prefs.getString(KEY_DANMAKU_BLOCK_WORDS, "").orEmpty(),
        ),
    )
        private set

    var onPlayNext: ((VideoItem) -> Unit)? = null

    private val preferredQn: Long
        get() = settings?.defaultQuality?.takeIf { it > 0 } ?: DEFAULT_QN

    val qualities: List<PlaybackQuality>
        get() {
            val all = state.resolve?.qualities.orEmpty()
            val supported = all.filter { it.codec == "avc" || it.codec == "hevc" }
            return (supported.ifEmpty { all }).sortedWith(
                compareByDescending<PlaybackQuality> { it.qn }
                    .thenBy { if (it.codec == "avc") 0 else 1 },
            )
        }

    val pages get() = state.resolve?.pages.orEmpty()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val commandMutex = Mutex()
    private val retiredSessions = mutableSetOf<String>()
    private var subtitleCues: List<SubtitleCue> = emptyList()
    private var autoplayJob: Job? = null

    private var activeSession: StreamSession? = null
    private var currentCid: Long? = null
    private var pendingStart: PendingStart? = null
    private var heartbeatJob: Job? = null
    private var suppressPauseReport = false
    private var didReachEnd = false
    private var released = false
    private var started = false
    private val loadedDanmakuSegments = mutableSetOf<Int>()
    private val loadingDanmakuSegments = mutableSetOf<Int>()
    private val failedDanmakuSegments = mutableSetOf<Int>()

    private data class PendingStart(
        val positionMs: Long,
        val autoplay: Boolean,
    )

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_IDLE -> Unit
                Player.STATE_BUFFERING -> {
                    state = state.copy(isBuffering = true)
                }

                Player.STATE_READY -> handleReady()
                Player.STATE_ENDED -> handleEnded()
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            val wasPlaying = state.isPlaying
            state = state.copy(isPlaying = isPlaying)
            if (isPlaying) {
                startHeartbeat()
                return
            }
            heartbeatJob?.cancel()
            heartbeatJob = null
            if (wasPlaying &&
                state.isReady &&
                !suppressPauseReport &&
                !player.playWhenReady &&
                player.playbackState != Player.STATE_ENDED
            ) {
                reportProgress("pause", safePosition())
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            suppressPauseReport = false
            heartbeatJob?.cancel()
            heartbeatJob = null
            activeSession?.let { session ->
                retiredSessions.add(session.sessionId)
                cleanupScope.launch { repository.stopStream(session.sessionId) }
            }
            activeSession = null
            state = state.copy(
                isLoading = false,
                isReady = false,
                isPlaying = false,
                isBuffering = false,
                error = "视频播放失败，请稍后重试（${error.errorCodeName}）",
            )
        }
    }

    init {
        player.addListener(listener)
        startTicker()
    }

    fun start() {
        if (started || released) return
        started = true
        prepare()
    }

    fun retry() {
        prepare()
    }

    fun togglePlayback() {
        if (player.isPlaying) {
            player.pause()
        } else {
            play()
        }
    }

    fun toggleDanmaku() {
        val enabled = !state.danmakuEnabled
        prefs.edit().putBoolean(KEY_DANMAKU_ENABLED, enabled).apply()
        state = state.copy(danmakuEnabled = enabled)
        if (enabled) {
            failedDanmakuSegments.clear()
            ensureDanmakuSegment(safePosition())
        }
    }

    val visibleDanmaku: List<DanmakuItem>
        get() {
            if (!state.danmakuEnabled) return emptyList()
            val words = blockedWords()
            if (words.isEmpty()) return state.danmakuItems
            return state.danmakuItems.filter { item ->
                words.none { word -> item.text.contains(word, ignoreCase = true) }
            }
        }

    private fun blockedWords(): List<String> = state.danmakuBlockWords
        .split(',', '，', ';', '；')
        .map { it.trim() }
        .filter { it.isNotEmpty() }

    fun setRate(rate: Float) {
        val value = rate.coerceIn(0.5f, 3f)
        player.setPlaybackSpeed(value)
        prefs.edit().putFloat(KEY_RATE, value).apply()
        state = state.copy(playbackRate = value)
    }

    fun setAutoplay(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTOPLAY, enabled).apply()
        state = state.copy(autoplayNext = enabled)
        if (!enabled) cancelAutoplay()
    }

    fun setDanmakuOpacity(opacity: Float) {
        val value = opacity.coerceIn(0.2f, 1f)
        prefs.edit().putFloat(KEY_DANMAKU_OPACITY, value).apply()
        state = state.copy(danmakuOpacity = value)
    }

    fun setDanmakuSpeed(speed: Float) {
        val value = speed.coerceIn(0.5f, 2f)
        prefs.edit().putFloat(KEY_DANMAKU_SPEED, value).apply()
        state = state.copy(
            danmakuSpeed = value,
            danmakuItems = assignDanmakuLanes(state.danmakuItems, value.toDouble()),
        )
    }

    fun setDanmakuFontScale(scale: Float) {
        val value = scale.coerceIn(0.6f, 1.6f)
        prefs.edit().putFloat(KEY_DANMAKU_FONT_SCALE, value).apply()
        state = state.copy(danmakuFontScale = value)
    }

    fun setDanmakuBlockWords(words: String) {
        prefs.edit().putString(KEY_DANMAKU_BLOCK_WORDS, words).apply()
        state = state.copy(danmakuBlockWords = words)
    }

    fun selectSubtitle(subtitle: PlaybackSubtitle?) {
        if (subtitle == null) {
            subtitleCues = emptyList()
            state = state.copy(selectedSubtitle = null, subtitleText = null)
            return
        }
        if (subtitle.url.isNullOrBlank()) {
            showNotice("该字幕暂不可用")
            return
        }
        scope.launch {
            try {
                val cues = WebVttParser.parse(repository.subtitleVtt(subtitle.url))
                if (released) return@launch
                subtitleCues = cues
                state = state.copy(selectedSubtitle = subtitle, subtitleText = null)
                if (cues.isEmpty()) showNotice("该字幕暂无内容")
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                showNotice("字幕加载失败")
            }
        }
    }

    suspend fun sendDanmaku(text: String): Boolean {
        val message = text.trim().takeIf { it.isNotEmpty() } ?: return false
        val cid = currentCid ?: return false
        val bvid = state.resolve?.bvid ?: video.bvid
        val startMs = safePosition()
        return try {
            danmakuRepository.send(cid, bvid, startMs, message)
            val local = DanmakuItem(
                id = "local-${System.currentTimeMillis()}",
                startMs = startMs,
                mode = 1,
                text = message,
                colorValue = 0xFFFFFF,
                fontSize = 25f,
                widthUnits = message.length.toFloat().coerceAtLeast(2f),
                lane = -1,
            )
            val merged = (state.danmakuItems + local).sortedBy { it.startMs }
            state = state.copy(
                danmakuItems = assignDanmakuLanes(merged, state.danmakuSpeed.toDouble()),
            )
            showNotice("弹幕已发送")
            true
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            val hint = if (error is CoreException && (error.code == -101 || error.code == -111)) {
                "请先登录"
            } else {
                error.message?.takeIf { it.isNotBlank() } ?: "弹幕发送失败"
            }
            showNotice(hint)
            false
        }
    }

    fun cancelAutoplay() {
        autoplayJob?.cancel()
        autoplayJob = null
        state = state.copy(nextVideo = null, autoplayCountdown = null)
    }

    val casting: CastUiState? get() = castController?.state

    fun castTo(device: CastDevice) {
        val cast = castController ?: return
        val cid = currentCid
        if (cid == null || !state.isReady) {
            showNotice("视频尚未加载完成")
            return
        }
        cast.castVideo(
            device = device,
            bvid = state.resolve?.bvid ?: video.bvid,
            cid = cid,
            page = state.selectedPage,
            qn = state.selectedQuality?.qn ?: preferredQn,
            codec = state.selectedQuality?.codec ?: DEFAULT_CODEC,
            title = state.title ?: video.title,
            positionMs = safePosition(),
        ) {
            player.pause()
            showNotice("已投屏到${device.name}")
        }
    }

    fun refreshCastDevices() {
        castController?.refresh()
    }

    fun stopCasting() {
        castController?.stop()
    }

    fun playNextNow() {
        val target = state.nextVideo ?: return
        cancelAutoplay()
        onPlayNext?.invoke(target)
    }

    fun play() {
        if (state.error != null && !state.isReady) return
        if (didReachEnd || player.playbackState == Player.STATE_ENDED) {
            didReachEnd = false
            cancelAutoplay()
            player.seekTo(0)
            state = state.copy(positionMs = 0)
        }
        player.play()
        player.setPlaybackSpeed(state.playbackRate)
    }

    fun pause() {
        player.pause()
    }

    fun seekTo(positionMs: Long) {
        val target = positionMs.coerceIn(0, state.durationMs.coerceAtLeast(0))
        didReachEnd = false
        if (state.autoplayCountdown != null) cancelAutoplay()
        player.seekTo(target)
        state = state.copy(positionMs = target)
        reportProgress("seek", target)
    }

    fun selectQuality(quality: PlaybackQuality) {
        if (!state.isReady || quality.id == state.selectedQuality?.id) return
        val startAt = safePosition()
        val wasPlaying = state.isPlaying
        scope.launch {
            commandMutex.withLock {
                loadStream(
                    resolve = state.resolve,
                    quality = quality,
                    startAtMs = startAt,
                    autoplay = wasPlaying,
                    failureNotice = "切换清晰度失败",
                )
            }
        }
    }

    fun selectPage(page: Int) {
        if (!state.isReady || page == state.selectedPage) return
        val wasPlaying = state.isPlaying
        scope.launch {
            commandMutex.withLock {
                val previous = state
                state = previous.copy(isLoading = true, error = null, notice = null)
                try {
                    val resolved = repository.resolve(
                        bvid = video.bvid,
                        page = page,
                        qn = preferredQn,
                        codec = DEFAULT_CODEC,
                    )
                    if (!resolved.canPlay) {
                        state = previous.copy(isLoading = false, notice = "该分P暂不可播放")
                        if (wasPlaying) player.play()
                        return@withLock
                    }
                    val quality = matchingQuality(previous.selectedQuality, resolved)
                    val started = loadStream(
                        resolve = resolved,
                        quality = quality,
                        startAtMs = 0,
                        autoplay = wasPlaying,
                        failureNotice = "切换分P失败",
                    )
                    if (!started && wasPlaying) player.play()
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Throwable) {
                    state = previous.copy(isLoading = false, notice = "切换分P失败")
                    if (wasPlaying) player.play()
                }
            }
        }
    }

    fun release() {
        if (released) return
        released = true
        val position = safePosition()
        val cid = currentCid
        val wasReady = state.isReady && !didReachEnd
        val sessionIds = buildList {
            activeSession?.let { add(it.sessionId) }
            addAll(retiredSessions)
        }
        heartbeatJob?.cancel()
        heartbeatJob = null
        autoplayJob?.cancel()
        autoplayJob = null
        pendingStart = null
        activeSession = null
        scope.cancel()
        player.removeListener(listener)
        player.release()

        if (wasReady && cid != null && position > 0) {
            cleanupScope.launch {
                repository.reportProgress(video.bvid, cid, position, "pause")
            }
        }
        sessionIds.forEach { sessionId ->
            cleanupScope.launch { repository.stopStream(sessionId) }
        }
    }

    private fun prepare() {
        scope.launch {
            commandMutex.withLock {
                if (released) return@withLock
                stopActivePlayback()
                pendingStart = null
                didReachEnd = false
                suppressPauseReport = false
                cancelAutoplay()
                subtitleCues = emptyList()
                state = PlaybackUiState(
                    isLoading = true,
                    title = video.title,
                    playbackRate = state.playbackRate,
                    autoplayNext = state.autoplayNext,
                    danmakuEnabled = state.danmakuEnabled,
                    danmakuOpacity = state.danmakuOpacity,
                    danmakuSpeed = state.danmakuSpeed,
                    danmakuFontScale = state.danmakuFontScale,
                    danmakuBlockWords = state.danmakuBlockWords,
                )
                try {
                    val resolved = repository.resolve(
                        bvid = video.bvid,
                        page = 1,
                        qn = preferredQn,
                        codec = DEFAULT_CODEC,
                    )
                    if (released) return@withLock
                    if (!resolved.canPlay) {
                        state = state.copy(
                            isLoading = false,
                            resolve = resolved,
                            selectedPage = resolved.page ?: 1,
                            durationMs = resolved.durationMs,
                            error = if (resolved.isPreview) {
                                "当前视频为预览片段，暂不可播放"
                            } else {
                                "当前视频暂不可播放"
                            },
                        )
                        return@withLock
                    }
                    val quality = preferredQuality(resolved)
                    if (quality == null) {
                        state = state.copy(
                            isLoading = false,
                            resolve = resolved,
                            error = "没有可用的视频流",
                        )
                        return@withLock
                    }
                    state = state.copy(
                        resolve = resolved,
                        title = resolved.title ?: video.title,
                        selectedPage = resolved.page ?: 1,
                        selectedQuality = quality,
                        durationMs = resolved.durationMs,
                        subtitles = resolved.subtitles,
                    )
                    loadStream(
                        resolve = resolved,
                        quality = quality,
                        startAtMs = initialResume(resolved),
                        autoplay = true,
                        failureNotice = null,
                    )
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Throwable) {
                    if (!released) {
                        state = state.copy(
                            isLoading = false,
                            isReady = false,
                            error = error.playbackMessage(),
                        )
                    }
                }
            }
        }
    }

    private suspend fun loadStream(
        resolve: PlayerResolveResult?,
        quality: PlaybackQuality,
        startAtMs: Long,
        autoplay: Boolean,
        failureNotice: String?,
    ): Boolean {
        val bvid = resolve?.bvid ?: video.bvid
        val cid = resolve?.cid ?: currentCid
        val page = resolve?.page ?: state.selectedPage
        if (cid == null) {
            state = state.copy(isLoading = false, error = "缺少视频 cid")
            return false
        }

        val hadReadyPlayback = state.isReady
        suppressPauseReport = true
        state = state.copy(isLoading = true, isBuffering = true, error = null, notice = null)
        player.pause()

        val stream = try {
            startStreamWithFallback(bvid, cid, page, quality)
        } catch (error: CancellationException) {
            suppressPauseReport = false
            throw error
        } catch (error: Throwable) {
            suppressPauseReport = false
            if (hadReadyPlayback) {
                state = state.copy(isLoading = false, isBuffering = false)
                if (autoplay) player.play()
                showNotice(failureNotice ?: "切换失败")
            } else {
                state = state.copy(
                    isLoading = false,
                    isBuffering = false,
                    isReady = false,
                    error = error.playbackMessage(),
                )
            }
            return false
        }

        if (released) {
            repository.stopStream(stream.sessionId)
            return false
        }

        val previousSession = activeSession
        val cidChanged = currentCid != null && currentCid != cid
        activeSession = stream
        currentCid = cid
        if (cidChanged) {
            loadedDanmakuSegments.clear()
            loadingDanmakuSegments.clear()
            failedDanmakuSegments.clear()
            subtitleCues = emptyList()
            state = state.copy(
                danmakuItems = emptyList(),
                selectedSubtitle = null,
                subtitleText = null,
            )
        }

        val actualQuality = actualQuality(stream, quality, resolve)
        val duration = stream.durationMs?.takeIf { it > 0 }
            ?: resolve?.durationMs?.takeIf { it > 0 }
            ?: state.durationMs
        state = state.copy(
            resolve = resolve ?: state.resolve,
            selectedPage = page,
            selectedQuality = actualQuality,
            sessionId = stream.sessionId,
            durationMs = duration,
            subtitles = (resolve ?: state.resolve)?.subtitles.orEmpty(),
            isBuffering = true,
        )
        pendingStart = PendingStart(startAtMs, autoplay)
        player.setMediaItem(MediaItem.fromUri(stream.masterUrl))
        player.prepare()
        ensureDanmakuSegment(startAtMs)

        if (previousSession != null && previousSession.sessionId != stream.sessionId) {
            retiredSessions.add(previousSession.sessionId)
            cleanupScope.launch { repository.stopStream(previousSession.sessionId) }
        }
        return true
    }

    private suspend fun startStreamWithFallback(
        bvid: String,
        cid: Long,
        page: Int,
        quality: PlaybackQuality,
    ): StreamSession {
        val codec = quality.codec ?: DEFAULT_CODEC
        return try {
            repository.startStream(bvid, cid, page, quality.qn, codec)
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (codec == "avc") throw error
            repository.startStream(bvid, cid, page, quality.qn, "avc")
        }
    }

    private fun handleReady() {
        val pending = pendingStart
        suppressPauseReport = false
        if (pending == null) {
            state = state.copy(
                isLoading = false,
                isBuffering = false,
                isReady = true,
                durationMs = playerDuration(),
            )
            return
        }
        pendingStart = null
        state = state.copy(
            isLoading = false,
            isBuffering = false,
            isReady = true,
            durationMs = playerDuration(),
        )
        player.setPlaybackSpeed(state.playbackRate)
        if (pending.positionMs > 1_000) {
            player.seekTo(pending.positionMs)
            state = state.copy(positionMs = pending.positionMs)
        }
        if (pending.autoplay) {
            player.play()
            startHeartbeat()
        } else {
            player.pause()
        }
        reportProgress(
            if (pending.positionMs > 1_000) "seek" else "start",
            pending.positionMs,
        )
    }

    private fun handleEnded() {
        didReachEnd = true
        suppressPauseReport = false
        state = state.copy(
            isPlaying = false,
            isBuffering = false,
            positionMs = state.durationMs,
        )
        reportProgress("end", -1)
        scheduleAutoplay()
    }

    private fun scheduleAutoplay() {
        if (!state.autoplayNext || released) return
        autoplayJob?.cancel()
        autoplayJob = scope.launch {
            val next = runCatching { repository.related(video.bvid) }.getOrNull()
                ?.firstOrNull { it.bvid != video.bvid && it.bvid != state.resolve?.bvid }
                ?: return@launch
            if (!didReachEnd || released) return@launch
            state = state.copy(nextVideo = next, autoplayCountdown = AUTOPLAY_SECONDS)
            for (remaining in AUTOPLAY_SECONDS - 1 downTo 1) {
                delay(1_000)
                if (released || !didReachEnd) return@launch
                state = state.copy(autoplayCountdown = remaining)
            }
            delay(1_000)
            if (released || !didReachEnd || state.nextVideo?.bvid != next.bvid) return@launch
            state = state.copy(nextVideo = null, autoplayCountdown = null)
            onPlayNext?.invoke(next)
        }
    }

    private fun startHeartbeat() {
        if (heartbeatJob?.isActive == true) return
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(15_000)
                if (!released && state.isPlaying) {
                    reportProgress("heartbeat", safePosition())
                }
            }
        }
    }

    private fun startTicker() {
        scope.launch {
            while (isActive) {
                if (!released && (state.isReady || state.isPlaying)) {
                    val position = safePosition()
                    val duration = playerDuration()
                    val cue = if (state.selectedSubtitle != null) {
                        subtitleCues.firstOrNull { position in it.startMs..it.endMs }?.text
                    } else {
                        null
                    }
                    if (position != state.positionMs ||
                        duration != state.durationMs ||
                        cue != state.subtitleText
                    ) {
                        state = state.copy(
                            positionMs = position,
                            durationMs = duration,
                            subtitleText = cue,
                        )
                    }
                    ensureDanmakuSegment(position)
                }
                delay(250)
            }
        }
    }

    private fun ensureDanmakuSegment(positionMs: Long) {
        if (!state.danmakuEnabled) return
        val cid = currentCid ?: return
        val segment = (positionMs.coerceAtLeast(0) / DANMAKU_SEGMENT_MS).toInt() + 1
        if (segment in loadedDanmakuSegments ||
            segment in loadingDanmakuSegments ||
            segment in failedDanmakuSegments
        ) {
            return
        }
        loadingDanmakuSegments.add(segment)
        scope.launch {
            try {
                val incoming = danmakuRepository.fetch(cid, segment)
                if (released || currentCid != cid) return@launch
                loadedDanmakuSegments.add(segment)
                val known = state.danmakuItems.mapTo(HashSet()) { it.id }
                val merged = state.danmakuItems + incoming.filter { known.add(it.id) }
                state = state.copy(
                    danmakuItems = assignDanmakuLanes(
                        merged.sortedBy { it.startMs },
                        state.danmakuSpeed.toDouble(),
                    ),
                )
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                failedDanmakuSegments.add(segment)
            } finally {
                loadingDanmakuSegments.remove(segment)
            }
        }
    }

    private fun reportProgress(event: String, positionMs: Long) {
        val cid = currentCid ?: return
        val bvid = state.resolve?.bvid ?: video.bvid
        scope.launch {
            repository.reportProgress(bvid, cid, positionMs, event)
        }
    }

    private fun showNotice(text: String) {
        state = state.copy(notice = text)
        scope.launch {
            delay(3_000)
            if (state.notice == text) {
                state = state.copy(notice = null)
            }
        }
    }

    private fun stopActivePlayback() {
        player.stop()
        player.clearMediaItems()
        activeSession?.let { session ->
            retiredSessions.add(session.sessionId)
            cleanupScope.launch { repository.stopStream(session.sessionId) }
        }
        activeSession = null
        currentCid = null
    }

    private fun preferredQuality(resolved: PlayerResolveResult): PlaybackQuality? {
        val all = resolved.qualities
        val supported = all.filter { it.codec == "avc" || it.codec == "hevc" }
        val candidates = supported.ifEmpty { all }
        if (candidates.isEmpty()) return null
        val target = minOf(
            resolved.defaultQn.takeIf { it > 0 } ?: preferredQn,
            preferredQn,
        )
        val eligible = candidates.filter { it.qn <= target }
        val pool = eligible.ifEmpty { candidates }
        return pool.maxWithOrNull(
            compareBy<PlaybackQuality> { it.qn }
                .thenBy { if (it.codec == DEFAULT_CODEC) 1 else 0 },
        )
    }

    private fun matchingQuality(
        previous: PlaybackQuality?,
        resolved: PlayerResolveResult,
    ): PlaybackQuality {
        if (previous != null) {
            resolved.qualities.firstOrNull {
                it.qn == previous.qn && it.codec == previous.codec
            }?.let { return it }
            resolved.qualities.firstOrNull {
                it.qn == previous.qn && it.codec == DEFAULT_CODEC
            }?.let { return it }
        }
        return preferredQuality(resolved) ?: resolved.qualities.first()
    }

    private fun actualQuality(
        stream: StreamSession,
        requested: PlaybackQuality,
        resolved: PlayerResolveResult?,
    ): PlaybackQuality {
        val actualQN = stream.video?.id?.toLong()
        val actualCodecID = stream.video?.codecid
        val candidates = resolved?.qualities.orEmpty()
        return candidates.firstOrNull {
            (actualQN == null || it.qn == actualQN) &&
                (actualCodecID == null || it.codecid == actualCodecID)
        } ?: requested
    }

    private fun initialResume(resolved: PlayerResolveResult): Long {
        val resume = resolved.resumeMs
        val total = resolved.durationMs
        if (resume <= 3_000) return 0
        if (total > 0 && resume >= total - 2_000) return 0
        return resume
    }

    private fun safePosition(): Long = runCatching { player.currentPosition }.getOrDefault(0)

    private fun playerDuration(): Long {
        val duration = player.duration
        return if (duration != C.TIME_UNSET && duration > 0) duration else state.durationMs
    }

    private companion object {
        const val DEFAULT_QN = 80L
        const val DEFAULT_CODEC = "avc"
        const val DANMAKU_SEGMENT_MS = 360_000L
        const val AUTOPLAY_SECONDS = 3
        const val KEY_RATE = "rate"
        const val KEY_AUTOPLAY = "autoplay"
        const val KEY_DANMAKU_ENABLED = "danmaku.enabled"
        const val KEY_DANMAKU_OPACITY = "danmaku.opacity"
        const val KEY_DANMAKU_SPEED = "danmaku.speed"
        const val KEY_DANMAKU_FONT_SCALE = "danmaku.fontScale"
        const val KEY_DANMAKU_BLOCK_WORDS = "danmaku.blockWords"
    }
}
