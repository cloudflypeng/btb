package com.cloudflypeng.btb.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

data class ContentState(
    val icon: ImageVector,
    val title: String,
    val message: String? = null,
    val actionLabel: String? = null,
    val onAction: (() -> Unit)? = null,
)

@Composable
fun ContentStateView(
    state: ContentState,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    iconSize: Dp = 44.dp,
    verticalPadding: Dp = 32.dp,
) {
    Box(
        modifier = modifier.padding(horizontal = 32.dp, vertical = verticalPadding),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 12.dp),
        ) {
            Icon(
                imageVector = state.icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(iconSize),
            )
            Text(
                text = state.title,
                style = if (compact) {
                    MaterialTheme.typography.titleSmall
                } else {
                    MaterialTheme.typography.titleMedium
                },
                textAlign = TextAlign.Center,
            )
            state.message?.let { message ->
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            if (state.actionLabel != null && state.onAction != null) {
                TextButton(onClick = state.onAction) {
                    Text(state.actionLabel)
                }
            }
        }
    }
}

@Composable
fun LoadingState(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(strokeWidth = 2.dp)
    }
}

@Composable
fun MessageState(
    icon: ImageVector,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    ContentStateView(
        state = ContentState(
            icon = icon,
            title = title,
            message = message,
            actionLabel = actionLabel,
            onAction = onAction,
        ),
        modifier = modifier.fillMaxSize(),
    )
}

enum class NoticeTone { Info, Warning, Error }

@Composable
fun InlineNotice(
    text: String,
    modifier: Modifier = Modifier,
    tone: NoticeTone = NoticeTone.Warning,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    onDismiss: (() -> Unit)? = null,
) {
    val icon = when (tone) {
        NoticeTone.Info -> Icons.Default.Info
        NoticeTone.Warning, NoticeTone.Error -> Icons.Default.Warning
    }
    val tint = when (tone) {
        NoticeTone.Info -> MaterialTheme.colorScheme.secondary
        NoticeTone.Warning -> Color(0xFFE08A00)
        NoticeTone.Error -> MaterialTheme.colorScheme.error
    }
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(16.dp),
            )
            Text(
                text = text,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            if (actionLabel != null && onAction != null) {
                TextButton(onClick = onAction) {
                    Text(actionLabel)
                }
            }
            if (onDismiss != null) {
                IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "关闭提示",
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
    }
}
