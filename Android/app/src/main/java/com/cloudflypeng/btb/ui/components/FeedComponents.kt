package com.cloudflypeng.btb.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.theme.BtbBrand
import kotlinx.coroutines.flow.distinctUntilChanged

@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    count: Int? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        if (count != null && count > 0) {
            Spacer(Modifier.width(6.dp))
            Text(
                text = formatCount(count.toLong()),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.weight(1f))
        if (actionLabel != null && onAction != null) {
            TextButton(onClick = onAction) {
                Text(actionLabel)
            }
        }
    }
}

data class FilterPill(
    val label: String,
    val badge: Int = 0,
)

@Composable
fun FilterPillRow(
    items: List<FilterPill>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
) {
    LazyRow(
        modifier = modifier.fillMaxWidth(),
        contentPadding = contentPadding,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        itemsIndexed(items) { index, item ->
            FilterPillChip(
                item = item,
                selected = index == selectedIndex,
                onClick = { onSelect(index) },
            )
        }
    }
}

@Composable
private fun FilterPillChip(
    item: FilterPill,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        modifier = Modifier
            .clip(CircleShape)
            .background(
                if (selected) {
                    MaterialTheme.colorScheme.onBackground
                } else {
                    MaterialTheme.colorScheme.surfaceVariant
                },
            )
            .btbPressable(haptic = false, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 7.dp),
    ) {
        Text(
            text = item.label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) {
                MaterialTheme.colorScheme.background
            } else {
                MaterialTheme.colorScheme.onSurface
            },
        )
        if (item.badge > 0) {
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .background(BtbBrand, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (item.badge > 99) "99+" else item.badge.toString(),
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
fun LoadMoreFooter(
    isLoading: Boolean,
    hasMore: Boolean,
    failed: Boolean,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    endText: String = "没有更多了",
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        when {
            failed -> TextButton(onClick = onRetry) {
                Text("加载失败，点击重试")
            }

            isLoading -> CircularProgressIndicator(
                strokeWidth = 2.dp,
                modifier = Modifier.size(20.dp),
            )

            !hasMore -> Text(
                text = endText,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun LoadMoreEffect(
    listState: LazyListState,
    itemCount: Int,
    hasMore: Boolean,
    isLoading: Boolean,
    onLoadMore: () -> Unit,
    enabled: Boolean = true,
    threshold: Int = 3,
) {
    LaunchedEffect(listState, itemCount, hasMore, isLoading, enabled) {
        if (!enabled) return@LaunchedEffect
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1 }
            .distinctUntilChanged()
            .collect { index ->
                if (hasMore && !isLoading && itemCount > 0 && index >= itemCount - threshold) {
                    onLoadMore()
                }
            }
    }
}

@Composable
fun LoadMoreEffect(
    gridState: LazyGridState,
    itemCount: Int,
    hasMore: Boolean,
    isLoading: Boolean,
    onLoadMore: () -> Unit,
    enabled: Boolean = true,
    threshold: Int = 3,
) {
    LaunchedEffect(gridState, itemCount, hasMore, isLoading, enabled) {
        if (!enabled) return@LaunchedEffect
        snapshotFlow { gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1 }
            .distinctUntilChanged()
            .collect { index ->
                if (hasMore && !isLoading && itemCount > 0 && index >= itemCount - threshold) {
                    onLoadMore()
                }
            }
    }
}
