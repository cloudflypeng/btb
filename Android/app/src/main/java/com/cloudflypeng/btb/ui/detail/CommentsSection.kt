package com.cloudflypeng.btb.ui.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cloudflypeng.btb.data.CommentItem
import com.cloudflypeng.btb.data.CommentRepository
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.CommentRowSkeleton
import com.cloudflypeng.btb.ui.components.InlineNotice
import com.cloudflypeng.btb.ui.components.NoticeTone
import com.cloudflypeng.btb.ui.components.SectionHeader
import com.cloudflypeng.btb.ui.interaction.btbPressable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

private data class CommentsUiState(
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val items: List<CommentItem> = emptyList(),
    val total: Int = 0,
    val error: String? = null,
    val hasMore: Boolean = true,
    val notice: String? = null,
)

private class CommentsController(
    private val repository: CommentRepository,
    private val scope: CoroutineScope,
) {
    var state by mutableStateOf(CommentsUiState())
        private set

    private var job: Job? = null
    private var page = 0
    private val likesInFlight = mutableSetOf<Long>()

    fun load(aid: Long?, sort: Int) {
        if (aid == null) return
        if (state.isLoading || state.isLoadingMore || !state.hasMore) return
        if (page == 0) {
            state = CommentsUiState(isLoading = true)
        } else {
            state = state.copy(isLoadingMore = true, error = null)
        }
        job = scope.launch {
            try {
                val nextPage = page + 1
                val result = repository.list(aid = aid, page = nextPage, sort = sort)
                page = nextPage
                val merged = (state.items + result.items).distinctBy { it.rpid }
                state = state.copy(
                    isLoading = false,
                    isLoadingMore = false,
                    items = merged,
                    total = if (result.total > 0) result.total else state.total,
                    error = null,
                    hasMore = result.items.isNotEmpty() &&
                        merged.size < result.total.coerceAtLeast(result.items.size) &&
                        nextPage < 50,
                )
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                state = state.copy(
                    isLoading = false,
                    isLoadingMore = false,
                    error = error.message?.takeIf { it.isNotBlank() } ?: "评论加载失败",
                )
            }
        }
    }

    fun retry(aid: Long?, sort: Int) {
        if (aid == null) return
        job?.cancel()
        page = 0
        state = CommentsUiState()
        load(aid, sort)
    }

    fun toggleLike(aid: Long?, comment: CommentItem) {
        if (aid == null) return
        if (!likesInFlight.add(comment.rpid)) return

        val target = !comment.liked
        state = state.copy(notice = null)
        updateItem(comment.rpid) {
            it.copy(
                liked = target,
                likeCount = (it.likeCount + if (target) 1 else -1).coerceAtLeast(0),
            )
        }

        scope.launch {
            try {
                repository.like(aid, comment.rpid, target)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                updateItem(comment.rpid) {
                    it.copy(liked = comment.liked, likeCount = comment.likeCount)
                }
                state = state.copy(notice = "点赞失败，请稍后重试")
            } finally {
                likesInFlight.remove(comment.rpid)
            }
        }
    }

    fun dismissNotice() {
        state = state.copy(notice = null)
    }

    private fun updateItem(rpid: Long, transform: (CommentItem) -> CommentItem) {
        state = state.copy(items = state.items.map { if (it.rpid == rpid) transform(it) else it })
    }
}

@Composable
fun CommentsSection(
    aid: Long?,
    repository: CommentRepository,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    var sort by remember { mutableIntStateOf(CommentRepository.SORT_HOT) }
    var expanded by remember(aid, sort) { mutableStateOf(false) }
    val controller = remember(aid) { CommentsController(repository, scope) }
    LaunchedEffect(aid, sort) {
        controller.retry(aid, sort)
    }
    val state = controller.state

    Column(modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            SectionHeader(
                title = "评论",
                count = state.total,
                modifier = Modifier.weight(1f),
            )
            SortChip("热门", selected = sort == CommentRepository.SORT_HOT) {
                sort = CommentRepository.SORT_HOT
            }
            SortChip("最新", selected = sort == CommentRepository.SORT_NEW) {
                sort = CommentRepository.SORT_NEW
            }
        }

        Spacer(Modifier.height(8.dp))

        state.notice?.let { notice ->
            InlineNotice(
                text = notice,
                tone = NoticeTone.Error,
                onDismiss = controller::dismissNotice,
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }

        when {
            state.isLoading -> Column {
                repeat(3) {
                    CommentRowSkeleton()
                }
            }

            state.error != null && state.items.isEmpty() -> InlineNotice(
                text = state.error,
                tone = NoticeTone.Error,
                actionLabel = "重试",
                onAction = { controller.retry(aid, sort) },
            )

            state.items.isEmpty() -> Text(
                text = "还没有评论，来抢沙发吧",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 16.dp),
            )

            else -> {
                val visibleItems = if (expanded) state.items else state.items.take(3)
                visibleItems.forEach { comment ->
                    CommentRow(
                        comment = comment,
                        onLike = { controller.toggleLike(aid, comment) },
                    )
                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f),
                    )
                }

                if (!expanded) {
                    if (state.items.size > 3) {
                        TextButton(
                            onClick = { expanded = true },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                if (state.total > 0) {
                                    "查看全部 ${formatCount(state.total.toLong())} 条评论"
                                } else {
                                    "查看全部评论"
                                },
                            )
                        }
                    }
                } else {
                    when {
                        state.isLoadingMore -> Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                        ) {
                            CircularProgressIndicator(
                                strokeWidth = 2.dp,
                                modifier = Modifier.size(20.dp),
                            )
                        }

                        state.error != null -> InlineNotice(
                            text = state.error,
                            tone = NoticeTone.Error,
                            actionLabel = "重试",
                            onAction = { controller.load(aid, sort) },
                            modifier = Modifier.padding(vertical = 8.dp),
                        )

                        state.hasMore -> TextButton(
                            onClick = { controller.load(aid, sort) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("加载更多评论")
                        }

                        else -> Text(
                            text = "没有更多评论了",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 12.dp),
                        )
                    }

                    if (state.items.size > 3) {
                        TextButton(
                            onClick = { expanded = false },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("收起评论")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SortChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (selected) {
            MaterialTheme.colorScheme.onBackground
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(
                if (selected) {
                    MaterialTheme.colorScheme.surfaceVariant
                } else {
                    Color.Transparent
                },
                RoundedCornerShape(50),
            )
            .btbPressable(haptic = false, onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

@Composable
private fun CommentRow(comment: CommentItem, onLike: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
    ) {
        Avatar(url = comment.avatarUrl, size = 32.dp)
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = comment.userName,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (comment.isUp) {
                    Text(
                        text = "UP",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .padding(start = 6.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                            .padding(horizontal = 4.dp, vertical = 1.dp),
                    )
                }
            }
            Spacer(Modifier.height(3.dp))
            Text(
                text = comment.message,
                style = MaterialTheme.typography.bodyMedium,
            )
            Spacer(Modifier.height(6.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = comment.timeText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .btbPressable(onClick = onLike)
                        .padding(horizontal = 5.dp, vertical = 3.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.ThumbUp,
                        contentDescription = if (comment.liked) "取消点赞" else "点赞",
                        tint = if (comment.liked) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = if (comment.likeCount > 0) {
                            formatCount(comment.likeCount.toLong())
                        } else {
                            "赞"
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = if (comment.liked) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }
                if (comment.replyCount > 0) {
                    Text(
                        text = "${comment.replyCount} 条回复",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (comment.replies.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                ) {
                    comment.replies.forEach { reply ->
                        Text(
                            text = "${reply.userName}：${reply.message}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}
