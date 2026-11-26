package com.cloudflypeng.btb.core

import android.content.Context
import com.cloudflypeng.bbcore.mobile.EventHandler
import com.cloudflypeng.bbcore.mobile.Mobile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import java.io.File

class EmbeddedCoreTransport(context: Context) : CoreTransport {
    private val appContext = context.applicationContext
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val eventSink = MutableSharedFlow<CoreEvent>(
        extraBufferCapacity = 1024,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    override val events: SharedFlow<CoreEvent> = eventSink.asSharedFlow()

    private val lifecycle = Mutex()
    private var running = false

    init {
        Mobile.setEventHandler(object : EventHandler {
            override fun onEvent(payload: String) {
                val message = runCatching { json.parseToJsonElement(payload).jsonObject }.getOrNull() ?: return
                val method = (message["method"] as? JsonPrimitive)?.contentOrNull ?: return
                val envelope = (message["params"] as? JsonObject) ?: JsonObject(emptyMap())
                // The embedded transport wraps every notification as {seq, ts, data};
                // consumers want the topic payload itself.
                val params = (envelope["data"] as? JsonObject) ?: envelope
                eventSink.tryEmit(CoreEvent(method, params))
            }
        })
    }

    override suspend fun start() {
        lifecycle.withLock {
            if (running) return
            withContext(Dispatchers.IO) {
                val directory = File(appContext.noBackupFilesDir, "bbcore")
                if (!directory.isDirectory) {
                    directory.mkdirs()
                }
                try {
                    Mobile.start(directory.absolutePath)
                } catch (error: Exception) {
                    if (!error.message.orEmpty().contains("already running")) throw error
                }
            }
            running = true
        }
    }

    override suspend fun stop() {
        lifecycle.withLock {
            if (!running) return
            withContext(Dispatchers.IO) { Mobile.stop() }
            running = false
        }
    }

    override suspend fun call(method: String, params: JsonObject): JsonElement {
        val result = withContext(Dispatchers.IO) {
            try {
                Mobile.call(method, params.toString())
            } catch (error: Exception) {
                throw error.toCoreException()
            }
        }
        return json.parseToJsonElement(result)
    }
}

private fun Throwable.toCoreException(): CoreException {
    val raw = message?.trim().orEmpty()
    val code = raw.substringBefore(':', "").trim().toIntOrNull()
    val text = if (code != null) raw.substringAfter(':', raw).trim() else raw
    return CoreException(code, text.ifEmpty { "核心调用失败" }, this)
}
