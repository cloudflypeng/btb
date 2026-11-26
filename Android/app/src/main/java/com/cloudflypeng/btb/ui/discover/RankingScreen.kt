package com.cloudflypeng.btb.ui.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.theme.BtbBrand

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RankingScreen(
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    viewModel: DiscoverViewModel = viewModel(),
) {
    val ui by viewModel.ranking.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.loadRanking() }

    DiscoverSubScreen(
        title = "排行榜",
        onBack = onBack,
        actions = {
            IconButton(onClick = { viewModel.loadRanking(force = true) }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新排行榜",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
            }
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading && ui.items.isEmpty() -> LoadingState()

                ui.error != null && ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "排行榜加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.loadRanking(force = true) },
                )

                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "暂无排行榜",
                    message = "稍后刷新试试",
                )

                else -> PullToRefreshBox(
                    isRefreshing = ui.isRefreshing,
                    onRefresh = { viewModel.loadRanking(force = true) },
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        itemsIndexed(ui.items, key = { _, item -> item.bvid }) { index, video ->
                            RankingRow(rank = index + 1, video = video, onClick = { onVideoClick(video) })
                        }
                        item {
                            LoadMoreFooter(
                                isLoading = false,
                                hasMore = false,
                                failed = false,
                                onRetry = {},
                                endText = "共 ${ui.items.size} 个视频",
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RankingRow(rank: Int, video: VideoItem, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick)
            .padding(vertical = 8.dp),
    ) {
        Text(
            text = rank.toString(),
            style = TextStyle(
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                fontFeatureSettings = "tnum",
            ),
            color = if (rank <= 3) BtbBrand else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            modifier = Modifier.width(27.dp),
        )
        Box(
            modifier = Modifier
                .width(118.dp)
                .height(66.dp)
                .clip(RoundedCornerShape(8.dp)),
        ) {
            BtbImage(
                url = video.coverUrl,
                contentDescription = video.title,
                modifier = Modifier.fillMaxSize(),
            )
            if (video.durationText.isNotEmpty()) {
                Text(
                    text = video.durationText,
                    color = androidx.compose.ui.graphics.Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(5.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.78f))
                        .padding(horizontal = 4.dp, vertical = 1.dp),
                )
            }
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = video.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(5.dp))
            Text(
                text = listOfNotNull(
                    video.ownerName.takeIf { it.isNotBlank() },
                    video.viewText.takeIf { it.isNotBlank() }?.let { "${it}观看" },
                    video.publishedText.takeIf { it.isNotBlank() },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
