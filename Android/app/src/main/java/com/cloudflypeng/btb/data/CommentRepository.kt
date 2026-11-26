package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

@Serializable
data class ReplyListData(
    val page: ReplyPageRaw? = null,
    val replies: List<ReplyRaw>? = null,
    @SerialName("top_replies") val topReplies: List<ReplyRaw>? = null,
    val upper: ReplyUpperRaw? = null,
)

@Serializable
data class ReplyPageRaw(
    val count: Int = 0,
    val acount: Int? = null,
    val num: Int = 1,
    val size: Int = 20,
)

@Serializable
data class ReplyUpperRaw(
    val mid: Long? = null,
)

@Serializable
data class ReplyRaw(
    val rpid: Long = 0,
    @SerialName("rpid_str") val rpidStr: String? = null,
    val oid: Long = 0,
    val mid: Long = 0,
    val root: Long = 0,
    val parent: Long = 0,
    val count: Int? = null,
    val rcount: Int? = null,
    val like: Int = 0,
    val action: Int = 0,
    val ctime: Long = 0,
    val member: ReplyMemberRaw? = null,
    val content: ReplyContentRaw? = null,
    val replies: List<ReplyRaw>? = null,
)

@Serializable
data class ReplyMemberRaw(
    val uname: String? = null,
    val avatar: String? = null,
    val mid: String? = null,
)

@Serializable
data class ReplyContentRaw(
    val message: String? = null,
)

data class CommentItem(
    val rpid: Long,
    val userName: String,
    val avatarUrl: String?,
    val message: String,
    val likeCount: Int,
    val replyCount: Int,
    val timeText: String,
    val isUp: Boolean,
    val liked: Boolean,
    val replies: List<CommentPreview>,
)

data class CommentPreview(
    val rpid: Long,
    val userName: String,
    val message: String,
)

data class CommentPage(
    val items: List<CommentItem>,
    val total: Int,
    val pageNumber: Int,
)

class CommentRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun list(
        aid: Long,
        page: Int = 1,
        sort: Int = SORT_HOT,
        pageSize: Int = 20,
    ): CommentPage {
        val result = core.call(
            "reply.list",
            buildJsonObject {
                put("oid", aid)
                put("type", 1)
                put("pn", page)
                put("ps", pageSize)
                put("sort", sort)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<ReplyListData>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "评论加载失败")
        }
        val data = response.data ?: throw CoreException(null, "评论加载失败")
        val upperMid = data.upper?.mid
        val merged = buildList {
            data.topReplies?.let { addAll(it) }
            data.replies?.let { addAll(it) }
        }
        return CommentPage(
            items = merged.distinctBy { it.rpid }.mapNotNull { it.toCommentItem(upperMid) },
            total = data.page?.acount ?: data.page?.count ?: 0,
            pageNumber = data.page?.num ?: page,
        )
    }

    companion object {
        const val SORT_HOT = 1
        const val SORT_NEW = 0
    }

    suspend fun like(aid: Long, rpid: Long, liked: Boolean) {
        val response = json.decodeFromJsonElement<UpstreamResponse<JsonElement>>(
            core.call(
                "reply.like",
                buildJsonObject {
                    put("oid", aid)
                    put("type", "1")
                    put("rpid", rpid)
                    put("action", if (liked) 1 else 0)
                },
            ),
        )
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "点赞失败")
        }
    }
}

private fun ReplyRaw.toCommentItem(upperMid: Long?): CommentItem? {
    val message = content?.message?.trim().orEmpty()
    if (message.isEmpty()) return null
    return CommentItem(
        rpid = rpid,
        userName = member?.uname?.trim().takeUnless { it.isNullOrEmpty() } ?: "B站用户",
        avatarUrl = normalizeMediaUrl(member?.avatar),
        message = message,
        likeCount = like,
        replyCount = rcount ?: 0,
        timeText = relativeTime(ctime),
        isUp = upperMid != null && this.mid == upperMid,
        liked = action == 1,
        replies = replies.orEmpty()
            .mapNotNull { reply ->
                val text = reply.content?.message?.trim().orEmpty()
                if (text.isEmpty()) return@mapNotNull null
                CommentPreview(
                    rpid = reply.rpid,
                    userName = reply.member?.uname?.trim().takeUnless { it.isNullOrEmpty() } ?: "B站用户",
                    message = text,
                )
            }
            .take(2),
    )
}
