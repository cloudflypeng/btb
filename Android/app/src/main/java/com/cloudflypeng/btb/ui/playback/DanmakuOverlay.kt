package com.cloudflypeng.btb.ui.playback

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloudflypeng.btb.data.DanmakuItem
import kotlinx.coroutines.isActive
import kotlin.math.max
import kotlin.math.min

private const val SCROLL_LIFETIME_MS = 8_000L
private const val STATIC_LIFETIME_MS = 4_000L
private const val STATIC_LANE_LIMIT = 3

/**
 * Draws danmaku on a Compose canvas at display refresh rate. Text is measured once
 * per item and only positions change per frame.
 */
@Composable
fun DanmakuOverlay(
    items: List<DanmakuItem>,
    enabled: Boolean,
    isPlaying: Boolean,
    pausedPositionMs: Long,
    livePositionMs: () -> Long,
    modifier: Modifier = Modifier,
    opacity: Float = 0.92f,
    speed: Float = 1f,
    fontScale: Float = 1f,
) {
    if (!enabled || items.isEmpty()) return

    var framePositionMs by remember { mutableLongStateOf(pausedPositionMs) }
    LaunchedEffect(isPlaying, pausedPositionMs) {
        if (!isPlaying) {
            framePositionMs = pausedPositionMs
            return@LaunchedEffect
        }
        while (isActive) {
            withFrameNanos { }
            framePositionMs = livePositionMs()
        }
    }

    BoxWithConstraints(modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val widthDp = maxWidth.value
        val heightPx = with(density) { maxHeight.toPx() }
        val scale = (widthDp / 1280f).coerceIn(0.62f, 1.2f) * fontScale.coerceIn(0.6f, 1.6f)
        val alpha = opacity.coerceIn(0.2f, 1f)
        val scrollLifetimeMs = (SCROLL_LIFETIME_MS / speed.coerceIn(0.5f, 2f)).toLong()
        val lineHeightPx = with(density) { (30f * scale).sp.toPx() }
        val topPadPx = with(density) { 8.dp.toPx() }
        val bottomPadPx = with(density) { 14.dp.toPx() }
        val scrollLanes = max(1, ((heightPx - topPadPx) / lineHeightPx).toInt())
        val staticLanes = min(
            STATIC_LANE_LIMIT,
            max(1, (heightPx * 0.28f / lineHeightPx).toInt()),
        )
        val textMeasurer = rememberTextMeasurer(cacheSize = 256)
        val textStyle = remember(scale, density) {
            TextStyle(
                fontSize = (25f * scale).sp,
                fontWeight = FontWeight.SemiBold,
                shadow = Shadow(
                    color = Color.Black.copy(alpha = 0.85f),
                    offset = Offset(1.2f, 1.2f),
                    blurRadius = 2.5f,
                ),
            )
        }
        val layouts = remember(items, textStyle) { HashMap<String, TextLayoutResult>() }

        Canvas(Modifier.fillMaxSize()) {
            val nowMs = if (isPlaying) framePositionMs else pausedPositionMs
            if (nowMs < 0) return@Canvas
            val lifetime = max(scrollLifetimeMs, STATIC_LIFETIME_MS)
            var index = lowerBound(items, nowMs - lifetime)
            while (index < items.size) {
                val item = items[index]
                if (item.startMs > nowMs) break
                index += 1
                if (item.lane < 0) continue
                val elapsed = nowMs - item.startMs
                if (item.mode == 1) {
                    if (elapsed > scrollLifetimeMs || item.lane >= scrollLanes) continue
                } else {
                    if (elapsed > STATIC_LIFETIME_MS || item.lane >= staticLanes) continue
                }

                val baseStyle = if (item.fontSize == 25f) {
                    textStyle
                } else {
                    textStyle.copy(fontSize = (item.fontSize * scale).sp)
                }
                val layout = layouts.getOrPut(item.id) {
                    textMeasurer.measure(
                        text = AnnotatedString(item.text),
                        style = baseStyle.copy(color = item.color().copy(alpha = alpha)),
                        maxLines = 1,
                        softWrap = false,
                    )
                }

                val laneTop = when (item.mode) {
                    1, 5 -> topPadPx + item.lane * lineHeightPx
                    else -> size.height - bottomPadPx - (item.lane + 1) * lineHeightPx
                }
                val centerY = laneTop + lineHeightPx / 2f

                if (item.mode == 1) {
                    val progress = elapsed.toFloat() / scrollLifetimeMs
                    val travel = layout.size.width + 12.dp.toPx()
                    val x = size.width - progress * (size.width + travel)
                    drawText(
                        textLayoutResult = layout,
                        topLeft = Offset(x, centerY - layout.size.height / 2f),
                    )
                } else {
                    val x = (size.width - layout.size.width) / 2f
                    drawText(
                        textLayoutResult = layout,
                        topLeft = Offset(x, centerY - layout.size.height / 2f),
                    )
                }
            }
        }
    }
}

private fun DanmakuItem.color(): Color =
    Color(0xFF000000.toInt() or (colorValue and 0xFFFFFF))

private fun lowerBound(items: List<DanmakuItem>, startMs: Long): Int {
    var low = 0
    var high = items.size
    while (low < high) {
        val mid = (low + high) ushr 1
        if (items[mid].startMs < startMs) {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}
