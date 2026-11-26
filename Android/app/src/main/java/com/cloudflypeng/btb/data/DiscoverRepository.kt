package com.cloudflypeng.btb.data

import android.content.Context
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class DiscoverRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
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

    suspend fun partitionRanking(tid: Int): List<VideoItem> {
        val result = core.call(
            "video.rank",
            buildJsonObject {
                put("rid", tid)
                put("type", "all")
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<HotData>>(result)
        requireSuccess(response)
        return response.data?.list.orEmpty().mapNotNull { it.toVideoItem() }
    }

    suspend fun weeklySeries(): List<WeeklySeriesItem> {
        val result = core.call("video.weekly")
        val response = json.decodeFromJsonElement<UpstreamResponse<WeeklySeriesData>>(result)
        requireSuccess(response)
        return response.data?.list.orEmpty().filter { it.number > 0 }
    }

    suspend fun weeklyIssue(number: Int): WeeklyIssueData {
        val result = core.call(
            "video.weekly",
            buildJsonObject { put("number", number) },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<WeeklyIssueData>>(result)
        requireSuccess(response)
        return response.data ?: WeeklyIssueData()
    }

    suspend fun articleRank(): List<ArticleRankItem> {
        val result = core.call(
            "article.rank",
            buildJsonObject {
                put("page", 1)
                put("page_size", 100)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<List<ArticleRankItem>>>(result)
        requireSuccess(response)
        return response.data.orEmpty().filter { it.id > 0 }
    }

    suspend fun article(id: Long): ArticleDetail {
        val result = core.call(
            "article.view",
            buildJsonObject { put("article_id", id) },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<ArticleDetail>>(result)
        requireSuccess(response)
        return response.data ?: throw CoreException(response.code, "专栏内容为空")
    }

    suspend fun topicSquare(): List<TopicSquareItem> {
        val result = core.call(
            "topic.square",
            buildJsonObject { put("page_size", 30) },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<TopicSquareData>>(result)
        requireSuccess(response)
        return response.data?.topicItems.orEmpty().filter { it.id > 0 }
    }

    suspend fun topicDetail(id: Long): TopicDetailItem? {
        val result = core.call(
            "topic.detail",
            buildJsonObject { put("topic_id", id) },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<TopicDetailData>>(result)
        if (response.code != 0) return null
        return response.data?.topDetails?.topicItem
    }

    suspend fun topicFeed(id: Long, name: String, offset: String? = null): TopicFeedPage {
        val result = core.call(
            "topic.feed",
            buildJsonObject {
                put("topic_id", id)
                put("page_size", 20)
                if (!offset.isNullOrBlank()) put("offset", offset)
                if (name.isNotBlank()) put("topic_name", name)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<TopicFeedData>>(result)
        requireSuccess(response)
        val list = response.data?.topicCardList ?: return TopicFeedPage()
        val cards = list.items.mapNotNull { it.dynamicCardItem?.toCard() }
        return TopicFeedPage(
            cards = cards,
            offset = list.offset.orEmpty(),
            hasMore = list.hasMore && !list.offset.isNullOrBlank(),
        )
    }

    private fun requireSuccess(response: UpstreamResponse<*>) {
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "上游接口返回错误")
        }
    }
}

enum class SearchTab(val label: String, val apiType: String) {
    All("综合", ""),
    Video("视频", "video"),
    User("用户", "bili_user"),
    Media("番剧", "media_bangumi"),
    Live("直播", "live_room"),
    Article("专栏", "article"),
}

data class SearchFilters(
    val order: String = "totalrank",
    val duration: String = "",
    val tids: String = "",
)

data class SearchChunk(
    val videos: List<VideoItem> = emptyList(),
    val users: List<SearchUser> = emptyList(),
    val media: List<SearchMedia> = emptyList(),
    val liveRooms: List<SearchLiveRoom> = emptyList(),
    val articles: List<SearchArticle> = emptyList(),
    val total: Int = 0,
    val numPages: Int = 0,
) {
    val itemCount: Int
        get() = videos.size + users.size + media.size + liveRooms.size + articles.size

    val isEmpty: Boolean get() = itemCount == 0

    fun hasMore(page: Int, pageSize: Int): Boolean =
        if (numPages > 0) page < numPages else itemCount >= pageSize
}

object SearchFilterCatalog {
    val orders = listOf(
        "totalrank" to "综合排序",
        "click" to "最多播放",
        "pubdate" to "最新发布",
        "dm" to "最多弹幕",
        "stow" to "最多收藏",
    )

    val durations = listOf(
        "" to "全部时长",
        "1" to "10 分钟以下",
        "2" to "10-30 分钟",
        "3" to "30-60 分钟",
        "4" to "60 分钟以上",
    )

    val partitions = listOf(
        "" to "全部分区",
        "1" to "动画",
        "4" to "游戏",
        "36" to "知识",
        "188" to "科技",
        "160" to "生活",
        "181" to "影视",
        "5" to "娱乐",
        "3" to "音乐",
        "129" to "舞蹈",
        "119" to "鬼畜",
        "211" to "美食",
    )
}

class SearchRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun all(keyword: String, pageSize: Int = 10): SearchAllResult {
        val result = core.call(
            "search.all",
            buildJsonObject {
                put("keyword", keyword)
                put("page", 1)
                put("page_size", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<SearchAllData>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "搜索失败")
        }
        val data = response.data ?: SearchAllData()
        if (!data.vVoucher.isNullOrBlank()) {
            throw CoreException(-412, "请求过于频繁，请稍后再试")
        }

        fun groupItems(type: String): List<JsonElement> =
            data.result.firstOrNull { it.resultType == type }?.data?.let { element ->
                runCatching {
                    json.decodeFromJsonElement<List<JsonElement>>(element)
                }.getOrNull()
            }.orEmpty()

        fun <T> decodeGroup(deserializer: kotlinx.serialization.KSerializer<T>, type: String): List<T> =
            groupItems(type).mapNotNull { element ->
                runCatching { json.decodeFromJsonElement(deserializer, element) }.getOrNull()
            }

        return SearchAllResult(
            videos = decodeGroup(SearchVideo.serializer(), "video").mapNotNull { it.toVideoItem() },
            bangumi = decodeGroup(SearchMedia.serializer(), "media_bangumi").uniqueMedia(),
            films = decodeGroup(SearchMedia.serializer(), "media_ft").uniqueMedia(),
            users = decodeGroup(SearchUser.serializer(), "bili_user"),
            liveRooms = decodeGroup(SearchLiveRoom.serializer(), "live_room"),
            articles = decodeGroup(SearchArticle.serializer(), "article"),
            total = data.numResults,
        )
    }

    suspend fun page(
        keyword: String,
        tab: SearchTab,
        page: Int,
        pageSize: Int,
        filters: SearchFilters = SearchFilters(),
    ): SearchChunk {
        require(tab != SearchTab.All) { "综合搜索请使用 all()" }
        val params = buildJsonObject {
            put("keyword", keyword)
            put("search_type", tab.apiType)
            put("page", page)
            put("page_size", pageSize)
            if (tab == SearchTab.Video) {
                put("order", filters.order)
                if (filters.duration.isNotBlank()) put("duration", filters.duration)
                if (filters.tids.isNotBlank()) put("tids", filters.tids)
            }
        }
        val result = core.call("search.type", params)
        return when (tab) {
            SearchTab.Video -> {
                val data = decodePage(result, SearchVideo.serializer())
                SearchChunk(
                    videos = data.result.orEmpty().mapNotNull { it.toVideoItem() },
                    total = data.numResults,
                    numPages = data.numPages,
                )
            }

            SearchTab.User -> {
                val data = decodePage(result, SearchUser.serializer())
                SearchChunk(
                    users = data.result.orEmpty(),
                    total = data.numResults,
                    numPages = data.numPages,
                )
            }

            SearchTab.Media -> {
                val data = decodePage(result, SearchMedia.serializer())
                SearchChunk(
                    media = data.result.orEmpty().uniqueMedia(),
                    total = data.numResults,
                    numPages = data.numPages,
                )
            }

            SearchTab.Live -> {
                val data = decodePage(result, SearchLiveRoom.serializer())
                SearchChunk(
                    liveRooms = data.result.orEmpty(),
                    total = data.numResults,
                    numPages = data.numPages,
                )
            }

            SearchTab.Article -> {
                val data = decodePage(result, SearchArticle.serializer())
                SearchChunk(
                    articles = data.result.orEmpty(),
                    total = data.numResults,
                    numPages = data.numPages,
                )
            }

            SearchTab.All -> SearchChunk()
        }
    }

    suspend fun suggest(term: String): List<SearchSuggestItem> {
        val result = core.call(
            "search.suggest",
            buildJsonObject { put("term", term) },
        )
        val response = json.decodeFromJsonElement<SearchSuggestPayload>(result)
        val seen = HashSet<String>()
        return (response.data?.result?.tag.orEmpty())
            .filter { it.query.isNotBlank() && seen.add(it.query) }
    }

    suspend fun hotWords(): List<SearchHotWord> {
        for (method in listOf("search.hot", "search.trending")) {
            val words = runCatching {
                val result = core.call(
                    method,
                    buildJsonObject { put("limit", 30) },
                )
                val response = json.decodeFromJsonElement<SearchHotPayload>(result)
                if ((response.code ?: 0) != 0) emptyList()
                else response.data?.list.orEmpty().filter { it.display.isNotBlank() }
            }.getOrDefault(emptyList())
            if (words.isNotEmpty()) return words
        }
        return emptyList()
    }

    private fun <T> decodePage(
        result: JsonElement,
        deserializer: kotlinx.serialization.KSerializer<T>,
    ): SearchPageData<T> {
        val serializer = UpstreamResponse.serializer(SearchPageData.serializer(deserializer))
        val response = json.decodeFromJsonElement(serializer, result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "搜索失败")
        }
        val data = response.data ?: SearchPageData()
        if (!data.vVoucher.isNullOrBlank()) {
            throw CoreException(-412, "请求过于频繁，请稍后再试")
        }
        return data
    }

    private fun List<SearchMedia>.uniqueMedia(): List<SearchMedia> {
        val seen = HashSet<Long>()
        return filter { it.resolvedSeasonId > 0 && seen.add(it.resolvedSeasonId) }
    }
}

class SearchHistoryStore(context: Context) {
    private val prefs = context.getSharedPreferences("btb.search", Context.MODE_PRIVATE)

    fun load(): List<String> = prefs.getString(KEY, null)
        ?.split('\n')
        ?.filter { it.isNotBlank() }
        .orEmpty()

    fun remember(keyword: String): List<String> {
        val value = keyword.trim()
        if (value.isEmpty()) return load()
        val items = (listOf(value) + load().filter { it != value }).take(10)
        prefs.edit().putString(KEY, items.joinToString("\n")).apply()
        return items
    }

    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private companion object {
        const val KEY = "history"
    }
}

internal fun SearchVideo.toVideoItem(): VideoItem? {
    val id = bvid?.takeIf { it.isNotBlank() } ?: return null
    return VideoItem(
        bvid = id,
        title = cleanSearchText(title.orEmpty()),
        coverUrl = normalizeMediaUrl(pic),
        ownerName = author?.takeIf { it.isNotBlank() } ?: "未知 UP 主",
        ownerFaceUrl = normalizeMediaUrl(upic),
        viewText = formatCount((play ?: 0).toLong()),
        durationText = durationText,
        publishedText = relativeTime(pubdate),
        description = cleanSearchText(description.orEmpty()).takeUnless { it == "-" }.orEmpty(),
        cid = null,
    )
}
