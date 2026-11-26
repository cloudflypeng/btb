package com.cloudflypeng.btb.ui.anime

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.data.AnimeEpisode
import com.cloudflypeng.btb.data.AnimeRankItem
import com.cloudflypeng.btb.data.AnimeSeason
import com.cloudflypeng.btb.data.AnimeTimelineDay
import com.cloudflypeng.btb.data.AnimeTimelineEpisode
import com.cloudflypeng.btb.data.CastDevice
import com.cloudflypeng.btb.data.LiveQuality
import com.cloudflypeng.btb.data.PgcPlayResult
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.discover.DiscoverSubScreen
import com.cloudflypeng.btb.ui.discover.userMessage
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.playback.CastSheet
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AnimeUiState(
    val tab: Int = 0,
    val days: List<AnimeTimelineDay> = emptyList(),
    val selectedDay: Int = 0,
    val rank: List<AnimeRankItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

class AnimeViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.pgcRepository

    private val _ui = MutableStateFlow(AnimeUiState())
    val ui = _ui.asStateFlow()

    fun load(force: Boolean = false) {
        val state = _ui.value
        if (!force && (state.loaded || state.isLoading)) return
        viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.days.isEmpty() && it.rank.isEmpty(), error = null) }
            var failure: Throwable? = null
            val days = try {
                repository.timeline()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                failure = error
                emptyList()
            }
            val rank = try {
                repository.rank()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                if (failure == null) failure = error
                emptyList()
            }
            val todayIndex = days.indexOfFirst { it.isTodayDay }
            _ui.update {
                it.copy(
                    days = days,
                    rank = rank,
                    selectedDay = if (todayIndex >= 0) todayIndex else 0,
                    isLoading = false,
                    loaded = true,
                    error = failure?.userMessage("番剧加载失败"),
                )
            }
        }
    }

    fun selectTab(index: Int) {
        _ui.update { it.copy(tab = index) }
    }

    fun selectDay(index: Int) {
        _ui.update { it.copy(selectedDay = index) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnimeScreen(
    onBack: () -> Unit,
    onOpenSeason: (Long) -> Unit,
    viewModel: AnimeViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.load() }

    DiscoverSubScreen(title = "番剧", onBack = onBack) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading && ui.days.isEmpty() && ui.rank.isEmpty() -> LoadingState()

                ui.error != null && ui.days.isEmpty() && ui.rank.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "番剧加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.load(force = true) },
                )

                else -> Column(Modifier.fillMaxSize()) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    ) {
                        AnimeTabPill("时间表", selected = ui.tab == 0) { viewModel.selectTab(0) }
                        AnimeTabPill("排行", selected = ui.tab == 1) { viewModel.selectTab(1) }
                    }
                    if (ui.tab == 0) {
                        TimelineContent(
                            ui = ui,
                            onSelectDay = viewModel::selectDay,
                            onOpenSeason = onOpenSeason,
                        )
                    } else {
                        RankContent(rank = ui.rank, onOpenSeason = onOpenSeason)
                    }
                }
            }
        }
    }
}

@Composable
private fun AnimeTabPill(label: String, selected: Boolean, onClick: () -> Unit) {
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
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 7.dp),
        )
    }
}

@Composable
private fun TimelineContent(
    ui: AnimeUiState,
    onSelectDay: (Int) -> Unit,
    onOpenSeason: (Long) -> Unit,
) {
    val day = ui.days.getOrNull(ui.selectedDay)
    Column(Modifier.fillMaxSize()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            ui.days.forEachIndexed { index, item ->
                val selected = index == ui.selectedDay
                Surface(
                    color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier
                        .weight(1f)
                        .btbPressable(haptic = false, onClick = { onSelectDay(index) }),
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(vertical = 7.dp),
                    ) {
                        Text(
                            text = item.weekdayTitle,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = item.date.takeLast(5),
                            style = MaterialTheme.typography.labelSmall,
                            fontSize = 9.sp,
                            color = if (selected) Color.White.copy(alpha = 0.85f) else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            if (day == null || day.episodes.isEmpty()) {
                item(key = "empty") {
                    Text(
                        text = "当日暂无更新",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 28.dp),
                    )
                }
            } else {
                items(day.episodes.chunked(3), key = { row -> row.first().seasonId }) { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        row.forEach { episode ->
                            TimelineCard(
                                episode = episode,
                                onClick = { onOpenSeason(episode.seasonId) },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        repeat(3 - row.size) {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
                item(key = "spacer") { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

@Composable
private fun TimelineCard(
    episode: AnimeTimelineEpisode,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .btbPressable(onClick = onClick),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            BtbImage(
                url = episode.coverUrl,
                contentDescription = episode.title,
                modifier = Modifier.fillMaxSize(),
            )
            episode.pubIndex?.takeIf { it.isNotBlank() }?.let { index ->
                Surface(
                    color = Color.Black.copy(alpha = 0.62f),
                    shape = RoundedCornerShape(4.dp),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(5.dp),
                ) {
                    Text(
                        text = index,
                        color = Color.White,
                        fontSize = 9.sp,
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp),
                    )
                }
            }
            if (!episode.isPublished) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.42f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("待更新", color = Color.White, fontSize = 10.sp)
                }
            }
        }
        Spacer(Modifier.height(5.dp))
        Text(
            text = episode.title,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            lineHeight = 16.sp,
        )
    }
}

@Composable
private fun RankContent(rank: List<AnimeRankItem>, onOpenSeason: (Long) -> Unit) {
    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        if (rank.isEmpty()) {
            item(key = "empty") {
                Text(
                    text = "暂无排行数据",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 28.dp),
                )
            }
        }
        items(rank, key = { it.seasonId }) { item ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .btbPressable(onClick = { onOpenSeason(item.seasonId) })
                    .padding(vertical = 7.dp),
            ) {
                Text(
                    text = (item.rank ?: 0).toString(),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = if ((item.rank ?: 99) <= 3) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(24.dp),
                )
                Box(
                    Modifier
                        .width(92.dp)
                        .aspectRatio(16f / 10f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    BtbImage(
                        url = item.coverUrl,
                        contentDescription = item.title,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        text = item.title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Medium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (item.subtitle.isNotBlank()) {
                        Spacer(Modifier.height(3.dp))
                        Text(
                            text = item.subtitle,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                Text(
                    text = item.rating?.text ?: "暂无评分",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = if ((item.rating?.score ?: 0.0) > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

data class AnimeDetailUiState(
    val isLoading: Boolean = true,
    val season: AnimeSeason? = null,
    val isFollowing: Boolean = false,
    val isUpdatingFollow: Boolean = false,
    val playingEpisode: AnimeEpisode? = null,
    val qualities: List<LiveQuality> = emptyList(),
    val selectedQn: Long? = null,
    val isPlayLoading: Boolean = false,
    val playError: String? = null,
    val isReady: Boolean = false,
    val isPlaying: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
)

class AnimeDetailViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.pgcRepository
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

    var state by mutableStateOf(AnimeDetailUiState())
        private set

    private var seasonId = 0L
    private var sessionId: String? = null
    private var loaded = false
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_READY -> state = state.copy(
                    isReady = true,
                    isPlayLoading = false,
                    playError = null,
                )
                Player.STATE_ENDED -> state = state.copy(isPlaying = false, isPlayLoading = false)
                Player.STATE_BUFFERING -> Unit
                Player.STATE_IDLE -> Unit
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            state = state.copy(isPlaying = isPlaying)
        }

        override fun onPlayerError(error: PlaybackException) {
            state = state.copy(
                isPlaying = false,
                isReady = false,
                isPlayLoading = false,
                playError = "视频播放失败，请稍后重试（${error.errorCodeName}）",
            )
        }
    }

    init {
        player.addListener(listener)
    }

    fun load(seasonId: Long, force: Boolean = false) {
        if (loaded && this.seasonId == seasonId && !force) return
        this.seasonId = seasonId
        loaded = true
        state = AnimeDetailUiState(isLoading = true)
        viewModelScope.launch {
            runCatching { container.core.start() }
            try {
                val season = repository.info(seasonId)
                state = state.copy(
                    season = season,
                    isFollowing = season.isFollowing,
                    isLoading = false,
                )
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(isLoading = false, error = error.userMessage("番剧详情加载失败"))
            }
        }
    }

    fun play(episode: AnimeEpisode, qn: Long? = null) {
        if (state.isPlayLoading) return
        state = state.copy(isPlayLoading = true, playError = null, playingEpisode = episode)
        viewModelScope.launch {
            try {
                val result = repository.play(seasonId, episode.epId, qn ?: state.selectedQn)
                if (!result.playable) {
                    state = state.copy(
                        isPlayLoading = false,
                        playError = result.unavailableText,
                        playingEpisode = episode,
                    )
                    return@launch
                }
                state = state.copy(
                    playingEpisode = result.episode ?: episode,
                    qualities = result.qualities.orEmpty(),
                    selectedQn = result.quality?.qn,
                    season = result.season ?: state.season,
                )
                attachStream(result)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(
                    isPlayLoading = false,
                    playError = if (error is CoreException) error.message else error.userMessage("视频加载失败"),
                )
            }
        }
    }

    private fun attachStream(result: PgcPlayResult) {
        val url = result.playbackUrl
        if (url.isNullOrBlank()) {
            state = state.copy(isPlayLoading = false, playError = result.unavailableText)
            return
        }
        val previous = sessionId
        sessionId = result.sessionId
        if (previous != null && previous != result.sessionId) {
            cleanupScope.launch { repository.stopStream(previous) }
        }
        player.setMediaItem(MediaItem.fromUri(url))
        player.playWhenReady = true
        player.prepare()
    }

    fun selectQuality(qn: Long) {
        val episode = state.playingEpisode ?: return
        if (qn == state.selectedQn || state.isPlayLoading) return
        state = state.copy(selectedQn = qn)
        play(episode, qn)
    }

    fun toggleFollow(hasAccount: Boolean, onRequireLogin: () -> Unit) {
        if (state.isUpdatingFollow) return
        if (!hasAccount) {
            onRequireLogin()
            return
        }
        val next = !state.isFollowing
        state = state.copy(isFollowing = next, isUpdatingFollow = true)
        viewModelScope.launch {
            try {
                repository.follow(seasonId, next)
                state = state.copy(isUpdatingFollow = false, notice = if (next) "已追番" else "已取消追番")
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(
                    isFollowing = !next,
                    isUpdatingFollow = false,
                    notice = error.userMessage(if (next) "追番失败" else "取消追番失败"),
                )
            }
        }
    }

    fun consumeNotice() {
        state = state.copy(notice = null)
    }

    fun stopPlayback() {
        player.stop()
        player.clearMediaItems()
        val session = sessionId
        sessionId = null
        if (session != null) {
            cleanupScope.launch { repository.stopStream(session) }
        }
        state = state.copy(isPlaying = false, isReady = false, isPlayLoading = false)
    }

    val casting: com.cloudflypeng.btb.playback.CastUiState get() = castController.state

    fun castTo(device: CastDevice) {
        val episode = state.playingEpisode ?: return
        if (!state.isReady) {
            state = state.copy(notice = "视频尚未加载完成")
            return
        }
        val title = listOfNotNull(
            state.season?.title?.takeIf { it.isNotBlank() },
            episode.displayTitle.takeIf { it.isNotBlank() },
        ).joinToString(" · ").ifBlank { "番剧" }
        val position = runCatching { player.currentPosition }.getOrDefault(0L)
        castController.castPgc(
            device = device,
            seasonId = seasonId,
            episodeId = episode.epId,
            qn = state.selectedQn,
            title = title,
            positionMs = position,
        ) {
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

    override fun onCleared() {
        player.removeListener(listener)
        player.release()
        val session = sessionId
        if (session != null) {
            cleanupScope.launch { repository.stopStream(session) }
        }
        super.onCleared()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnimeDetailScreen(
    seasonId: Long,
    hasAccount: Boolean,
    onBack: () -> Unit,
    onRequireLogin: () -> Unit,
    viewModel: AnimeDetailViewModel = viewModel(key = "anime-detail"),
) {
    val ui = viewModel.state
    val castState = viewModel.casting
    var fullscreen by remember { mutableStateOf(false) }
    var qualityMenuOpen by remember { mutableStateOf(false) }
    var castOpen by remember { mutableStateOf(false) }
    var descriptionExpanded by remember(seasonId) { mutableStateOf(false) }

    LaunchedEffect(seasonId) { viewModel.load(seasonId) }
    DisposableEffect(seasonId) {
        onDispose { viewModel.stopPlayback() }
    }

    DiscoverSubScreen(title = ui.season?.title ?: "番剧详情", onBack = onBack) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                ui.isLoading -> LoadingState()
                ui.season == null -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "番剧详情加载失败",
                    message = ui.error ?: "请稍后重试",
                    actionLabel = "重试",
                    onAction = { viewModel.load(seasonId, force = true) },
                )
                else -> {
                    val season = ui.season!!
                    LazyColumn(
                        contentPadding = PaddingValues(bottom = 28.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item(key = "header") {
                            AnimeHeader(
                                season = season,
                                isFollowing = ui.isFollowing,
                                isUpdating = ui.isUpdatingFollow,
                                onToggleFollow = { viewModel.toggleFollow(hasAccount, onRequireLogin) },
                            )
                        }
                        if (ui.playingEpisode != null) {
                            item(key = "player") {
                                AnimePlayerCard(
                                    viewModel = viewModel,
                                    episode = ui.playingEpisode!!,
                                    playError = ui.playError,
                                    isPlayLoading = ui.isPlayLoading,
                                    qualities = ui.qualities,
                                    selectedQn = ui.selectedQn,
                                    qualityMenuOpen = qualityMenuOpen,
                                    onQualityMenuChange = { qualityMenuOpen = it },
                                    castingNow = castState.target != null,
                                    onCast = { castOpen = true },
                                    onFullscreen = { fullscreen = true },
                                    onRetry = { viewModel.play(ui.playingEpisode!!) },
                                )
                            }
                        }
                        ui.notice?.let { notice ->
                            item(key = "notice") {
                                Text(
                                    text = notice,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier
                                        .padding(horizontal = 16.dp, vertical = 4.dp)
                                        .btbPressable(onClick = viewModel::consumeNotice),
                                )
                            }
                        }
                        item(key = "episodes-title") {
                            Text(
                                text = "选集（${season.episodeCount}）",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                            )
                        }
                        item(key = "episodes") {
                            EpisodeGrid(
                                episodes = season.episodes.orEmpty(),
                                selectedId = ui.playingEpisode?.epId,
                                onSelect = { episode -> viewModel.play(episode) },
                            )
                        }
                        season.evaluate?.takeIf { it.isNotBlank() }?.let { evaluate ->
                            item(key = "evaluate-title") {
                                Text(
                                    text = "简介",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                                )
                            }
                            item(key = "evaluate") {
                                Text(
                                    text = evaluate,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = if (descriptionExpanded) Int.MAX_VALUE else 4,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier
                                        .padding(horizontal = 16.dp)
                                        .btbPressable(haptic = false) { descriptionExpanded = !descriptionExpanded },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (fullscreen) {
        AnimeFullscreenDialog(
            viewModel = viewModel,
            onDismiss = { fullscreen = false },
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

@Composable
private fun AnimeHeader(
    season: AnimeSeason,
    isFollowing: Boolean,
    isUpdating: Boolean,
    onToggleFollow: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(172.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            BtbImage(
                url = season.backgroundUrl,
                contentDescription = season.title,
                modifier = Modifier.fillMaxSize(),
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0.35f to Color.Transparent,
                            1f to Color.Black.copy(alpha = 0.78f),
                        ),
                    ),
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Text(
                    text = season.title,
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (season.progressText.isNotBlank()) {
                    Spacer(Modifier.height(3.dp))
                    Text(
                        text = season.progressText,
                        color = Color.White.copy(alpha = 0.82f),
                        style = MaterialTheme.typography.labelSmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = season.rating?.text ?: "暂无评分",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    if ((season.rating?.count ?: 0) > 0) {
                        Text(
                            text = "${season.rating?.count}人评分",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 4.dp),
                        )
                    }
                }
                if (season.statsText.isNotBlank()) {
                    Text(
                        text = season.statsText,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (isFollowing) {
                OutlinedButton(onClick = onToggleFollow, enabled = !isUpdating) {
                    Text("已追番")
                }
            } else {
                Button(onClick = onToggleFollow, enabled = !isUpdating) {
                    Text(if (isUpdating) "处理中…" else "追番")
                }
            }
        }
    }
}

@Composable
private fun EpisodeGrid(
    episodes: List<AnimeEpisode>,
    selectedId: Long?,
    onSelect: (AnimeEpisode) -> Unit,
) {
    if (episodes.isEmpty()) {
        Text(
            text = "暂无剧集",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
        )
        return
    }
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.padding(horizontal = 16.dp),
    ) {
        episodes.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { episode ->
                    val selected = episode.epId == selectedId
                    Surface(
                        color = if (selected) {
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)
                        } else {
                            MaterialTheme.colorScheme.surfaceVariant
                        },
                        shape = RoundedCornerShape(9.dp),
                        modifier = Modifier
                            .weight(1f)
                            .btbPressable(haptic = false, onClick = { onSelect(episode) }),
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 9.dp),
                        ) {
                            Text(
                                text = episode.displayTitle,
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            if (episode.durationText.isNotBlank()) {
                                Text(
                                    text = episode.durationText,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontSize = 9.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                repeat(4 - row.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun AnimePlayerCard(
    viewModel: AnimeDetailViewModel,
    episode: AnimeEpisode,
    playError: String?,
    isPlayLoading: Boolean,
    qualities: List<LiveQuality>,
    selectedQn: Long?,
    qualityMenuOpen: Boolean,
    onQualityMenuChange: (Boolean) -> Unit,
    castingNow: Boolean,
    onCast: () -> Unit,
    onFullscreen: () -> Unit,
    onRetry: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = true
                        setShowNextButton(false)
                        setShowPreviousButton(false)
                        setShutterBackgroundColor(android.graphics.Color.BLACK)
                        player = viewModel.player
                    }
                },
                update = { view -> view.player = viewModel.player },
                onRelease = { view -> view.player = null },
                modifier = Modifier.fillMaxSize(),
            )
            if (playError != null) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.82f)),
                ) {
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = playError,
                        color = Color.White.copy(alpha = 0.85f),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 24.dp),
                    )
                    Button(onClick = onRetry) {
                        Text("重试")
                    }
                    Spacer(Modifier.weight(1.2f))
                }
            } else if (isPlayLoading) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.3f)),
                    contentAlignment = Alignment.Center,
                ) {
                    androidx.compose.material3.CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text(
                text = buildString {
                    append(episode.displayTitle)
                    if (episode.subtitleText.isNotBlank()) {
                        append(" · ")
                        append(episode.subtitleText)
                    }
                },
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (qualities.isNotEmpty()) {
                Box {
                    TextButton(onClick = { onQualityMenuChange(true) }) {
                        Text(
                            text = qualities.firstOrNull { it.qn == selectedQn }?.desc ?: "清晰度",
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                    DropdownMenu(
                        expanded = qualityMenuOpen,
                        onDismissRequest = { onQualityMenuChange(false) },
                    ) {
                        qualities.forEach { quality ->
                            DropdownMenuItem(
                                text = { Text(quality.desc ?: "QN ${quality.qn}") },
                                onClick = {
                                    onQualityMenuChange(false)
                                    viewModel.selectQuality(quality.qn)
                                },
                            )
                        }
                    }
                }
            }
            TextButton(onClick = onCast) {
                ChromeGlyph(
                    kind = ChromeGlyphKind.Cast,
                    color = if (castingNow) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(14.dp),
                )
                Spacer(Modifier.size(4.dp))
                Text(
                    text = if (castingNow) "投屏中" else "投屏",
                    style = MaterialTheme.typography.labelMedium,
                    color = if (castingNow) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                )
            }
            TextButton(onClick = onFullscreen) {
                Text("全屏", style = MaterialTheme.typography.labelMedium)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AnimeFullscreenDialog(
    viewModel: AnimeDetailViewModel,
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
        val activity = remember(context) { context.findAnimeActivity() }
        DisposableEffect(activity) {
            val previousOrientation = activity?.requestedOrientation
            activity?.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            onDispose {
                activity?.requestedOrientation =
                    previousOrientation ?: android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = true
                        setShowNextButton(false)
                        setShowPreviousButton(false)
                        setShutterBackgroundColor(android.graphics.Color.BLACK)
                        player = viewModel.player
                    }
                },
                update = { view -> view.player = viewModel.player },
                onRelease = { view -> view.player = null },
                modifier = Modifier.fillMaxSize(),
            )
            TextButton(
                onClick = onDismiss,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(14.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.45f)),
            ) {
                Text("退出全屏", color = Color.White)
            }
        }
    }
}

private fun android.content.Context.findAnimeActivity(): android.app.Activity? {
    var current: android.content.Context? = this
    while (current is android.content.ContextWrapper) {
        if (current is android.app.Activity) return current
        current = current.baseContext
    }
    return null
}
