package com.cloudflypeng.btb.ui.discover

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.WeeklyConfig
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.components.VideoCard
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.theme.BtbBrand

@Composable
fun WeeklyScreen(
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    viewModel: DiscoverViewModel = viewModel(),
) {
    val ui by viewModel.weekly.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.loadWeekly() }

    DiscoverSubScreen(
        title = "每周必看",
        onBack = onBack,
        actions = {
            IconButton(onClick = { viewModel.loadWeekly(force = true) }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新每周必看",
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
                ui.isLoading && ui.series.isEmpty() -> LoadingState()

                ui.error != null && ui.series.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "每周必看加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.loadWeekly(force = true) },
                )

                else -> PullToRefreshBox(
                    isRefreshing = ui.isLoadingIssue,
                    onRefresh = { viewModel.loadWeekly(force = true) },
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item {
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                items(ui.series, key = { it.number }) { series ->
                                    WeeklyPill(
                                        label = "第${series.number}期",
                                        selected = ui.selectedNumber == series.number,
                                        onClick = { viewModel.selectWeekly(series.number) },
                                    )
                                }
                            }
                        }

                        ui.config?.let { config ->
                            item { WeeklyConfigCard(config) }
                        }

                        ui.issueError?.let { error ->
                            item {
                                MessageState(
                                    icon = Icons.Default.Warning,
                                    title = "本期加载失败",
                                    message = error,
                                    actionLabel = "重试",
                                    onAction = {
                                        ui.selectedNumber?.let { viewModel.selectWeekly(it, force = true) }
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                )
                            }
                        }

                        if (ui.isLoadingIssue && ui.videos.isEmpty()) {
                            item { LoadingState(Modifier.fillMaxWidth().height(160.dp)) }
                        } else if (ui.videos.isEmpty() && ui.issueError == null && !ui.isLoadingIssue) {
                            item {
                                MessageState(
                                    icon = Icons.Default.Star,
                                    title = "本期暂无视频",
                                    message = "换一期看看吧",
                                    modifier = Modifier.fillMaxWidth(),
                                )
                            }
                        } else {
                            ui.videos.chunked(2).forEach { row ->
                                item(key = row.joinToString("|") { it.bvid }) {
                                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        row.forEach { video ->
                                            VideoCard(
                                                video = video,
                                                onClick = { onVideoClick(video) },
                                                modifier = Modifier.weight(1f),
                                            )
                                        }
                                        repeat(2 - row.size) {
                                            Spacer(Modifier.weight(1f))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyPill(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        color = if (selected) {
            MaterialTheme.colorScheme.onBackground
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        },
        shape = RoundedCornerShape(50),
        modifier = Modifier
            .btbPressable(onClick = onClick)
            .height(34.dp),
    ) {
        Box(
            contentAlignment = androidx.compose.ui.Alignment.Center,
            modifier = Modifier.padding(horizontal = 14.dp),
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = if (selected) {
                    MaterialTheme.colorScheme.background
                } else {
                    MaterialTheme.colorScheme.onSurface
                },
            )
        }
    }
}

@Composable
private fun WeeklyConfigCard(config: WeeklyConfig) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row {
                Text(
                    text = config.name ?: "每周必看",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                config.label?.takeIf { it.isNotBlank() }?.let { label ->
                    Spacer(Modifier.size(8.dp))
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelSmall,
                        color = BtbBrand,
                    )
                }
            }
            config.subject?.takeIf { it.isNotBlank() }?.let { subject ->
                Spacer(Modifier.height(6.dp))
                Text(
                    text = subject,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.86f),
                )
            }
            config.shareSubtitle?.takeIf { it.isNotBlank() }?.let { subtitle ->
                Spacer(Modifier.height(4.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
