package com.cloudflypeng.btb.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

enum class ChromeGlyphKind {
    Ranking,
    Weekly,
    Article,
    Topic,
    Grid,
    Live,
    Movie,
    ChevronRight,
    Back,
    Search,
    Cast,
    Tv,
}

@Composable
fun ChromeGlyph(
    kind: ChromeGlyphKind,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val unit = size.width / 24f
        val stroke = Stroke(width = 1.8f * unit, cap = androidx.compose.ui.graphics.StrokeCap.Round)
        fun line(x1: Float, y1: Float, x2: Float, y2: Float) {
            drawLine(color, Offset(x1 * unit, y1 * unit), Offset(x2 * unit, y2 * unit), strokeWidth = stroke.width, cap = androidx.compose.ui.graphics.StrokeCap.Round)
        }
        fun rect(x: Float, y: Float, rw: Float, rh: Float, corner: Float = 2f) {
            drawRoundRect(
                color = color,
                topLeft = Offset(x * unit, y * unit),
                size = Size(rw * unit, rh * unit),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(corner * unit, corner * unit),
                style = stroke,
            )
        }
        fun dot(x: Float, y: Float, r: Float) {
            drawCircle(color, radius = r * unit, center = Offset(x * unit, y * unit))
        }

        when (kind) {
            ChromeGlyphKind.Ranking -> {
                rect(3.5f, 13f, 4f, 7f, 1.2f)
                rect(10f, 8f, 4f, 12f, 1.2f)
                rect(16.5f, 3.5f, 4f, 16.5f, 1.2f)
            }

            ChromeGlyphKind.Weekly -> {
                rect(3.5f, 5.5f, 17f, 15f)
                line(3.5f, 10f, 20.5f, 10f)
                line(8f, 3f, 8f, 7f)
                line(16f, 3f, 16f, 7f)
                dot(8f, 14f, 0.9f)
                dot(12f, 14f, 0.9f)
                dot(16f, 14f, 0.9f)
            }

            ChromeGlyphKind.Article -> {
                rect(5.5f, 3.5f, 13f, 17f)
                line(8.5f, 8f, 15.5f, 8f)
                line(8.5f, 12f, 15.5f, 12f)
                line(8.5f, 16f, 12.5f, 16f)
            }

            ChromeGlyphKind.Topic -> {
                line(9.5f, 4f, 7.5f, 20f)
                line(16.5f, 4f, 14.5f, 20f)
                line(4.5f, 9f, 19.5f, 9f)
                line(3.5f, 15f, 18.5f, 15f)
            }

            ChromeGlyphKind.Grid -> {
                rect(3.5f, 3.5f, 7f, 7f, 1.5f)
                rect(13.5f, 3.5f, 7f, 7f, 1.5f)
                rect(3.5f, 13.5f, 7f, 7f, 1.5f)
                rect(13.5f, 13.5f, 7f, 7f, 1.5f)
            }

            ChromeGlyphKind.Live -> {
                rect(3.5f, 6.5f, 17f, 12f, 2f)
                val path = Path().apply {
                    moveTo(10.5f * unit, 10f * unit)
                    lineTo(15f * unit, 12.5f * unit)
                    lineTo(10.5f * unit, 15f * unit)
                    close()
                }
                drawPath(path, color)
                line(8f, 3f, 6f, 5.5f)
                line(16f, 3f, 18f, 5.5f)
            }

            ChromeGlyphKind.Movie -> {
                rect(3.5f, 5.5f, 17f, 14f, 2f)
                line(3.5f, 9.5f, 20.5f, 9.5f)
                dot(7f, 7.5f, 0.8f)
                dot(12f, 7.5f, 0.8f)
                dot(17f, 7.5f, 0.8f)
                line(10f, 12f, 10f, 16.5f)
                line(14f, 12f, 14f, 16.5f)
            }

            ChromeGlyphKind.ChevronRight -> {
                line(9.5f, 5f, 16.5f, 12f)
                line(16.5f, 12f, 9.5f, 19f)
            }

            ChromeGlyphKind.Back -> {
                line(14.5f, 5f, 7.5f, 12f)
                line(7.5f, 12f, 14.5f, 19f)
            }

            ChromeGlyphKind.Search -> {
                drawCircle(color, radius = 6.2f * unit, center = Offset(10.5f * unit, 10.5f * unit), style = stroke)
                line(15.2f, 15.2f, 20f, 20f)
            }

            ChromeGlyphKind.Cast -> {
                val screen = Path().apply {
                    moveTo(4.2f * unit, 17.8f * unit)
                    lineTo(20.5f * unit, 17.8f * unit)
                    lineTo(20.5f * unit, 4.2f * unit)
                    lineTo(3.5f * unit, 4.2f * unit)
                    lineTo(3.5f * unit, 13.8f * unit)
                }
                drawPath(screen, color, style = stroke)
                drawArc(
                    color = color,
                    startAngle = 270f,
                    sweepAngle = 90f,
                    useCenter = false,
                    topLeft = Offset(-1f * unit, 13.5f * unit),
                    size = Size(9f * unit, 9f * unit),
                    style = stroke,
                )
                drawArc(
                    color = color,
                    startAngle = 270f,
                    sweepAngle = 90f,
                    useCenter = false,
                    topLeft = Offset(-4.5f * unit, 10f * unit),
                    size = Size(16f * unit, 16f * unit),
                    style = stroke,
                )
                dot(3.5f, 17.8f, 1.1f)
            }

            ChromeGlyphKind.Tv -> {
                rect(3.5f, 5.5f, 17f, 12f, 2f)
                line(9f, 20.5f, 15f, 20.5f)
                line(12f, 17.5f, 12f, 20.5f)
            }
        }
    }
}
