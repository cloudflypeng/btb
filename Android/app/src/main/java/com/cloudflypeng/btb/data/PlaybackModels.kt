package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PlayerResolveResult(
    val bvid: String,
    val aid: Long? = null,
    val cid: Long,
    val page: Int? = null,
    val title: String? = null,
    @SerialName("page_title") val pageTitle: String? = null,
    @SerialName("duration_ms") val durationMs: Long = 0,
    val pages: List<PlaybackPage> = emptyList(),
    val qualities: List<PlaybackQuality> = emptyList(),
    val audio: List<PlaybackAudio> = emptyList(),
    val subtitles: List<PlaybackSubtitle> = emptyList(),
    @SerialName("resume_ms") val resumeMs: Long = 0,
    @SerialName("last_play_cid") val lastPlayCid: Long = 0,
    @SerialName("default_qn") val defaultQn: Long = 80,
    @SerialName("default_codec") val defaultCodec: String = "hevc",
    val playable: Boolean? = null,
    @SerialName("is_preview") val isPreview: Boolean = false,
) {
    val canPlay: Boolean get() = playable ?: qualities.isNotEmpty()
}

@Serializable
data class PlaybackPage(
    val page: Int,
    val cid: Long,
    val part: String? = null,
    @SerialName("duration_ms") val durationMs: Long? = null,
)

@Serializable
data class PlaybackQuality(
    val qn: Long,
    val label: String? = null,
    val codecid: Int? = null,
    val codec: String? = null,
    val codecs: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val bandwidth: Long? = null,
    @SerialName("frame_rate") val frameRate: String? = null,
) {
    val id: String get() = "$qn-${codec ?: "unknown"}"
    val displayLabel: String
        get() {
            val base = label ?: "QN$qn"
            val codecName = codec?.uppercase() ?: return base
            return "$base · $codecName"
        }
}

@Serializable
data class PlaybackAudio(
    val id: Int,
    val codecs: String? = null,
    val bandwidth: Long? = null,
)

@Serializable
data class PlaybackSubtitle(
    val lan: String? = null,
    val label: String? = null,
    val url: String? = null,
    @SerialName("id") val subtitleId: String? = null,
) {
    val id: String get() = subtitleId ?: url ?: lan ?: "unknown"
    val displayLabel: String get() = label ?: lan ?: "字幕"
}

@Serializable
data class StreamSession(
    @SerialName("session_id") val sessionId: String,
    @SerialName("master_url") val masterUrl: String,
    @SerialName("expires_at") val expiresAt: Long? = null,
    @SerialName("duration_ms") val durationMs: Long? = null,
    val video: StreamTrackInfo? = null,
    val audio: StreamTrackInfo? = null,
)

@Serializable
data class StreamTrackInfo(
    val id: Int? = null,
    val codecid: Int? = null,
    val codecs: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val bandwidth: Long? = null,
    val segments: Int? = null,
)
