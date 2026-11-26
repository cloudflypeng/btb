package com.cloudflypeng.btb.data

import android.text.Html
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put
import java.util.Locale

class FeedRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun recommend(freshIndex: Int, pageSize: Int = 20): List<VideoItem> {
        val result = core.call(
            "video.recommend",
            buildJsonObject {
                put("ps", pageSize)
                put("desktop", true)
                put("fresh_idx", freshIndex)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<RecommendData>>(result)
        requireSuccess(response)
        return response.data?.item.orEmpty().mapNotNull { it.toVideoItem() }
    }

    suspend fun hot(page: Int, pageSize: Int = 20): List<VideoItem> {
        val result = core.call(
            "video.hot",
            buildJsonObject {
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<HotData>>(result)
        requireSuccess(response)
        return response.data?.list.orEmpty().mapNotNull { it.toVideoItem() }
    }

    suspend fun ranking(): List<VideoItem> {
        val result = core.call(
            "video.rank",
            buildJsonObject {
                put("rid", 0)
                put("type", "all")
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<HotData>>(result)
        requireSuccess(response)
        return response.data?.list.orEmpty().mapNotNull { it.toVideoItem() }
    }

    private fun requireSuccess(response: UpstreamResponse<*>) {
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "上游接口返回错误")
        }
    }
}

internal fun HotVideo.toVideoItem(): VideoItem? {
    val id = bvid?.takeIf { it.isNotBlank() } ?: return null
    val viewCount = stat?.view ?: 0
    return VideoItem(
        bvid = id,
        title = cleanHtml(title),
        coverUrl = normalizeMediaUrl(pic ?: cover43),
        ownerName = owner?.name?.takeIf { it.isNotBlank() } ?: "未知 UP 主",
        ownerFaceUrl = normalizeMediaUrl(owner?.face),
        viewText = formatCount(viewCount),
        durationText = formatDuration(duration ?: 0),
        publishedText = relativeTime(pubdate),
        description = cleanHtml(desc),
        cid = cid,
    )
}

private fun cleanHtml(raw: String?): String {
    if (raw.isNullOrBlank()) return ""
    return Html.fromHtml(raw, Html.FROM_HTML_MODE_LEGACY).toString().trim()
}

private fun formatDuration(seconds: Int): String {
    if (seconds <= 0) return ""
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    val secs = seconds % 60
    return if (hours > 0) {
        String.format(Locale.CHINA, "%d:%02d:%02d", hours, minutes, secs)
    } else {
        String.format(Locale.CHINA, "%d:%02d", minutes, secs)
    }
}

