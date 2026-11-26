package com.cloudflypeng.btb.ui.live

import android.app.Application
import android.content.res.Configuration
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreEvent
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.data.CastDevice
import com.cloudflypeng.btb.data.LiveQuality
import com.cloudflypeng.btb.data.LiveRoom
import com.cloudflypeng.btb.data.LiveRoomInfo
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.components.LoadMoreEffect
import com.cloudflypeng.btb.ui.components.LoadMoreFooter
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.discover.DiscoverSubScreen
import com.cloudflypeng.btb.ui.discover.userMessage
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.playback.CastSheet
import com.cloudflypeng.btb.ui.theme.BtbBrand
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.longOrNull

data class LiveListUiState(
    val rooms: List<LiveRoom> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val liveOnly: Boolean = true,
    val liveCount: Int = 0,
    val error: String? = null,
    val loaded: Boolean = false,
)

class LiveListViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.liveRepository

    private val _ui = MutableStateFlow(LiveListUiState())
    val ui = _ui.asStateFlow()
    private var page = 1
    private var totalPage = 1

    fun load(hasAccount: Boolean, force: Boolean = false) {
        val state = _ui.value
        if (!hasAccount) {
            _ui.value = state.copy(isLoading = false, loaded = true)
            return
        }
        if (!force && (state.loaded || state.isLoading)) return
        page = 1
        viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.rooms.isEmpty(), error = null) }
            try {
                val result = repository.following(page = 1)
                totalPage = result.totalPage
                _ui.update {
                    it.copy(
                        rooms = result.rooms,
                        liveCount = result.liveCount,
                        isLoading = false,
                        loaded = true,
                        hasMore = page < totalPage,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(isLoading = false, loaded = true, error = error.userMessage("直播关注列表加载失败"))
                }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingMore || !state.hasMore) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val result = repository.following(page + 1)
                page += 1
                totalPage = result.totalPage
                _ui.update {
                    it.copy(
                        rooms = it.rooms + result.rooms.filterNot { room -> it.rooms.any { e -> e.roomId == room.roomId } },
                        isLoadingMore = false,
                        hasMore = page < totalPage,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }

    fun setLiveOnly(value: Boolean) {
        _ui.update { it.copy(liveOnly = value) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveListScreen(
    hasAccount: Boolean,
    onBack: () -> Unit,
    onOpenRoom: (Long) -> Unit,
    onRequireLogin: () -> Unit,
    viewModel: LiveListViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    var roomInputOpen by remember { mutableStateOf(false) }
    LaunchedEffect(hasAccount) { viewModel.load(hasAccount) }

    DiscoverSubScreen(
        title = "直播",
        onBack = onBack,
        actions = {
            TextButton(onClick = { roomInputOpen = true }) {
                Text("房间号")
            }
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                !hasAccount -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "登录后查看关注的主播",
                    message = "登录账号即可看到关注主播的开播状态",
                    actionLabel = "登录",
                    onAction = onRequireLogin,
                )

                ui.isLoading && ui.rooms.isEmpty() -> LoadingState()

                ui.error != null && ui.rooms.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(hasAccount, force = true) },
                )

                else -> {
                    val rooms = if (ui.liveOnly) ui.rooms.filter { it.isLive } else ui.rooms
                    val gridState = rememberLazyGridState()
                    LoadMoreEffect(
                        gridState = gridState,
                        itemCount = rooms.size,
                        hasMore = ui.hasMore,
                        isLoading = ui.isLoadingMore,
                        onLoadMore = viewModel::loadMore,
                    )
                    LazyVerticalGrid(
                        state = gridState,
                        columns = GridCells.Adaptive(168.dp),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "filters") {
                            LiveFilterRow(
                                liveOnly = ui.liveOnly,
                                liveCount = ui.liveCount,
                                total = ui.rooms.size,
                                onChange = viewModel::setLiveOnly,
                            )
                        }
                        if (rooms.isEmpty()) {
                            item(span = { GridItemSpan(maxLineSpan) }, key = "empty") {
                                Text(
                                    text = if (ui.liveOnly) "关注的主播都还没开播" else "还没有关注主播",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(vertical = 32.dp),
                                )
                            }
                        }
                        items(rooms, key = { it.roomId }) { room ->
                            LiveRoomCard(room = room, onClick = { onOpenRoom(room.roomId) })
                        }
                        item(span = { GridItemSpan(maxLineSpan) }, key = "footer") {
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

    if (roomInputOpen) {
        var input by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { roomInputOpen = false },
            title = { Text("进入直播间") },
            text = {
                OutlinedTextField(
                    value = input,
                    onValueChange = { value -> input = value.filter { it.isDigit() }.take(12) },
                    label = { Text("直播间房间号") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    enabled = (input.toLongOrNull() ?: 0) > 0,
                    onClick = {
                        val roomId = input.toLongOrNull()
                        roomInputOpen = false
                        if (roomId != null) onOpenRoom(roomId)
                    },
                ) {
                    Text("进入")
                }
            },
            dismissButton = {
                TextButton(onClick = { roomInputOpen = false }) {
                    Text("取消")
                }
            },
        )
    }
}

@Composable
private fun LiveFilterRow(
    liveOnly: Boolean,
    liveCount: Int,
    total: Int,
    onChange: (Boolean) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.padding(bottom = 2.dp),
    ) {
        FilterPillButton(
            label = "直播中 $liveCount",
            selected = liveOnly,
            onClick = { onChange(true) },
        )
        FilterPillButton(
            label = "全部关注 $total",
            selected = !liveOnly,
            onClick = { onChange(false) },
        )
    }
}

@Composable
private fun FilterPillButton(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        color = if (selected) MaterialTheme.colorScheme.onBackground else MaterialTheme.colorScheme.surfaceVariant,
        shape = CircleShape,
        modifier = Modifier.btbPressable(onClick = onClick),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) MaterialTheme.colorScheme.background else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp),
        )
    }
}

@Composable
private fun LiveRoomCard(room: LiveRoom, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 10f)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            BtbImage(
                url = room.coverUrl,
                contentDescription = room.title,
                modifier = Modifier.fillMaxSize(),
            )
            if (!room.isLive) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.45f)),
                )
            }
            Surface(
                color = if (room.isLive) BtbBrand else Color.Black.copy(alpha = 0.6f),
                shape = RoundedCornerShape(4.dp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(7.dp),
            ) {
                Text(
                    text = if (room.isLive) "直播中" else "未开播",
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
            if (room.popularText.isNotBlank()) {
                Text(
                    text = room.popularText,
                    color = Color.White,
                    fontSize = 10.sp,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.Black.copy(alpha = 0.55f))
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                )
            }
        }
        Spacer(Modifier.height(7.dp))
        Text(
            text = room.title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            lineHeight = 19.sp,
        )
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Avatar(url = room.avatarUrl, size = 18.dp)
            Text(
                text = room.anchorName,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (room.areaName.isNotBlank()) {
                Text(
                    text = room.areaName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
        }
    }
}

enum class LiveChatKind { Normal, System, SuperChat }

data class LiveChatMessage(
    val id: Long,
    val uname: String,
    val text: String,
    val kind: LiveChatKind = LiveChatKind.Normal,
)

data class LiveRoomUiState(
    val isLoading: Boolean = true,
    val room: LiveRoomInfo? = null,
    val title: String = "",
    val areaName: String = "",
    val popularityText: String = "",
    val isFollowing: Boolean = false,
    val isUpdatingFollow: Boolean = false,
    val messages: List<LiveChatMessage> = emptyList(),
    val qualities: List<LiveQuality> = emptyList(),
    val selectedQn: Long? = null,
    val isReady: Boolean = false,
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
    val isSending: Boolean = false,
)

class LiveRoomViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.liveRepository
    private val social = container.socialRepository
    private val castController = container.castController

    val player: ExoPlayer = ExoPlayer.Builder(application)
        .build()
        .apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                true,
            )
            setHandleAudioBecomingNoisy(true)
        }

    var state by mutableStateOf(LiveRoomUiState())
        private set

    private var currentRoomId = 0L
    private var sessionId: String? = null
    private var started = false
    private var messageId = 0L
    private var chatJob: Job? = null
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> state = state.copy(isBuffering = true)
                Player.STATE_READY -> state = state.copy(isReady = true, isBuffering = false, error = null)
                Player.STATE_ENDED -> state = state.copy(isPlaying = false, isBuffering = false)
                Player.STATE_IDLE -> Unit
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            state = state.copy(isPlaying = isPlaying)
        }

        override fun onPlayerError(error: PlaybackException) {
            state = state.copy(
                isPlaying = false,
                isBuffering = false,
                isReady = false,
                error = "直播播放失败，请稍后重试（${error.errorCodeName}）",
            )
        }
    }

    init {
        player.addListener(playerListener)
        chatJob = viewModelScope.launch {
            container.core.events.collect { event -> handleEvent(event) }
        }
    }

    fun start(roomId: Long, force: Boolean = false) {
        if (!force && started && currentRoomId == roomId) return
        if (force || (currentRoomId != 0L && currentRoomId != roomId)) {
            player.stop()
            player.clearMediaItems()
            leaveRoom()
        }
        started = true
        currentRoomId = roomId
        state = LiveRoomUiState(isLoading = true)
        viewModelScope.launch {
            runCatching { container.core.start() }
            try {
                val result = repository.play(roomId)
                if (!result.playable) {
                    state = state.copy(isLoading = false, error = result.unavailableText)
                    return@launch
                }
                val room = result.room
                state = state.copy(
                    isLoading = false,
                    room = room,
                    title = room?.title ?: "直播间 $roomId",
                    areaName = room?.areaName.orEmpty(),
                    popularityText = room?.online?.takeIf { it > 0 }?.let { "${formatCount(it)}人气" } ?: "",
                    qualities = result.qualities.orEmpty(),
                    selectedQn = result.quality?.qn,
                )
                attachStream(result.playbackUrl, result.sessionId)
                connectChat()
                loadRelation(room?.uid ?: 0)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(isLoading = false, error = error.userMessage("直播加载失败"))
            }
        }
    }

    private fun attachStream(url: String?, newSessionId: String?) {
        if (url.isNullOrBlank()) {
            state = state.copy(error = "该直播间暂不支持 HLS 播放")
            return
        }
        val previous = sessionId
        sessionId = newSessionId
        if (previous != null && previous != newSessionId) {
            cleanupScope.launch { repository.stopStream(previous) }
        }
        player.setMediaItem(MediaItem.fromUri(url))
        player.playWhenReady = true
        player.prepare()
    }

    private suspend fun connectChat() {
        runCatching { repository.connect(currentRoomId) }
            .onFailure { appendMessage("系统", "弹幕连接失败", LiveChatKind.System) }
    }

    private fun loadRelation(uid: Long) {
        if (uid <= 0) return
        viewModelScope.launch {
            val relation = runCatching { social.relation(uid) }.getOrNull() ?: return@launch
            state = state.copy(isFollowing = relation.isFollowing)
        }
    }

    fun togglePlayback() {
        if (player.isPlaying) player.pause() else player.play()
    }

    fun selectQuality(qn: Long) {
        val roomId = currentRoomId
        if (roomId <= 0 || state.selectedQn == qn) return
        viewModelScope.launch {
            try {
                val result = repository.play(roomId, qn)
                if (!result.playable) {
                    state = state.copy(notice = result.unavailableText)
                    return@launch
                }
                state = state.copy(
                    selectedQn = result.quality?.qn ?: qn,
                    qualities = result.qualities.orEmpty().ifEmpty { state.qualities },
                )
                attachStream(result.playbackUrl, result.sessionId)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(notice = error.userMessage("切换清晰度失败"))
            }
        }
    }

    fun toggleFollow(uid: Long, hasAccount: Boolean, onRequireLogin: () -> Unit) {
        if (uid <= 0 || state.isUpdatingFollow) return
        if (!hasAccount) {
            onRequireLogin()
            return
        }
        val next = !state.isFollowing
        state = state.copy(isFollowing = next, isUpdatingFollow = true)
        viewModelScope.launch {
            try {
                social.follow(uid, next)
                state = state.copy(isUpdatingFollow = false, notice = if (next) "已关注" else "已取消关注")
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(
                    isFollowing = !next,
                    isUpdatingFollow = false,
                    notice = error.userMessage(if (next) "关注失败" else "取消关注失败"),
                )
            }
        }
    }

    fun sendMessage(text: String, onDone: () -> Unit) {
        val message = text.trim().takeIf { it.isNotEmpty() } ?: return
        if (state.isSending) return
        state = state.copy(isSending = true)
        viewModelScope.launch {
            try {
                val response = repository.sendDanmaku(currentRoomId, message)
                if (response.code == 0) {
                    appendMessage("我", message)
                    onDone()
                } else {
                    state = state.copy(notice = response.message ?: "发送失败")
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                val hint = if (error is CoreException && (error.code == -101 || error.code == -111)) {
                    "请先登录后再发送"
                } else {
                    error.userMessage("发送失败")
                }
                state = state.copy(notice = hint)
            } finally {
                state = state.copy(isSending = false)
            }
        }
    }

    fun consumeNotice() {
        state = state.copy(notice = null)
    }

    val casting: com.cloudflypeng.btb.playback.CastUiState get() = castController.state

    fun castTo(device: CastDevice) {
        val room = state.room ?: return
        castController.castLive(device, room.roomId, state.title.ifBlank { "直播间 ${room.roomId}" }) {
            player.pause()
            state = state.copy(notice = "已投屏到${device.name}")
        }
    }

    fun refreshCastDevices() {
        castController.refresh()
    }

    fun stopCasting() {
        castController.stop()
    }

    fun leave() {
        leaveRoom()
        started = false
        player.pause()
        player.stop()
        player.clearMediaItems()
        state = state.copy(isPlaying = false, isReady = false)
    }

    private fun leaveRoom() {
        val roomId = currentRoomId
        val session = sessionId
        sessionId = null
        if (roomId > 0) {
            cleanupScope.launch { repository.disconnect(roomId) }
        }
        if (session != null) {
            cleanupScope.launch { repository.stopStream(session) }
        }
    }

    private fun handleEvent(event: CoreEvent) {
        val roomId = (event.params["room_id"] as? JsonPrimitive)?.longOrNull ?: return
        if (roomId != currentRoomId) return
        when (event.method) {
            "event.live.message" -> handleLiveMessage(event)
            "event.live.popularity" -> {
                val value = (event.params["value"] as? JsonPrimitive)?.longOrNull ?: return
                // Heartbeat replies now carry the placeholder 1; real popularity
                // only comes from the room info snapshot.
                if (value > 1) state = state.copy(popularityText = "${formatCount(value)}人气")
            }
            "event.live.connected" -> appendMessage("系统", "弹幕已连接", LiveChatKind.System)
            "event.live.disconnected" -> appendMessage("系统", "弹幕连接已断开", LiveChatKind.System)
        }
    }

    private fun handleLiveMessage(event: CoreEvent) {
        val cmd = (event.params["cmd"] as? JsonPrimitive)?.contentOrNull.orEmpty()
        val danmaku = event.params["danmaku"] as? JsonObject
        if (danmaku != null) {
            val text = (danmaku["text"] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() } ?: return
            val uname = (danmaku["uname"] as? JsonPrimitive)?.contentOrNull ?: "观众"
            appendMessage(uname, text)
            return
        }
        if (cmd == "SUPER_CHAT_MESSAGE") {
            val data = runCatching {
                (event.params["data"] as JsonObject)["data"]?.jsonObject
            }.getOrNull() ?: return
            val text = (data["message"] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() } ?: return
            val uname = runCatching {
                ((data["user_info"] as JsonObject)["uname"] as? JsonPrimitive)?.contentOrNull
            }.getOrNull() ?: "观众"
            val price = (data["price"] as? JsonPrimitive)?.longOrNull ?: 0
            appendMessage(uname, if (price > 0) "¥$price $text" else text, LiveChatKind.SuperChat)
        }
    }

    private fun appendMessage(uname: String, text: String, kind: LiveChatKind = LiveChatKind.Normal) {
        val message = LiveChatMessage(messageId++, uname, text, kind)
        state = state.copy(messages = (state.messages + message).takeLast(MAX_MESSAGES))
    }

    override fun onCleared() {
        chatJob?.cancel()
        player.removeListener(playerListener)
        player.release()
        leaveRoom()
        super.onCleared()
    }

    private companion object {
        const val MAX_MESSAGES = 200
    }
}

@Composable
fun LiveRoomScreen(
    roomId: Long,
    hasAccount: Boolean,
    onBack: () -> Unit,
    onRequireLogin: () -> Unit,
    viewModel: LiveRoomViewModel = viewModel(key = "live-room"),
) {
    val ui = viewModel.state
    val castState = viewModel.casting
    var isFullscreen by remember { mutableStateOf(false) }
    var qualityMenuOpen by remember { mutableStateOf(false) }
    var castOpen by remember { mutableStateOf(false) }
    var composer by remember(roomId) { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(roomId) { viewModel.start(roomId) }
    DisposableEffect(roomId) {
        onDispose { viewModel.leave() }
    }
    LaunchedEffect(ui.messages.size) {
        if (ui.messages.isNotEmpty()) {
            listState.animateScrollToItem(ui.messages.lastIndex)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = false
                        setShutterBackgroundColor(android.graphics.Color.BLACK)
                        player = viewModel.player
                    }
                },
                update = { view -> view.player = viewModel.player },
                onRelease = { view -> view.player = null },
                modifier = Modifier.fillMaxSize(),
            )

            LiveDanmakuColumn(
                messages = ui.messages,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth(0.72f)
                    .padding(start = 10.dp, bottom = 46.dp),
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .statusBarsPadding()
                    .padding(6.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.45f)),
            ) {
                IconButton(onClick = onBack, modifier = Modifier.size(34.dp)) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "退出直播间",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp),
                    )
                }
                if (ui.popularityText.isNotBlank()) {
                    Text(
                        text = ui.popularityText,
                        color = Color.White,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(end = 10.dp),
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .statusBarsPadding()
                    .padding(8.dp),
            ) {
                val castingNow = castState.target != null
                TextButton(
                    onClick = { castOpen = true },
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.5f)),
                ) {
                    ChromeGlyph(
                        kind = ChromeGlyphKind.Cast,
                        color = if (castingNow) MaterialTheme.colorScheme.primary else Color.White,
                        modifier = Modifier.size(13.dp),
                    )
                    Spacer(Modifier.size(4.dp))
                    Text(
                        text = if (castingNow) "投屏中" else "投屏",
                        color = if (castingNow) MaterialTheme.colorScheme.primary else Color.White,
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
                if (ui.qualities.isNotEmpty()) {
                    Box {
                        TextButton(
                            onClick = { qualityMenuOpen = true },
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.Black.copy(alpha = 0.5f)),
                        ) {
                            Text(
                                text = ui.qualities.firstOrNull { it.qn == ui.selectedQn }?.desc
                                    ?: ui.qualities.firstOrNull()?.desc
                                    ?: "清晰度",
                                color = Color.White,
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                            )
                        }
                        DropdownMenu(
                            expanded = qualityMenuOpen,
                            onDismissRequest = { qualityMenuOpen = false },
                        ) {
                            ui.qualities.forEach { quality ->
                                DropdownMenuItem(
                                    text = { Text(quality.desc ?: "QN ${quality.qn}") },
                                    onClick = {
                                        qualityMenuOpen = false
                                        viewModel.selectQuality(quality.qn)
                                    },
                                )
                            }
                        }
                    }
                }
                TextButton(
                    onClick = { isFullscreen = true },
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.5f)),
                ) {
                    Text("全屏", color = Color.White, style = MaterialTheme.typography.labelSmall)
                }
            }

            if (!ui.isPlaying && ui.error == null && !ui.isLoading) {
                TextButton(
                    onClick = viewModel::togglePlayback,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.5f)),
                ) {
                    Text("播放", color = Color.White)
                }
            }

            when {
                ui.isLoading -> LoadingState()
                ui.error != null -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 24.dp),
                ) {
                    Text(
                        text = ui.error ?: "",
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Button(onClick = { viewModel.start(roomId, force = true) }) {
                        Text("重试")
                    }
                }
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Avatar(url = ui.room?.anchorFace?.let { normalizeLiveUrl(it) }, size = 38.dp)
            Column(Modifier.weight(1f)) {
                Text(
                    text = ui.room?.anchorName?.takeIf { it.isNotBlank() } ?: "主播",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                val subtitle = listOfNotNull(
                    ui.areaName.takeIf { it.isNotBlank() },
                    ui.room?.attention?.takeIf { it > 0 }?.let { "${formatCount(it)}关注" },
                ).joinToString(" · ")
                if (subtitle.isNotBlank()) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            val uid = ui.room?.uid ?: 0
            if (ui.isFollowing) {
                OutlinedButton(
                    onClick = { viewModel.toggleFollow(uid, hasAccount, onRequireLogin) },
                    enabled = !ui.isUpdatingFollow,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 2.dp),
                ) {
                    Text("已关注")
                }
            } else {
                Button(
                    onClick = { viewModel.toggleFollow(uid, hasAccount, onRequireLogin) },
                    enabled = !ui.isUpdatingFollow,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 2.dp),
                ) {
                    Text("关注")
                }
            }
        }

        Text(
            text = ui.title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 14.dp),
        )

        ui.notice?.let { notice ->
            Text(
                text = notice,
                style = MaterialTheme.typography.labelMedium,
                color = BtbBrand,
                modifier = Modifier
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .btbPressable(onClick = viewModel::consumeNotice),
            )
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 14.dp),
            contentPadding = PaddingValues(vertical = 6.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            if (ui.messages.isEmpty()) {
                item(key = "chat-empty") {
                    Text(
                        text = "正在等待弹幕…",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 12.dp),
                    )
                }
            }
            items(ui.messages, key = { it.id }) { message ->
                LiveChatRow(message)
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            OutlinedTextField(
                value = composer,
                onValueChange = { if (it.length <= 30) composer = it },
                placeholder = { Text("发个弹幕…") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Button(
                enabled = composer.isNotBlank() && !ui.isSending,
                onClick = {
                    if (!hasAccount) {
                        onRequireLogin()
                    } else {
                        viewModel.sendMessage(composer) { composer = "" }
                    }
                },
            ) {
                Text(if (ui.isSending) "发送中" else "发送")
            }
        }
    }

    if (isFullscreen) {
        LiveFullscreenDialog(
            viewModel = viewModel,
            roomTitle = ui.title,
            messages = ui.messages,
            qualities = ui.qualities,
            selectedQn = ui.selectedQn,
            isPlaying = ui.isPlaying,
            onDismiss = { isFullscreen = false },
        )
    }

    if (castOpen) {
        CastSheet(
            state = castState,
            onRefresh = viewModel::refreshCastDevices,
            onSelect = viewModel::castTo,
            onStop = viewModel::stopCasting,
            onDismiss = { castOpen = false },
        )
    }
}

private fun normalizeLiveUrl(raw: String): String =
    if (raw.startsWith("//")) "https:$raw" else raw

@Composable
private fun LiveDanmakuColumn(
    messages: List<LiveChatMessage>,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        messages.takeLast(5).filter { it.kind != LiveChatKind.System }.forEach { message ->
            Text(
                text = "${message.uname}：${message.text}",
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.Black.copy(alpha = 0.32f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun LiveChatRow(message: LiveChatMessage) {
    val tone = when (message.kind) {
        LiveChatKind.System -> MaterialTheme.colorScheme.onSurfaceVariant
        LiveChatKind.SuperChat -> BtbBrand
        LiveChatKind.Normal -> MaterialTheme.colorScheme.onSurface
    }
    Text(
        text = if (message.kind == LiveChatKind.System) {
            message.text
        } else {
            "${message.uname}：${message.text}"
        },
        style = MaterialTheme.typography.bodySmall,
        color = tone,
        modifier = if (message.kind == LiveChatKind.SuperChat) {
            Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(BtbBrand.copy(alpha = 0.1f))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        } else {
            Modifier
        },
    )
}

@Composable
private fun LiveFullscreenDialog(
    viewModel: LiveRoomViewModel,
    roomTitle: String,
    messages: List<LiveChatMessage>,
    qualities: List<LiveQuality>,
    selectedQn: Long?,
    isPlaying: Boolean,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDismiss,
        properties = androidx.compose.ui.window.DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        val activity = remember(context) { context.findLiveActivity() }
        DisposableEffect(activity) {
            val previousOrientation = activity?.requestedOrientation
            activity?.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            onDispose {
                activity?.requestedOrientation =
                    previousOrientation ?: android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
        var qualityMenuOpen by remember { mutableStateOf(false) }
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = false
                        setShutterBackgroundColor(android.graphics.Color.BLACK)
                        player = viewModel.player
                    }
                },
                update = { view -> view.player = viewModel.player },
                onRelease = { view -> view.player = null },
                modifier = Modifier.fillMaxSize(),
            )
            LiveDanmakuColumn(
                messages = messages,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth(0.55f)
                    .padding(start = 18.dp, bottom = 18.dp),
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp),
            ) {
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.45f)),
                ) {
                    Text("退出全屏", color = Color.White)
                }
                Text(
                    text = roomTitle,
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth(0.6f),
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp),
            ) {
                if (qualities.isNotEmpty()) {
                    Box {
                        TextButton(
                            onClick = { qualityMenuOpen = true },
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.Black.copy(alpha = 0.45f)),
                        ) {
                            Text(
                                qualities.firstOrNull { it.qn == selectedQn }?.desc ?: "清晰度",
                                color = Color.White,
                                style = MaterialTheme.typography.labelSmall,
                            )
                        }
                        DropdownMenu(expanded = qualityMenuOpen, onDismissRequest = { qualityMenuOpen = false }) {
                            qualities.forEach { quality ->
                                DropdownMenuItem(
                                    text = { Text(quality.desc ?: "QN ${quality.qn}") },
                                    onClick = {
                                        qualityMenuOpen = false
                                        viewModel.selectQuality(quality.qn)
                                    },
                                )
                            }
                        }
                    }
                }
                TextButton(
                    onClick = viewModel::togglePlayback,
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.45f)),
                ) {
                    Text(if (isPlaying) "暂停" else "播放", color = Color.White, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

private fun android.content.Context.findLiveActivity(): android.app.Activity? {
    var current: android.content.Context? = this
    while (current is android.content.ContextWrapper) {
        if (current is android.app.Activity) return current
        current = current.baseContext
    }
    return null
}
