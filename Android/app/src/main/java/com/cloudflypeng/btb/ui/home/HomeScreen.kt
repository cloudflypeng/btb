package com.cloudflypeng.btb.ui.home

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.util.Rational
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreStatus
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.HomeTab
import com.cloudflypeng.btb.ui.HomeUiState
import com.cloudflypeng.btb.ui.components.AppMark
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.FilterPill
import com.cloudflypeng.btb.ui.components.FilterPillRow
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.components.VideoCard
import com.cloudflypeng.btb.ui.components.VideoCardSkeleton
import com.cloudflypeng.btb.ui.detail.CommentsSection
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.playback.PlayerSurface
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    ui: HomeUiState,
    onRetry: () -> Unit,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onSelectTab: (HomeTab) -> Unit,
    onOpenSearch: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        AppMark()
                        Text(
                            text = "BTB",
                            fontWeight = FontWeight.Bold,
                            fontSize = 22.sp,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onOpenSearch) {
                        Icon(Icons.Default.Search, contentDescription = "搜索")
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
            HomeTabRow(
                selected = ui.tab,
                onSelect = onSelectTab,
            )
            Box(Modifier.fillMaxSize()) {
                when {
                    ui.coreStatus is CoreStatus.Failed && ui.items.isEmpty() -> MessageState(
                        icon = Icons.Default.Warning,
                        title = "核心启动失败",
                        message = ui.coreStatus.message,
                        actionLabel = "重试",
                        onAction = onRetry,
                    )

                    ui.isLoading && ui.items.isEmpty() -> HomeSkeleton()

                    ui.error != null && ui.items.isEmpty() -> MessageState(
                        icon = Icons.Default.Warning,
                        title = "内容加载失败",
                        message = ui.error,
                        actionLabel = "重试",
                        onAction = onRefresh,
                    )

                    else -> HomeGrid(
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
private fun HomeTabRow(
    selected: HomeTab,
    onSelect: (HomeTab) -> Unit,
) {
    FilterPillRow(
        items = HomeTab.entries.map { FilterPill(it.label) },
        selectedIndex = HomeTab.entries.indexOf(selected),
        onSelect = { onSelect(HomeTab.entries[it]) },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeGrid(
    ui: HomeUiState,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = when {
            maxWidth < 600.dp -> 1
            maxWidth < 840.dp -> 2
            maxWidth < 1200.dp -> 3
            else -> 4
        }
        val gridState = rememberLazyGridState()

        LoadMoreEffect(
            gridState = gridState,
            itemCount = ui.items.size,
            hasMore = ui.hasMore,
            isLoading = ui.isLoadingMore,
            onLoadMore = onLoadMore,
            enabled = !ui.loadMoreFailed,
        )

        PullToRefreshBox(
            isRefreshing = ui.isRefreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize(),
        ) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = gridState,
                contentPadding = PaddingValues(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(ui.items, key = { it.bvid }) { video ->
                    VideoCard(
                        video = video,
                        onClick = { onVideoClick(video) },
                    )
                }

                item(span = { GridItemSpan(maxLineSpan) }) {
                    LoadMoreFooter(
                        isLoading = ui.isLoadingMore,
                        hasMore = ui.hasMore,
                        failed = ui.loadMoreFailed,
                        onRetry = onLoadMore,
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeSkeleton() {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = when {
            maxWidth < 600.dp -> 1
            maxWidth < 840.dp -> 2
            maxWidth < 1200.dp -> 3
            else -> 4
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            userScrollEnabled = false,
            modifier = Modifier.fillMaxSize(),
        ) {
            items(columns * 3) {
                VideoCardSkeleton()
            }
        }
    }
}

@Composable
fun VideoDetailPane(
    video: VideoItem,
    controller: PlaybackController,
    ensureAccount: suspend () -> Boolean,
    onClose: () -> Unit,
    onOpenLogin: () -> Unit = {},
    onOpenUser: (Long) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val application = context.applicationContext as BtbApplication
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var ownerError by remember(video.bvid) { mutableStateOf<String?>(null) }
    var ownerLoading by remember(video.bvid) { mutableStateOf(false) }
    val openOwner: () -> Unit = {
        if (!ownerLoading) {
            ownerLoading = true
            ownerError = null
            scope.launch {
                val mid = runCatching {
                    application.container.socialRepository.videoOwnerMid(video.bvid)
                }.getOrNull()
                ownerLoading = false
                if (mid != null) {
                    onOpenUser(mid)
                } else {
                    ownerError = "无法打开 UP 主页"
                }
            }
        }
    }
    var fullscreen by remember(video.bvid) { mutableStateOf(false) }
    val canEnterPip = remember(context) {
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }
    val enterPip: (() -> Unit)? = if (canEnterPip) {
        {
            context.findActivity()?.enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build(),
            )
        }
    } else {
        null
    }
    val playback = controller.state
    val pages = controller.pages

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        Box(Modifier.fillMaxWidth()) {
            if (!fullscreen) {
                PlayerSurface(
                    controller = controller,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f),
                    onToggleFullscreen = { fullscreen = true },
                    onEnterPip = enterPip,
                    ensureAccount = ensureAccount,
                    onRequestLogin = onOpenLogin,
                )
                IconButton(
                    onClick = onClose,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.5f)),
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "关闭",
                        tint = Color.White,
                    )
                }
            } else {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f)
                        .background(Color.Black),
                )
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp),
        ) {
            if (pages.size > 1) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pages.forEach { page ->
                        item(key = page.cid) {
                            FilterChip(
                                selected = playback.selectedPage == page.page,
                                onClick = { controller.selectPage(page.page) },
                                label = {
                                    Text(
                                        page.part?.takeIf { it.isNotBlank() } ?: "P${page.page}",
                                        maxLines = 1,
                                    )
                                },
                                shape = CircleShape,
                            )
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
            }

            Text(
                text = playback.title ?: video.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )

            val pageTitle = playback.resolve?.pageTitle
            if (pages.size > 1 && !pageTitle.isNullOrBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "P${playback.selectedPage} · $pageTitle",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(12.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .btbPressable(onClick = openOwner)
                    .padding(vertical = 4.dp),
            ) {
                Avatar(url = video.ownerFaceUrl, size = 32.dp)
                Text(
                    text = video.ownerName,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = "${video.viewText}次观看",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            ownerError?.let { error ->
                Text(
                    text = error,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }

            Spacer(Modifier.height(16.dp))

            CommentsSection(
                aid = playback.resolve?.aid,
                repository = application.container.commentRepository,
            )

            if (video.description.isNotEmpty()) {
                Spacer(Modifier.height(20.dp))
                Text(
                    text = "简介",
                    style = MaterialTheme.typography.titleSmall,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = video.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    if (fullscreen) {
        FullscreenPlayerDialog(
            controller = controller,
            onDismiss = { fullscreen = false },
            onEnterPip = enterPip,
            ensureAccount = ensureAccount,
            onRequestLogin = onOpenLogin,
        )
    }
}

@Composable
private fun FullscreenPlayerDialog(
    controller: PlaybackController,
    onDismiss: () -> Unit,
    onEnterPip: (() -> Unit)?,
    ensureAccount: suspend () -> Boolean,
    onRequestLogin: () -> Unit,
) {
    val context = LocalContext.current
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        val activity = remember(context) { context.findActivity() }
        DisposableEffect(activity) {
            val previousOrientation = activity?.requestedOrientation
            val window = activity?.window
            val insetsController = window?.let {
                WindowCompat.getInsetsController(it, it.decorView)
            }
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            insetsController?.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            insetsController?.hide(WindowInsetsCompat.Type.systemBars())
            onDispose {
                insetsController?.show(WindowInsetsCompat.Type.systemBars())
                activity?.requestedOrientation =
                    previousOrientation ?: ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
            PlayerSurface(
                controller = controller,
                modifier = Modifier.fillMaxSize(),
                isFullscreen = true,
                onToggleFullscreen = onDismiss,
                onEnterPip = onEnterPip,
                ensureAccount = ensureAccount,
                onRequestLogin = onRequestLogin,
            )
        }
    }
}

private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
