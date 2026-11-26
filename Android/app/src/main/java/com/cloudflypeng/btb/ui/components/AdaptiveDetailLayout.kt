package com.cloudflypeng.btb.ui.components

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdaptiveDetailLayout(
    selected: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    list: @Composable (Modifier) -> Unit,
    detail: @Composable (Modifier) -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        if (maxWidth >= 840.dp) {
            val detailWidth = (maxWidth * 0.4f).coerceIn(400.dp, 560.dp)
            Row(Modifier.fillMaxSize()) {
                list(Modifier.weight(1f))
                if (selected) {
                    VerticalDivider()
                    detail(
                        Modifier
                            .width(detailWidth)
                            .fillMaxHeight(),
                    )
                }
            }
        } else {
            list(Modifier)
            if (selected) {
                ModalBottomSheet(
                    onDismissRequest = onDismiss,
                    sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                    sheetMaxWidth = Dp.Unspecified,
                    shape = RectangleShape,
                    containerColor = MaterialTheme.colorScheme.background,
                    dragHandle = null,
                    contentWindowInsets = { WindowInsets(0) },
                ) {
                    detail(
                        Modifier
                            .fillMaxHeight()
                            .windowInsetsPadding(
                                WindowInsets.safeDrawing.only(
                                    WindowInsetsSides.Top + WindowInsetsSides.Horizontal,
                                ),
                            ),
                    )
                }
            }
        }
    }
}
