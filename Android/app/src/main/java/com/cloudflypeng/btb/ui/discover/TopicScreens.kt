package com.cloudflypeng.btb.ui.discover

import android.app.Application
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.DynamicCard
import com.cloudflypeng.btb.data.TopicDetailItem
import com.cloudflypeng.btb.data.TopicSquareItem
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.dynamic.DynamicCardView
import com.cloudflypeng.btb.ui.interaction.btbPressable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class TopicDetailUiState(
    val detail: TopicDetailItem? = null,
    val cards: List<DynamicCard> = emptyList(),
    val offset: String = "",
    val hasMore: Boolean = true,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
)

class TopicDetailViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.discoverRepository

    private val _ui = MutableStateFlow(TopicDetailUiState())
    val ui = _ui.asStateFlow()

    private var topicId: Long = 0
    private var topicName: String = ""
    private var loaded = false

    fun load(id: Long, name: String, force: Boolean = false) {
        if (topicId == id && loaded && !force) return
        topicId = id
        topicName = name
        loaded = true
        _ui.value = TopicDetailUiState(isLoading = true)
        viewModelScope.launch {
            runCatching { core.start() }
            try {
                val detail = repository.topicDetail(id)
                val page = repository.topicFeed(id, name)
                _ui.update {
                    it.copy(
                        detail = detail ?: _ui.value.detail,
                        cards = page.cards,
                        offset = page.offset,
                        hasMore = page.hasMore,
                        isLoading = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoading = false, error = error.userMessage("话题加载失败")) }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingMore || !state.hasMore || topicId <= 0) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val page = repository.topicFeed(topicId, topicName, state.offset)
                _ui.update { current ->
                    current.copy(
                        cards = current.cards + page.cards,
                        offset = page.offset,
                        hasMore = page.hasMore,
                        isLoadingMore = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, error = error.userMessage("话题动态加载失败")) }
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun TopicSquareScreen(
    onBack: () -> Unit,
    onOpenTopic: (TopicSquareItem) -> Unit,
    viewModel: DiscoverViewModel = viewModel(),
) {
    val ui by viewModel.topics.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.loadTopics() }

    DiscoverSubScreen(
        title = "话题",
        onBack = onBack,
        actions = {
            IconButton(onClick = { viewModel.loadTopics(force = true) }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新话题",
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
                    title = "话题加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.loadTopics(force = true) },
                )

                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "暂无话题",
                    message = "稍后刷新试试",
                )

                else -> PullToRefreshBox(
                    isRefreshing = ui.isLoading,
                    onRefresh = { viewModel.loadTopics(force = true) },
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        items(ui.items, key = { it.id }) { topic ->
                            TopicRow(topic) { onOpenTopic(topic) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TopicRow(topic: TopicSquareItem, onClick: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick),
    ) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(
                text = "#${topic.name}",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
            )
            topic.description?.takeIf { it.isNotBlank() }?.let { description ->
                Spacer(Modifier.height(4.dp))
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (topic.summaryText.isNotBlank()) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = topic.summaryText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                )
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun TopicDetailScreen(
    topicId: Long,
    topicName: String,
    topicDescription: String?,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    onOpenArticle: (Long) -> Unit,
    viewModel: TopicDetailViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    LaunchedEffect(topicId) { viewModel.load(topicId, topicName) }
    val listState = androidx.compose.foundation.lazy.rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.cards.size,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
        enabled = ui.error == null,
    )

    DiscoverSubScreen(
        title = "#$topicName",
        onBack = onBack,
        actions = {
            IconButton(onClick = { viewModel.load(topicId, topicName, force = true) }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新话题",
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
                ui.isLoading && ui.cards.isEmpty() -> LoadingState()

                ui.error != null && ui.cards.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "话题加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(topicId, topicName, force = true) },
                )

                ui.cards.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "还没有讨论",
                    message = topicDescription ?: "这个话题暂时没有内容",
                )

                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(bottom = 24.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    item(key = "header") {
                        TopicHeader(
                            detail = ui.detail,
                            name = topicName,
                            description = topicDescription,
                        )
                    }
                    items(ui.cards, key = { it.id }) { card ->
                        DynamicCardView(
                            card = card,
                            onVideoClick = onVideoClick,
                            onOpenArticle = onOpenArticle,
                        )
                    }
                    item {
                        LoadMoreFooter(
                            isLoading = ui.isLoadingMore,
                            hasMore = ui.hasMore,
                            failed = ui.error != null && ui.cards.isNotEmpty(),
                            onRetry = viewModel::loadMore,
                            endText = "没有更多讨论了",
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TopicHeader(detail: TopicDetailItem?, name: String, description: String?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        val banner = detail?.bannerUrl
        if (banner != null) {
            BtbImage(
                url = banner,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 7f)
                    .clip(RoundedCornerShape(14.dp)),
            )
            Spacer(Modifier.height(12.dp))
        }
        Text(
            text = "#${detail?.name ?: name}",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        val summary = detail?.description?.takeIf { it.isNotBlank() } ?: description
        summary?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(6.dp))
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        val stats = buildList {
            detail?.dynamics?.takeIf { it > 0 }?.let { add("$it 条讨论") }
            detail?.view?.takeIf { it > 0 }?.let { add("$it 次浏览") }
        }.joinToString(" · ")
        if (stats.isNotBlank()) {
            Spacer(Modifier.height(6.dp))
            Text(
                text = stats,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
            )
        }
        Spacer(Modifier.height(10.dp))
        androidx.compose.material3.HorizontalDivider(
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
        )
    }
}
