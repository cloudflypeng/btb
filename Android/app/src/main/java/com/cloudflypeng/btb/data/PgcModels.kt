package com.cloudflypeng.btb.data

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.nullable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement

@Serializable
data class UpstreamResultResponse<T>(
    val code: Int = 0,
    val message: String? = null,
    val result: T? = null,
)

@Serializable
data class AnimeRating(
    val score: Double? = null,
    val count: Int? = null,
) {
    val text: String
        get() = score?.takeIf { it > 0 }?.let {
            String.format(java.util.Locale.CHINA, "%.1f", it)
        } ?: "暂无评分"
}

// pgc.rank returns the rating as "8.8分"; pgc.info as {score, count}.
object FlexibleRatingSerializer : KSerializer<AnimeRating?> {
    private val delegate = AnimeRating.serializer().nullable

    override val descriptor: SerialDescriptor = delegate.descriptor

    override fun deserialize(decoder: Decoder): AnimeRating? {
        val input = decoder as? JsonDecoder ?: return delegate.deserialize(decoder)
        val element = input.decodeJsonElement()
        if (element is JsonNull) return null
        val primitive = element as? JsonPrimitive
        if (primitive != null) {
            val score = primitive.contentOrNull?.removeSuffix("分")?.trim()?.toDoubleOrNull()
            return score?.let { AnimeRating(score = it) }
        }
        return input.json.decodeFromJsonElement(AnimeRating.serializer(), element)
    }

    override fun serialize(encoder: Encoder, value: AnimeRating?) {
        delegate.serialize(encoder, value)
    }
}

@Serializable
data class AnimeArea(val name: String? = null)

@Serializable
data class AnimeNewEp(
    val desc: String? = null,
    val title: String? = null,
    @SerialName("index_show") val indexShow: String? = null,
)

@Serializable
data class AnimeSeasonStat(
    val views: Long? = null,
    val danmakus: Long? = null,
    val favorites: Long? = null,
    @SerialName("follow_text") val followText: String? = null,
)

@Serializable
data class AnimeUserStatus(
    val follow: Int? = null,
    @SerialName("follow_status") val followStatus: Int? = null,
    val pay: Int? = null,
    val login: Int? = null,
) {
    val isFollowing: Boolean get() = (follow ?: 0) == 1 || (followStatus ?: 0) == 2
}

@Serializable
data class AnimePublish(
    @SerialName("is_finish") val isFinish: Int? = null,
    @SerialName("is_started") val isStarted: Int? = null,
    @SerialName("pub_time_show") val pubTimeShow: String? = null,
)

@Serializable
data class AnimeEpisode(
    @SerialName("ep_id") val epId: Long = 0,
    val cid: Long? = null,
    val aid: Long? = null,
    val bvid: String? = null,
    val title: String = "",
    @SerialName("long_title") val longTitle: String? = null,
    @SerialName("show_title") val showTitle: String? = null,
    val cover: String? = null,
    val duration: Long? = null,
    val badge: String? = null,
    @SerialName("pub_time") val pubTime: Long? = null,
) {
    val displayTitle: String
        get() = longTitle?.takeIf { it.isNotBlank() } ?: title
    val subtitleText: String
        get() = listOfNotNull(
            title.takeIf { it.isNotBlank() && it != displayTitle },
            badge?.takeIf { it.isNotBlank() },
        ).joinToString(" · ")
    val durationText: String
        get() = duration?.takeIf { it > 0 }?.let { seconds ->
            val total = seconds / 1000
            val minutes = total / 60
            val rest = total % 60
            "%d:%02d".format(minutes, rest)
        } ?: ""
}

@Serializable
data class AnimeSeason(
    @SerialName("season_id") val seasonId: Long = 0,
    @SerialName("media_id") val mediaId: Long? = null,
    val title: String = "",
    @SerialName("season_title") val seasonTitle: String? = null,
    val cover: String? = null,
    @SerialName("square_cover") val squareCover: String? = null,
    @SerialName("bkg_cover") val backgroundCover: String? = null,
    val evaluate: String? = null,
    val total: Int? = null,
    val rating: AnimeRating? = null,
    val areas: List<AnimeArea>? = null,
    @SerialName("new_ep") val newEp: AnimeNewEp? = null,
    val episodes: List<AnimeEpisode>? = null,
    val stat: AnimeSeasonStat? = null,
    @SerialName("user_status") val userStatus: AnimeUserStatus? = null,
    val publish: AnimePublish? = null,
    @SerialName("type_name") val typeName: String? = null,
    val subtitle: String? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(cover ?: squareCover)
    val backgroundUrl: String? get() = normalizeMediaUrl(backgroundCover) ?: coverUrl
    val isFollowing: Boolean get() = userStatus?.isFollowing ?: false
    val areaText: String get() = areas.orEmpty().mapNotNull { it.name }.filter { it.isNotBlank() }.joinToString(" · ")
    val episodeCount: Int get() = episodes?.size ?: 0
    val progressText: String
        get() = listOfNotNull(
            newEp?.indexShow?.takeIf { it.isNotBlank() },
            publish?.pubTimeShow?.takeIf { it.isNotBlank() },
            typeName?.takeIf { it.isNotBlank() },
            areaText.takeIf { it.isNotBlank() },
        ).joinToString(" · ")
    val statsText: String
        get() = listOfNotNull(
            stat?.views?.takeIf { it > 0 }?.let { "${formatCount(it)}播放" },
            stat?.favorites?.takeIf { it > 0 }?.let { "${formatCount(it)}追番" },
        ).joinToString(" · ")
}

@Serializable
data class AnimeTimelineEpisode(
    @SerialName("season_id") val seasonId: Long = 0,
    @SerialName("episode_id") val episodeId: Long? = null,
    val title: String = "",
    val cover: String? = null,
    @SerialName("square_cover") val squareCover: String? = null,
    @SerialName("pub_index") val pubIndex: String? = null,
    @SerialName("pub_time") val pubTime: String? = null,
    val published: Int? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(squareCover ?: cover)
    val isPublished: Boolean get() = (published ?: 1) == 1
}

@Serializable
data class AnimeTimelineDay(
    val date: String = "",
    @SerialName("day_of_week") val dayOfWeek: Int = 1,
    @SerialName("is_today") val isToday: Int? = null,
    val episodes: List<AnimeTimelineEpisode> = emptyList(),
) {
    val isTodayDay: Boolean get() = (isToday ?: 0) == 1
    val weekdayTitle: String
        get() {
            val names = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
            return names[((dayOfWeek - 1) % 7 + 7) % 7]
        }
}

@Serializable
data class AnimeRankItem(
    @SerialName("season_id") val seasonId: Long = 0,
    val title: String = "",
    val cover: String? = null,
    @SerialName("new_ep") val newEp: AnimeNewEp? = null,
    @Serializable(with = FlexibleRatingSerializer::class) val rating: AnimeRating? = null,
    val rank: Int? = null,
    @SerialName("ss_horizontal_cover") val horizontalCover: String? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(cover ?: horizontalCover)
    val subtitle: String
        get() = listOfNotNull(
            newEp?.indexShow?.takeIf { it.isNotBlank() },
            newEp?.desc?.takeIf { it.isNotBlank() },
        ).joinToString(" · ")
}

@Serializable
data class AnimeRankData(
    val list: List<AnimeRankItem> = emptyList(),
    val note: String? = null,
)

@Serializable
data class PgcPlayResult(
    val playable: Boolean = false,
    val reason: String? = null,
    val message: String? = null,
    @SerialName("session_id") val sessionId: String? = null,
    @SerialName("playback_url") val playbackUrl: String? = null,
    @SerialName("expires_at") val expiresAt: Long? = null,
    @SerialName("duration_ms") val durationMs: Long = 0,
    @SerialName("is_preview") val isPreview: Boolean = false,
    @SerialName("season_id") val seasonId: Long = 0,
    @SerialName("media_id") val mediaId: Long? = null,
    val quality: LiveQuality? = null,
    val qualities: List<LiveQuality>? = null,
    val episode: AnimeEpisode? = null,
    val episodes: List<AnimeEpisode> = emptyList(),
    val season: AnimeSeason? = null,
) {
    val unavailableText: String
        get() = when (reason) {
            "entitlement_required" -> message?.takeIf { it.isNotBlank() } ?: "需要大会员或该地区不可观看"
            "auth_required" -> "登录后才能观看"
            "not_found" -> "剧集不存在或已下架"
            else -> message?.takeIf { it.isNotBlank() } ?: "视频加载失败"
        }
}
