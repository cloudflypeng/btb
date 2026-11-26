package com.cloudflypeng.btb.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ThemeMode(val label: String) {
    System("跟随系统"),
    Dark("深色"),
    Light("浅色"),
}

data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.System,
    val autoplayNext: Boolean = true,
    val defaultQuality: Long = 80,
    val danmakuEnabled: Boolean = true,
    val danmakuOpacity: Float = 0.92f,
    val danmakuSpeed: Float = 1f,
    val danmakuFontScale: Float = 1f,
    val danmakuBlockWords: String = "",
)

class SettingsStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("btb.settings", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow(read())
    val state: StateFlow<AppSettings> = _state.asStateFlow()

    val current: AppSettings get() = _state.value

    fun setThemeMode(mode: ThemeMode) = update { it.copy(themeMode = mode) }
    fun setAutoplayNext(enabled: Boolean) = update { it.copy(autoplayNext = enabled) }
    fun setDefaultQuality(qn: Long) = update { it.copy(defaultQuality = qn) }
    fun setDanmakuEnabled(enabled: Boolean) = update { it.copy(danmakuEnabled = enabled) }
    fun setDanmakuOpacity(value: Float) = update { it.copy(danmakuOpacity = value) }
    fun setDanmakuSpeed(value: Float) = update { it.copy(danmakuSpeed = value) }
    fun setDanmakuFontScale(value: Float) = update { it.copy(danmakuFontScale = value) }
    fun setDanmakuBlockWords(value: String) = update { it.copy(danmakuBlockWords = value) }

    private fun update(transform: (AppSettings) -> AppSettings) {
        val next = transform(_state.value)
        _state.value = next
        prefs.edit()
            .putString("theme", next.themeMode.name)
            .putBoolean("autoplay", next.autoplayNext)
            .putLong("quality", next.defaultQuality)
            .putBoolean("danmaku", next.danmakuEnabled)
            .putFloat("danmakuOpacity", next.danmakuOpacity)
            .putFloat("danmakuSpeed", next.danmakuSpeed)
            .putFloat("danmakuFontScale", next.danmakuFontScale)
            .putString("danmakuBlock", next.danmakuBlockWords)
            .apply()
    }

    private fun read(): AppSettings = AppSettings(
        themeMode = runCatching {
            ThemeMode.valueOf(prefs.getString("theme", ThemeMode.System.name) ?: ThemeMode.System.name)
        }.getOrDefault(ThemeMode.System),
        autoplayNext = prefs.getBoolean("autoplay", true),
        defaultQuality = prefs.getLong("quality", 80),
        danmakuEnabled = prefs.getBoolean("danmaku", true),
        danmakuOpacity = prefs.getFloat("danmakuOpacity", 0.92f),
        danmakuSpeed = prefs.getFloat("danmakuSpeed", 1f),
        danmakuFontScale = prefs.getFloat("danmakuFontScale", 1f),
        danmakuBlockWords = prefs.getString("danmakuBlock", "").orEmpty(),
    )
}

data class PlaybackSettings(
    val autoplayNext: Boolean,
    val defaultQuality: Long,
    val danmakuEnabled: Boolean,
    val danmakuOpacity: Float,
    val danmakuSpeed: Float,
    val danmakuFontScale: Float,
    val danmakuBlockWords: String,
)

fun AppSettings.playbackSettings() = PlaybackSettings(
    autoplayNext = autoplayNext,
    defaultQuality = defaultQuality,
    danmakuEnabled = danmakuEnabled,
    danmakuOpacity = danmakuOpacity,
    danmakuSpeed = danmakuSpeed,
    danmakuFontScale = danmakuFontScale,
    danmakuBlockWords = danmakuBlockWords,
)
