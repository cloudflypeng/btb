package com.cloudflypeng.btb.core

import kotlinx.coroutines.flow.SharedFlow
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

sealed interface CoreStatus {
    data object Starting : CoreStatus
    data object Ready : CoreStatus
    data class Failed(val message: String) : CoreStatus
}

data class CoreEvent(val method: String, val params: JsonObject)

class CoreException(
    val code: Int?,
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

interface CoreTransport {
    val events: SharedFlow<CoreEvent>
    suspend fun start()
    suspend fun stop()
    suspend fun call(method: String, params: JsonObject = JsonObject(emptyMap())): JsonElement
}
