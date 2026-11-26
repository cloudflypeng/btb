package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class PgcRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun timeline(): List<AnimeTimelineDay> {
        val result = core.call(
            "pgc.timeline",
            buildJsonObject {
                put("types", 1)
                put("before", 3)
                put("after", 3)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResultResponse<List<AnimeTimelineDay>>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "时间表加载失败")
        }
        return response.result.orEmpty()
    }

    suspend fun rank(): List<AnimeRankItem> {
        val result = core.call(
            "pgc.rank",
            buildJsonObject {
                put("day", 3)
                put("season_type", 1)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResultResponse<AnimeRankData>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "排行榜加载失败")
        }
        return response.result?.list.orEmpty()
    }

    suspend fun info(seasonId: Long): AnimeSeason {
        val result = core.call(
            "pgc.info",
            buildJsonObject { put("season_id", seasonId) },
        )
        val response = json.decodeFromJsonElement<UpstreamResultResponse<AnimeSeason>>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "番剧详情加载失败")
        }
        return response.result ?: throw CoreException(response.code, "番剧详情为空")
    }

    suspend fun follow(seasonId: Long, follow: Boolean): LiveBasicResponse {
        val result = core.call(
            "pgc.follow",
            buildJsonObject {
                put("season_id", seasonId)
                put("follow", follow)
            },
        )
        val response = json.decodeFromJsonElement<LiveBasicResponse>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "追番操作失败")
        }
        return response
    }

    suspend fun play(
        seasonId: Long,
        episodeId: Long? = null,
        qn: Long? = null,
    ): PgcPlayResult {
        val result = core.call(
            "pgc.play",
            buildJsonObject {
                put("season_id", seasonId)
                if (episodeId != null && episodeId > 0) put("ep_id", episodeId)
                if (qn != null && qn > 0) put("qn", qn)
            },
        )
        return json.decodeFromJsonElement<PgcPlayResult>(result)
    }

    suspend fun stopStream(sessionId: String) {
        runCatching {
            core.call("stream.stop", buildJsonObject { put("session_id", sessionId) })
        }
    }
}
