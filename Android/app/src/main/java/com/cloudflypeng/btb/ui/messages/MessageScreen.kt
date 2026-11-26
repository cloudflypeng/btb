package com.cloudflypeng.btb.ui.messages

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cloudflypeng.btb.data.MessageEntry
import com.cloudflypeng.btb.data.MessageTab
import com.cloudflypeng.btb.data.MessageUnread
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.components.AdaptiveDetailLayout
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.FilterPill
import com.cloudflypeng.btb.ui.components.FilterPillRow
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.MessageRowSkeleton
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.home.VideoDetailPane
import com.cloudflypeng.btb.ui.interaction.btbPressable

@Composable
fun MessageDestination(
    ui: MessagesUiState,
    viewModel: MessageViewModel,
    selectedVideo: VideoItem?,
    controller: PlaybackController?,
    ensureAccount: suspend () -> Boolean,
    onSelectVideo: (VideoItem?) -> Unit,
    onOpenLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AdaptiveDetailLayout(
        selected = selectedVideo != null,
        onDismiss = { onSelectVideo(null) },
        modifier = modifier,
        list = { listModifier ->
            MessageScreen(
                ui = ui,
                onSelectTab = viewModel::select,
                onRefresh = viewModel::refresh,
                onRetry = viewModel::retry,
                onLoadMore = viewModel::loadMore,
                onOpenLogin = onOpenLogin,
                onVideoClick = onSelectVideo,
                modifier = listModifier,
            )
        },
        detail = { detailModifier ->
            val video = selectedVideo
            if (video != null && controller != null) {
                VideoDetailPane(
                    video = video,
                    controller = controller,
                    ensureAccount = ensureAccount,
                    onClose = { onSelectVideo(null) },
                    onOpenLogin = onOpenLogin,
                    modifier = detailModifier,
                )
            }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageScreen(
    ui: MessagesUiState,
    onSelectTab: (MessageTab) -> Unit,
    onRefresh: () -> Unit,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    onOpenLogin: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("消息", fontWeight = FontWeight.Bold) },
                actions = {
                    if (ui.hasAccount == false) {
                        TextButton(onClick = onOpenLogin) {
                            Text("登录")
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            MessageTabRow(
                selected = ui.selected,
                unread = ui.unread,
                onSelect = onSelectTab,
            )
            Box(Modifier.fillMaxSize()) {
                when {
                    ui.hasAccount == false -> MessageState(
                        icon = Icons.Default.Person,
                        title = "登录后查看消息",
                        message = "登录 B 站账号后，回复、@、点赞和系统通知会显示在这里。",
                        actionLabel = "登录",
                        onAction = onOpenLogin,
                    )

                    ui.coreStatus is com.cloudflypeng.btb.core.CoreStatus.Failed -> MessageState(
                        icon = Icons.Default.Warning,
                        title = "核心启动失败",
                        message = ui.coreStatus.message,
                        actionLabel = "重试",
                        onAction = onRetry,
                    )

                    ui.hasAccount == null -> MessageSkeleton()

                    ui.currentFeed.isLoading && ui.currentFeed.items.isEmpty() -> MessageSkeleton()

                    ui.currentFeed.error != null && ui.currentFeed.items.isEmpty() -> MessageState(
                        icon = Icons.Default.Warning,
                        title = "消息加载失败",
                        message = ui.currentFeed.error ?: "请稍后重试",
                        actionLabel = "重试",
                        onAction = onRetry,
                    )

                    ui.currentFeed.items.isEmpty() && ui.currentFeed.loaded -> MessageState(
                        icon = Icons.Default.Person,
                        title = emptyTitle(ui.selected),
                        message = emptyMessage(ui.selected),
                    )

                    else -> MessageFeedList(
                        ui = ui,
                        onRefresh = onRefresh,
                        onLoadMore = onLoadMore,
                        onVideoClick = onVideoClick,
                    )
                }
            }
        }
    }
}

@Composable
private fun MessageTabRow(
    selected: MessageTab,
    unread: MessageUnread,
    onSelect: (MessageTab) -> Unit,
) {
    FilterPillRow(
        items = MessageTab.entries.map { FilterPill(it.label, unread.count(it)) },
        selectedIndex = MessageTab.entries.indexOf(selected),
        onSelect = { onSelect(MessageTab.entries[it]) },
    )
}

@Composable
private fun MessageSkeleton() {
    LazyColumn(
        contentPadding = PaddingValues(bottom = 24.dp),
        userScrollEnabled = false,
        modifier = Modifier.fillMaxSize(),
    ) {
        items(6) {
            MessageRowSkeleton()
            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f),
                modifier = Modifier.padding(start = 64.dp),
            )
        }
    }
}

@Composable
private fun MessageFeedList(
    ui: MessagesUiState,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
) {
    val feed = ui.currentFeed
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = feed.items.size,
        hasMore = feed.hasMore,
        isLoading = feed.isLoadingMore,
        onLoadMore = onLoadMore,
        enabled = feed.error == null,
    )

    PullToRefreshBox(
        isRefreshing = feed.isLoading && feed.items.isNotEmpty(),
        onRefresh = onRefresh,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            state = listState,
            contentPadding = PaddingValues(bottom = 24.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            items(feed.items, key = { it.id }) { entry ->
                MessageRow(entry) {
                    val bvid = entry.bvid ?: return@MessageRow
                    onVideoClick(
                        VideoItem(
                            bvid = bvid,
                            title = entry.context.ifBlank { entry.text },
                            coverUrl = null,
                            ownerName = entry.userName,
                            ownerFaceUrl = entry.avatarUrl,
                            viewText = "",
                            durationText = "",
                            publishedText = entry.timeText,
                            description = "",
                        ),
                    )
                }
                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f),
                    modifier = Modifier.padding(start = 64.dp),
                )
            }

            item {
                LoadMoreFooter(
                    isLoading = feed.isLoadingMore,
                    hasMore = feed.hasMore,
                    failed = feed.error != null && feed.items.isNotEmpty(),
                    onRetry = onLoadMore,
                    endText = "没有更多消息了",
                )
            }
        }
    }
}

@Composable
private fun MessageRow(entry: MessageEntry, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Avatar(url = entry.avatarUrl, size = 38.dp)
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = entry.userName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = entry.timeText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(2.dp))
            Text(
                text = entry.action,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = entry.text,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 5,
                overflow = TextOverflow.Ellipsis,
            )
            if (entry.context.isNotBlank()) {
                Spacer(Modifier.height(6.dp))
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(8.dp),
                ) {
                    Text(
                        text = entry.context,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                    )
                }
            }
        }
    }
}

private fun emptyTitle(tab: MessageTab): String = when (tab) {
    MessageTab.Replies -> "还没有收到回复"
    MessageTab.Ats -> "还没有人提到你"
    MessageTab.Likes -> "还没有收到赞"
    MessageTab.System -> "没有系统通知"
}

private fun emptyMessage(tab: MessageTab): String = when (tab) {
    MessageTab.Replies -> "别人回复你的评论时会出现在这里。"
    MessageTab.Ats -> "有人在评论或动态中 @ 你时会出现在这里。"
    MessageTab.Likes -> "别人赞了你的评论、弹幕或动态时会出现在这里。"
    MessageTab.System -> "账号与平台通知会出现在这里。"
}
