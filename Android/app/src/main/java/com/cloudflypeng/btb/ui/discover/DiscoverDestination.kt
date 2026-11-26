package com.cloudflypeng.btb.ui.discover

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.anime.AnimeDetailScreen
import com.cloudflypeng.btb.ui.anime.AnimeScreen
import com.cloudflypeng.btb.ui.components.AdaptiveDetailLayout
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.home.VideoDetailPane
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.live.LiveListScreen
import com.cloudflypeng.btb.ui.live.LiveRoomScreen
import com.cloudflypeng.btb.ui.user.UserSpaceScreen

sealed interface DiscoverRoute {
    data object Root : DiscoverRoute
    data class Search(val initialQuery: String? = null) : DiscoverRoute
    data object Ranking : DiscoverRoute
    data object Weekly : DiscoverRoute
    data object Articles : DiscoverRoute
    data object Topics : DiscoverRoute
    data object Partitions : DiscoverRoute
    data class Partition(val tid: Int, val label: String) : DiscoverRoute
    data class ArticleDetail(val articleId: Long) : DiscoverRoute
    data class TopicDetail(val topicId: Long, val name: String, val description: String?) : DiscoverRoute
    data object Live : DiscoverRoute
    data class LiveRoom(val roomId: Long) : DiscoverRoute
    data object Anime : DiscoverRoute
    data class AnimeDetail(val seasonId: Long) : DiscoverRoute
    data class UserSpace(val mid: Long) : DiscoverRoute
}

private val DiscoverRoute.depth: Int
    get() = when (this) {
        DiscoverRoute.Root -> 0
        is DiscoverRoute.ArticleDetail,
        is DiscoverRoute.TopicDetail,
        is DiscoverRoute.Partition,
        is DiscoverRoute.LiveRoom,
        is DiscoverRoute.AnimeDetail,
        -> 2
        else -> 1
    }

@Composable
fun DiscoverDestination(
    stack: List<DiscoverRoute>,
    onStackChange: (List<DiscoverRoute>) -> Unit,
    selectedVideo: VideoItem?,
    controller: PlaybackController?,
    ensureAccount: suspend () -> Boolean,
    hasAccount: Boolean,
    onSelectVideo: (VideoItem?) -> Unit,
    onOpenLogin: () -> Unit,
    onOpenUser: (Long) -> Unit,
    modifier: Modifier = Modifier,
) {
    val push: (DiscoverRoute) -> Unit = { route -> onStackChange(stack + route) }
    val pop: () -> Unit = { if (stack.size > 1) onStackChange(stack.dropLast(1)) }

    AdaptiveDetailLayout(
        selected = selectedVideo != null,
        onDismiss = { onSelectVideo(null) },
        modifier = modifier,
        list = { listModifier ->
            DiscoverStack(
                stack = stack,
                onPush = push,
                onPop = pop,
                onSelectVideo = onSelectVideo,
                hasAccount = hasAccount,
                onOpenLogin = onOpenLogin,
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
                    onOpenUser = onOpenUser,
                    modifier = detailModifier,
                )
            }
        },
    )
}

@Composable
private fun DiscoverStack(
    stack: List<DiscoverRoute>,
    onPush: (DiscoverRoute) -> Unit,
    onPop: () -> Unit,
    onSelectVideo: (VideoItem) -> Unit,
    hasAccount: Boolean,
    onOpenLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(enabled = stack.size > 1) { onPop() }

    AnimatedContent(
        targetState = stack.last(),
        transitionSpec = {
            if (targetState.depth >= initialState.depth) {
                (slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Left, tween(280)) + fadeIn(tween(180)))
                    .togetherWith(fadeOut(tween(120)))
            } else {
                (slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Right, tween(280)) + fadeIn(tween(180)))
                    .togetherWith(fadeOut(tween(120)))
            }
        },
        modifier = modifier.fillMaxSize(),
        label = "discover",
    ) { route ->
        when (route) {
            DiscoverRoute.Root -> DiscoverScreen(
                onOpenSearch = { onPush(DiscoverRoute.Search()) },
                onOpen = onPush,
            )

            is DiscoverRoute.Search -> SearchScreen(
                initialQuery = route.initialQuery,
                onBack = onPop,
                onVideoClick = onSelectVideo,
                onOpenArticle = { onPush(DiscoverRoute.ArticleDetail(it)) },
                onOpenUser = { user -> onPush(DiscoverRoute.UserSpace(user.mid)) },
                onOpenLive = { room -> onPush(DiscoverRoute.LiveRoom(room.roomId)) },
                onOpenMedia = { media ->
                    val seasonId = media.resolvedSeasonId
                    if (seasonId > 0) onPush(DiscoverRoute.AnimeDetail(seasonId))
                },
            )

            DiscoverRoute.Ranking -> RankingScreen(onBack = onPop, onVideoClick = onSelectVideo)

            DiscoverRoute.Weekly -> WeeklyScreen(onBack = onPop, onVideoClick = onSelectVideo)

            DiscoverRoute.Articles -> ArticleRankScreen(
                onBack = onPop,
                onOpenArticle = { onPush(DiscoverRoute.ArticleDetail(it)) },
            )

            DiscoverRoute.Topics -> TopicSquareScreen(
                onBack = onPop,
                onOpenTopic = { topic ->
                    onPush(DiscoverRoute.TopicDetail(topic.id, topic.name, topic.description))
                },
            )

            DiscoverRoute.Partitions -> PartitionsScreen(
                onBack = onPop,
                onOpenPartition = { tid, label -> onPush(DiscoverRoute.Partition(tid, label)) },
            )

            is DiscoverRoute.Partition -> PartitionBrowseScreen(
                tid = route.tid,
                label = route.label,
                onBack = onPop,
                onVideoClick = onSelectVideo,
            )

            is DiscoverRoute.ArticleDetail -> ArticleDetailScreen(
                articleId = route.articleId,
                onBack = onPop,
            )

            is DiscoverRoute.TopicDetail -> TopicDetailScreen(
                topicId = route.topicId,
                topicName = route.name,
                topicDescription = route.description,
                onBack = onPop,
                onVideoClick = onSelectVideo,
                onOpenArticle = { onPush(DiscoverRoute.ArticleDetail(it)) },
            )

            DiscoverRoute.Live -> LiveListScreen(
                hasAccount = hasAccount,
                onBack = onPop,
                onOpenRoom = { onPush(DiscoverRoute.LiveRoom(it)) },
                onRequireLogin = onOpenLogin,
            )

            is DiscoverRoute.LiveRoom -> LiveRoomScreen(
                roomId = route.roomId,
                hasAccount = hasAccount,
                onBack = onPop,
                onRequireLogin = onOpenLogin,
            )

            DiscoverRoute.Anime -> AnimeScreen(
                onBack = onPop,
                onOpenSeason = { onPush(DiscoverRoute.AnimeDetail(it)) },
            )

            is DiscoverRoute.AnimeDetail -> AnimeDetailScreen(
                seasonId = route.seasonId,
                hasAccount = hasAccount,
                onBack = onPop,
                onRequireLogin = onOpenLogin,
            )

            is DiscoverRoute.UserSpace -> UserSpaceScreen(
                mid = route.mid,
                onBack = onPop,
                onVideoClick = onSelectVideo,
                hasAccount = hasAccount,
                onRequireLogin = onOpenLogin,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiscoverScreen(
    onOpenSearch: () -> Unit,
    onOpen: (DiscoverRoute) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("发现", fontWeight = FontWeight.Bold) })
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            SearchEntry(onClick = onOpenSearch)

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                DiscoverRow(
                    kind = ChromeGlyphKind.Ranking,
                    title = "排行榜",
                    subtitle = "全站热门视频",
                    onClick = { onOpen(DiscoverRoute.Ranking) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Weekly,
                    title = "每周必看",
                    subtitle = "每周精选合集",
                    onClick = { onOpen(DiscoverRoute.Weekly) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Article,
                    title = "专栏",
                    subtitle = "排行榜与深度阅读",
                    onClick = { onOpen(DiscoverRoute.Articles) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Topic,
                    title = "话题",
                    subtitle = "热门话题与讨论",
                    onClick = { onOpen(DiscoverRoute.Topics) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Grid,
                    title = "分区",
                    subtitle = "按动画、游戏、知识等分区浏览",
                    onClick = { onOpen(DiscoverRoute.Partitions) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Live,
                    title = "直播",
                    subtitle = "关注主播的开播动态与直播间",
                    onClick = { onOpen(DiscoverRoute.Live) },
                )
                DiscoverRow(
                    kind = ChromeGlyphKind.Movie,
                    title = "番剧",
                    subtitle = "新番时间表与排行榜",
                    onClick = { onOpen(DiscoverRoute.Anime) },
                )
            }
        }
    }
}

@Composable
private fun SearchEntry(onClick: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = CircleShape,
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(9.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(46.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(17.dp),
            )
            Text(
                text = "搜索视频、UP 主、番剧",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun DiscoverRow(
    kind: ChromeGlyphKind,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    trailing: String? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 12.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(38.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, CircleShape),
        ) {
            ChromeGlyph(
                kind = kind,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(21.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
        if (trailing != null) {
            Text(
                text = trailing,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        ChromeGlyph(
            kind = ChromeGlyphKind.ChevronRight,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            modifier = Modifier.size(16.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverSubScreen(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    actions: @Composable () -> Unit = {},
    content: @Composable (androidx.compose.foundation.layout.PaddingValues) -> Unit,
) {
    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text(title, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    androidx.compose.material3.IconButton(onClick = onBack) {
                        ChromeGlyph(
                            kind = ChromeGlyphKind.Back,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                },
                actions = { actions() },
            )
        },
        content = content,
    )
}
