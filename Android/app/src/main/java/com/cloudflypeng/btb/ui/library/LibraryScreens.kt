package com.cloudflypeng.btb.ui.library

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.DownloadItem
import com.cloudflypeng.btb.data.FavMedia
import com.cloudflypeng.btb.data.HistoryVideo
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.toVideoItemOrNull
import com.cloudflypeng.btb.data.WatchLaterEntry
import com.cloudflypeng.btb.data.formatBytes
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.discover.DiscoverSubScreen
import com.cloudflypeng.btb.ui.discover.userMessage
import com.cloudflypeng.btb.ui.interaction.btbPressable
import kotlinx.coroutines.launch

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    viewModel: HistoryViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val paused by viewModel.paused.collectAsStateWithLifecycle()
    var confirmClear by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.load() }
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.items.size,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
    )

    DiscoverSubScreen(
        title = "历史记录",
        onBack = onBack,
        actions = {
            if (ui.items.isNotEmpty()) {
                TextButton(onClick = { confirmClear = true }) { Text("清空") }
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
                    title = "历史记录加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(force = true) },
                )
                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "暂无观看记录",
                    message = "看过的视频会出现在这里",
                )
                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    item(key = "pause") {
                        PauseHistoryRow(paused = paused, onToggle = viewModel::setPaused)
                    }
                    items(ui.items, key = { it.kid ?: it.resolvedBvid ?: it.hashCode().toString() }) { entry ->
                        LibraryVideoRow(
                            title = entry.title.orEmpty(),
                            coverUrl = entry.coverUrl,
                            durationText = entry.durationText,
                            meta = listOfNotNull(
                                entry.authorName?.takeIf { it.isNotBlank() },
                                entry.viewedText.takeIf { it.isNotBlank() },
                            ).joinToString(" · "),
                            onClick = {
                                entry.resolvedBvid?.let { bvid ->
                                    onVideoClick(
                                        VideoItem(
                                            bvid = bvid,
                                            title = entry.title.orEmpty(),
                                            coverUrl = entry.coverUrl,
                                            ownerName = entry.authorName.orEmpty(),
                                            ownerFaceUrl = entry.authorFace,
                                            viewText = "",
                                            durationText = entry.durationText,
                                            publishedText = "",
                                            description = "",
                                            cid = entry.history?.cid,
                                        ),
                                    )
                                }
                            },
                            trailing = {
                                TextButton(onClick = { viewModel.remove(entry) }) { Text("移除") }
                            },
                        )
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = false,
                            onRetry = viewModel::loadMore,
                            endText = "没有更多记录了",
                        )
                    }
                }
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("清空历史记录") },
            text = { Text("将删除全部观看记录，此操作不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    viewModel.clearAll()
                }) { Text("清空") }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun PauseHistoryRow(paused: Boolean, onToggle: (Boolean) -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
        ) {
            Column(Modifier.weight(1f)) {
                Text("暂停记录观看历史", style = MaterialTheme.typography.bodyMedium)
                Text(
                    "暂停后观看视频不会写入历史",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = paused, onCheckedChange = onToggle)
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun WatchLaterScreen(
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    viewModel: WatchLaterViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    var confirmClear by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.load() }
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.items.size,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
    )

    DiscoverSubScreen(
        title = "稍后再看",
        onBack = onBack,
        actions = {
            if (ui.items.isNotEmpty()) {
                TextButton(onClick = { confirmClear = true }) { Text("清空") }
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
                    title = "稍后再看加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(force = true) },
                )
                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "暂无稍后再看",
                    message = "在视频详情页添加稍后再看",
                )
                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(ui.items, key = { it.video.bvid }) { entry ->
                        LibraryVideoRow(
                            title = entry.video.title,
                            coverUrl = entry.video.coverUrl,
                            durationText = entry.video.durationText,
                            meta = listOfNotNull(
                                entry.video.ownerName.takeIf { it.isNotBlank() },
                                entry.video.viewText.takeIf { it.isNotBlank() }?.let { "${it}观看" },
                            ).joinToString(" · "),
                            onClick = { onVideoClick(entry.video) },
                            trailing = {
                                TextButton(onClick = { viewModel.remove(entry) }) { Text("移除") }
                            },
                        )
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = false,
                            onRetry = viewModel::loadMore,
                            endText = "没有更多了",
                        )
                    }
                }
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("清空稍后再看") },
            text = { Text("将移除全部稍后再看视频。") },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    viewModel.clearAll()
                }) { Text("清空") }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text("取消") }
            },
        )
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun UploadsScreen(
    mid: Long,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    viewModel: UploadsViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    LaunchedEffect(mid) { viewModel.load(mid) }
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.items.size,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
    )

    DiscoverSubScreen(title = "我的投稿", onBack = onBack) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading && ui.items.isEmpty() -> LoadingState()
                ui.error != null && ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "投稿加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(mid, force = true) },
                )
                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "还没有投稿",
                    message = "发布视频后会展示在这里",
                )
                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(ui.items, key = { it.bvid }) { video ->
                        LibraryVideoRow(
                            title = video.title,
                            coverUrl = video.coverUrl,
                            durationText = video.durationText,
                            meta = listOfNotNull(
                                video.viewText.takeIf { it.isNotBlank() }?.let { "${it}观看" },
                                video.publishedText.takeIf { it.isNotBlank() },
                            ).joinToString(" · "),
                            onClick = { onVideoClick(video) },
                        )
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = false,
                            onRetry = viewModel::loadMore,
                            endText = "没有更多投稿了",
                        )
                    }
                }
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(
    onBack: () -> Unit,
    onOpenFolder: (Long, String) -> Unit,
    viewModel: FavoritesViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val actionError by viewModel.actionError.collectAsStateWithLifecycle()
    var showCreate by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var deleting by remember { mutableStateOf<com.cloudflypeng.btb.data.FavFolder?>(null) }
    LaunchedEffect(Unit) { viewModel.load() }

    DiscoverSubScreen(
        title = "收藏与播放列表",
        onBack = onBack,
        actions = {
            IconButton(onClick = { showCreate = true }) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "新建收藏夹",
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
                    title = "收藏夹加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(force = true) },
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    actionError?.let { error ->
                        item(key = "error") {
                            Text(
                                error,
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.error,
                                modifier = Modifier.padding(vertical = 6.dp),
                            )
                        }
                    }
                    items(ui.items, key = { it.id }) { folder ->
                        FolderRow(
                            title = folder.title,
                            coverUrl = folder.coverUrl,
                            mediaCount = folder.mediaCount,
                            isDefault = folder.isDefault,
                            onClick = { onOpenFolder(folder.id, folder.title) },
                            onDelete = if (folder.isDefault) null else ({ deleting = folder }),
                        )
                    }
                }
            }
        }
    }

    if (showCreate) {
        AlertDialog(
            onDismissRequest = { showCreate = false },
            title = { Text("新建收藏夹") },
            text = {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("名称") },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.create(title) {
                            showCreate = false
                            title = ""
                        }
                    },
                    enabled = title.isNotBlank(),
                ) { Text("创建") }
            },
            dismissButton = {
                TextButton(onClick = { showCreate = false }) { Text("取消") }
            },
        )
    }

    deleting?.let { folder ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text("删除收藏夹") },
            text = { Text("删除「${folder.title}」及其中的 ${folder.mediaCount} 个内容？") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(folder)
                    deleting = null
                }) { Text("删除") }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun FolderRow(
    title: String,
    coverUrl: String?,
    mediaCount: Int,
    isDefault: Boolean,
    onClick: () -> Unit,
    onDelete: (() -> Unit)?,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick)
            .padding(vertical = 8.dp),
    ) {
        BtbImage(
            url = coverUrl,
            contentDescription = title,
            modifier = Modifier
                .size(width = 88.dp, height = 56.dp)
                .clip(RoundedCornerShape(8.dp)),
        )
        Column(Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                buildString {
                    append("$mediaCount 个内容")
                    if (isDefault) append(" · 默认收藏夹")
                },
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (onDelete != null) {
            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "删除收藏夹",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FavoriteFolderScreen(
    folderId: Long,
    title: String,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val container = remember(context) {
        (context.applicationContext as BtbApplication).container
    }
    var items by remember(folderId) { mutableStateOf<List<FavMedia>>(emptyList()) }
    var loading by remember(folderId) { mutableStateOf(true) }
    var loadingMore by remember(folderId) { mutableStateOf(false) }
    var hasMore by remember(folderId) { mutableStateOf(false) }
    var error by remember(folderId) { mutableStateOf<String?>(null) }
    var page by remember(folderId) { mutableStateOf(1) }
    var reloadKey by remember(folderId) { mutableStateOf(0) }

    LaunchedEffect(folderId, reloadKey) {
        if (items.isEmpty()) loading = true
        error = null
        try {
            runCatching { container.core.start() }
            val result = container.libraryRepository.favoriteMedias(folderId, page = 1)
            items = result.first
            hasMore = result.second
            page = 1
        } catch (throwable: Throwable) {
            error = throwable.userMessage("收藏内容加载失败")
        } finally {
            loading = false
        }
    }

    LaunchedEffect(loadingMore) {
        if (loadingMore) {
            try {
                val result = container.libraryRepository.favoriteMedias(folderId, page = page + 1)
                items = items + result.first.filterNot { media -> items.any { it.id == media.id } }
                hasMore = result.second
                page += 1
            } catch (_: Throwable) {
            } finally {
                loadingMore = false
            }
        }
    }

    DiscoverSubScreen(
        title = title,
        onBack = onBack,
        actions = {
            IconButton(onClick = {
                loading = items.isEmpty()
                reloadKey += 1
            }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新收藏",
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
                error != null && items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "收藏内容加载失败",
                    message = error ?: "",
                    actionLabel = "重试",
                    onAction = { reloadKey += 1 },
                )
                items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "收藏夹是空的",
                    message = "在视频详情页收藏内容试试",
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(items, key = { it.id ?: it.bvid.hashCode().toLong() }) { media ->
                        LibraryVideoRow(
                            title = media.title.orEmpty(),
                            coverUrl = media.coverUrl,
                            durationText = media.durationText,
                            meta = listOfNotNull(
                                media.upper?.name?.takeIf { it.isNotBlank() },
                                media.viewText.takeIf { it.isNotBlank() }?.let { "${it}观看" },
                            ).joinToString(" · "),
                            onClick = { media.toVideoItemOrNull()?.let(onVideoClick) },
                            trailing = {
                                TextButton(onClick = {
                                    val aid = media.id ?: return@TextButton
                                    val removed = media
                                    items = items.filterNot { it.id == media.id }
                                    scope.launch {
                                        runCatching {
                                            container.libraryRepository.removeFavorite(folderId, listOf(aid))
                                        }.onFailure {
                                            items = items + removed
                                        }
                                    }
                                }) { Text("移除") }
                            },
                        )
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = loadingMore,
                            hasMore = hasMore,
                            failed = false,
                            onRetry = { loadingMore = true },
                            endText = "没有更多内容了",
                        )
                    }
                }
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun DownloadsScreen(
    onBack: () -> Unit,
    viewModel: DownloadsViewModel = viewModel(),
) {
    val data by viewModel.ui.collectAsStateWithLifecycle()
    val error by viewModel.error.collectAsStateWithLifecycle()
    val loading by viewModel.loading.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.start() }

    DiscoverSubScreen(title = "下载", onBack = onBack) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            val items = data?.items.orEmpty()
            when {
                loading && items.isEmpty() -> LoadingState()
                error != null && items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "下载列表加载失败",
                    message = error ?: "",
                    actionLabel = "重试",
                    onAction = viewModel::load,
                )
                items.isEmpty() -> MessageState(
                    icon = Icons.Default.Star,
                    title = "暂无下载",
                    message = "在视频详情页选择缓存视频",
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    data?.let { list ->
                        item(key = "storage") {
                            StorageCard(
                                usedBytes = list.usedBytes,
                                freeBytes = list.freeBytes,
                                total = list.summary.total,
                                downloading = list.summary.downloading,
                            )
                        }
                    }
                    items(items, key = { it.id }) { item ->
                        DownloadRow(
                            item = item,
                            onPause = { viewModel.pause(item) },
                            onResume = { viewModel.resume(item) },
                            onRemove = { viewModel.remove(item) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StorageCard(usedBytes: Long, freeBytes: Long, total: Int, downloading: Int) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
            Text("下载占用 ${formatBytes(usedBytes)}", style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(3.dp))
            Text(
                "$total 个任务 · $downloading 个下载中 · 剩余空间 ${formatBytes(freeBytes)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun DownloadRow(
    item: DownloadItem,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRemove: () -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                BtbImage(
                    url = item.cover,
                    contentDescription = item.title,
                    modifier = Modifier
                        .size(width = 96.dp, height = 56.dp)
                        .clip(RoundedCornerShape(8.dp)),
                )
                Column(Modifier.weight(1f)) {
                    Text(
                        item.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(3.dp))
                    Text(
                        listOfNotNull(
                            item.owner?.takeIf { it.isNotBlank() },
                            item.sizeText,
                            item.statusText,
                        ).joinToString(" · "),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (item.status == "downloading" || item.status == "paused") {
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { item.progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp)),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Spacer(Modifier.weight(1f))
                when (item.status) {
                    "downloading", "queued" -> TextButton(onClick = onPause) { Text("暂停") }
                    "paused", "failed" -> TextButton(onClick = onResume) { Text("继续") }
                }
                TextButton(onClick = onRemove) { Text("删除") }
            }
        }
    }
}

@Composable
internal fun LibraryVideoRow(
    title: String,
    coverUrl: String?,
    durationText: String,
    meta: String,
    onClick: () -> Unit,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick)
            .padding(vertical = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .width(118.dp)
                .height(66.dp)
                .clip(RoundedCornerShape(8.dp)),
        ) {
            BtbImage(
                url = coverUrl,
                contentDescription = title,
                modifier = Modifier.fillMaxSize(),
            )
            if (durationText.isNotEmpty()) {
                Text(
                    text = durationText,
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(5.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Color.Black.copy(alpha = 0.78f))
                        .padding(horizontal = 4.dp, vertical = 1.dp),
                )
            }
        }
        Column(Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (meta.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    meta,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        trailing?.invoke()
    }
}
