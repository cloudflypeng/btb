package com.cloudflypeng.btb.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Badge
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.playbackSettings
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.account.AccountViewModel
import com.cloudflypeng.btb.ui.account.LoginSheet
import com.cloudflypeng.btb.ui.components.AdaptiveDetailLayout
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.discover.DiscoverDestination
import com.cloudflypeng.btb.ui.discover.DiscoverRoute
import com.cloudflypeng.btb.ui.dynamic.DynamicDestination
import com.cloudflypeng.btb.ui.dynamic.DynamicViewModel
import com.cloudflypeng.btb.ui.home.HomeScreen
import com.cloudflypeng.btb.ui.home.VideoDetailPane
import com.cloudflypeng.btb.ui.messages.MessageDestination
import com.cloudflypeng.btb.ui.messages.MessageViewModel
import com.cloudflypeng.btb.ui.playback.PlayerSurface
import com.cloudflypeng.btb.ui.profile.ProfileDestination
import com.cloudflypeng.btb.ui.profile.ProfileRoute
import com.cloudflypeng.btb.ui.user.UserSpaceScreen

enum class AppDestination(
    val label: String,
    val icon: ImageVector,
) {
    Home("首页", Icons.Default.Home),
    Dynamic("动态", Icons.Default.PlayArrow),
    Discover("发现", Icons.Default.Search),
    Messages("消息", Icons.Default.Notifications),
    Profile("我的", Icons.Default.Person),
}

@Composable
fun BtbApp(
    pipMode: Boolean = false,
    viewModel: MainViewModel = viewModel(),
    accountViewModel: AccountViewModel = viewModel(),
    dynamicViewModel: DynamicViewModel = viewModel(),
    messageViewModel: MessageViewModel = viewModel(),
) {
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val dynamicUi by dynamicViewModel.ui.collectAsStateWithLifecycle()
    val messagesUi by messageViewModel.ui.collectAsStateWithLifecycle()
    val accountUi by accountViewModel.state.collectAsStateWithLifecycle()
    val hasAccount = accountUi.active != null
    val activeMid = accountUi.active?.mid ?: 0L
    var destination by rememberSaveable { mutableStateOf(AppDestination.Home) }
    var discoverStack by remember { mutableStateOf(listOf<DiscoverRoute>(DiscoverRoute.Root)) }
    var profileStack by remember { mutableStateOf(listOf<ProfileRoute>(ProfileRoute.Root)) }
    var selectedVideo by remember { mutableStateOf<VideoItem?>(null) }
    var userSpaceMid by remember { mutableStateOf<Long?>(null) }
    var showLogin by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val application = context.applicationContext as BtbApplication
    val controller = remember(selectedVideo?.bvid) {
        selectedVideo?.let { video ->
            PlaybackController(
                context = context,
                video = video,
                repository = application.container.playbackRepository,
                danmakuRepository = application.container.danmakuRepository,
                settings = application.container.settings.current.playbackSettings(),
                castController = application.container.castController,
            )
        }
    }
    val openUserSpace: (Long) -> Unit = { mid ->
        if (mid > 0) {
            userSpaceMid = mid
            selectedVideo = null
        }
    }
    LaunchedEffect(controller) { controller?.start() }
    DisposableEffect(controller) {
        controller?.onPlayNext = { next -> selectedVideo = next }
        onDispose {
            controller?.onPlayNext = null
            controller?.release()
        }
    }
    val ensureAccount: suspend () -> Boolean = {
        runCatching { application.container.accountRepository.profile() != null }
            .getOrDefault(false)
    }

    val openLogin: () -> Unit = {
        accountViewModel.prepareLogin()
        showLogin = true
    }

    LaunchedEffect(accountViewModel) {
        accountViewModel.refresh()
        accountViewModel.accountChanges.collect {
            viewModel.refresh()
            dynamicViewModel.accountChanged()
            messageViewModel.accountChanged()
        }
    }

    LaunchedEffect(Unit) {
        messageViewModel.start()
    }

    LaunchedEffect(destination) {
        when (destination) {
            AppDestination.Dynamic -> dynamicViewModel.start()
            AppDestination.Messages -> messageViewModel.start()
            else -> Unit
        }
    }

    if (pipMode && controller != null) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
            PlayerSurface(
                controller = controller,
                modifier = Modifier.fillMaxSize(),
                pipMode = true,
                ensureAccount = ensureAccount,
            )
        }
        return
    }

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            AppDestination.entries.forEach { entry ->
                item(
                    selected = destination == entry,
                    onClick = {
                        if (destination == entry && entry == AppDestination.Discover) {
                            discoverStack = listOf(DiscoverRoute.Root)
                        }
                        if (destination == entry && entry == AppDestination.Profile) {
                            profileStack = listOf(ProfileRoute.Root)
                        }
                        destination = entry
                        selectedVideo = null
                    },
                    icon = {
                        Icon(
                            imageVector = entry.icon,
                            contentDescription = entry.label,
                        )
                    },
                    label = { Text(entry.label) },
                    badge = if (entry == AppDestination.Messages && messagesUi.unreadTotal > 0) {
                        {
                            Badge {
                                Text(
                                    if (messagesUi.unreadTotal > 99) "99+"
                                    else messagesUi.unreadTotal.toString(),
                                )
                            }
                        }
                    } else {
                        null
                    },
                )
            }
        },
    ) {
        when (destination) {
            AppDestination.Home -> HomeDestination(
                ui = ui,
                viewModel = viewModel,
                selectedVideo = selectedVideo,
                controller = controller,
                ensureAccount = ensureAccount,
                onSelectVideo = { selectedVideo = it },
                onOpenUser = openUserSpace,
                onOpenSearch = {
                    discoverStack = listOf(DiscoverRoute.Search())
                    destination = AppDestination.Discover
                },
                onOpenLogin = openLogin,
            )

            AppDestination.Dynamic -> DynamicDestination(
                ui = dynamicUi,
                viewModel = dynamicViewModel,
                selectedVideo = selectedVideo,
                controller = controller,
                ensureAccount = ensureAccount,
                onSelectVideo = { selectedVideo = it },
                onOpenLogin = openLogin,
            )

            AppDestination.Messages -> MessageDestination(
                ui = messagesUi,
                viewModel = messageViewModel,
                selectedVideo = selectedVideo,
                controller = controller,
                ensureAccount = ensureAccount,
                onSelectVideo = { selectedVideo = it },
                onOpenLogin = openLogin,
            )

            AppDestination.Profile -> ProfileDestination(
                stack = profileStack,
                onStackChange = { profileStack = it },
                activeMid = activeMid,
                selectedVideo = selectedVideo,
                controller = controller,
                ensureAccount = ensureAccount,
                onSelectVideo = { selectedVideo = it },
                onOpenLogin = openLogin,
                onOpenUser = openUserSpace,
                accountViewModel = accountViewModel,
            )

            AppDestination.Discover -> DiscoverDestination(
                stack = discoverStack,
                onStackChange = { discoverStack = it },
                selectedVideo = selectedVideo,
                controller = controller,
                ensureAccount = ensureAccount,
                hasAccount = hasAccount,
                onSelectVideo = { selectedVideo = it },
                onOpenLogin = openLogin,
                onOpenUser = openUserSpace,
            )

            else -> MessageState(
                icon = destination.icon,
                title = destination.label,
                message = "该模块正在接入 bbcore 语义接口。",
            )
        }
    }

    if (userSpaceMid != null) {
        UserSpaceOverlay(
            mid = userSpaceMid!!,
            hasAccount = hasAccount,
            ensureAccount = ensureAccount,
            onOpenLogin = openLogin,
            onOpenUser = openUserSpace,
            onClose = { userSpaceMid = null },
        )
    }

    if (showLogin) {
        LoginSheet(viewModel = accountViewModel, onDismiss = { showLogin = false })
    }
}

@Composable
private fun HomeDestination(
    ui: HomeUiState,
    viewModel: MainViewModel,
    selectedVideo: VideoItem?,
    controller: PlaybackController?,
    ensureAccount: suspend () -> Boolean,
    onSelectVideo: (VideoItem?) -> Unit,
    onOpenUser: (Long) -> Unit,
    onOpenSearch: () -> Unit,
    onOpenLogin: () -> Unit,
) {
    AdaptiveDetailLayout(
        selected = selectedVideo != null,
        onDismiss = { onSelectVideo(null) },
        list = { modifier ->
            HomeScreen(
                ui = ui,
                onRetry = viewModel::retry,
                onRefresh = viewModel::refresh,
                onLoadMore = viewModel::loadMore,
                onSelectTab = viewModel::selectTab,
                onOpenSearch = onOpenSearch,
                onVideoClick = { onSelectVideo(it) },
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
                    onOpenUser = onOpenUser,
                    modifier = modifier,
                )
            }
        },
    )
}

@Composable
private fun UserSpaceOverlay(
    mid: Long,
    hasAccount: Boolean,
    ensureAccount: suspend () -> Boolean,
    onOpenLogin: () -> Unit,
    onOpenUser: (Long) -> Unit,
    onClose: () -> Unit,
) {
    var selected by remember(mid) { mutableStateOf<VideoItem?>(null) }
    val context = LocalContext.current
    val application = context.applicationContext as BtbApplication
    val controller = remember(selected?.bvid) {
        selected?.let { video ->
            PlaybackController(
                context = context,
                video = video,
                repository = application.container.playbackRepository,
                danmakuRepository = application.container.danmakuRepository,
                settings = application.container.settings.current.playbackSettings(),
                castController = application.container.castController,
            )
        }
    }
    LaunchedEffect(controller) { controller?.start() }
    DisposableEffect(controller) {
        controller?.onPlayNext = { next -> selected = next }
        onDispose {
            controller?.onPlayNext = null
            controller?.release()
        }
    }
    BackHandler {
        if (selected != null) {
            selected = null
        } else {
            onClose()
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        AdaptiveDetailLayout(
            selected = selected != null,
            onDismiss = { selected = null },
            list = { modifier ->
                UserSpaceScreen(
                    mid = mid,
                    onBack = onClose,
                    onVideoClick = { selected = it },
                    hasAccount = hasAccount,
                    onRequireLogin = onOpenLogin,
                    modifier = modifier,
                )
            },
            detail = { modifier ->
                val video = selected
                if (video != null && controller != null) {
                    VideoDetailPane(
                        video = video,
                        controller = controller,
                        ensureAccount = ensureAccount,
                        onClose = { selected = null },
                        onOpenLogin = onOpenLogin,
                        onOpenUser = onOpenUser,
                        modifier = modifier,
                    )
                }
            },
        )
    }
}
