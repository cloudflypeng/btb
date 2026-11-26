package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

class CastRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun discover(timeoutMs: Long = 3000): List<CastDevice> {
        core.start()
        val result = core.call(
            "cast.discover",
            buildJsonObject { put("timeout_ms", timeoutMs) },
        )
        return json.decodeFromJsonElement<CastDevicesResponse>(result).devices
    }

    suspend fun playVideo(
        device: CastDevice,
        bvid: String,
        cid: Long?,
        page: Int,
        qn: Long,
        codec: String?,
        title: String,
        positionMs: Long,
    ): CastPlayResponse {
        val params = buildJsonObject {
            putDevice(device)
            put("bvid", bvid)
            if (cid != null && cid > 0) put("cid", cid)
            put("page", page)
            put("qn", qn)
            if (!codec.isNullOrBlank()) put("codec", codec)
            put("title", title)
            if (positionMs > 1000) put("position_ms", positionMs)
        }
        return play(params)
    }

    suspend fun playPgc(
        device: CastDevice,
        seasonId: Long,
        episodeId: Long?,
        qn: Long?,
        title: String,
        positionMs: Long,
    ): CastPlayResponse {
        val params = buildJsonObject {
            putDevice(device)
            if (seasonId > 0) put("season_id", seasonId)
            if (episodeId != null && episodeId > 0) put("ep_id", episodeId)
            if (qn != null && qn > 0) put("qn", qn)
            put("title", title)
            if (positionMs > 1000) put("position_ms", positionMs)
        }
        return play(params)
    }

    suspend fun playLive(
        device: CastDevice,
        roomId: Long,
        title: String,
    ): CastPlayResponse {
        val params = buildJsonObject {
            putDevice(device)
            put("room_id", roomId)
            put("title", title)
        }
        return play(params)
    }

    suspend fun stop() {
        core.call("cast.stop")
    }

    suspend fun status(): CastStatusResponse {
        val result = core.call("cast.status")
        return json.decodeFromJsonElement(result)
    }

    private suspend fun play(params: kotlinx.serialization.json.JsonObject): CastPlayResponse {
        core.start()
        val result = core.call("cast.play", params)
        return json.decodeFromJsonElement(result)
    }

    private fun kotlinx.serialization.json.JsonObjectBuilder.putDevice(device: CastDevice) {
        put("control_url", device.avTransportUrl)
        put("device_id", device.id)
        put("device_name", device.name)
    }
}
