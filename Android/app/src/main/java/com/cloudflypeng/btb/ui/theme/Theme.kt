package com.cloudflypeng.btb.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

val BtbBrand = Color(0xFFFF0033)
val BtbAccent = Color(0xFF3EA6FF)

private val LightColors = lightColorScheme(
    primary = BtbBrand,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFD9E0),
    onPrimaryContainer = Color(0xFF3F0010),
    secondary = BtbAccent,
    onSecondary = Color(0xFF00344F),
    secondaryContainer = Color(0xFFE5E5E5),
    onSecondaryContainer = Color(0xFF0F0F0F),
    tertiary = BtbAccent,
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFD6EEFF),
    onTertiaryContainer = Color(0xFF00344F),
    background = Color.White,
    onBackground = Color(0xFF0F0F0F),
    surface = Color.White,
    onSurface = Color(0xFF0F0F0F),
    surfaceVariant = Color(0xFFF2F2F2),
    onSurfaceVariant = Color(0xFF606060),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFFAFAFA),
    surfaceContainer = Color(0xFFF2F2F2),
    surfaceContainerHigh = Color(0xFFEDEDED),
    surfaceContainerHighest = Color(0xFFE5E5E5),
    outline = Color(0xFF909090),
    outlineVariant = Color(0xFFE5E5E5),
)

private val DarkColors = darkColorScheme(
    primary = BtbBrand,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF5E0018),
    onPrimaryContainer = Color(0xFFFFD9E0),
    secondary = BtbAccent,
    onSecondary = Color(0xFF00344F),
    secondaryContainer = Color(0xFF303030),
    onSecondaryContainer = Color.White,
    tertiary = BtbAccent,
    onTertiary = Color(0xFF00344F),
    tertiaryContainer = Color(0xFF004A6B),
    onTertiaryContainer = Color(0xFFD6EEFF),
    background = Color(0xFF0F0F0F),
    onBackground = Color.White,
    surface = Color(0xFF0F0F0F),
    onSurface = Color.White,
    surfaceVariant = Color(0xFF212121),
    onSurfaceVariant = Color(0xFFAAAAAA),
    surfaceContainerLowest = Color(0xFF0A0A0A),
    surfaceContainerLow = Color(0xFF141414),
    surfaceContainer = Color(0xFF1B1B1B),
    surfaceContainerHigh = Color(0xFF212121),
    surfaceContainerHighest = Color(0xFF2A2A2A),
    outline = Color(0xFF717171),
    outlineVariant = Color(0xFF303030),
)

@Composable
fun BtbTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}

object BtbMotion {
    const val Fast = 160
    const val Base = 220
    const val Slow = 340
    const val Press = 120

    // Strong ease-out; FastOutSlowIn is too weak for UI feedback.
    val EaseOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)
    val EaseInOut = CubicBezierEasing(0.77f, 0f, 0.175f, 1f)
}

object BtbDimens {
    val radiusSmall = 8.dp
    val radiusCard = 12.dp
    val radiusPanel = 16.dp
    val controlHeight = 32.dp
    val pagePadding = 16.dp
}
