package com.cloudflypeng.btb.ui.dynamic

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloudflypeng.btb.data.DynamicAttachment
import com.cloudflypeng.btb.data.DynamicCard
import com.cloudflypeng.btb.data.DynamicPicture
import com.cloudflypeng.btb.data.DynamicVideo
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.components.AdaptiveDetailLayout
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.DynamicCardSkeleton
import com.cloudflypeng.btb.ui.components.FilterPill
import com.cloudflypeng.btb.ui.components.FilterPillRow
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.home.VideoDetailPane
import com.cloudflypeng.btb.ui.interaction.btbPressable

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DynamicDestination(
    ui: DynamicUiState,
    viewModel: DynamicViewModel,
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
        list = { modifier ->
            DynamicScreen(
                ui = ui,
                onRetry = viewModel::retry,
                onRefresh = viewModel::refresh,
                onLoadMore = viewModel::loadMore,
                onSelectTab = viewModel::selectTab,
                onToggleLike = viewModel::toggleLike,
                onOpenLogin = onOpenLogin,
                onVideoClick = onSelectVideo,
                modifier = modifier,
            )
        },
        detail = { modifier ->
            val video = selectedVideo
            if (video != null && controller != null) {
                VideoDetailPane(
                    video = video,
                    controller = controller,
                    ensureAccount = ensureAccount,
                    onClose = { onSelectVideo(null) },
                    onOpenLogin = onOpenLogin,
                    modifier = modifier,
                )
            }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DynamicScreen(
    ui: DynamicUiState,
    onRetry: () -> Unit,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onSelectTab: (DynamicTab) -> Unit,
    onToggleLike: (DynamicCard) -> Unit,
    onOpenLogin: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("动态", fontWeight = FontWeight.Bold) },
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
            DynamicTabRow(selected = ui.tab, onSelect = onSelectTab)
            Box(Modifier.fillMaxSize()) {
                when {
                    ui.hasAccount == false -> MessageState(
                        icon = Icons.Default.Person,
                        title = "登录后查看关注动态",
                        message = "登录 B 站账号，关注 UP 主的视频和图文动态会出现在这里。",
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

                    ui.hasAccount == null -> DynamicSkeleton()

                    ui.isLoading && ui.items.isEmpty() -> DynamicSkeleton()

                    ui.error != null && ui.items.isEmpty() -> MessageState(
                        icon = Icons.Default.Warning,
                        title = "动态加载失败",
                        message = ui.error,
                        actionLabel = "重试",
                        onAction = onRetry,
                    )

                    ui.items.isEmpty() && !ui.isLoading -> MessageState(
                        icon = Icons.Default.Person,
                        title = "还没有新动态",
                        message = "关注一些 UP 主后，他们的更新会显示在这里。",
                    )

                    else -> DynamicFeed(
                        ui = ui,
                        onRefresh = onRefresh,
                        onLoadMore = onLoadMore,
                        onToggleLike = onToggleLike,
                        onVideoClick = onVideoClick,
                    )
                }
            }
        }
    }
}

@Composable
private fun DynamicTabRow(
    selected: DynamicTab,
    onSelect: (DynamicTab) -> Unit,
) {
    FilterPillRow(
        items = DynamicTab.entries.map { FilterPill(it.label) },
        selectedIndex = DynamicTab.entries.indexOf(selected),
        onSelect = { onSelect(DynamicTab.entries[it]) },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DynamicFeed(
    ui: DynamicUiState,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onToggleLike: (DynamicCard) -> Unit,
    onVideoClick: (VideoItem) -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = when {
            maxWidth < 600.dp -> 1
            maxWidth < 1080.dp -> 2
            else -> 3
        }
        val gridState = rememberLazyGridState()
        LoadMoreEffect(
            gridState = gridState,
            itemCount = ui.items.size,
            hasMore = ui.hasMore,
            isLoading = ui.isLoadingMore,
            onLoadMore = onLoadMore,
            enabled = ui.error == null,
        )

        PullToRefreshBox(
            isRefreshing = ui.isRefreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize(),
        ) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = gridState,
                contentPadding = PaddingValues(
                    start = if (columns == 1) 0.dp else 16.dp,
                    end = if (columns == 1) 0.dp else 16.dp,
                    top = 8.dp,
                    bottom = 24.dp,
                ),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(if (columns == 1) 12.dp else 16.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(ui.items, key = { it.id }) { card ->
                    DynamicCardView(
                        card = card,
                        inGrid = columns > 1,
                        onToggleLike = { onToggleLike(card) },
                        onVideoClick = onVideoClick,
                    )
                }

                item(span = { GridItemSpan(maxLineSpan) }) {
                    LoadMoreFooter(
                        isLoading = ui.isLoadingMore,
                        hasMore = ui.hasMore,
                        failed = ui.error != null && ui.items.isNotEmpty(),
                        onRetry = onLoadMore,
                        endText = "没有更多动态了",
                    )
                }
            }
        }
    }
}

@Composable
private fun DynamicSkeleton() {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = when {
            maxWidth < 600.dp -> 1
            maxWidth < 1080.dp -> 2
            else -> 3
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            userScrollEnabled = false,
            modifier = Modifier.fillMaxSize(),
        ) {
            items(columns * 2) {
                DynamicCardSkeleton()
            }
        }
    }
}

@Composable
fun DynamicCardView(
    card: DynamicCard,
    onVideoClick: (VideoItem) -> Unit,
    inGrid: Boolean = false,
    onToggleLike: () -> Unit = {},
    onOpenArticle: (Long) -> Unit = {},
) {
    val video = card.attachment.video
    val edgeToEdge = video != null
    val horizontalPadding = if (edgeToEdge) 14.dp else 16.dp

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (edgeToEdge) {
                    Modifier
                } else {
                    Modifier
                        .padding(horizontal = if (inGrid) 0.dp else 14.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.surface)
                },
            )
            .padding(vertical = if (edgeToEdge) 10.dp else 12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = horizontalPadding),
        ) {
            Avatar(url = card.authorAvatarUrl, size = 34.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = card.authorName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = listOf(card.pubTime, card.pubAction)
                        .filter { it.isNotBlank() }
                        .joinToString(" · "),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        if (card.text.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = card.text,
                style = MaterialTheme.typography.bodyMedium,
                lineHeight = 21.sp,
                maxLines = 8,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        val attachment = card.attachment
        val videoAttachment = attachment.video
        if (videoAttachment != null) {
            Spacer(Modifier.height(10.dp))
            DynamicVideoCard(
                video = videoAttachment,
                authorName = card.authorName,
                authorAvatarUrl = card.authorAvatarUrl,
                pubTime = card.pubTime,
                onClick = {
                    onVideoClick(
                        VideoItem(
                            bvid = videoAttachment.bvid,
                            title = videoAttachment.title,
                            coverUrl = videoAttachment.coverUrl,
                            ownerName = card.authorName,
                            ownerFaceUrl = card.authorAvatarUrl,
                            viewText = videoAttachment.playText,
                            durationText = videoAttachment.durationText,
                            publishedText = card.pubTime,
                            description = videoAttachment.desc,
                        ),
                    )
                },
            )
        }

        if (attachment.pictures.isNotEmpty()) {
            Spacer(Modifier.height(10.dp))
            DynamicPictureGrid(
                pictures = attachment.pictures,
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        attachment.article?.let { article ->
            Spacer(Modifier.height(10.dp))
            AttachmentRow(
                coverUrl = article.coverUrl,
                title = article.title,
                subtitle = article.summary,
                badge = "专栏",
                onClick = { article.id.toLongOrNull()?.let(onOpenArticle) },
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        attachment.pgc?.let { pgc ->
            Spacer(Modifier.height(10.dp))
            AttachmentRow(
                coverUrl = pgc.coverUrl,
                title = pgc.title,
                subtitle = pgc.badge,
                badge = "番剧",
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        attachment.live?.let { live ->
            Spacer(Modifier.height(10.dp))
            AttachmentRow(
                coverUrl = live.coverUrl,
                title = live.title,
                subtitle = live.areaName,
                badge = "直播",
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        val orig = card.orig
        if (orig != null) {
            Spacer(Modifier.height(10.dp))
            ForwardQuote(
                authorName = orig.authorName,
                text = orig.text,
                attachment = orig.attachment,
                modifier = Modifier.padding(horizontal = horizontalPadding),
            )
        }

        Spacer(Modifier.height(10.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(18.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = horizontalPadding),
        ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .btbPressable(onClick = onToggleLike)
                .padding(vertical = 4.dp, horizontal = 2.dp),
        ) {
                Icon(
                    imageVector = Icons.Default.ThumbUp,
                    contentDescription = "点赞",
                    tint = if (card.liked) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    text = formatCount(card.likeCount.toLong()),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (card.liked) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
            if (card.commentCount > 0) {
                Text(
                    text = "评论 ${formatCount(card.commentCount.toLong())}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (card.forwardCount > 0) {
                Text(
                    text = "转发 ${formatCount(card.forwardCount.toLong())}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun DynamicVideoCard(
    video: DynamicVideo,
    authorName: String,
    authorAvatarUrl: String?,
    pubTime: String,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f),
        ) {
            BtbImage(
                url = video.coverUrl,
                contentDescription = video.title,
                modifier = Modifier.matchParentSize(),
            )
            if (video.durationText.isNotBlank()) {
                Surface(
                    color = Color.Black.copy(alpha = 0.72f),
                    shape = RoundedCornerShape(4.dp),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(8.dp),
                ) {
                    Text(
                        text = video.durationText,
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = video.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            lineHeight = 22.sp,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 14.dp),
        )
        Spacer(Modifier.height(8.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(horizontal = 14.dp),
        ) {
            Avatar(url = authorAvatarUrl, size = 22.dp)
            Text(
                text = authorName,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (video.playText.isNotBlank()) {
                Text(
                    text = "· ${video.playText}播放",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            if (pubTime.isNotBlank()) {
                Text(
                    text = "· $pubTime",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun DynamicPictureGrid(
    pictures: List<DynamicPicture>,
    modifier: Modifier = Modifier,
) {
    if (pictures.size == 1) {
        val picture = pictures.first()
        val ratio = if (picture.width > 0 && picture.height > 0) {
            (picture.width.toFloat() / picture.height.toFloat()).coerceIn(0.8f, 1.9f)
        } else {
            (4f / 3f)
        }
        BtbImage(
            url = picture.url,
            contentDescription = null,
            modifier = modifier
                .fillMaxWidth()
                .aspectRatio(ratio)
                .clip(RoundedCornerShape(10.dp)),
        )
        return
    }

    val rows = pictures.take(9).chunked(3)
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                row.forEach { picture ->
                    BtbImage(
                        url = picture.url,
                        contentDescription = null,
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(8.dp)),
                    )
                }
                repeat(3 - row.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun AttachmentRow(
    coverUrl: String?,
    title: String,
    subtitle: String,
    badge: String,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(10.dp),
        modifier = modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.btbPressable(onClick = onClick) else Modifier),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(8.dp),
        ) {
            BtbImage(
                url = coverUrl,
                contentDescription = null,
                modifier = Modifier
                    .width(96.dp)
                    .height(60.dp)
                    .clip(RoundedCornerShape(8.dp)),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = badge,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotBlank()) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun ForwardQuote(
    authorName: String,
    text: String,
    attachment: DynamicAttachment,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(10.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Text(
                text = "@$authorName",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            if (text.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 4,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            val originalVideo = attachment.video
            if (originalVideo != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "▶ ${originalVideo.title}",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (attachment.pictures.isNotEmpty()) {
                Spacer(Modifier.height(6.dp))
                DynamicPictureGrid(
                    pictures = attachment.pictures.take(3),
                )
            }
        }
    }
}
