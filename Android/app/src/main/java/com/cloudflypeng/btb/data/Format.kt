package com.cloudflypeng.btb.data

import java.util.Locale

internal fun formatCount(value: Long): String = when {
    value >= 100_000_000 -> "${trimDecimal(value / 100_000_000.0)}亿"
    value >= 10_000 -> "${trimDecimal(value / 10_000.0)}万"
    else -> value.toString()
}

private fun trimDecimal(value: Double): String {
    if (value >= 100) return String.format(Locale.CHINA, "%.0f", value)
    val rounded = String.format(Locale.CHINA, "%.1f", value)
    return rounded.removeSuffix(".0")
}

internal fun relativeTime(epochSeconds: Long?): String {
    if (epochSeconds == null || epochSeconds <= 0) return ""
    val seconds = (System.currentTimeMillis() / 1000 - epochSeconds).coerceAtLeast(0)
    return when {
        seconds < 60 -> "刚刚"
        seconds < 3_600 -> "${seconds / 60}分钟前"
        seconds < 86_400 -> "${seconds / 3_600}小时前"
        seconds < 2_592_000 -> "${seconds / 86_400}天前"
        seconds < 31_536_000 -> "${seconds / 2_592_000}个月前"
        else -> "${seconds / 31_536_000}年前"
    }
}
