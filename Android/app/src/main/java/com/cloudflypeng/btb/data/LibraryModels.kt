package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class HistoryRef(
    val business: String? = null,
    val bvid: String? = null,
    val cid: Long? = null,
)

@Serializable
data class HistoryCursor(
    val max: Long? = null,
    @SerialName("view_at") val viewAt: Long? = null,
)

@Serializable
data class HistoryVideo(
    val kid: Long? = null,
    val bvid: String? = null,
    val title: String? = null,
    val cover: String? = null,
    val duration: Long? = null,
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("author_face") val authorFace: String? = null,
    @SerialName("view_at") val viewAt: Long? = null,
    val progress: Long? = null,
    val history: HistoryRef? = null,
) {
    val resolvedBvid: String? get() = bvid?.takeIf { it.isNotBlank() } ?: history?.bvid
    val coverUrl: String? get() = normalizeMediaUrl(cover)
    val durationText: String
        get() = duration?.takeIf { it > 0 }?.let { formatDurationSeconds(it) } ?: ""
    val viewedText: String get() = relativeTime(viewAt)
}

@Serializable
data class UserHistoryData(
    val list: List<HistoryVideo>? = null,
    val cursor: HistoryCursor? = null,
)

@Serializable
data class UserVideoRaw(
    val aid: Long? = null,
    val bvid: String? = null,
    val title: String? = null,
    val pic: String? = null,
    val author: String? = null,
    val created: Long? = null,
    val description: String? = null,
    val length: String? = null,
    val play: Long? = null,
    @SerialName("video_review") val danmaku: Long? = null,
)

@Serializable
data class UserVideoList(
    val vlist: List<UserVideoRaw>? = null,
)

@Serializable
data class UserVideosData(
    val list: UserVideoList? = null,
    val page: UserVideoPage? = null,
)

@Serializable
data class UserVideoPage(
    val pn: Int? = null,
    val ps: Int? = null,
    val count: Int? = null,
)

fun UserVideoRaw.toVideoItemOrNull(): VideoItem? {
    val id = bvid?.takeIf { it.isNotBlank() } ?: return null
    return VideoItem(
        bvid = id,
        title = title.orEmpty(),
        coverUrl = normalizeMediaUrl(pic),
        ownerName = author.orEmpty(),
        ownerFaceUrl = null,
        viewText = play?.takeIf { it > 0 }?.let { formatCount(it) } ?: "",
        durationText = length.orEmpty(),
        publishedText = relativeTime(created),
        description = description.orEmpty(),
        cid = null,
    )
}

@Serializable
data class FavFolderRaw(
    val id: Long? = null,
    val title: String? = null,
    val cover: String? = null,
    val intro: String? = null,
    @SerialName("media_count") val mediaCount: Int? = null,
    val attr: Int? = null,
    @SerialName("fav_state") val favState: Int? = null,
    val state: Int? = null,
)

data class FavFolder(
    val id: Long,
    val title: String,
    val coverUrl: String?,
    val intro: String,
    val mediaCount: Int,
    val isDefault: Boolean,
)

fun FavFolderRaw.toFolder(): FavFolder? {
    val folderId = id?.takeIf { it > 0 } ?: return null
    return FavFolder(
        id = folderId,
        title = title?.takeIf { it.isNotBlank() } ?: "未命名收藏夹",
        coverUrl = normalizeMediaUrl(cover),
        intro = intro.orEmpty(),
        mediaCount = mediaCount ?: 0,
        isDefault = (favState ?: 0) == 1 || (attr ?: 0) == 1,
    )
}

@Serializable
data class FavFoldersData(
    val list: List<FavFolderRaw>? = null,
    val count: Int? = null,
)

@Serializable
data class FavUpper(
    val mid: Long? = null,
    val name: String? = null,
    val face: String? = null,
)

@Serializable
data class FavCountInfo(
    val play: Int? = null,
)

@Serializable
data class FavMedia(
    val id: Long? = null,
    val type: Int? = null,
    val bvid: String? = null,
    val title: String? = null,
    val cover: String? = null,
    val duration: Int? = null,
    val intro: String? = null,
    val pubtime: Long? = null,
    @SerialName("fav_time") val favTime: Long? = null,
    val upper: FavUpper? = null,
    @SerialName("cnt_info") val countInfo: FavCountInfo? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(cover)
    val durationText: String get() = duration?.takeIf { it > 0 }?.let { formatDurationSeconds(it.toLong()) } ?: ""
    val viewText: String get() = countInfo?.play?.takeIf { it > 0 }?.let { formatCount(it.toLong()) } ?: ""
}

fun FavMedia.toVideoItemOrNull(): VideoItem? {
    val videoId = bvid?.takeIf { it.isNotBlank() } ?: return null
    return VideoItem(
        bvid = videoId,
        title = title.orEmpty(),
        coverUrl = coverUrl,
        ownerName = upper?.name.orEmpty(),
        ownerFaceUrl = normalizeMediaUrl(upper?.face),
        viewText = viewText,
        durationText = durationText,
        publishedText = relativeTime(pubtime),
        description = intro.orEmpty(),
        cid = null,
    )
}

@Serializable
data class FavListData(
    val info: FavFolderRaw? = null,
    val medias: List<FavMedia>? = null,
    @SerialName("has_more") val hasMore: Boolean? = null,
)

@Serializable
data class LaterData(
    val list: List<HotVideo>? = null,
    val count: Int? = null,
)

data class WatchLaterEntry(
    val aid: Long,
    val video: VideoItem,
)

@Serializable
data class DownloadItem(
    val id: String = "",
    val bvid: String = "",
    val cid: Long = 0,
    val title: String = "",
    val cover: String? = null,
    val owner: String? = null,
    val qn: Int? = null,
    val codec: String? = null,
    @SerialName("duration_ms") val durationMs: Long? = null,
    val status: String = "queued",
    val error: String? = null,
    @SerialName("downloaded_bytes") val downloadedBytes: Long = 0,
    @SerialName("total_bytes") val totalBytes: Long = 0,
    @SerialName("created_at") val createdAt: Long = 0,
    @SerialName("updated_at") val updatedAt: Long = 0,
) {
    val progress: Float
        get() = if (totalBytes > 0) (downloadedBytes.toFloat() / totalBytes).coerceIn(0f, 1f) else 0f
    val statusText: String
        get() = when (status) {
            "queued" -> "等待中"
            "downloading" -> "下载中"
            "paused" -> "已暂停"
            "completed" -> "已完成"
            "failed" -> "下载失败"
            else -> status
        }
    val sizeText: String
        get() = formatBytes(if (totalBytes > 0) totalBytes else downloadedBytes)
}

@Serializable
data class DownloadSummary(
    val completed: Int = 0,
    val downloading: Int = 0,
    val failed: Int = 0,
    val paused: Int = 0,
    val queued: Int = 0,
    val total: Int = 0,
)

@Serializable
data class DownloadListData(
    val items: List<DownloadItem> = emptyList(),
    val summary: DownloadSummary = DownloadSummary(),
    @SerialName("used_bytes") val usedBytes: Long = 0,
    @SerialName("disk_bytes") val diskBytes: Long = 0,
    @SerialName("free_bytes") val freeBytes: Long = 0,
)

internal fun formatDurationSeconds(totalSeconds: Long): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return if (minutes >= 60) {
        "%d:%02d:%02d".format(minutes / 60, minutes % 60, seconds)
    } else {
        "%d:%02d".format(minutes, seconds)
    }
}

internal fun formatBytes(bytes: Long): String = when {
    bytes >= 1L shl 30 -> String.format(java.util.Locale.CHINA, "%.1f GB", bytes / (1L shl 30).toDouble())
    bytes >= 1L shl 20 -> String.format(java.util.Locale.CHINA, "%.0f MB", bytes / (1L shl 20).toDouble())
    bytes >= 1L shl 10 -> String.format(java.util.Locale.CHINA, "%.0f KB", bytes / (1L shl 10).toDouble())
    else -> "$bytes B"
}
