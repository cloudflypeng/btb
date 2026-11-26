package com.cloudflypeng.btb.ui.interaction

import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import com.cloudflypeng.btb.ui.theme.BtbMotion

@Composable
fun rememberAnimationsEnabled(): Boolean {
    val context = LocalContext.current
    return remember(context) {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) > 0f
    }
}

@Composable
fun rememberHapticFeedback(): HapticFeedback {
    val view = LocalView.current
    return remember(view) { HapticFeedback(view) }
}

class HapticFeedback internal constructor(private val view: View) {
    fun tap() {
        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }
}

fun Modifier.btbPressable(
    enabled: Boolean = true,
    haptic: Boolean = true,
    onClick: () -> Unit,
): Modifier = composed {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val animationsEnabled = rememberAnimationsEnabled()
    val haptics = rememberHapticFeedback()
    val scale by animateFloatAsState(
        targetValue = if (pressed && animationsEnabled) 0.98f else 1f,
        animationSpec = tween(durationMillis = BtbMotion.Press, easing = BtbMotion.EaseOut),
        label = "btb-press-scale",
    )

    this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
        .clickable(
            interactionSource = interactionSource,
            indication = LocalIndication.current,
            enabled = enabled,
        ) {
            if (haptic) {
                haptics.tap()
            }
            onClick()
        }
}
