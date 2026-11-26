package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class UpstreamResponse<T>(
    val code: Int = 0,
    val message: String? = null,
    val data: T? = null,
)

@Serializable
data class RecommendData(
    val item: List<HotVideo> = emptyList(),
)

@Serializable
data class HotData(
    val list: List<HotVideo> = emptyList(),
)

@Serializable
data class HotVideo(
    val aid: Long? = null,
    val bvid: String? = null,
    val cid: Long? = null,
    val title: String? = null,
    val pic: String? = null,
    @SerialName("cover43") val cover43: String? = null,
    val desc: String? = null,
    val duration: Int? = null,
    val pubdate: Long? = null,
    val owner: HotOwner? = null,
    val stat: HotStat? = null,
)

@Serializable
data class HotOwner(
    val mid: Long? = null,
    val name: String? = null,
    val face: String? = null,
)

@Serializable
data class HotStat(
    val view: Long? = null,
    val danmaku: Long? = null,
    val like: Long? = null,
)

data class VideoItem(
    val bvid: String,
    val title: String,
    val coverUrl: String?,
    val ownerName: String,
    val ownerFaceUrl: String?,
    val viewText: String,
    val durationText: String,
    val publishedText: String,
    val description: String,
    val cid: Long? = null,
)

internal fun normalizeMediaUrl(raw: String?): String? {
    var value = raw?.trim().orEmpty()
    if (value.isEmpty()) return null
    if (value.startsWith("//")) {
        value = "https:$value"
    } else if (value.startsWith("http://")) {
        value = "https://${value.removePrefix("http://")}"
    }
    return value
}
