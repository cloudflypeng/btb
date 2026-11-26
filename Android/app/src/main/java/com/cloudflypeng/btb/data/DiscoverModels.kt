package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

@Serializable
data class WeeklySeriesData(
    val list: List<WeeklySeriesItem> = emptyList(),
)

@Serializable
data class WeeklySeriesItem(
    val name: String = "",
    val number: Int = 0,
    val status: Int? = null,
    val subject: String? = null,
)

@Serializable
data class WeeklyIssueData(
    val config: WeeklyConfig? = null,
    val list: List<HotVideo> = emptyList(),
)

@Serializable
data class WeeklyConfig(
    val id: Long? = null,
    val name: String? = null,
    val number: Int? = null,
    val subject: String? = null,
    val label: String? = null,
    @SerialName("share_title") val shareTitle: String? = null,
    @SerialName("share_subtitle") val shareSubtitle: String? = null,
    val cover: String? = null,
    val stime: Long? = null,
    val etime: Long? = null,
)

@Serializable
data class TopicSquareData(
    @SerialName("topic_items") val topicItems: List<TopicSquareItem> = emptyList(),
)

@Serializable
data class TopicSquareItem(
    val id: Long = 0,
    val name: String = "",
    val description: String? = null,
    val discuss: Long? = null,
    val view: Long? = null,
    @SerialName("stat_desc") val statDesc: String? = null,
) {
    val summaryText: String
        get() {
            val desc = statDesc?.takeIf { it.isNotBlank() }
            if (desc != null) return desc
            val parts = buildList {
                view?.takeIf { it > 0 }?.let { add("${formatCount(it.toLong())}浏览") }
                discuss?.takeIf { it > 0 }?.let { add("${formatCount(it.toLong())}讨论") }
            }
            return parts.joinToString(" · ")
        }
}

@Serializable
data class TopicDetailData(
    @SerialName("top_details") val topDetails: TopicTopDetails? = null,
)

@Serializable
data class TopicTopDetails(
    @SerialName("topic_item") val topicItem: TopicDetailItem? = null,
)

@Serializable
data class TopicDetailItem(
    val id: Long = 0,
    val name: String = "",
    val description: String? = null,
    @SerialName("back_color") val backColor: String? = null,
    @SerialName("share_pic") val sharePic: String? = null,
    val dynamics: Long? = null,
    val view: Long? = null,
    val discuss: Long? = null,
    @SerialName("jump_url") val jumpUrl: String? = null,
) {
    val bannerUrl: String? get() = normalizeMediaUrl(sharePic)
}

@Serializable
data class TopicFeedData(
    @SerialName("topic_card_list") val topicCardList: TopicCardList? = null,
)

@Serializable
data class TopicCardList(
    val items: List<TopicFeedItemRaw> = emptyList(),
    val offset: String? = null,
    @SerialName("has_more") val hasMore: Boolean = false,
)

@Serializable
data class TopicFeedItemRaw(
    @SerialName("dynamic_card_item") val dynamicCardItem: DynamicRawItem? = null,
    @SerialName("topic_type") val topicType: String? = null,
)

@Serializable
data class ArticleRankItem(
    val id: Long = 0,
    val title: String = "",
    val summary: String? = null,
    @SerialName("banner_url") val bannerUrl: String? = null,
    @SerialName("image_urls") val imageUrls: List<String> = emptyList(),
    val author: ArticleAuthor? = null,
    val stats: ArticleStats? = null,
    @SerialName("publish_time") val publishTime: Long? = null,
    val category: ArticleCategory? = null,
    val words: Int? = null,
    val score: Int? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(bannerUrl) ?: normalizeMediaUrl(imageUrls.firstOrNull())
    val authorName: String get() = author?.name?.takeIf { it.isNotBlank() } ?: "未知作者"
    val summaryText: String
        get() = summary.orEmpty()
            .replace("[图片]", "")
            .replace("  ", " ")
            .trim()
    val publishedText: String
        get() = weekdayDate(publishTime)
}

@Serializable
data class ArticleAuthor(
    val mid: Long? = null,
    val name: String? = null,
    val face: String? = null,
)

@Serializable
data class ArticleStats(
    val view: Int? = null,
    val like: Int? = null,
    val reply: Int? = null,
    val favorite: Int? = null,
    val coin: Int? = null,
)

@Serializable
data class ArticleCategory(
    val id: Int? = null,
    val name: String? = null,
)

@Serializable
data class ArticleDetail(
    val id: Long = 0,
    val title: String = "",
    val summary: String? = null,
    @SerialName("banner_url") val bannerUrl: String? = null,
    val content: String? = null,
    @SerialName("publish_time") val publishTime: Long? = null,
    val words: Int? = null,
    val author: ArticleAuthor? = null,
    val stats: ArticleStats? = null,
    val category: ArticleCategory? = null,
)

@Serializable
data class SearchPageData<T>(
    val result: List<T>? = null,
    @SerialName("num_results") val numResults: Int = 0,
    @SerialName("num_pages") val numPages: Int = 0,
    @SerialName("v_voucher") val vVoucher: String? = null,
)

@Serializable
data class SearchAllGroup(
    @SerialName("result_type") val resultType: String = "",
    val data: JsonElement? = null,
)

@Serializable
data class SearchAllData(
    val result: List<SearchAllGroup> = emptyList(),
    @SerialName("num_results") val numResults: Int = 0,
    @SerialName("v_voucher") val vVoucher: String? = null,
)

@Serializable
data class SearchVideo(
    val aid: Long? = null,
    val bvid: String? = null,
    val title: String? = null,
    val pic: String? = null,
    val author: String? = null,
    val upic: String? = null,
    val play: Int? = null,
    val danmaku: Int? = null,
    val duration: JsonElement? = null,
    val pubdate: Long? = null,
    val description: String? = null,
) {
    val durationText: String get() = normalizeDuration(jsonScalarText(duration))
}

internal fun normalizeDuration(raw: String): String {
    val text = raw.trim()
    val parts = text.split(":")
    if (parts.size != 2) return text
    val minutes = parts[0].toIntOrNull() ?: return text
    val seconds = parts[1].toIntOrNull() ?: return text
    if (seconds !in 0..59) return text
    return "$minutes:${seconds.toString().padStart(2, '0')}"
}

@Serializable
data class SearchUserOfficial(
    val type: Int? = null,
    val desc: String? = null,
)

@Serializable
data class SearchUser(
    val mid: Long = 0,
    val uname: String = "",
    val upic: String? = null,
    val fans: Int? = null,
    val videos: Int? = null,
    val level: Int? = null,
    @SerialName("usign") val sign: String? = null,
    @SerialName("official_verify") val official: SearchUserOfficial? = null,
    @SerialName("is_live") val isLive: Int? = null,
    @SerialName("room_id") val roomId: Long? = null,
) {
    val avatarUrl: String? get() = normalizeMediaUrl(upic)
    val isLiveNow: Boolean get() = (isLive ?: 0) == 1
    val displayName: String get() = cleanSearchText(uname)
    val detailText: String
        get() = cleanSearchText(official?.desc?.takeIf { it.isNotBlank() } ?: sign.orEmpty())
    val statsText: String
        get() = buildList {
            fans?.takeIf { it > 0 }?.let { add("${formatCount(it.toLong())}粉丝") }
            videos?.takeIf { it > 0 }?.let { add("${formatCount(it.toLong())}个视频") }
        }.joinToString(" · ")
}

@Serializable
data class SearchMediaBadge(
    val text: String? = null,
)

@Serializable
data class SearchMediaScore(
    val score: Double? = null,
    @SerialName("user_count") val userCount: Int? = null,
)

@Serializable
data class SearchMedia(
    @SerialName("season_id") val seasonId: Long = 0,
    @SerialName("pgc_season_id") val pgcSeasonId: Long? = null,
    @SerialName("media_id") val mediaId: Long? = null,
    val title: String = "",
    val cover: String? = null,
    val desc: String? = null,
    val areas: String? = null,
    @SerialName("ep_size") val epSize: Int? = null,
    @SerialName("index_show") val indexShow: String? = null,
    @SerialName("season_type_name") val seasonTypeName: String? = null,
    @SerialName("media_score") val score: SearchMediaScore? = null,
    val badges: List<SearchMediaBadge> = emptyList(),
    @SerialName("goto_url") val gotoUrl: String? = null,
) {
    val resolvedSeasonId: Long get() = seasonId.takeIf { it > 0 } ?: (pgcSeasonId ?: 0)
    val coverUrl: String? get() = normalizeMediaUrl(cover)
    val displayTitle: String get() = cleanSearchText(title)
    val badgeText: String? get() = badges.firstNotNullOfOrNull { it.text?.takeIf { text -> text.isNotBlank() } }
    val scoreText: String
        get() = score?.score?.takeIf { it > 0 }?.let { String.format(java.util.Locale.CHINA, "%.1f", it) }
            ?: "暂无评分"
    val infoText: String
        get() = buildList {
            seasonTypeName?.takeIf { it.isNotBlank() }?.let { add(it) }
            areas?.takeIf { it.isNotBlank() }?.let { add(it) }
            indexShow?.takeIf { it.isNotBlank() }?.let { add(it) }
            if (isEmpty()) epSize?.takeIf { it > 0 }?.let { add("全 $it 话") }
        }.joinToString(" · ")
}

@Serializable
data class SearchLiveRoom(
    @SerialName("roomid") val roomId: Long = 0,
    val uid: Long? = null,
    val title: String = "",
    val uname: String = "",
    val uface: String? = null,
    val cover: String? = null,
    val pic: String? = null,
    val online: Int? = null,
    val attentions: Int? = null,
    @SerialName("area") val areaId: Int? = null,
    @SerialName("live_status") val liveStatus: Int? = null,
    @SerialName("cate_name") val categoryName: String? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(cover ?: pic)
    val displayTitle: String get() = cleanSearchText(title)
    val displayUserName: String get() = cleanSearchText(uname)
    val displayCategory: String? get() = categoryName?.let { cleanSearchText(it) }?.takeIf { it.isNotBlank() }
}

@Serializable
data class SearchArticle(
    val id: Long = 0,
    val title: String = "",
    val desc: String? = null,
    @SerialName("image_urls") val imageUrls: List<String> = emptyList(),
    val author: String? = null,
    val mid: Long? = null,
    val view: Int? = null,
    val like: Int? = null,
    val reply: Int? = null,
    @SerialName("pub_time") val publishTime: Long? = null,
    @SerialName("category_name") val categoryName: String? = null,
) {
    val coverUrl: String? get() = normalizeMediaUrl(imageUrls.firstOrNull())
    val displayTitle: String get() = cleanSearchText(title)
    val displayDesc: String? get() = desc?.let { cleanSearchText(it) }?.takeIf { it.isNotBlank() }
}

@Serializable
data class SearchHotPayload(
    val code: Int? = null,
    val data: SearchHotData? = null,
)

@Serializable
data class SearchHotData(
    val list: List<SearchHotWord> = emptyList(),
)

@Serializable
data class SearchHotWord(
    val keyword: String? = null,
    @SerialName("show_name") val showName: String? = null,
    val icon: String? = null,
    @SerialName("hot_id") val hotId: Long? = null,
) {
    val display: String get() = cleanSearchText(showName ?: keyword.orEmpty())
    val id: String get() = hotId?.takeIf { it > 0 }?.toString() ?: display
}

@Serializable
data class SearchSuggestPayload(
    val code: Int? = null,
    val data: SearchSuggestData? = null,
)

@Serializable
data class SearchSuggestData(
    val result: SearchSuggestResult? = null,
)

@Serializable
data class SearchSuggestResult(
    val tag: List<SearchSuggestItem> = emptyList(),
)

@Serializable
data class SearchSuggestItem(
    val name: String? = null,
    val term: String? = null,
    val value: String? = null,
) {
    val display: String get() = cleanSearchText(name ?: value ?: term.orEmpty())
    val query: String
        get() = value?.takeIf { it.isNotBlank() }
            ?: term?.takeIf { it.isNotBlank() }
            ?: display
}

data class SearchAllResult(
    val videos: List<VideoItem> = emptyList(),
    val bangumi: List<SearchMedia> = emptyList(),
    val films: List<SearchMedia> = emptyList(),
    val users: List<SearchUser> = emptyList(),
    val liveRooms: List<SearchLiveRoom> = emptyList(),
    val articles: List<SearchArticle> = emptyList(),
    val total: Int = 0,
) {
    val isEmpty: Boolean
        get() = videos.isEmpty() && bangumi.isEmpty() && films.isEmpty() &&
            users.isEmpty() && liveRooms.isEmpty() && articles.isEmpty()
}

data class TopicFeedPage(
    val cards: List<DynamicCard> = emptyList(),
    val offset: String = "",
    val hasMore: Boolean = false,
)

fun cleanSearchText(raw: String): String = raw
    .replace(Regex("<[^>]+>"), "")
    .replace("&amp;", "&")
    .replace("&lt;", "<")
    .replace("&gt;", ">")
    .replace("&quot;", "\"")
    .replace("&#39;", "'")
    .replace("&nbsp;", " ")
    .trim()

private fun jsonScalarText(value: JsonElement?): String {
    val primitive = value as? JsonPrimitive ?: return ""
    return primitive.contentOrNull.orEmpty()
}

internal fun weekdayDate(epochSeconds: Long?): String {
    if (epochSeconds == null || epochSeconds <= 0) return ""
    val date = java.util.Date(epochSeconds * 1000)
    return java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.CHINA).format(date)
}
