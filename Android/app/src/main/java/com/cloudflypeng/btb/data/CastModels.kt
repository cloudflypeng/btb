package com.cloudflypeng.btb.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CastDevice(
    val id: String = "",
    val name: String = "",
    val model: String? = null,
    val manufacturer: String? = null,
    val host: String? = null,
    val location: String? = null,
    @SerialName("av_transport_url") val avTransportUrl: String = "",
) {
    val subtitle: String
        get() = listOfNotNull(
            model?.takeIf { it.isNotBlank() },
            manufacturer?.takeIf { it.isNotBlank() },
        ).distinct().joinToString(" · ").ifBlank { host.orEmpty() }
}

@Serializable
data class CastDevicesResponse(val devices: List<CastDevice> = emptyList())

@Serializable
data class CastPlayResponse(
    val playing: Boolean = false,
    val mode: String? = null,
    val kind: String? = null,
    val title: String? = null,
    val message: String? = null,
    @SerialName("session_id") val sessionId: String? = null,
    @SerialName("playback_url") val playbackUrl: String? = null,
    val device: CastDevice? = null,
    @SerialName("started_at") val startedAt: Long? = null,
)

@Serializable
data class CastStatusResponse(
    val active: Boolean = false,
    val mode: String? = null,
    val kind: String? = null,
    val title: String? = null,
    val device: CastDevice? = null,
    @SerialName("session_id") val sessionId: String? = null,
)

data class CastTarget(
    val device: CastDevice,
    val title: String,
    val kind: String,
    val mode: String? = null,
) {
    val isDirect: Boolean get() = mode == "direct"
}
