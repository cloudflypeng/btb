package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

enum class MessageTab(val label: String) {
    Replies("回复"),
    Ats("@我"),
    Likes("点赞"),
    System("系统"),
}

@Serializable
data class MessageUnread(
    val reply: Int = 0,
    val at: Int = 0,
    val like: Int = 0,
    @SerialName("recv_like") val recvLike: Int = 0,
    @SerialName("sys_msg") val sysMsg: Int = 0,
    val chat: Int = 0,
) {
    fun count(tab: MessageTab): Int = when (tab) {
        MessageTab.Replies -> reply
        MessageTab.Ats -> at
        MessageTab.Likes -> maxOf(like, recvLike)
        MessageTab.System -> sysMsg
    }

    val total: Int
        get() = MessageTab.entries.sumOf { count(it) }
}

@Serializable
data class MessageCursor(
    val id: Long = 0,
    val time: Long = 0,
    @SerialName("is_end") val isEnd: Boolean = false,
)

@Serializable
data class MessageUserRaw(
    val mid: Long? = null,
    val nickname: String? = null,
    val avatar: String? = null,
)

@Serializable
data class MessageItemRaw(
    val title: String? = null,
    val desc: String? = null,
    val business: String? = null,
    val type: String? = null,
    val uri: String? = null,
    @SerialName("native_uri") val nativeUri: String? = null,
    @SerialName("source_content") val sourceContent: String? = null,
    @SerialName("target_reply_content") val targetReplyContent: String? = null,
    @SerialName("root_reply_content") val rootReplyContent: String? = null,
)

@Serializable
data class MessageReplyRaw(
    val id: Long = 0,
    @SerialName("reply_time") val replyTime: Long = 0,
    val counts: Int? = null,
    val user: MessageUserRaw? = null,
    val item: MessageItemRaw? = null,
)

@Serializable
data class MessageAtRaw(
    val id: Long = 0,
    @SerialName("at_time") val atTime: Long = 0,
    val user: MessageUserRaw? = null,
    val item: MessageItemRaw? = null,
)

@Serializable
data class MessageLikeRaw(
    val id: Long = 0,
    @SerialName("like_time") val likeTime: Long = 0,
    val counts: Int? = null,
    val users: List<MessageUserRaw>? = null,
    val item: MessageItemRaw? = null,
)

@Serializable
data class MessageReplyData(
    val cursor: MessageCursor? = null,
    val items: List<MessageReplyRaw>? = null,
)

@Serializable
data class MessageAtData(
    val cursor: MessageCursor? = null,
    val items: List<MessageAtRaw>? = null,
)

@Serializable
data class MessageLikesData(
    val latest: MessageLikesLatest? = null,
    val total: MessageLikesTotal? = null,
)

@Serializable
data class MessageLikesLatest(
    val items: List<MessageLikeRaw>? = null,
)

@Serializable
data class MessageLikesTotal(
    val items: List<MessageLikeRaw>? = null,
    val cursor: MessageCursor? = null,
)

@Serializable
data class SystemMessageSource(
    val name: String? = null,
    val logo: String? = null,
)

@Serializable
data class SystemMessageRaw(
    val id: Long = 0,
    val cursor: Long = 0,
    val title: String? = null,
    val content: String? = null,
    @SerialName("time_at") val timeAt: String? = null,
    val type: Int? = null,
    @SerialName("card_cover") val cardCover: String? = null,
    @SerialName("card_link") val cardLink: String? = null,
    val source: SystemMessageSource? = null,
)

data class MessageEntry(
    val id: String,
    val tab: MessageTab,
    val userName: String,
    val avatarUrl: String?,
    val action: String,
    val text: String,
    val context: String,
    val timeText: String,
    val coverUrl: String? = null,
    val bvid: String? = null,
)

data class MessageFeedPage(
    val items: List<MessageEntry>,
    val cursorId: Long,
    val cursorTime: Long,
    val hasMore: Boolean,
)

data class SystemMessagePage(
    val items: List<MessageEntry>,
    val nextCursor: Long,
    val hasMore: Boolean,
)

class MessageRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun unread(): MessageUnread {
        val response = json.decodeFromJsonElement<UpstreamResponse<MessageUnread>>(
            core.call("msg.unread"),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "未读消息加载失败")
        }
        return response.data ?: MessageUnread()
    }

    suspend fun replies(cursorId: Long = 0, cursorTime: Long = 0): MessageFeedPage {
        val response = json.decodeFromJsonElement<UpstreamResponse<MessageReplyData>>(
            core.call(
                "msg.replies",
                buildJsonObject {
                    put("cursor", cursorId)
                    put("cursor_time", cursorTime)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "回复消息加载失败")
        }
        val data = response.data ?: MessageReplyData()
        return MessageFeedPage(
            items = data.items.orEmpty().map { it.toEntry() },
            cursorId = data.cursor?.id ?: 0,
            cursorTime = data.cursor?.time ?: 0,
            hasMore = data.cursor?.isEnd == false && data.items.orEmpty().isNotEmpty(),
        )
    }

    suspend fun ats(cursorId: Long = 0, cursorTime: Long = 0): MessageFeedPage {
        val response = json.decodeFromJsonElement<UpstreamResponse<MessageAtData>>(
            core.call(
                "msg.ats",
                buildJsonObject {
                    put("cursor", cursorId)
                    put("cursor_time", cursorTime)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "@消息加载失败")
        }
        val data = response.data ?: MessageAtData()
        return MessageFeedPage(
            items = data.items.orEmpty().map { it.toEntry() },
            cursorId = data.cursor?.id ?: 0,
            cursorTime = data.cursor?.time ?: 0,
            hasMore = data.cursor?.isEnd == false && data.items.orEmpty().isNotEmpty(),
        )
    }

    suspend fun likes(cursorId: Long = 0, cursorTime: Long = 0): MessageFeedPage {
        val response = json.decodeFromJsonElement<UpstreamResponse<MessageLikesData>>(
            core.call(
                "msg.likes",
                buildJsonObject {
                    put("cursor", cursorId)
                    put("cursor_time", cursorTime)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "点赞消息加载失败")
        }
        val data = response.data ?: MessageLikesData()
        val items = data.total?.items.orEmpty()
        return MessageFeedPage(
            items = items.map { it.toEntry() },
            cursorId = data.total?.cursor?.id ?: 0,
            cursorTime = data.total?.cursor?.time ?: 0,
            hasMore = data.total?.cursor?.isEnd == false && items.isNotEmpty(),
        )
    }

    suspend fun system(cursor: Long = 0, pageSize: Int = 20): SystemMessagePage {
        val response = json.decodeFromJsonElement<UpstreamResponse<List<SystemMessageRaw>>>(
            core.call(
                "msg.system",
                buildJsonObject {
                    put("cursor", cursor)
                    put("page_size", pageSize)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "系统通知加载失败")
        }
        val items = response.data.orEmpty()
        return SystemMessagePage(
            items = items.map { it.toEntry() },
            nextCursor = items.lastOrNull()?.cursor ?: 0,
            hasMore = items.size >= pageSize,
        )
    }
}

private fun MessageReplyRaw.toEntry(): MessageEntry {
    val item = item
    val text = firstNotEmpty(item?.sourceContent, item?.title, item?.desc)
    val context = firstNotEmpty(item?.title, item?.desc).takeIf { it != text }.orEmpty()
    return MessageEntry(
        id = "reply-$id",
        tab = MessageTab.Replies,
        userName = user?.nickname?.trim().takeUnless { it.isNullOrEmpty() } ?: "B站用户",
        avatarUrl = normalizeMediaUrl(user?.avatar),
        action = "回复了我的评论",
        text = text.ifEmpty { "[评论]" },
        context = context,
        timeText = relativeTime(replyTime),
        bvid = item.bvid(),
    )
}

private fun MessageAtRaw.toEntry(): MessageEntry {
    val item = item
    val text = firstNotEmpty(item?.title, item?.sourceContent, item?.desc)
    val business = item?.business?.takeIf { it.isNotBlank() } ?: "内容"
    return MessageEntry(
        id = "at-$id",
        tab = MessageTab.Ats,
        userName = user?.nickname?.trim().takeUnless { it.isNullOrEmpty() } ?: "B站用户",
        avatarUrl = normalizeMediaUrl(user?.avatar),
        action = "提到了我",
        text = text.ifEmpty { "在${business}中提到了你" },
        context = if (text.isEmpty()) "" else business,
        timeText = relativeTime(atTime),
    )
}

private fun MessageLikeRaw.toEntry(): MessageEntry {
    val item = item
    val primary = users.orEmpty().firstOrNull()
    val extra = users.orEmpty().size.takeIf { it > 1 }
    val text = firstNotEmpty(item?.title, item?.desc)
    return MessageEntry(
        id = "like-$id",
        tab = MessageTab.Likes,
        userName = primary?.nickname?.trim().takeUnless { it.isNullOrEmpty() } ?: "有人",
        avatarUrl = normalizeMediaUrl(primary?.avatar),
        action = if (extra != null) "等 $extra 人赞了我的内容" else "赞了我的${item?.business ?: "内容"}",
        text = text.ifEmpty { item?.business ?: "内容" },
        context = "",
        timeText = relativeTime(likeTime),
        bvid = item.bvid(),
    )
}

private fun SystemMessageRaw.toEntry(): MessageEntry {
    val title = title?.trim().orEmpty()
    val body = cleanSystemText(content)
    return MessageEntry(
        id = "system-$id",
        tab = MessageTab.System,
        userName = source?.name?.trim().takeUnless { it.isNullOrEmpty() } ?: "系统通知",
        avatarUrl = normalizeMediaUrl(cardCover) ?: normalizeMediaUrl(source?.logo),
        action = title.ifEmpty { "系统通知" },
        text = body,
        context = "",
        timeText = timeAt.orEmpty(),
        coverUrl = normalizeMediaUrl(cardCover) ?: normalizeMediaUrl(source?.logo),
    )
}

private fun firstNotEmpty(vararg values: String?): String {
    for (value in values) {
        val text = value?.trim().orEmpty()
        if (text.isNotEmpty()) return text
    }
    return ""
}

private val BVID_PATTERN = Regex("BV[0-9A-Za-z]{10}")

private fun MessageItemRaw?.bvid(): String? {
    val source = firstNotEmpty(this?.uri, this?.nativeUri)
    if (source.isEmpty()) return null
    return BVID_PATTERN.find(source)?.value
}

private val SYSTEM_TEMPLATE_PATTERN = Regex("#\\{[^}]*\\}\\{[^}]*\\}")
private val HTML_TAG_PATTERN = Regex("<[^>]+>")

private fun cleanSystemText(raw: String?): String {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return ""
    val web = runCatching {
        val objectValue = Json.parseToJsonElement(text) as? JsonObject
        objectValue?.get("web")?.jsonPrimitive?.content
    }.getOrNull()
    val source = web ?: text
    return source
        .replace(SYSTEM_TEMPLATE_PATTERN, "")
        .replace(HTML_TAG_PATTERN, "")
        .trim()
}
