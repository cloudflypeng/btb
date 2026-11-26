package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LiveFollowingData(
    val list: List<LiveRoomRaw>? = null,
    val pageSize: Int? = null,
    val totalPage: Int? = null,
    @SerialName("live_count") val liveCount: Int? = null,
    val count: Int? = null,
)

@Serializable
data class LiveRoomRaw(
    val roomid: Long? = null,
    val uid: Long? = null,
    val uname: String? = null,
    val face: String? = null,
    @SerialName("room_cover") val roomCover: String? = null,
    val title: String? = null,
    @SerialName("area_name") val areaName: String? = null,
    @SerialName("area_name_v2") val areaNameV2: String? = null,
    @SerialName("parent_area_id") val parentAreaId: Int? = null,
    @SerialName("live_status") val liveStatus: Int? = null,
    @SerialName("text_small") val textSmall: String? = null,
    @SerialName("is_attention") val isAttention: Int? = null,
)

data class LiveRoom(
    val roomId: Long,
    val uid: Long,
    val anchorName: String,
    val avatarUrl: String?,
    val coverUrl: String?,
    val title: String,
    val areaName: String,
    val liveStatus: Int,
    val popularText: String,
    val isFollowed: Boolean,
) {
    val isLive: Boolean get() = liveStatus == 1
    val areaLine: String
        get() = listOf(anchorName, areaName, popularText)
            .filter { it.isNotBlank() }
            .joinToString(" · ")
}

fun LiveRoomRaw.toRoom(): LiveRoom? {
    val id = roomid?.takeIf { it > 0 } ?: return null
    val area = areaNameV2?.takeIf { it.isNotBlank() } ?: areaName.orEmpty()
    return LiveRoom(
        roomId = id,
        uid = uid ?: 0,
        anchorName = uname?.trim().orEmpty(),
        avatarUrl = normalizeMediaUrl(face),
        coverUrl = normalizeMediaUrl(roomCover),
        title = cleanSearchText(title.orEmpty()).trim(),
        areaName = area.trim(),
        liveStatus = liveStatus ?: 0,
        popularText = textSmall?.trim().orEmpty(),
        isFollowed = (isAttention ?: 0) == 1,
    )
}

@Serializable
data class LiveQuality(
    val qn: Long = 0,
    val desc: String? = null,
    val current: Boolean? = null,
)

@Serializable
data class LiveRoomInfo(
    @SerialName("room_id") val roomId: Long = 0,
    val uid: Long = 0,
    val title: String = "",
    @SerialName("anchor_name") val anchorName: String = "",
    @SerialName("anchor_face") val anchorFace: String? = null,
    val cover: String? = null,
    val keyframe: String? = null,
    @SerialName("area_name") val areaName: String = "",
    @SerialName("parent_area_name") val parentAreaName: String = "",
    @SerialName("live_status") val liveStatus: Int = 0,
    val online: Long = 0,
    val attention: Long = 0,
    val watched: Long = 0,
    val description: String? = null,
)

@Serializable
data class LivePlayResult(
    val playable: Boolean = false,
    val reason: String? = null,
    val message: String? = null,
    @SerialName("session_id") val sessionId: String? = null,
    @SerialName("playback_url") val playbackUrl: String? = null,
    @SerialName("expires_at") val expiresAt: Long? = null,
    val quality: LiveQuality? = null,
    val qualities: List<LiveQuality>? = null,
    val room: LiveRoomInfo? = null,
    val format: String? = null,
    val codec: String? = null,
) {
    val unavailableText: String
        get() = when (reason) {
            "not_live" -> "主播暂未开播"
            "hls_unavailable" -> "该直播间暂不支持 HLS 播放"
            "auth_required" -> "登录后才能观看直播"
            else -> message?.takeIf { it.isNotBlank() } ?: "直播加载失败"
        }
}

@Serializable
data class LiveBasicResponse(
    val code: Int = 0,
    val message: String? = null,
)
