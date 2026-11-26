package com.cloudflypeng.btb.ui.user

import android.app.Application
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.SocialUser
import com.cloudflypeng.btb.data.UserSpaceInfo
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.discover.DiscoverSubScreen
import com.cloudflypeng.btb.ui.discover.userMessage
import com.cloudflypeng.btb.ui.library.LibraryVideoRow
import com.cloudflypeng.btb.ui.interaction.btbPressable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class UserSpaceUiState(
    val info: UserSpaceInfo? = null,
    val isFollowing: Boolean = false,
    val videos: List<VideoItem> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingVideos: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val isUpdatingFollow: Boolean = false,
    val notice: String? = null,
    val error: String? = null,
    val loaded: Boolean = false,
)

class UserSpaceViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.socialRepository

    private val _ui = MutableStateFlow(UserSpaceUiState())
    val ui = _ui.asStateFlow()

    private var mid = 0L
    private var page = 1
    private var loadedFor = 0L

    fun load(mid: Long, force: Boolean = false) {
        if (this.mid == mid && loadedFor == mid && !force) return
        this.mid = mid
        this.page = 1
        loadedFor = mid
        _ui.value = UserSpaceUiState(isLoading = true)
        viewModelScope.launch {
            runCatching { container.core.start() }
            try {
                val info = repository.info(mid)
                val relation = runCatching { repository.relation(mid) }.getOrNull()
                _ui.update {
                    it.copy(
                        info = info,
                        isFollowing = relation?.isFollowing ?: false,
                        isLoading = false,
                        loaded = true,
                        isLoadingVideos = true,
                    )
                }
                val videos = repository.videos(mid, page = 1)
                _ui.update {
                    it.copy(
                        videos = videos,
                        isLoadingVideos = false,
                        hasMore = videos.size >= 20,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(
                        isLoading = false,
                        isLoadingVideos = false,
                        loaded = true,
                        error = error.userMessage("主页加载失败"),
                    )
                }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingVideos || state.isLoadingMore || !state.hasMore || mid <= 0) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val videos = repository.videos(mid, page + 1)
                page += 1
                _ui.update {
                    it.copy(
                        videos = it.videos + videos.filterNot { video -> it.videos.any { e -> e.bvid == video.bvid } },
                        isLoadingMore = false,
                        hasMore = videos.size >= 20,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }

    fun toggleFollow(hasAccount: Boolean, onRequireLogin: () -> Unit) {
        val state = _ui.value
        if (state.isUpdatingFollow || mid <= 0) return
        if (!hasAccount) {
            onRequireLogin()
            return
        }
        val next = !state.isFollowing
        _ui.update { it.copy(isFollowing = next, isUpdatingFollow = true, notice = null) }
        viewModelScope.launch {
            try {
                repository.follow(mid, next)
                _ui.update {
                    it.copy(isUpdatingFollow = false, notice = if (next) "已关注" else "已取消关注")
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(
                        isFollowing = !next,
                        isUpdatingFollow = false,
                        notice = error.userMessage(if (next) "关注失败" else "取消关注失败"),
                    )
                }
            }
        }
    }

    fun consumeNotice() {
        _ui.update { it.copy(notice = null) }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun UserSpaceScreen(
    mid: Long,
    onBack: () -> Unit,
    onVideoClick: (VideoItem) -> Unit,
    hasAccount: Boolean,
    onRequireLogin: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: UserSpaceViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    LaunchedEffect(mid) { viewModel.load(mid) }
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.videos.size + 1,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
        enabled = !ui.isLoadingVideos,
    )

    DiscoverSubScreen(
        title = ui.info?.name ?: "个人主页",
        onBack = onBack,
        modifier = modifier,
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading -> LoadingState()

                ui.info == null -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "主页加载失败",
                    message = ui.error ?: "请稍后重试",
                    actionLabel = "重试",
                    onAction = { viewModel.load(mid, force = true) },
                )

                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(bottom = 28.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    item(key = "header") {
                        UserHeader(
                            info = ui.info!!,
                            isFollowing = ui.isFollowing,
                            isUpdating = ui.isUpdatingFollow,
                            onToggleFollow = { viewModel.toggleFollow(hasAccount, onRequireLogin) },
                        )
                    }
                    ui.notice?.let { notice ->
                        item(key = "notice") {
                            Surface(
                                color = MaterialTheme.colorScheme.surfaceVariant,
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 6.dp)
                                    .btbPressable(onClick = viewModel::consumeNotice),
                            ) {
                                Text(
                                    notice,
                                    style = MaterialTheme.typography.labelMedium,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                )
                            }
                        }
                    }
                    item(key = "videos-title") {
                        Text(
                            "投稿",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }
                    if (ui.isLoadingVideos) {
                        item(key = "videos-loading") { LoadingState(Modifier.height(160.dp)) }
                    } else if (ui.videos.isEmpty()) {
                        item(key = "videos-empty") {
                            Text(
                                "暂无投稿",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 18.dp),
                            )
                        }
                    } else {
                        items(ui.videos, key = { it.bvid }) { video ->
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
}

@Composable
private fun UserHeader(
    info: UserSpaceInfo,
    isFollowing: Boolean,
    isUpdating: Boolean,
    onToggleFollow: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(3.2f)
                .background(
                    Brush.verticalGradient(
                        listOf(
                            MaterialTheme.colorScheme.surfaceVariant,
                            MaterialTheme.colorScheme.surface,
                        ),
                    ),
                ),
        ) {
            BtbImage(
                url = info.bannerUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Row(
            verticalAlignment = Alignment.Bottom,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(top = 0.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape),
            ) {
                Avatar(url = info.faceUrl, size = 64.dp)
            }
            Spacer(Modifier.weight(1f))
            if (isFollowing) {
                OutlinedButton(onClick = onToggleFollow, enabled = !isUpdating) {
                    Text("已关注")
                }
            } else {
                Button(onClick = onToggleFollow, enabled = !isUpdating) {
                    Text(if (isUpdating) "处理中…" else "关注")
                }
            }
        }
        Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    info.name,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                info.level?.takeIf { it > 0 }?.let { level ->
                    Text(
                        "LV$level",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.85f))
                            .padding(horizontal = 5.dp, vertical = 1.dp),
                    )
                }
            }
            if (!info.sign.isNullOrBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    info.sign.orEmpty(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                listOfNotNull(
                    info.attention?.takeIf { it > 0 }?.let { "${formatCount(it)}关注" },
                    info.fans?.takeIf { it > 0 }?.let { "${formatCount(it)}粉丝" },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            androidx.compose.material3.HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            )
        }
    }
}

data class FollowListUiState(
    val users: List<SocialUser> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

class FollowListViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.socialRepository

    private val _ui = MutableStateFlow(FollowListUiState())
    val ui = _ui.asStateFlow()
    private var page = 1
    private var mid = 0L
    private var followers = false

    fun load(mid: Long, followers: Boolean, force: Boolean = false) {
        if (this.mid == mid && this.followers == followers && _ui.value.loaded && !force) return
        this.mid = mid
        this.followers = followers
        this.page = 1
        viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.users.isEmpty(), error = null) }
            try {
                val users = if (followers) {
                    repository.followers(mid, page = 1)
                } else {
                    repository.followings(mid, page = 1)
                }
                _ui.update {
                    it.copy(users = users, isLoading = false, loaded = true, hasMore = users.size >= 30)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(isLoading = false, loaded = true, error = error.userMessage("列表加载失败"))
                }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingMore || !state.hasMore || mid <= 0) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val users = if (followers) {
                    repository.followers(mid, page + 1)
                } else {
                    repository.followings(mid, page + 1)
                }
                page += 1
                _ui.update {
                    it.copy(
                        users = it.users + users.filterNot { user -> it.users.any { e -> e.mid == user.mid } },
                        isLoadingMore = false,
                        hasMore = users.size >= 30,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }

    fun toggleFollow(user: SocialUser) {
        viewModelScope.launch {
            val next = !user.isFollowing
            _ui.update { state ->
                state.copy(users = state.users.map { if (it.mid == user.mid) it.copy(attribute = if (next) 2 else 0) else it })
            }
            runCatching { repository.follow(user.mid, next) }
                .onFailure {
                    _ui.update { state ->
                        state.copy(users = state.users.map { if (it.mid == user.mid) it else it })
                    }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FollowListScreen(
    mid: Long,
    followers: Boolean,
    onBack: () -> Unit,
    onOpenUser: (Long) -> Unit,
    viewModel: FollowListViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    LaunchedEffect(mid, followers) { viewModel.load(mid, followers) }
    val listState = rememberLazyListState()
    LoadMoreEffect(
        listState = listState,
        itemCount = ui.users.size,
        hasMore = ui.hasMore,
        isLoading = ui.isLoadingMore,
        onLoadMore = viewModel::loadMore,
    )

    DiscoverSubScreen(
        title = if (followers) "我的粉丝" else "我的关注",
        onBack = onBack,
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading && ui.users.isEmpty() -> LoadingState()
                ui.error != null && ui.users.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "列表加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(mid, followers, force = true) },
                )
                ui.users.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = if (followers) "还没有粉丝" else "还没有关注",
                    message = "去发现页看看吧",
                )
                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(ui.users, key = { it.mid }) { user ->
                        SocialUserRow(
                            user = user,
                            onClick = { onOpenUser(user.mid) },
                            trailing = {
                                if (!followers) {
                                    OutlinedButton(
                                        onClick = { viewModel.toggleFollow(user) },
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 2.dp),
                                    ) {
                                        Text(if (user.isFollowing) "已关注" else "回关", style = MaterialTheme.typography.labelMedium)
                                    }
                                }
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
}

@Composable
internal fun SocialUserRow(
    user: SocialUser,
    onClick: () -> Unit,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(vertical = 8.dp),
    ) {
        Avatar(url = user.faceUrl, size = 44.dp)
        Column(Modifier.weight(1f)) {
            Text(
                user.uname,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            val detail = user.detailText
            if (detail.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    detail,
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
