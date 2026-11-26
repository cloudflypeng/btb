package com.cloudflypeng.btb.ui.discover

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.data.ArticleRankItem
import com.cloudflypeng.btb.data.TopicSquareItem
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.WeeklyConfig
import com.cloudflypeng.btb.data.WeeklySeriesItem
import com.cloudflypeng.btb.data.toVideoItem
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RankingUiState(
    val items: List<VideoItem> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

data class WeeklyUiState(
    val series: List<WeeklySeriesItem> = emptyList(),
    val selectedNumber: Int? = null,
    val config: WeeklyConfig? = null,
    val videos: List<VideoItem> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingIssue: Boolean = false,
    val error: String? = null,
    val issueError: String? = null,
    val loaded: Boolean = false,
)

data class ArticleRankUiState(
    val items: List<ArticleRankItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

data class TopicSquareUiState(
    val items: List<TopicSquareItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

class DiscoverViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.discoverRepository

    private val _ranking = MutableStateFlow(RankingUiState())
    val ranking = _ranking.asStateFlow()

    private val _weekly = MutableStateFlow(WeeklyUiState())
    val weekly = _weekly.asStateFlow()

    private val _articles = MutableStateFlow(ArticleRankUiState())
    val articles = _articles.asStateFlow()

    private val _topics = MutableStateFlow(TopicSquareUiState())
    val topics = _topics.asStateFlow()

    private var rankingJob: Job? = null
    private var weeklyJob: Job? = null
    private var issueJob: Job? = null
    private var articlesJob: Job? = null
    private var topicsJob: Job? = null

    fun loadRanking(force: Boolean = false) {
        val state = _ranking.value
        if (!force && (state.loaded || state.isLoading)) return
        rankingJob?.cancel()
        rankingJob = viewModelScope.launch {
            ensureCore()
            _ranking.update { it.copy(isLoading = it.items.isEmpty(), isRefreshing = it.items.isNotEmpty(), error = null) }
            try {
                val items = repository.ranking()
                _ranking.update { it.copy(items = items, isLoading = false, isRefreshing = false, loaded = true) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ranking.update {
                    it.copy(isLoading = false, isRefreshing = false, error = error.userMessage("排行榜加载失败"))
                }
            }
        }
    }

    fun loadWeekly(force: Boolean = false) {
        val state = _weekly.value
        if (!force && (state.loaded || state.isLoading)) return
        weeklyJob?.cancel()
        weeklyJob = viewModelScope.launch {
            ensureCore()
            _weekly.update { it.copy(isLoading = it.series.isEmpty(), error = null) }
            try {
                val series = repository.weeklySeries()
                _weekly.update { it.copy(series = series, isLoading = false, loaded = true) }
                if (series.isEmpty()) {
                    _weekly.update { it.copy(error = "暂无每周必看内容") }
                    return@launch
                }
                val current = _weekly.value.selectedNumber
                val target = series.firstOrNull { it.number == current } ?: series.first()
                selectWeekly(target.number, force = force)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _weekly.update { it.copy(isLoading = false, error = error.userMessage("每周必看加载失败")) }
            }
        }
    }

    fun selectWeekly(number: Int, force: Boolean = false) {
        if (number <= 0) return
        if (!force && number == _weekly.value.selectedNumber && _weekly.value.videos.isNotEmpty()) return
        issueJob?.cancel()
        _weekly.update {
            it.copy(
                selectedNumber = number,
                config = null,
                videos = emptyList(),
                issueError = null,
                isLoadingIssue = true,
            )
        }
        issueJob = viewModelScope.launch {
            ensureCore()
            try {
                val issue = repository.weeklyIssue(number)
                _weekly.update {
                    it.copy(
                        config = issue.config,
                        videos = issue.list.mapNotNull { video -> video.toVideoItem() },
                        isLoadingIssue = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _weekly.update {
                    it.copy(isLoadingIssue = false, issueError = error.userMessage("本期加载失败"))
                }
            }
        }
    }

    fun loadArticles(force: Boolean = false) {
        val state = _articles.value
        if (!force && (state.loaded || state.isLoading)) return
        articlesJob?.cancel()
        articlesJob = viewModelScope.launch {
            ensureCore()
            _articles.update { it.copy(isLoading = it.items.isEmpty(), error = null) }
            try {
                val items = repository.articleRank()
                _articles.update { it.copy(items = items, isLoading = false, loaded = true) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _articles.update { it.copy(isLoading = false, error = error.userMessage("专栏加载失败")) }
            }
        }
    }

    fun loadTopics(force: Boolean = false) {
        val state = _topics.value
        if (!force && (state.loaded || state.isLoading)) return
        topicsJob?.cancel()
        topicsJob = viewModelScope.launch {
            ensureCore()
            _topics.update { it.copy(isLoading = it.items.isEmpty(), error = null) }
            try {
                val items = repository.topicSquare().distinctBy { it.id }
                _topics.update { it.copy(items = items, isLoading = false, loaded = true) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _topics.update { it.copy(isLoading = false, error = error.userMessage("话题加载失败")) }
            }
        }
    }

    private suspend fun ensureCore() {
        runCatching { core.start() }
    }
}

internal fun Throwable.userMessage(prefix: String): String = when (this) {
    is kotlinx.serialization.SerializationException -> "$prefix：数据格式异常，请稍后重试"
    is CoreException -> "$prefix：${message ?: "核心调用失败"}"
    else -> "$prefix：${message?.takeIf { it.isNotBlank() && it.length <= 120 } ?: "未知错误"}"
}
