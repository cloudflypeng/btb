package com.cloudflypeng.btb.ui.discover

import android.text.Html
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.ArticleDetail
import com.cloudflypeng.btb.data.ArticleRankItem
import com.cloudflypeng.btb.data.formatCount
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.BtbImage
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState
import com.cloudflypeng.btb.ui.interaction.btbPressable

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ArticleRankScreen(
    onBack: () -> Unit,
    onOpenArticle: (Long) -> Unit,
    viewModel: DiscoverViewModel = viewModel(),
) {
    val ui by viewModel.articles.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.loadArticles() }

    DiscoverSubScreen(
        title = "专栏",
        onBack = onBack,
        actions = {
            IconButton(onClick = { viewModel.loadArticles(force = true) }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "刷新专栏",
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
                    title = "专栏加载失败",
                    message = ui.error ?: "",
                    actionLabel = "重试",
                    onAction = { viewModel.loadArticles(force = true) },
                )

                ui.items.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "暂无专栏",
                    message = "稍后刷新试试",
                )

                else -> LazyColumn(
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(ui.items, key = { it.id }) { article ->
                        ArticleRankRow(article) { onOpenArticle(article.id) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ArticleRankRow(article: ArticleRankItem, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .btbPressable(onClick = onClick),
    ) {
        BtbImage(
            url = article.coverUrl,
            contentDescription = article.title,
            modifier = Modifier
                .width(112.dp)
                .height(74.dp)
                .clip(RoundedCornerShape(10.dp)),
        )
        Column(Modifier.weight(1f)) {
            Text(
                text = article.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (article.summaryText.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = article.summaryText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = listOfNotNull(
                    article.authorName,
                    article.stats?.view?.takeIf { it > 0 }?.let { "${formatCount(it.toLong())}阅读" },
                ).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ArticleDetailScreen(articleId: Long, onBack: () -> Unit) {
    val context = LocalContext.current
    val repository = remember(context) {
        (context.applicationContext as BtbApplication).container.discoverRepository
    }
    var article by remember(articleId) { mutableStateOf<ArticleDetail?>(null) }
    var loading by remember(articleId) { mutableStateOf(true) }
    var error by remember(articleId) { mutableStateOf<String?>(null) }

    LaunchedEffect(articleId) {
        loading = true
        error = null
        try {
            article = repository.article(articleId)
        } catch (throwable: Throwable) {
            error = throwable.message ?: "专栏加载失败"
        } finally {
            loading = false
        }
    }

    DiscoverSubScreen(title = "专栏", onBack = onBack) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                loading -> LoadingState()

                article == null -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "专栏加载失败",
                    message = error ?: "请稍后重试",
                )

                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 18.dp)
                        .padding(bottom = 32.dp),
                ) {
                    val detail = article ?: return@Column
                    Text(
                        text = detail.title,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Avatar(url = detail.author?.face, size = 26.dp)
                        Text(
                            text = detail.author?.name ?: "未知作者",
                            style = MaterialTheme.typography.labelLarge,
                        )
                        detail.category?.name?.takeIf { it.isNotBlank() }?.let { name ->
                            Text(
                                text = name,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    val meta = listOfNotNull(
                        detail.publishedText(),
                        detail.stats?.view?.takeIf { it > 0 }?.let { "${formatCount(it.toLong())}阅读" },
                        detail.words?.takeIf { it > 0 }?.let { "${formatCount(it.toLong())}字" },
                    ).joinToString(" · ")
                    if (meta.isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = meta,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    detail.bannerUrl?.let { banner ->
                        Spacer(Modifier.height(14.dp))
                        BtbImage(
                            url = banner,
                            contentDescription = null,
                            modifier = Modifier
                                .fillMaxWidth()
                                .aspectRatio(16f / 9f)
                                .clip(RoundedCornerShape(12.dp)),
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                    SelectionContainer {
                        Text(
                            text = articlePlainText(detail.content),
                            style = MaterialTheme.typography.bodyLarge,
                            lineHeight = 28.sp,
                        )
                    }
                }
            }
        }
    }
}

private fun articlePlainText(html: String?): String {
    if (html.isNullOrBlank()) return ""
    return Html.fromHtml(html, Html.FROM_HTML_MODE_LEGACY)
        .toString()
        .replace(Regex("\n{3,}"), "\n\n")
        .trim()
}

private fun ArticleDetail.publishedText(): String? {
    val time = publishTime ?: return null
    if (time <= 0) return null
    return com.cloudflypeng.btb.data.weekdayDate(time)
}
