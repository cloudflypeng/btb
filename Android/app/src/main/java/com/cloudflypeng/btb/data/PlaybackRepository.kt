package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class PlaybackRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun resolve(
        bvid: String,
        page: Int = 1,
        qn: Long = 80,
        codec: String = "avc",
    ): PlayerResolveResult {
        val result = core.call(
            "player.resolve",
            buildJsonObject {
                put("bvid", bvid)
                put("page", page)
                put("qn", qn)
                put("codec", codec)
            },
        )
        return json.decodeFromJsonElement(result)
    }

    suspend fun startStream(
        bvid: String,
        cid: Long,
        page: Int,
        qn: Long,
        codec: String,
    ): StreamSession {
        val result = core.call(
            "stream.start",
            buildJsonObject {
                put("bvid", bvid)
                put("cid", cid)
                put("page", page)
                put("qn", qn)
                put("codec", codec)
            },
        )
        return json.decodeFromJsonElement(result)
    }

    suspend fun stopStream(sessionId: String) {
        runCatching {
            core.call("stream.stop", buildJsonObject { put("session_id", sessionId) })
        }
    }

    suspend fun reportProgress(
        bvid: String,
        cid: Long,
        progressMs: Long,
        event: String,
    ) {
        runCatching {
            core.call(
                "player.progress",
                buildJsonObject {
                    put("bvid", bvid)
                    put("cid", cid)
                    put("progress_ms", progressMs)
                    put("event", event)
                },
            )
        }
    }

    suspend fun related(bvid: String): List<VideoItem> {
        val result = core.call("video.related", buildJsonObject { put("bvid", bvid) })
        val response = json.decodeFromJsonElement<UpstreamResponse<List<HotVideo>>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "推荐视频加载失败")
        }
        return response.data.orEmpty().mapNotNull { it.toVideoItem() }
    }

    suspend fun subtitleVtt(url: String): String {
        val result = core.call("video.subtitle_vtt", buildJsonObject { put("url", url) })
        val response = json.decodeFromJsonElement<SubtitleVttResponse>(result)
        return response.vtt
    }
}

@Serializable
data class SubtitleVttResponse(
    val vtt: String = "",
    @SerialName("cue_count") val cueCount: Int? = null,
)

data class SubtitleCue(
    val startMs: Long,
    val endMs: Long,
    val text: String,
)

object WebVttParser {
    private val timingPattern =
        Regex("""(\d{1,2}):(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[.,](\d{3})""")
    private val shortTimingPattern =
        Regex("""(\d{1,2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{1,2}):(\d{2})[.,](\d{3})""")
    private val tagPattern = Regex("""<[^>]+>""")

    fun parse(source: String): List<SubtitleCue> {
        val blocks = source.replace("\r\n", "\n").split("\n\n")
        val cues = buildList {
            for (block in blocks) {
                val lines = block.split("\n")
                val timingIndex = lines.indexOfFirst { it.contains("-->") }
                if (timingIndex < 0) continue
                val (start, end) = parseTiming(lines[timingIndex].trim()) ?: continue
                if (end < start) continue
                val text = lines.drop(timingIndex + 1)
                    .joinToString("\n")
                    .replace(tagPattern, "")
                    .replace("&amp;", "&")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&nbsp;", " ")
                    .trim()
                if (text.isEmpty()) continue
                add(SubtitleCue(startMs = start, endMs = end, text = text))
            }
        }
        return cues.sortedBy { it.startMs }
    }

    private fun parseTiming(line: String): Pair<Long, Long>? {
        timingPattern.find(line)?.let { match ->
            return timestamp(
                match.groupValues[1].toLong(),
                match.groupValues[2].toLong(),
                match.groupValues[3].toLong(),
                match.groupValues[4].toLong(),
            ) to timestamp(
                match.groupValues[5].toLong(),
                match.groupValues[6].toLong(),
                match.groupValues[7].toLong(),
                match.groupValues[8].toLong(),
            )
        }
        shortTimingPattern.find(line)?.let { match ->
            return timestamp(
                0,
                match.groupValues[1].toLong(),
                match.groupValues[2].toLong(),
                match.groupValues[3].toLong(),
            ) to timestamp(
                0,
                match.groupValues[4].toLong(),
                match.groupValues[5].toLong(),
                match.groupValues[6].toLong(),
            )
        }
        return null
    }

    private fun timestamp(hours: Long, minutes: Long, seconds: Long, millis: Long): Long =
        ((hours * 3600 + minutes * 60 + seconds) * 1000 + millis)
}

internal fun Throwable.playbackMessage(): String {
    val raw = message?.takeIf { it.isNotBlank() } ?: return "视频加载失败，请稍后重试"
    if (raw.contains("context deadline exceeded") || raw.contains("i/o timeout")) {
        return "视频加载超时，请检查网络后重试"
    }
    val cleaned = raw
        .replace(URL_PATTERN, "")
        .replace(WHITESPACE_PATTERN, " ")
        .trim()
        .trim(':', ',', '，', '-', '\'')
        .trim()
    return when {
        cleaned.isEmpty() -> "视频加载失败，请稍后重试"
        cleaned.length > 140 -> cleaned.take(140) + "…"
        else -> cleaned
    }
}

private val URL_PATTERN = Regex("https?://\\S+")
private val WHITESPACE_PATTERN = Regex("\\s+")
