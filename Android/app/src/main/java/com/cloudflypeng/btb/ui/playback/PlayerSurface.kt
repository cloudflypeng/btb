package com.cloudflypeng.btb.ui.playback

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.ui.PlayerView
import com.cloudflypeng.btb.data.PlaybackSubtitle
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.theme.BtbMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

@Composable
fun PlayerSurface(
    controller: PlaybackController,
    modifier: Modifier = Modifier,
    isFullscreen: Boolean = false,
    pipMode: Boolean = false,
    onToggleFullscreen: () -> Unit = {},
    onEnterPip: (() -> Unit)? = null,
    ensureAccount: suspend () -> Boolean = { true },
    onRequestLogin: () -> Unit = {},
) {
    val state = controller.state
    val castState = controller.casting
    var controlsVisible by remember { mutableStateOf(true) }
    var qualityMenuOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var composerOpen by remember { mutableStateOf(false) }
    var castOpen by remember { mutableStateOf(false) }
    var scrubPosition by remember { mutableFloatStateOf(0f) }
    var scrubbing by remember { mutableStateOf(false) }
    var gestureHint by remember { mutableStateOf<String?>(null) }
    val view = LocalView.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(state.isPlaying) {
        if (!state.isPlaying) controlsVisible = true
    }
    LaunchedEffect(state.isPlaying, controlsVisible, qualityMenuOpen, scrubbing, settingsOpen) {
        if (state.isPlaying && controlsVisible && !qualityMenuOpen && !scrubbing && !settingsOpen) {
            delay(3_500)
            controlsVisible = false
        }
    }
    LaunchedEffect(gestureHint) {
        if (gestureHint != null) {
            delay(700)
            gestureHint = null
        }
    }
    DisposableEffect(state.isPlaying) {
        view.keepScreenOn = state.isPlaying
        onDispose { view.keepScreenOn = false }
    }

    val showControls = controlsVisible || !state.isPlaying
    val duration = state.durationMs.coerceAtLeast(1)
    val sliderValue = if (scrubbing) {
        scrubPosition
    } else {
        state.positionMs.toFloat().coerceIn(0f, duration.toFloat())
    }
    val playing = state.isPlaying

    Box(
        modifier = modifier
            .background(Color.Black),
    ) {
        AndroidView(
            factory = { context ->
                PlayerView(context).apply {
                    useController = false
                    setShutterBackgroundColor(android.graphics.Color.BLACK)
                    setKeepContentOnPlayerReset(true)
                    setEnableComposeSurfaceSyncWorkaround(true)
                    player = controller.player
                }
            },
            update = { view ->
                view.player = controller.player
            },
            onRelease = { view ->
                view.player = null
            },
            modifier = Modifier.fillMaxSize(),
        )

        DanmakuOverlay(
            items = controller.visibleDanmaku,
            enabled = state.danmakuEnabled,
            isPlaying = state.isPlaying,
            pausedPositionMs = state.positionMs,
            livePositionMs = { controller.player.currentPosition },
            opacity = state.danmakuOpacity,
            speed = state.danmakuSpeed,
            fontScale = state.danmakuFontScale,
            modifier = Modifier
                .fillMaxSize()
                .clipToBounds(),
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(
                    if (pipMode) {
                        Modifier
                    } else {
                        Modifier.pointerInput(Unit) {
                            detectTapGestures(
                                onTap = {
                                    if (controller.state.isReady) {
                                        controlsVisible = !controlsVisible
                                    }
                                },
                                onDoubleTap = { offset ->
                                    val current = controller.state
                                    if (!current.isReady) return@detectTapGestures
                                    val third = size.width / 3f
                                    val position = controller.player.currentPosition
                                    when {
                                        offset.x < third -> {
                                            val target = (position - 10_000).coerceAtLeast(0)
                                            controller.seekTo(target)
                                            gestureHint = "快退 10 秒"
                                        }

                                        offset.x > third * 2 -> {
                                            val target = (position + 10_000)
                                                .coerceAtMost(current.durationMs.coerceAtLeast(0))
                                            controller.seekTo(target)
                                            gestureHint = "快进 10 秒"
                                        }

                                        else -> {
                                            val willPlay = !current.isPlaying
                                            controller.togglePlayback()
                                            gestureHint = if (willPlay) "播放" else "暂停"
                                        }
                                    }
                                    view.performHapticFeedback(
                                        android.view.HapticFeedbackConstants.KEYBOARD_TAP,
                                    )
                                    controlsVisible = false
                                },
                            )
                        }
                    },
                ),
        )

        AnimatedVisibility(
            visible = gestureHint != null,
            enter = fadeIn(tween(90, easing = BtbMotion.EaseOut)),
            exit = fadeOut(tween(120, easing = BtbMotion.EaseOut)),
            modifier = Modifier.align(Alignment.Center),
        ) {
            Text(
                text = gestureHint ?: "",
                color = Color.White,
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.62f))
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            )
        }

        if (state.error == null &&
            (state.isLoading || (state.isBuffering && state.isPlaying))
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.align(Alignment.Center),
            ) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.5.dp,
                    modifier = Modifier.size(30.dp),
                )
                if (!state.isReady) {
                    Text(
                        text = "正在加载视频…",
                        color = Color.White.copy(alpha = 0.85f),
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
            }
        }

        if (state.error != null && !state.isReady) {
            PlaybackErrorOverlay(
                message = state.error,
                onRetry = controller::retry,
                modifier = Modifier.fillMaxSize(),
            )
        }

        state.subtitleText?.let { subtitle ->
            Text(
                text = subtitle,
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 24.dp)
                    .padding(
                        bottom = when {
                            pipMode -> 10.dp
                            showControls -> 86.dp
                            else -> 22.dp
                        },
                    )
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.Black.copy(alpha = 0.55f))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }

        state.notice?.let { notice ->
            Text(
                text = notice,
                color = Color.White,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(10.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.7f))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }

        val nextVideo = state.nextVideo
        val countdown = state.autoplayCountdown
        if (nextVideo != null && countdown != null) {
            AutoplayCard(
                title = nextVideo.title,
                countdown = countdown,
                onCancel = controller::cancelAutoplay,
                onPlayNow = controller::playNextNow,
                modifier = Modifier.align(Alignment.Center),
            )
        }

        AnimatedVisibility(
            visible = showControls && state.error == null && state.isReady && !pipMode,
            enter = fadeIn(tween(180, easing = BtbMotion.EaseOut)),
            exit = fadeOut(tween(140, easing = BtbMotion.EaseOut)),
            modifier = Modifier.fillMaxSize(),
        ) {
            Box(Modifier.fillMaxSize()) {
                if (isFullscreen) {
                    PlayerGlyphButton(
                        onClick = onToggleFullscreen,
                        size = 36.dp,
                        background = Color.Black.copy(alpha = 0.4f),
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(16.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.KeyboardArrowDown,
                            contentDescription = "退出全屏",
                            tint = Color.White,
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }

                if (!playing) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .size(58.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.5f))
                            .clickable {
                                controlsVisible = true
                                controller.togglePlayback()
                            }
                            .semantics {
                                contentDescription = "播放"
                            },
                    ) {
                        PlayPauseGlyph(
                            isPlaying = false,
                            tint = Color.White,
                            modifier = Modifier.size(28.dp),
                        )
                    }
                }

                Row(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (castState != null) {
                        val castingNow = castState.target != null
                        TextButton(
                            onClick = {
                                castOpen = true
                                controlsVisible = true
                            },
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.Black.copy(alpha = 0.55f)),
                        ) {
                            ChromeGlyph(
                                kind = ChromeGlyphKind.Cast,
                                color = if (castingNow) MaterialTheme.colorScheme.primary else Color.White,
                                modifier = Modifier.size(14.dp),
                            )
                            Spacer(Modifier.width(4.dp))
                            Text(
                                text = if (castingNow) "投屏中" else "投屏",
                                color = if (castingNow) MaterialTheme.colorScheme.primary else Color.White,
                                style = MaterialTheme.typography.labelSmall,
                            )
                        }
                    }
                    TextButton(
                        onClick = {
                            controller.toggleDanmaku()
                            controlsVisible = true
                        },
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.Black.copy(alpha = 0.55f)),
                    ) {
                        Text(
                            text = if (state.danmakuEnabled) "弹幕开" else "弹幕关",
                            color = if (state.danmakuEnabled) {
                                Color.White
                            } else {
                                Color.White.copy(alpha = 0.55f)
                            },
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                    Box {
                        TextButton(
                            onClick = {
                                qualityMenuOpen = true
                                controlsVisible = true
                            },
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.Black.copy(alpha = 0.55f)),
                        ) {
                            Text(
                                text = state.selectedQuality?.displayLabel ?: "清晰度",
                                color = Color.White,
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp),
                            )
                        }
                        DropdownMenu(
                            expanded = qualityMenuOpen,
                            onDismissRequest = { qualityMenuOpen = false },
                        ) {
                            controller.qualities.forEach { quality ->
                                DropdownMenuItem(
                                    text = { Text(quality.displayLabel) },
                                    onClick = {
                                        qualityMenuOpen = false
                                        controller.selectQuality(quality)
                                    },
                                    trailingIcon = {
                                        if (quality.id == state.selectedQuality?.id) {
                                            Icon(
                                                imageVector = Icons.Default.Check,
                                                contentDescription = null,
                                            )
                                        }
                                    },
                                )
                            }
                        }
                    }
                }

                Column(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.78f),
                                ),
                            ),
                        )
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        PlayerGlyphButton(
                            onClick = {
                                controlsVisible = true
                                controller.togglePlayback()
                            },
                            size = 36.dp,
                        ) {
                            PlayPauseGlyph(
                                isPlaying = playing,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                        Text(
                            text = formatTime(
                                if (scrubbing) scrubPosition.toLong() else state.positionMs,
                            ),
                            color = Color.White,
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.width(42.dp),
                        )
                        Slider(
                            value = sliderValue,
                            onValueChange = {
                                scrubbing = true
                                scrubPosition = it
                                controlsVisible = true
                            },
                            onValueChangeFinished = {
                                controller.seekTo(scrubPosition.toLong())
                                scrubbing = false
                            },
                            valueRange = 0f..duration.toFloat(),
                            enabled = state.isReady && duration > 1,
                            colors = SliderDefaults.colors(
                                thumbColor = MaterialTheme.colorScheme.primary,
                                activeTrackColor = MaterialTheme.colorScheme.primary,
                                inactiveTrackColor = Color.White.copy(alpha = 0.32f),
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .height(32.dp),
                        )
                        Text(
                            text = formatTime(state.durationMs),
                            color = Color.White.copy(alpha = 0.65f),
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.width(42.dp),
                        )
                        PlayerGlyphButton(
                            onClick = {
                                controlsVisible = true
                                scope.launch {
                                    if (ensureAccount()) {
                                        composerOpen = true
                                    } else {
                                        onRequestLogin()
                                    }
                                }
                            },
                            size = 36.dp,
                        ) {
                            DanmakuComposeGlyph(
                                tint = Color.White.copy(alpha = 0.9f),
                                modifier = Modifier.size(19.dp),
                            )
                        }
                        PlayerGlyphButton(
                            onClick = {
                                settingsOpen = true
                                controlsVisible = true
                            },
                            size = 36.dp,
                        ) {
                            Icon(
                                imageVector = Icons.Default.Settings,
                                contentDescription = "播放设置",
                                tint = Color.White.copy(alpha = 0.9f),
                                modifier = Modifier.size(19.dp),
                            )
                        }
                        if (onEnterPip != null) {
                            PlayerGlyphButton(
                                onClick = {
                                    controlsVisible = true
                                    onEnterPip()
                                },
                                size = 36.dp,
                            ) {
                                PipGlyph(
                                    tint = Color.White.copy(alpha = 0.9f),
                                    modifier = Modifier.size(19.dp),
                                )
                            }
                        }
                        PlayerGlyphButton(
                            onClick = {
                                controlsVisible = true
                                onToggleFullscreen()
                            },
                            size = 36.dp,
                        ) {
                            FullscreenGlyph(
                                expanded = isFullscreen,
                                tint = Color.White.copy(alpha = 0.9f),
                                modifier = Modifier.size(19.dp),
                            )
                        }
                    }
                    if (state.isBuffering && state.isPlaying) {
                        Text(
                            text = "缓冲中",
                            color = Color.White.copy(alpha = 0.72f),
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.padding(start = 12.dp, bottom = 2.dp),
                        )
                    }
                }
            }
        }
    }

    if (settingsOpen) {
        PlayerSettingsSheet(
            controller = controller,
            onDismiss = {
                settingsOpen = false
                controlsVisible = true
            },
        )
    }

    if (composerOpen) {
        DanmakuComposerDialog(
            controller = controller,
            onDismiss = {
                composerOpen = false
                controlsVisible = true
            },
        )
    }

    if (castOpen && castState != null) {
        CastSheet(
            state = castState,
            onRefresh = controller::refreshCastDevices,
            onSelect = controller::castTo,
            onStop = controller::stopCasting,
            onDismiss = {
                castOpen = false
                controlsVisible = true
            },
        )
    }
}

@Composable
private fun AutoplayCard(
    title: String,
    countdown: Int,
    onCancel: () -> Unit,
    onPlayNow: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier
            .padding(horizontal = 24.dp)
            .width(300.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.Black.copy(alpha = 0.78f))
            .padding(14.dp),
    ) {
        Text(
            text = "即将播放",
            color = Color.White.copy(alpha = 0.72f),
            style = MaterialTheme.typography.labelMedium,
        )
        Text(
            text = title,
            color = Color.White,
            style = MaterialTheme.typography.titleSmall,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "$countdown 秒后自动播放",
                color = Color.White.copy(alpha = 0.62f),
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onCancel) {
                Text("取消", color = Color.White.copy(alpha = 0.9f))
            }
            Button(onClick = onPlayNow) {
                Text("立即播放")
            }
        }
    }
}

@Composable
private fun PlayerGlyphButton(
    onClick: () -> Unit,
    size: Dp,
    modifier: Modifier = Modifier,
    background: Color = Color.Transparent,
    content: @Composable () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(background)
            .clickable(onClick = onClick),
    ) {
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlayerSettingsSheet(
    controller: PlaybackController,
    onDismiss: () -> Unit,
) {
    val state = controller.state
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        sheetMaxWidth = Dp.Unspecified,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
        ) {
            Text(
                text = "播放设置",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            SettingsSection("清晰度") {
                if (controller.qualities.isEmpty()) {
                    SettingsHint("暂无可用清晰度")
                } else {
                    controller.qualities.forEach { quality ->
                        SettingsChoiceRow(
                            title = quality.displayLabel,
                            selected = quality.id == state.selectedQuality?.id,
                            onClick = { controller.selectQuality(quality) },
                        )
                    }
                }
            }
            SettingsSection("播放") {
                Text(
                    text = "倍速",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                ) {
                    RATE_OPTIONS.forEach { rate ->
                        FilterChip(
                            selected = kotlin.math.abs(state.playbackRate - rate) < 0.001f,
                            onClick = { controller.setRate(rate) },
                            label = { Text(rateText(rate)) },
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                SettingsSwitchRow(
                    title = "自动连播",
                    checked = state.autoplayNext,
                    onCheckedChange = controller::setAutoplay,
                )
            }
            SettingsSection("字幕") {
                SettingsChoiceRow(
                    title = "关闭字幕",
                    selected = state.selectedSubtitle == null,
                    onClick = { controller.selectSubtitle(null) },
                )
                if (state.subtitles.isEmpty()) {
                    SettingsHint("该视频暂无字幕")
                } else {
                    state.subtitles.forEach { subtitle ->
                        SettingsChoiceRow(
                            title = subtitle.displayLabel,
                            selected = state.selectedSubtitle?.id == subtitle.id,
                            onClick = { controller.selectSubtitle(subtitle) },
                        )
                    }
                }
            }
            SettingsSection("弹幕") {
                SettingsSwitchRow(
                    title = "显示弹幕",
                    checked = state.danmakuEnabled,
                    onCheckedChange = { controller.toggleDanmaku() },
                )
                SettingsSliderRow(
                    title = "不透明度",
                    value = state.danmakuOpacity,
                    range = 0.2f..1f,
                    valueText = "${(state.danmakuOpacity * 100).toInt()}%",
                    onValueChange = controller::setDanmakuOpacity,
                )
                SettingsSliderRow(
                    title = "滚动速度",
                    value = state.danmakuSpeed,
                    range = 0.5f..2f,
                    valueText = String.format(Locale.CHINA, "%.1fx", state.danmakuSpeed),
                    onValueChange = controller::setDanmakuSpeed,
                )
                SettingsSliderRow(
                    title = "字号",
                    value = state.danmakuFontScale,
                    range = 0.6f..1.6f,
                    valueText = "${(state.danmakuFontScale * 100).toInt()}%",
                    onValueChange = controller::setDanmakuFontScale,
                )
                Spacer(Modifier.height(10.dp))
                OutlinedTextField(
                    value = state.danmakuBlockWords,
                    onValueChange = controller::setDanmakuBlockWords,
                    placeholder = { Text("屏蔽词，用逗号分隔") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Spacer(Modifier.height(20.dp))
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
    )
    Spacer(Modifier.height(4.dp))
    content()
    Spacer(Modifier.height(8.dp))
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
}

@Composable
private fun SettingsHint(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(vertical = 8.dp),
    )
}

@Composable
private fun SettingsChoiceRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 6.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun SettingsSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun SettingsSliderRow(
    title: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    valueText: String,
    onValueChange: (Float) -> Unit,
) {
    Column(Modifier.padding(top = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = valueText,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = range,
        )
    }
}

@Composable
private fun DanmakuComposerDialog(
    controller: PlaybackController,
    onDismiss: () -> Unit,
) {
    var text by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AlertDialog(
        onDismissRequest = { if (!sending) onDismiss() },
        title = { Text("发弹幕") },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { if (it.length <= DANMAKU_LIMIT) text = it },
                placeholder = { Text("发一条友善的弹幕吧") },
                supportingText = { Text("${text.length}/$DANMAKU_LIMIT") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = {
            TextButton(
                enabled = text.isNotBlank() && !sending,
                onClick = {
                    sending = true
                    scope.launch {
                        val sent = controller.sendDanmaku(text)
                        sending = false
                        if (sent) onDismiss()
                    }
                },
            ) {
                Text(if (sending) "发送中…" else "发送")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !sending) {
                Text("取消")
            }
        },
    )
}

private fun rateText(rate: Float): String =
    if (kotlin.math.abs(rate - rate.toInt()) < 0.001f) {
        "${rate.toInt()}x"
    } else {
        String.format(Locale.CHINA, "%.2gx", rate)
    }

private val RATE_OPTIONS = listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f, 2.5f, 3f)
private const val DANMAKU_LIMIT = 100

@Composable
private fun PlaybackErrorOverlay(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = modifier
            .background(Color.Black.copy(alpha = 0.82f))
            .padding(20.dp),
    ) {
        Spacer(Modifier.weight(1f))
        Text(
            text = "无法播放",
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = message,
            color = Color.White.copy(alpha = 0.8f),
            style = MaterialTheme.typography.bodySmall,
        )
        Button(onClick = onRetry) {
            Text("重试")
        }
        Spacer(Modifier.weight(1.2f))
    }
}

@Composable
private fun PlayPauseGlyph(
    isPlaying: Boolean,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier) {
        if (isPlaying) {
            drawPauseBar(tint)
        } else {
            drawPlayTriangle(tint)
        }
    }
}

@Composable
private fun DanmakuComposeGlyph(tint: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.width * 0.08f
        val body = Size(size.width * 0.86f, size.height * 0.66f)
        val topLeft = Offset(size.width * 0.07f, size.height * 0.1f)
        drawRoundRect(
            color = tint,
            topLeft = topLeft,
            size = body,
            cornerRadius = CornerRadius(size.width * 0.2f, size.width * 0.2f),
            style = Stroke(width = stroke),
        )
        val tail = Path().apply {
            moveTo(size.width * 0.28f, topLeft.y + body.height)
            lineTo(size.width * 0.24f, size.height * 0.94f)
            lineTo(size.width * 0.44f, topLeft.y + body.height)
        }
        drawPath(tail, tint)
        drawLine(
            color = tint,
            start = Offset(size.width * 0.28f, size.height * 0.38f),
            end = Offset(size.width * 0.72f, size.height * 0.38f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
        drawLine(
            color = tint,
            start = Offset(size.width * 0.28f, size.height * 0.54f),
            end = Offset(size.width * 0.58f, size.height * 0.54f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}

@Composable
private fun PipGlyph(tint: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.width * 0.08f
        drawRoundRect(
            color = tint,
            topLeft = Offset(size.width * 0.06f, size.height * 0.1f),
            size = Size(size.width * 0.88f, size.height * 0.8f),
            cornerRadius = CornerRadius(size.width * 0.12f, size.width * 0.12f),
            style = Stroke(width = stroke),
        )
        drawRoundRect(
            color = tint,
            topLeft = Offset(size.width * 0.5f, size.height * 0.52f),
            size = Size(size.width * 0.34f, size.height * 0.28f),
            cornerRadius = CornerRadius(size.width * 0.05f, size.width * 0.05f),
        )
    }
}

@Composable
private fun FullscreenGlyph(expanded: Boolean, tint: Color, modifier: Modifier = Modifier) {    Canvas(modifier) {
        val stroke = size.width * 0.09f
        val length = size.width * 0.24f
        val inset = size.width * 0.14f
        val far = size.width - inset
        if (expanded) {
            drawLine(tint, Offset(inset, inset + length), Offset(inset, inset), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset, inset), Offset(inset + length, inset), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far - length, inset), Offset(far, inset), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far, inset), Offset(far, inset + length), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset, far - length), Offset(inset, far), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset, far), Offset(inset + length, far), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far - length, far), Offset(far, far), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far, far), Offset(far, far - length), stroke, StrokeCap.Round)
        } else {
            drawLine(tint, Offset(inset, inset + length), Offset(inset + length, inset + length), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset + length, inset + length), Offset(inset + length, inset), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far, inset + length), Offset(far - length, inset + length), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far - length, inset + length), Offset(far - length, inset), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset, far - length), Offset(inset + length, far - length), stroke, StrokeCap.Round)
            drawLine(tint, Offset(inset + length, far - length), Offset(inset + length, far), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far, far - length), Offset(far - length, far - length), stroke, StrokeCap.Round)
            drawLine(tint, Offset(far - length, far - length), Offset(far - length, far), stroke, StrokeCap.Round)
        }
    }
}

private fun DrawScope.drawPauseBar(tint: Color) {
    val barWidth = size.width * 0.17f
    val barHeight = size.height * 0.58f
    val top = (size.height - barHeight) / 2f
    val radius = CornerRadius(barWidth * 0.35f, barWidth * 0.35f)
    drawRoundRect(
        color = tint,
        topLeft = Offset(size.width * 0.25f, top),
        size = Size(barWidth, barHeight),
        cornerRadius = radius,
    )
    drawRoundRect(
        color = tint,
        topLeft = Offset(size.width * 0.58f, top),
        size = Size(barWidth, barHeight),
        cornerRadius = radius,
    )
}

private fun DrawScope.drawPlayTriangle(tint: Color) {
    val path = Path().apply {
        moveTo(size.width * 0.30f, size.height * 0.18f)
        lineTo(size.width * 0.80f, size.height * 0.50f)
        lineTo(size.width * 0.30f, size.height * 0.82f)
        close()
    }
    drawPath(path, tint)
}

internal fun formatTime(milliseconds: Long): String {
    val totalSeconds = (milliseconds.coerceAtLeast(0) / 1000).toInt()
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        String.format(Locale.CHINA, "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format(Locale.CHINA, "%d:%02d", minutes, seconds)
    }
}
