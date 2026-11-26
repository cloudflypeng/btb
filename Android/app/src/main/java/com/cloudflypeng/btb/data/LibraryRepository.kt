package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class LibraryRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun uploads(mid: Long, page: Int = 1, pageSize: Int = 20): List<VideoItem> {
        val result = core.call(
            "user.videos",
            buildJsonObject {
                put("mid", mid)
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<UserVideosData>>(result)
        requireSuccess(response, "投稿加载失败")
        return response.data?.list?.vlist.orEmpty().mapNotNull { it.toVideoItemOrNull() }
    }

    suspend fun history(pageSize: Int = 30, max: Long? = null, viewAt: Long? = null): Pair<List<HistoryVideo>, HistoryCursor?> {
        val result = core.call(
            "user.history",
            buildJsonObject {
                put("type", "archive")
                put("ps", pageSize)
                if (max != null && max > 0) put("max", max)
                if (viewAt != null && viewAt > 0) put("view_at", viewAt)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<UserHistoryData>>(result)
        requireSuccess(response, "历史记录加载失败")
        return response.data?.list.orEmpty().filter { it.resolvedBvid != null } to response.data?.cursor
    }

    suspend fun deleteHistory(kid: Long) {
        callOk("history.delete", buildJsonObject { put("kid", kid.toString()) }, "删除历史失败")
    }

    suspend fun clearHistory() {
        callOk("history.clear", buildJsonObject { }, "清空历史失败")
    }

    suspend fun historyStatus(): Boolean {
        val result = core.call("history.status")
        val value = result.jsonObjectOrNull() ?: return false
        return (value["data"]?.jsonObjectOrNull()?.get("status")?.toString()?.trim('"') == "1")
    }

    suspend fun pauseHistory(paused: Boolean) {
        callOk("history.pause", buildJsonObject { put("pause", paused) }, "设置失败")
    }

    suspend fun favoriteFolders(): List<FavFolder> {
        val result = core.call(
            "fav.folders",
            buildJsonObject {
                put("pn", 1)
                put("ps", 50)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<FavFoldersData>>(result)
        requireSuccess(response, "收藏夹加载失败")
        return response.data?.list.orEmpty().mapNotNull { it.toFolder() }
    }

    suspend fun favoriteMedias(mediaId: Long, page: Int = 1, pageSize: Int = 30): Pair<List<FavMedia>, Boolean> {
        val result = core.call(
            "fav.list",
            buildJsonObject {
                put("media_id", mediaId)
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<FavListData>>(result)
        requireSuccess(response, "收藏内容加载失败")
        return response.data?.medias.orEmpty() to (response.data?.hasMore ?: false)
    }

    suspend fun removeFavorite(mediaId: Long, aids: List<Long>) {
        if (aids.isEmpty()) return
        val resources = aids.joinToString(",") { "$it:2" }
        callOk(
            "fav.remove",
            buildJsonObject {
                put("media_id", mediaId)
                put("resources", resources)
            },
            "取消收藏失败",
        )
    }

    suspend fun createFolder(title: String) {
        callOk(
            "fav.create_folder",
            buildJsonObject {
                put("title", title)
                put("intro", "")
                put("privacy", 0)
            },
            "创建收藏夹失败",
        )
    }

    suspend fun deleteFolder(mediaId: Long) {
        callOk(
            "fav.delete_folder",
            buildJsonObject { put("media_ids", mediaId.toString()) },
            "删除收藏夹失败",
        )
    }

    suspend fun watchLater(page: Int = 1, pageSize: Int = 30): List<WatchLaterEntry> {
        val result = core.call(
            "user.later",
            buildJsonObject {
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<LaterData>>(result)
        requireSuccess(response, "稍后再看加载失败")
        return response.data?.list.orEmpty().mapNotNull { raw ->
            val video = raw.toVideoItem() ?: return@mapNotNull null
            WatchLaterEntry(aid = raw.aid ?: 0, video = video)
        }
    }

    suspend fun removeWatchLater(aids: List<Long>) {
        if (aids.isEmpty()) return
        callOk(
            "user.later.del",
            buildJsonObject { put("aids", aids.joinToString(",")) },
            "移除失败",
        )
    }

    suspend fun clearWatchLater() {
        callOk("user.later.clear", buildJsonObject { }, "清空失败")
    }

    suspend fun downloads(): DownloadListData {
        val result = core.call("download.list")
        return json.decodeFromJsonElement(result)
    }

    suspend fun pauseDownload(id: String) {
        callOk("download.pause", buildJsonObject { put("id", id) }, "暂停失败")
    }

    suspend fun resumeDownload(id: String) {
        callOk("download.resume", buildJsonObject { put("id", id) }, "恢复失败")
    }

    suspend fun removeDownload(id: String) {
        callOk("download.remove", buildJsonObject { put("id", id) }, "删除失败")
    }

    private suspend fun callOk(method: String, params: kotlinx.serialization.json.JsonObject, failure: String) {
        val result = core.call(method, params)
        val response = json.decodeFromJsonElement<LiveBasicResponse>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: failure)
        }
    }

    private fun requireSuccess(response: UpstreamResponse<*>, failure: String) {
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: failure)
        }
    }
}

internal fun kotlinx.serialization.json.JsonElement.jsonObjectOrNull(): kotlinx.serialization.json.JsonObject? =
    this as? kotlinx.serialization.json.JsonObject
