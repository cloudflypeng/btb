package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put
import kotlin.math.max

@Serializable
data class DanmakuSegment(
    val elems: List<DanmakuRawElem>? = null,
    val state: Long? = null,
)

@Serializable
data class DanmakuRawElem(
    val id: Long = 0,
    @SerialName("id_str") val idStr: String? = null,
    val progress: Long = 0,
    val mode: Long = 1,
    val fontsize: Long = 25,
    val color: Long = 0xFFFFFF,
    val content: String? = null,
)

data class DanmakuItem(
    val id: String,
    val startMs: Long,
    val mode: Int,
    val text: String,
    val colorValue: Int,
    val fontSize: Float,
    val widthUnits: Float,
    val lane: Int = -1,
)

fun DanmakuRawElem.toDanmakuItem(): DanmakuItem? {
    val body = content?.trim().orEmpty()
    if (body.isEmpty() || progress < 0) return null
    val itemMode = mode.toInt()
    if (itemMode != 1 && itemMode != 4 && itemMode != 5) return null
    val size = fontsize.toFloat().coerceIn(12f, 40f)
    return DanmakuItem(
        id = idStr ?: id.toString(),
        startMs = progress,
        mode = itemMode,
        text = body,
        colorValue = (color.toInt() and 0xFFFFFF),
        fontSize = size,
        widthUnits = measureDanmakuWidth(body),
        lane = -1,
    )
}

class DanmakuRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun fetch(cid: Long, segmentIndex: Int): List<DanmakuItem> {
        val result = core.call(
            "danmaku.seg",
            buildJsonObject {
                put("cid", cid)
                put("segment_index", segmentIndex)
                put("type", 1)
            },
        )
        val segment = json.decodeFromJsonElement<DanmakuSegment>(result)
        return segment.elems.orEmpty().mapNotNull { it.toDanmakuItem() }
    }

    suspend fun send(cid: Long, bvid: String, progressMs: Long, content: String) {
        val result = core.call(
            "danmaku.send",
            buildJsonObject {
                put("cid", cid)
                put("bvid", bvid)
                put("msg", content)
                put("progress", progressMs.coerceAtLeast(0))
                put("mode", 1)
                put("color", 16_777_215)
            },
        )
        val response = json.decodeFromJsonElement<DanmakuSendResponse>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "弹幕发送失败")
        }
    }
}

@Serializable
data class DanmakuSendResponse(
    val code: Int = 0,
    val message: String? = null,
)

fun assignDanmakuLanes(items: List<DanmakuItem>, speed: Double = 1.0): List<DanmakuItem> {
    val lanes = items.sortedBy { it.startMs }.map { it.copy(lane = -1) }.toMutableList()
    val scrollFreeAt = DoubleArray(SCROLL_LANE_COUNT)
    val topFreeAt = DoubleArray(STATIC_LANE_COUNT)
    val bottomFreeAt = DoubleArray(STATIC_LANE_COUNT)
    val scrollLifetime = 8.0 / max(0.25, speed)

    for (index in lanes.indices) {
        val item = lanes[index]
        val start = item.startMs / 1000.0
        if (item.mode == 1) {
            val width = max(40.0, item.widthUnits.toDouble() * item.fontSize)
            // Hold the lane until this comment's tail clears a narrow viewport.
            val clearance = scrollLifetime * (width + 24) / (400 + width)
            var chosen = -1
            var earliest = Double.MAX_VALUE
            var earliestLane = 0
            for (lane in 0 until SCROLL_LANE_COUNT) {
                if (scrollFreeAt[lane] <= start) {
                    chosen = lane
                    break
                }
                if (scrollFreeAt[lane] < earliest) {
                    earliest = scrollFreeAt[lane]
                    earliestLane = lane
                }
            }
            if (chosen < 0) {
                if (earliest - start >= 0.35) continue
                chosen = earliestLane
            }
            lanes[index] = item.copy(lane = chosen)
            scrollFreeAt[chosen] = start + clearance
        } else {
            val isTop = item.mode == 5
            val freeAt = if (isTop) topFreeAt else bottomFreeAt
            var chosen = -1
            for (lane in 0 until STATIC_LANE_COUNT) {
                if (freeAt[lane] <= start) {
                    chosen = lane
                    break
                }
            }
            if (chosen < 0) continue
            lanes[index] = item.copy(lane = chosen)
            freeAt[chosen] = start + 4.0
        }
    }
    return lanes
}

private fun measureDanmakuWidth(text: String): Float {
    var units = 0f
    var index = 0
    while (index < text.length) {
        val codePoint = text.codePointAt(index)
        units += when {
            codePoint == 0x20 -> 0.35f
            codePoint in 0x21..0x7E -> 0.58f
            codePoint in 0x2E80..0x9FFF ||
                codePoint in 0xAC00..0xD7AF ||
                codePoint in 0xF900..0xFAFF ||
                codePoint in 0xFE30..0xFE4F ||
                codePoint in 0xFF00..0xFFEF -> 1f

            else -> 0.85f
        }
        index += Character.charCount(codePoint)
    }
    return max(units, 2f)
}

private const val SCROLL_LANE_COUNT = 10
private const val STATIC_LANE_COUNT = 3
