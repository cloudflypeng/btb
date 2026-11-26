package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

@Serializable
data class DynamicFeedData(
    val items: List<DynamicRawItem>? = null,
    val offset: String? = null,
    @SerialName("has_more") val hasMore: Boolean = false,
    @SerialName("update_num") val updateNum: Int = 0,
)

@Serializable
data class DynamicRawItem(
    @SerialName("id_str") val idStr: String? = null,
    val type: String? = null,
    val basic: DynamicBasicRaw? = null,
    val modules: DynamicModulesRaw? = null,
    val orig: DynamicOrigRaw? = null,
)

@Serializable
data class DynamicBasicRaw(
    @SerialName("comment_id_str") val commentIdStr: String? = null,
    @SerialName("comment_type") val commentType: Int? = null,
)

@Serializable
data class DynamicOrigRaw(
    @SerialName("id_str") val idStr: String? = null,
    val type: String? = null,
    val modules: DynamicModulesRaw? = null,
)

@Serializable
data class DynamicModulesRaw(
    @SerialName("module_author") val author: DynamicAuthorRaw? = null,
    @SerialName("module_dynamic") val dynamic: DynamicContentRaw? = null,
    @SerialName("module_stat") val stat: DynamicStatRaw? = null,
)

@Serializable
data class DynamicAuthorRaw(
    val mid: Long? = null,
    val name: String? = null,
    val face: String? = null,
    @SerialName("pub_time") val pubTime: String? = null,
    @SerialName("pub_ts") val pubTs: String? = null,
    val following: Boolean? = null,
    @SerialName("is_top") val isTop: Boolean? = null,
    @SerialName("pub_action") val pubAction: String? = null,
)

@Serializable
data class DynamicContentRaw(
    val desc: DynamicTextRaw? = null,
    val major: DynamicMajorRaw? = null,
)

@Serializable
data class DynamicTextRaw(
    val text: String? = null,
    @SerialName("rich_text_nodes") val richTextNodes: List<DynamicRichNodeRaw>? = null,
)

@Serializable
data class DynamicRichNodeRaw(
    val text: String? = null,
)

@Serializable
data class DynamicMajorRaw(
    val type: String? = null,
    val archive: DynamicArchiveRaw? = null,
    val opus: DynamicOpusRaw? = null,
    val draw: DynamicDrawRaw? = null,
    val article: DynamicArticleRaw? = null,
    val pgc: DynamicPgcRaw? = null,
    val live: DynamicLiveRaw? = null,
    @SerialName("live_rcmd") val liveRcmd: DynamicLiveRcmdRaw? = null,
)

@Serializable
data class DynamicArchiveRaw(
    val bvid: String? = null,
    val title: String? = null,
    val cover: String? = null,
    val desc: String? = null,
    @SerialName("duration_text") val durationText: String? = null,
    val stat: DynamicArchiveStatRaw? = null,
)

@Serializable
data class DynamicArchiveStatRaw(
    val play: String? = null,
    val danmaku: String? = null,
)

@Serializable
data class DynamicOpusRaw(
    val title: String? = null,
    val summary: DynamicSummaryRaw? = null,
    val pics: List<DynamicPictureRaw>? = null,
)

@Serializable
data class DynamicSummaryRaw(
    @SerialName("rich_text_nodes") val richTextNodes: List<DynamicRichNodeRaw>? = null,
)

@Serializable
data class DynamicPictureRaw(
    val url: String? = null,
    val src: String? = null,
    val width: Int? = null,
    val height: Int? = null,
)

@Serializable
data class DynamicDrawRaw(
    val items: List<DynamicPictureRaw>? = null,
)

@Serializable
data class DynamicArticleRaw(
    val id: JsonElement? = null,
    val title: String? = null,
    val desc: String? = null,
    val covers: List<String>? = null,
)

@Serializable
data class DynamicPgcRaw(
    @SerialName("season_id") val seasonId: JsonElement? = null,
    @SerialName("epid") val epid: JsonElement? = null,
    val title: String? = null,
    val cover: String? = null,
    val badge: DynamicBadgeRaw? = null,
)

@Serializable
data class DynamicBadgeRaw(
    val text: String? = null,
)

@Serializable
data class DynamicLiveRaw(
    @SerialName("room_id") val roomId: Long? = null,
    val title: String? = null,
    val cover: String? = null,
    @SerialName("area_name") val areaName: String? = null,
)

@Serializable
data class DynamicLiveRcmdRaw(
    val content: String? = null,
)

@Serializable
data class DynamicLiveRcmdContent(
    @SerialName("live_play_info") val livePlayInfo: DynamicLivePlayInfoRaw? = null,
)

@Serializable
data class DynamicLivePlayInfoRaw(
    @SerialName("room_id") val roomId: Long? = null,
    val title: String? = null,
    val cover: String? = null,
    @SerialName("area_name") val areaName: String? = null,
)

@Serializable
data class DynamicStatRaw(
    val like: DynamicCountRaw? = null,
    val comment: DynamicCountRaw? = null,
    val forward: DynamicCountRaw? = null,
)

@Serializable
data class DynamicCountRaw(
    val count: Int? = null,
    val status: Boolean? = null,
)

data class DynamicVideo(
    val bvid: String,
    val title: String,
    val coverUrl: String?,
    val durationText: String,
    val playText: String,
    val desc: String,
)

data class DynamicPicture(
    val url: String,
    val width: Int,
    val height: Int,
)

data class DynamicArticle(
    val id: String,
    val title: String,
    val summary: String,
    val coverUrl: String?,
)

data class DynamicPgc(
    val seasonId: String,
    val episodeId: String,
    val title: String,
    val coverUrl: String?,
    val badge: String,
)

data class DynamicLive(
    val roomId: Long,
    val title: String,
    val coverUrl: String?,
    val areaName: String,
)

data class DynamicAttachment(
    val video: DynamicVideo? = null,
    val pictures: List<DynamicPicture> = emptyList(),
    val article: DynamicArticle? = null,
    val pgc: DynamicPgc? = null,
    val live: DynamicLive? = null,
) {
    val isEmpty: Boolean
        get() = video == null && pictures.isEmpty() && article == null && pgc == null && live == null
}

data class DynamicOriginal(
    val id: String,
    val authorName: String,
    val text: String,
    val attachment: DynamicAttachment,
)

data class DynamicCard(
    val id: String,
    val type: String,
    val authorName: String,
    val authorAvatarUrl: String?,
    val authorMid: Long?,
    val pubTime: String,
    val pubAction: String,
    val text: String,
    val attachment: DynamicAttachment,
    val orig: DynamicOriginal?,
    val likeCount: Int,
    val commentCount: Int,
    val forwardCount: Int,
    val liked: Boolean,
)

data class DynamicFeedPage(
    val items: List<DynamicCard>,
    val offset: String?,
    val hasMore: Boolean,
)

class DynamicRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun feed(type: String, offset: String? = null): DynamicFeedPage {
        val result = core.call(
            "dynamic.feed",
            buildJsonObject {
                put("type", type)
                if (!offset.isNullOrBlank()) put("offset", offset)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<DynamicFeedData>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "动态加载失败")
        }
        val data = response.data ?: DynamicFeedData()
        return DynamicFeedPage(
            items = data.items.orEmpty().mapNotNull { it.toCard() },
            offset = data.offset,
            hasMore = data.hasMore,
        )
    }

    suspend fun like(id: String, liked: Boolean) {
        val response = json.decodeFromJsonElement<UpstreamResponse<JsonElement>>(
            core.call(
                "dynamic.like",
                buildJsonObject {
                    put("id", id)
                    put("up", if (liked) 1 else 2)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "点赞失败")
        }
    }
}

private val dynamicJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

internal fun DynamicRawItem.toCard(): DynamicCard? {
    val id = idStr ?: return null
    val modules = modules ?: return null
    val author = modules.author
    val authorName = author?.name?.trim().takeUnless { it.isNullOrEmpty() } ?: "哔哩哔哩用户"
    val text = textFrom(modules.dynamic)
    val attachment = attachmentFrom(modules.dynamic?.major)
    if (text.isEmpty() && attachment.isEmpty) return null
    return DynamicCard(
        id = id,
        type = type.orEmpty(),
        authorName = authorName,
        authorAvatarUrl = normalizeMediaUrl(author?.face),
        authorMid = author?.mid,
        pubTime = author?.pubTime?.trim().takeUnless { it.isNullOrEmpty() }
            ?: relativeTime(author?.pubTs?.toLongOrNull()),
        pubAction = author?.pubAction.orEmpty(),
        text = text,
        attachment = attachment,
        orig = orig?.toOriginal(),
        likeCount = modules.stat?.like?.count ?: 0,
        commentCount = modules.stat?.comment?.count ?: 0,
        forwardCount = modules.stat?.forward?.count ?: 0,
        liked = modules.stat?.like?.status == true,
    )
}

private fun DynamicOrigRaw.toOriginal(): DynamicOriginal? {
    val id = idStr ?: return null
    val modules = modules ?: return null
    return DynamicOriginal(
        id = id,
        authorName = modules.author?.name?.trim().takeUnless { it.isNullOrEmpty() } ?: "哔哩哔哩用户",
        text = textFrom(modules.dynamic),
        attachment = attachmentFrom(modules.dynamic?.major),
    )
}

private fun textFrom(content: DynamicContentRaw?): String {
    if (content == null) return ""
    var value = content.desc?.text ?: nodesText(content.desc?.richTextNodes)
    if (value.isBlank()) {
        val opus = content.major?.opus
        if (opus != null) {
            value = nodesText(opus.summary?.richTextNodes)
            if (value.isBlank()) value = opus.title.orEmpty()
        } else {
            val article = content.major?.article
            if (article != null) value = article.desc ?: article.title.orEmpty()
        }
    }
    return value.trim()
}

private fun nodesText(nodes: List<DynamicRichNodeRaw>?): String =
    nodes.orEmpty().mapNotNull { it.text }.joinToString("")

private fun attachmentFrom(major: DynamicMajorRaw?): DynamicAttachment {
    if (major == null) return DynamicAttachment()

    val archive = major.archive
    val video = archive?.bvid?.takeIf { it.isNotBlank() }?.let { bvid ->
        DynamicVideo(
            bvid = bvid,
            title = archive.title.orEmpty(),
            coverUrl = normalizeMediaUrl(archive.cover),
            durationText = archive.durationText.orEmpty(),
            playText = archive.stat?.play.orEmpty(),
            desc = archive.desc.orEmpty(),
        )
    }

    val pictureSource = major.opus?.pics ?: major.draw?.items
    val pictures = pictureSource.orEmpty().mapNotNull { picture ->
        val url = normalizeMediaUrl(picture.url) ?: normalizeMediaUrl(picture.src) ?: return@mapNotNull null
        DynamicPicture(url = url, width = picture.width ?: 0, height = picture.height ?: 0)
    }

    val article = major.article?.let { raw ->
        DynamicArticle(
            id = raw.id.asIdString().orEmpty(),
            title = raw.title.orEmpty(),
            summary = raw.desc.orEmpty(),
            coverUrl = normalizeMediaUrl(raw.covers?.firstOrNull()),
        )
    }

    val pgc = major.pgc?.let { raw ->
        DynamicPgc(
            seasonId = raw.seasonId.asIdString().orEmpty(),
            episodeId = raw.epid.asIdString().orEmpty(),
            title = raw.title.orEmpty(),
            coverUrl = normalizeMediaUrl(raw.cover),
            badge = raw.badge?.text.orEmpty(),
        )
    }

    val live = major.live?.toLive() ?: major.liveRcmd?.parseLive()

    return DynamicAttachment(
        video = video,
        pictures = pictures,
        article = article,
        pgc = pgc,
        live = live,
    )
}

private fun DynamicLiveRaw.toLive(): DynamicLive? {
    val roomId = roomId ?: return null
    return DynamicLive(
        roomId = roomId,
        title = title?.takeIf { it.isNotBlank() } ?: "直播",
        coverUrl = normalizeMediaUrl(cover),
        areaName = areaName.orEmpty(),
    )
}

private fun DynamicLiveRcmdRaw.parseLive(): DynamicLive? {
    val payload = content?.takeIf { it.isNotBlank() } ?: return null
    val parsed = runCatching {
        dynamicJson.decodeFromString<DynamicLiveRcmdContent>(payload)
    }.getOrNull() ?: return null
    val info = parsed.livePlayInfo ?: return null
    val roomId = info.roomId ?: return null
    return DynamicLive(
        roomId = roomId,
        title = info.title?.takeIf { it.isNotBlank() } ?: "直播",
        coverUrl = normalizeMediaUrl(info.cover),
        areaName = info.areaName.orEmpty(),
    )
}

private fun JsonElement?.asIdString(): String? =
    (this as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
