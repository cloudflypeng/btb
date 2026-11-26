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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.SearchFilterCatalog
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.theme.BtbBrand

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun PartitionsScreen(
    onBack: () -> Unit,
    onOpenPartition: (Int, String) -> Unit,
) {
    DiscoverSubScreen(title = "分区", onBack = onBack) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            SearchFilterCatalog.partitions
                .filter { it.first.isNotBlank() }
                .forEach { (tid, label) ->
                    DiscoverRow(
                        kind = ChromeGlyphKind.Grid,
                        title = label,
                        subtitle = "浏览 $label 分区内容",
                        onClick = { tid.toIntOrNull()?.let { onOpenPartition(it, label) } },
                    )
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun PartitionBrowseScreen(
    tid: Int,
    label: String,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
) {
    val context = LocalContext.current
    val container = remember(context) {
        (context.applicationContext as BtbApplication).container
    }
    var videos by remember(tid) { mutableStateOf<List<VideoItem>>(emptyList()) }
    var loading by remember(tid) { mutableStateOf(true) }
    var refreshing by remember(tid) { mutableStateOf(false) }
    var error by remember(tid) { mutableStateOf<String?>(null) }
    var reloadKey by remember(tid) { mutableStateOf(0) }

    LaunchedEffect(tid, reloadKey) {
        if (videos.isEmpty()) loading = true
        error = null
        try {
            runCatching { container.core.start() }
            videos = container.discoverRepository.partitionRanking(tid)
        } catch (throwable: Throwable) {
            error = throwable.userMessage("分区加载失败")
        } finally {
            loading = false
            refreshing = false
        }
    }

    val reload = {
        refreshing = true
        reloadKey += 1
    }

    DiscoverSubScreen(
        title = label,
        onBack = onBack,
        actions = {
            IconButton(onClick = reload) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新$label",
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
                loading -> LoadingState()

                error != null && videos.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "分区加载失败",
                    message = error ?: "",
                    actionLabel = "重试",
                    onAction = reload,
                )

                videos.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "暂无内容",
                    message = "换一个分区看看吧",
                )

                else -> PullToRefreshBox(
                    isRefreshing = refreshing,
                    onRefresh = reload,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        itemsIndexed(videos, key = { _, item -> item.bvid }) { index, video ->
                            PartitionVideoRow(rank = index + 1, video = video) { onVideoClick(video) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PartitionVideoRow(rank: Int, video: VideoItem, onClick: () -> Unit) {
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
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
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
