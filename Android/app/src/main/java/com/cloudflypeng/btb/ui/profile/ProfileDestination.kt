package com.cloudflypeng.btb.ui.profile

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cloudflypeng.btb.BuildConfig
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.playback.PlaybackController
import com.cloudflypeng.btb.ui.account.AccountViewModel
import com.cloudflypeng.btb.ui.account.ProfileScreen
import com.cloudflypeng.btb.ui.components.AdaptiveDetailLayout
import com.cloudflypeng.btb.ui.components.ChromeGlyph
import com.cloudflypeng.btb.ui.components.ChromeGlyphKind
import com.cloudflypeng.btb.ui.home.VideoDetailPane
import com.cloudflypeng.btb.ui.interaction.btbPressable
import com.cloudflypeng.btb.ui.library.DownloadsScreen
import com.cloudflypeng.btb.ui.library.FavoriteFolderScreen
import com.cloudflypeng.btb.ui.library.FavoritesScreen
import com.cloudflypeng.btb.ui.library.HistoryScreen
import com.cloudflypeng.btb.ui.library.UploadsScreen
import com.cloudflypeng.btb.ui.library.WatchLaterScreen
import com.cloudflypeng.btb.ui.settings.SettingsScreen
import com.cloudflypeng.btb.ui.user.FollowListScreen

sealed interface ProfileRoute {
    data object Root : ProfileRoute
    data object History : ProfileRoute
    data object Favorites : ProfileRoute
    data class FavoriteFolder(val id: Long, val title: String) : ProfileRoute
    data object WatchLater : ProfileRoute
    data class Uploads(val mid: Long) : ProfileRoute
    data object Downloads : ProfileRoute
    data object Following : ProfileRoute
    data object Followers : ProfileRoute
    data object Settings : ProfileRoute
}

private val ProfileRoute.depth: Int
    get() = when (this) {
        ProfileRoute.Root -> 0
        is ProfileRoute.FavoriteFolder -> 2
        else -> 1
    }

@Composable
fun ProfileDestination(
    stack: List<ProfileRoute>,
    onStackChange: (List<ProfileRoute>) -> Unit,
    activeMid: Long,
    selectedVideo: VideoItem?,
    controller: PlaybackController?,
    ensureAccount: suspend () -> Boolean,
    onSelectVideo: (VideoItem?) -> Unit,
    onOpenLogin: () -> Unit,
    onOpenUser: (Long) -> Unit,
    accountViewModel: AccountViewModel,
    modifier: Modifier = Modifier,
) {
    val push: (ProfileRoute) -> Unit = { route -> onStackChange(stack + route) }
    val pop: () -> Unit = { if (stack.size > 1) onStackChange(stack.dropLast(1)) }

    AdaptiveDetailLayout(
        selected = selectedVideo != null,
        onDismiss = { onSelectVideo(null) },
        modifier = modifier,
        list = { listModifier ->
            ProfileStack(
                stack = stack,
                activeMid = activeMid,
                onPush = push,
                onPop = pop,
                onSelectVideo = onSelectVideo,
                onOpenUser = onOpenUser,
                accountViewModel = accountViewModel,
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
                    modifier = detailModifier,
                )
            }
        },
    )
}

@Composable
private fun ProfileStack(
    stack: List<ProfileRoute>,
    activeMid: Long,
    onPush: (ProfileRoute) -> Unit,
    onPop: () -> Unit,
    onSelectVideo: (VideoItem) -> Unit,
    onOpenUser: (Long) -> Unit,
    accountViewModel: AccountViewModel,
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
        label = "profile",
    ) { route ->
        when (route) {
            ProfileRoute.Root -> ProfileScreen(
                viewModel = accountViewModel,
                footer = {
                    ProfileMenu(
                        activeMid = activeMid,
                        onOpen = onPush,
                    )
                },
            )

            ProfileRoute.History -> HistoryScreen(
                onBack = onPop,
                onVideoClick = onSelectVideo,
            )

            ProfileRoute.Favorites -> FavoritesScreen(
                onBack = onPop,
                onOpenFolder = { id, title -> onPush(ProfileRoute.FavoriteFolder(id, title)) },
            )

            is ProfileRoute.FavoriteFolder -> FavoriteFolderScreen(
                folderId = route.id,
                title = route.title,
                onBack = onPop,
                onVideoClick = onSelectVideo,
            )

            ProfileRoute.WatchLater -> WatchLaterScreen(
                onBack = onPop,
                onVideoClick = onSelectVideo,
            )

            is ProfileRoute.Uploads -> UploadsScreen(
                mid = if (route.mid > 0) route.mid else activeMid,
                onBack = onPop,
                onVideoClick = onSelectVideo,
            )

            ProfileRoute.Downloads -> DownloadsScreen(onBack = onPop)

            ProfileRoute.Following -> FollowListScreen(
                mid = activeMid,
                followers = false,
                onBack = onPop,
                onOpenUser = onOpenUser,
            )

            ProfileRoute.Followers -> FollowListScreen(
                mid = activeMid,
                followers = true,
                onBack = onPop,
                onOpenUser = onOpenUser,
            )

            ProfileRoute.Settings -> SettingsScreen(
                onBack = onPop,
                version = BuildConfig.VERSION_NAME,
            )
        }
    }
}

@Composable
private fun ProfileMenu(
    activeMid: Long,
    onOpen: (ProfileRoute) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        ProfileMenuRow(
            icon = Icons.Default.Refresh,
            title = "历史记录",
            subtitle = "观看过的视频",
            onClick = { onOpen(ProfileRoute.History) },
        )
        ProfileMenuRow(
            icon = Icons.Default.Star,
            title = "收藏与播放列表",
            subtitle = "收藏夹与视频收藏",
            onClick = { onOpen(ProfileRoute.Favorites) },
        )
        ProfileMenuRow(
            icon = Icons.Default.PlayArrow,
            title = "稍后再看",
            subtitle = "留待以后观看的视频",
            onClick = { onOpen(ProfileRoute.WatchLater) },
        )
        ProfileMenuRow(
            icon = Icons.Default.KeyboardArrowDown,
            title = "下载",
            subtitle = "离线缓存与存储空间",
            onClick = { onOpen(ProfileRoute.Downloads) },
        )
        ProfileMenuRow(
            icon = Icons.Default.Person,
            title = "我的投稿",
            subtitle = "我发布的视频",
            onClick = { onOpen(ProfileRoute.Uploads(activeMid)) },
        )
        ProfileMenuRow(
            icon = Icons.Default.Person,
            title = "我的关注",
            subtitle = "关注列表与回关",
            onClick = { onOpen(ProfileRoute.Following) },
        )
        ProfileMenuRow(
            icon = Icons.Default.Person,
            title = "我的粉丝",
            subtitle = "粉丝列表",
            onClick = { onOpen(ProfileRoute.Followers) },
        )
        ProfileMenuRow(
            icon = Icons.Default.Settings,
            title = "设置",
            subtitle = "外观、播放与弹幕",
            onClick = { onOpen(ProfileRoute.Settings) },
        )
    }
}

@Composable
private fun ProfileMenuRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .btbPressable(onClick = onClick)
            .padding(vertical = 11.dp, horizontal = 4.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, CircleShape),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(19.dp),
            )
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.height(1.dp))
            Text(
                text = subtitle,
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
