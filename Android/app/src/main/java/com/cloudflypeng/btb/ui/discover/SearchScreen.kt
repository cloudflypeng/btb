package com.cloudflypeng.btb.ui.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.data.SearchArticle
import com.cloudflypeng.btb.data.SearchChunk
import com.cloudflypeng.btb.data.SearchFilters
import com.cloudflypeng.btb.data.SearchLiveRoom
import com.cloudflypeng.btb.data.SearchMedia
import com.cloudflypeng.btb.data.SearchTab
import com.cloudflypeng.btb.data.SearchUser
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.components.FilterPill
import com.cloudflypeng.btb.ui.components.FilterPillRow
import com.cloudflypeng.btb.ui.components.InlineNotice
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.components.SectionHeader
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.theme.BtbBrand
import kotlinx.coroutines.delay

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    initialQuery: String?,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    onOpenArticle: (Long) -> Unit,
    onOpenUser: (SearchUser) -> Unit = {},
    onOpenLive: (SearchLiveRoom) -> Unit = {},
    onOpenMedia: (SearchMedia) -> Unit = {},
    viewModel: SearchViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    var term by rememberSaveable { mutableStateOf(initialQuery.orEmpty()) }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(initialQuery) {
        if (!initialQuery.isNullOrBlank() && initialQuery != ui.keyword) {
            term = initialQuery
            viewModel.submit(initialQuery)
        }
    }
    LaunchedEffect(Unit) {
        viewModel.loadDiscoveryData()
        focusRequester.requestFocus()
    }
    LaunchedEffect(term) {
        val value = term.trim()
        if (value.isEmpty() || value == ui.keyword) {
            viewModel.suggest("")
        } else {
            delay(220)
            viewModel.suggest(value)
        }
    }

    Scaffold(
        topBar = {
            SearchTopBar(
                term = term,
                onTermChange = { term = it },
                onBack = {
                    if (ui.attempted && term.trim() != ui.keyword) {
                        viewModel.reset()
                    } else {
                        onBack()
                    }
                },
                onSubmit = { viewModel.submit(term) },
                focusRequester = focusRequester,
            )
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                !ui.attempted -> SearchLanding(
                    term = term,
                    ui = ui,
                    onSubmit = { keyword ->
                        term = keyword
                        viewModel.submit(keyword)
                    },
                    onClearHistory = viewModel::clearHistory,
                )

                else -> Column(Modifier.fillMaxSize()) {
                    FilterPillRow(
                        items = SearchTab.entries.map { FilterPill(it.label) },
                        selectedIndex = SearchTab.entries.indexOf(ui.tab),
                        onSelect = { viewModel.selectTab(SearchTab.entries[it]) },
                    )
                    Spacer(Modifier.height(6.dp))
                    SearchResults(
                        ui = ui,
                        onRetry = viewModel::retry,
                        onLoadMore = viewModel::loadMore,
                        onSelectTab = viewModel::selectTab,
                        onUpdateFilters = viewModel::updateFilters,
                        onVideoClick = onVideoClick,
                        onOpenArticle = onOpenArticle,
                        onOpenUser = onOpenUser,
                        onOpenLive = onOpenLive,
                        onOpenMedia = onOpenMedia,
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchTopBar(
    term: String,
    onTermChange: (String) -> Unit,
    onBack: () -> Unit,
    onSubmit: () -> Unit,
    focusRequester: FocusRequester,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(start = 4.dp, end = 10.dp, top = 6.dp, bottom = 8.dp),
    ) {
        IconButton(onClick = onBack) {
            ChromeGlyph(
                kind = ChromeGlyphKind.Back,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(20.dp),
            )
        }
        Surface(
            color = MaterialTheme.colorScheme.surfaceVariant,
            shape = CircleShape,
            modifier = Modifier.weight(1f),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(42.dp)
                    .padding(horizontal = 14.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp),
                )
                Box(Modifier.weight(1f)) {
                    if (term.isEmpty()) {
                        Text(
                            text = "搜索视频、UP 主、番剧",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    BasicTextField(
                        value = term,
                        onValueChange = onTermChange,
                        singleLine = true,
                        textStyle = TextStyle(
                            color = MaterialTheme.colorScheme.onSurface,
                            fontSize = 15.sp,
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focusRequester),
                    )
                }
                if (term.isNotEmpty()) {
                    IconButton(
                        onClick = { onTermChange("") },
                        modifier = Modifier.size(24.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "清空搜索词",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(15.dp),
                        )
                    }
                }
            }
        }
        TextButton(onClick = onSubmit, enabled = term.isNotBlank()) {
            Text("搜索", fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SearchLanding(
    term: String,
    ui: SearchUiState,
    onSubmit: (String) -> Unit,
    onClearHistory: () -> Unit,
) {
    val query = term.trim()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (query.isNotEmpty() && query != ui.keyword && ui.suggestions.isNotEmpty()) {
            SectionHeader(title = "搜索建议")
            ui.suggestions.forEach { item ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .btbPressable(onClick = { onSubmit(item.query) })
                        .padding(horizontal = 4.dp, vertical = 10.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(15.dp),
                    )
                    Text(
                        text = item.display,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            return@Column
        }

        if (ui.history.isNotEmpty()) {
            SectionHeader(
                title = "搜索历史",
                actionLabel = "清空",
                onAction = onClearHistory,
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ui.history.forEach { keyword ->
                    HistoryChip(keyword) { onSubmit(keyword) }
                }
            }
        }

        if (ui.hotWords.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            SectionHeader(title = "B 站热搜")
            ui.hotWords.forEachIndexed { index, word ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .btbPressable(onClick = { onSubmit(word.display) })
                        .padding(horizontal = 4.dp, vertical = 9.dp),
                ) {
                    Text(
                        text = (index + 1).toString(),
                        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold),
                        color = if (index < 3) BtbBrand else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                        modifier = Modifier.width(22.dp),
                    )
                    Text(
                        text = word.display,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun HistoryChip(label: String, onClick: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = CircleShape,
        modifier = Modifier.btbPressable(onClick = onClick),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp),
        )
    }
}

@Composable
private fun SearchResults(
    ui: SearchUiState,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    onSelectTab: (SearchTab) -> Unit,
    onUpdateFilters: (SearchFilters) -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    onOpenArticle: (Long) -> Unit,
    onOpenUser: (SearchUser) -> Unit,
    onOpenLive: (SearchLiveRoom) -> Unit,
    onOpenMedia: (SearchMedia) -> Unit,
) {
    if (ui.isLoading) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(strokeWidth = 2.dp)
        }
        return
    }

    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.chunk?.itemCount ?: 0,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = onLoadMore,
        enabled = ui.tab != SearchTab.All && ui.error == null,
    )

    LazyColumn(
        state = listState,
        contentPadding = PaddingValues(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        ui.error?.let { error ->
            item(key = "error") {
                InlineNotice(
                    text = error,
                    actionLabel = "重试",
                    onAction = onRetry,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }

        when (ui.tab) {
            SearchTab.All -> {
                val all = ui.all
                if (all == null) {
                    if (ui.error == null) {
                        item { EmptySearch(ui.keyword) }
                    }
                } else if (all.isEmpty) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    if (all.videos.isNotEmpty()) {
                        item {
                            SectionHeader(
                                title = "视频",
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                                actionLabel = "查看全部",
                                onAction = { onSelectTab(SearchTab.Video) },
                            )
                        }
                        items(all.videos.take(6), key = { "video-${it.bvid}" }) { video ->
                            SearchVideoRow(video) { onVideoClick(video) }
                        }
                    }
                    val media = (all.bangumi + all.films).distinctBy { it.resolvedSeasonId }
                    if (media.isNotEmpty()) {
                        item {
                            SectionHeader(
                                title = "番剧 · 影视",
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                                actionLabel = "查看全部",
                                onAction = { onSelectTab(SearchTab.Media) },
                            )
                        }
                        item {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 16.dp),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                items(media.take(10), key = { "media-${it.resolvedSeasonId}" }) { item ->
                                    SearchMediaCard(item) { onOpenMedia(item) }
                                }
                            }
                        }
                    }
                    if (all.users.isNotEmpty()) {
                        item {
                            SectionHeader(
                                title = "UP 主",
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                                actionLabel = "查看全部",
                                onAction = { onSelectTab(SearchTab.User) },
                            )
                        }
                        items(all.users.take(4), key = { "user-${it.mid}" }) { user ->
                            SearchUserRow(user) { onOpenUser(user) }
                        }
                    }
                    if (all.liveRooms.isNotEmpty()) {
                        item {
                            SectionHeader(
                                title = "直播",
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                                actionLabel = "查看全部",
                                onAction = { onSelectTab(SearchTab.Live) },
                            )
                        }
                        items(all.liveRooms.take(4), key = { "live-${it.roomId}" }) { room ->
                            SearchLiveRow(room) { onOpenLive(room) }
                        }
                    }
                    if (all.articles.isNotEmpty()) {
                        item {
                            SectionHeader(
                                title = "专栏",
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                                actionLabel = "查看全部",
                                onAction = { onSelectTab(SearchTab.Article) },
                            )
                        }
                        items(all.articles.take(4), key = { "article-${it.id}" }) { article ->
                            SearchArticleRow(article) { onOpenArticle(article.id) }
                        }
                    }
                }
            }

            SearchTab.Video -> {
                item(key = "filters") {
                    VideoFilterRow(filters = ui.filters, onChange = onUpdateFilters)
                }
                val videos = ui.chunk?.videos.orEmpty()
                if (videos.isEmpty() && ui.error == null) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    items(videos, key = { it.bvid }) { video ->
                        SearchVideoRow(video) { onVideoClick(video) }
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && videos.isNotEmpty(),
                            onRetry = onLoadMore,
                            endText = "没有更多结果了",
                        )
                    }
                }
            }

            SearchTab.User -> {
                val users = ui.chunk?.users.orEmpty()
                if (users.isEmpty() && ui.error == null) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    items(users, key = { it.mid }) { user ->
                        SearchUserRow(user) { onOpenUser(user) }
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && users.isNotEmpty(),
                            onRetry = onLoadMore,
                            endText = "没有更多结果了",
                        )
                    }
                }
            }

            SearchTab.Media -> {
                val media = ui.chunk?.media.orEmpty()
                if (media.isEmpty() && ui.error == null) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    media.chunked(3).forEach { row ->
                        item(key = row.joinToString("|") { it.resolvedSeasonId.toString() }) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                            ) {
                                row.forEach { item ->
                                    SearchMediaCard(item, Modifier.weight(1f)) { onOpenMedia(item) }
                                }
                                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && media.isNotEmpty(),
                            onRetry = onLoadMore,
                            endText = "没有更多结果了",
                        )
                    }
                }
            }

            SearchTab.Live -> {
                val rooms = ui.chunk?.liveRooms.orEmpty()
                if (rooms.isEmpty() && ui.error == null) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    items(rooms, key = { it.roomId }) { room ->
                        SearchLiveRow(room) { onOpenLive(room) }
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && rooms.isNotEmpty(),
                            onRetry = onLoadMore,
                            endText = "没有更多结果了",
                        )
                    }
                }
            }

            SearchTab.Article -> {
                val articles = ui.chunk?.articles.orEmpty()
                if (articles.isEmpty() && ui.error == null) {
                    item { EmptySearch(ui.keyword) }
                } else {
                    items(articles, key = { it.id }) { article ->
                        SearchArticleRow(article) { onOpenArticle(article.id) }
                    }
                    item(key = "footer") {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && articles.isNotEmpty(),
                            onRetry = onLoadMore,
                            endText = "没有更多结果了",
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptySearch(keyword: String) {
    MessageState(
        icon = Icons.Default.Warning,
        title = "没有找到「$keyword」相关内容",
        message = "换个关键词试试",
        modifier = Modifier.height(260.dp),
    )
}

@Composable
private fun VideoFilterRow(filters: SearchFilters, onChange: (SearchFilters) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 2.dp),
    ) {
        FilterMenu(
            label = com.cloudflypeng.btb.data.SearchFilterCatalog.orders.firstOrNull { it.first == filters.order }?.second
                ?: "综合排序",
            options = com.cloudflypeng.btb.data.SearchFilterCatalog.orders,
            onSelect = { onChange(filters.copy(order = it)) },
        )
        FilterMenu(
            label = com.cloudflypeng.btb.data.SearchFilterCatalog.durations.firstOrNull { it.first == filters.duration }?.second
                ?: "全部时长",
            options = com.cloudflypeng.btb.data.SearchFilterCatalog.durations,
            onSelect = { onChange(filters.copy(duration = it)) },
        )
        FilterMenu(
            label = com.cloudflypeng.btb.data.SearchFilterCatalog.partitions.firstOrNull { it.first == filters.tids }?.second
                ?: "全部分区",
            options = com.cloudflypeng.btb.data.SearchFilterCatalog.partitions,
            onSelect = { onChange(filters.copy(tids = it)) },
        )
    }
}

@Composable
private fun FilterMenu(
    label: String,
    options: List<Pair<String, String>>,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier
                .clip(CircleShape)
                .btbPressable(onClick = { expanded = true })
                .padding(horizontal = 10.dp, vertical = 7.dp),
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Icon(
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp),
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (value, title) ->
                DropdownMenuItem(
                    text = { Text(title) },
                    onClick = {
                        expanded = false
                        onSelect(value)
                    },
                )
            }
        }
    }
}

@Composable
private fun SearchVideoRow(video: VideoItem, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .width(132.dp)
                .height(74.dp)
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
                text = video.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = listOfNotNull(
                    video.ownerName.takeIf { it.isNotBlank() },
                    video.viewText.takeIf { it.isNotBlank() }?.let { "${it}观看" },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun SearchUserRow(user: SearchUser, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Avatar(url = user.avatarUrl, size = 42.dp)
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = user.displayName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (user.isLiveNow) {
                    Text(
                        text = "直播中",
                        style = MaterialTheme.typography.labelSmall,
                        color = BtbBrand,
                    )
                }
            }
            val detail = user.detailText
            val stats = user.statsText
            if (detail.isNotBlank() || stats.isNotBlank()) {
                Text(
                    text = listOf(detail, stats).filter { it.isNotBlank() }.joinToString(" · "),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun SearchMediaCard(
    media: SearchMedia,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .btbPressable(onClick = onClick),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
                .clip(RoundedCornerShape(10.dp)),
        ) {
            BtbImage(
                url = media.coverUrl,
                contentDescription = media.displayTitle,
                modifier = Modifier.fillMaxSize(),
            )
            media.badgeText?.let { badge ->
                Text(
                    text = badge,
                    color = Color.White,
                    fontSize = 9.sp,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(6.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(BtbBrand.copy(alpha = 0.9f))
                        .padding(horizontal = 5.dp, vertical = 2.dp),
                )
            }
            Text(
                text = media.scoreText,
                color = Color(0xFFFFB300),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(6.dp),
            )
        }
        Spacer(Modifier.height(5.dp))
        Text(
            text = media.displayTitle,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (media.infoText.isNotBlank()) {
            Text(
                text = media.infoText,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun SearchLiveRow(room: SearchLiveRoom, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .width(118.dp)
                .height(66.dp)
                .clip(RoundedCornerShape(8.dp)),
        ) {
            BtbImage(
                url = room.coverUrl,
                contentDescription = room.displayTitle,
                modifier = Modifier.fillMaxSize(),
            )
            if ((room.liveStatus ?: 0) == 1) {
                Text(
                    text = "直播中",
                    color = Color.White,
                    fontSize = 9.sp,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(5.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(BtbBrand.copy(alpha = 0.92f))
                        .padding(horizontal = 4.dp, vertical = 1.dp),
                )
            }
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = room.displayTitle,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text = listOfNotNull(
                    room.displayUserName.takeIf { it.isNotBlank() },
                    room.displayCategory,
                    room.online?.takeIf { it > 0 }?.let { "${formatCount(it.toLong())}人气" },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun SearchArticleRow(article: SearchArticle, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        BtbImage(
            url = article.coverUrl,
            contentDescription = article.displayTitle,
            modifier = Modifier
                .width(108.dp)
                .height(70.dp)
                .clip(RoundedCornerShape(8.dp)),
        )
        Column(Modifier.weight(1f)) {
            Text(
                text = article.displayTitle,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text = listOfNotNull(
                    article.author?.takeIf { it.isNotBlank() },
                    article.view?.takeIf { it > 0 }?.let { "${formatCount(it.toLong())}阅读" },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}
