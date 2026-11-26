package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

data class LiveFollowingPage(
    val rooms: List<LiveRoom>,
    val totalPage: Int,
    val liveCount: Int,
)

class LiveRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun following(page: Int): LiveFollowingPage {
        val result = core.call(
            "live.following",
            buildJsonObject { put("page", page) },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<LiveFollowingData>>(result)
        requireSuccess(response)
        val data = response.data ?: LiveFollowingData()
        val rooms = data.list.orEmpty().mapNotNull { it.toRoom() }
        return LiveFollowingPage(
            rooms = rooms,
            totalPage = data.totalPage ?: page,
            liveCount = data.liveCount ?: rooms.count { it.isLive },
        )
    }

    suspend fun play(roomId: Long, qn: Long? = null): LivePlayResult {
        val result = core.call(
            "live.play",
            buildJsonObject {
                put("room_id", roomId)
                if (qn != null && qn > 0) put("qn", qn)
            },
        )
        return json.decodeFromJsonElement<LivePlayResult>(result)
    }

    suspend fun connect(roomId: Long) {
        core.call("live.connect", buildJsonObject { put("room_id", roomId) })
    }

    suspend fun disconnect(roomId: Long) {
        runCatching { core.call("live.disconnect", buildJsonObject { put("room_id", roomId) }) }
    }

    suspend fun sendDanmaku(roomId: Long, text: String): LiveBasicResponse {
        val result = core.call(
            "live.send_msg",
            buildJsonObject {
                put("room_id", roomId)
                put("msg", text)
            },
        )
        return json.decodeFromJsonElement<LiveBasicResponse>(result)
    }

    suspend fun follow(uid: Long, follow: Boolean): LiveBasicResponse {
        val result = core.call(
            "user.follow",
            buildJsonObject {
                put("fid", uid)
                put("follow", follow)
            },
        )
        val response = json.decodeFromJsonElement<LiveBasicResponse>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "关注失败")
        }
        return response
    }

    suspend fun stopStream(sessionId: String) {
        runCatching {
            core.call("stream.stop", buildJsonObject { put("session_id", sessionId) })
        }
    }

    private fun requireSuccess(response: UpstreamResponse<*>) {
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "直播列表加载失败")
        }
    }
}
