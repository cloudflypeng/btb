package com.cloudflypeng.btb.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreStatus
import com.cloudflypeng.btb.data.VideoItem
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class HomeTab(val label: String) {
    Recommend("推荐"),
    Hot("热门"),
    Ranking("排行榜"),
}

data class HomeUiState(
    val coreStatus: CoreStatus = CoreStatus.Starting,
    val tab: HomeTab = HomeTab.Recommend,
    val items: List<VideoItem> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val loadMoreFailed: Boolean = false,
    val hasMore: Boolean = true,
    val error: String? = null,
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.feedRepository

    private val _ui = MutableStateFlow(HomeUiState())
    val ui = _ui.asStateFlow()

    private var bootstrapJob: Job? = null
    private var loadJob: Job? = null
    private var freshIndex = 1
    private var hotPage = 1

    init {
        bootstrap()
    }

    fun retry() {
        if (_ui.value.coreStatus == CoreStatus.Ready) {
            loadHome()
        } else {
            bootstrap()
        }
    }

    fun selectTab(tab: HomeTab) {
        if (_ui.value.tab == tab && _ui.value.error == null) return
        _ui.update {
            it.copy(
                tab = tab,
                items = emptyList(),
                error = null,
                hasMore = true,
            )
        }
        loadHome()
    }

    fun refresh() {
        loadHome(refreshing = true)
    }

    fun loadMore() {
        val state = _ui.value
        if (state.coreStatus != CoreStatus.Ready ||
            state.isLoading ||
            state.isRefreshing ||
            state.isLoadingMore ||
            !state.hasMore ||
            state.items.isEmpty()
        ) {
            return
        }

        loadJob = viewModelScope.launch {
            val tab = state.tab
            _ui.update { it.copy(isLoadingMore = true, loadMoreFailed = false) }
            try {
                val incoming = when (tab) {
                    HomeTab.Recommend -> {
                        val items = repository.recommend(freshIndex)
                        freshIndex += 1
                        items
                    }

                    HomeTab.Hot -> {
                        val items = repository.hot(hotPage + 1)
                        hotPage += 1
                        items
                    }

                    HomeTab.Ranking -> emptyList()
                }
                val current = _ui.value
                if (current.tab != tab) return@launch
                val merged = appendUnique(current.items, incoming)
                _ui.update {
                    it.copy(
                        items = merged,
                        isLoadingMore = false,
                        loadMoreFailed = false,
                        hasMore = tab != HomeTab.Ranking &&
                            incoming.isNotEmpty() &&
                            merged.size > current.items.size,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, loadMoreFailed = true) }
            }
        }
    }

    private fun bootstrap() {
        if (bootstrapJob?.isActive == true) return
        bootstrapJob = viewModelScope.launch {
            _ui.update { it.copy(coreStatus = CoreStatus.Starting, error = null) }
            try {
                core.start()
                core.call("core.ping")
                _ui.update { it.copy(coreStatus = CoreStatus.Ready) }
                loadHome()
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(
                        coreStatus = CoreStatus.Failed(error.userMessage()),
                        isLoading = false,
                        isRefreshing = false,
                    )
                }
            }
        }
    }

    private fun loadHome(refreshing: Boolean = false) {
        if (_ui.value.coreStatus != CoreStatus.Ready) return
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            val tab = _ui.value.tab
            _ui.update {
                it.copy(
                    isLoading = !refreshing && it.items.isEmpty(),
                    isRefreshing = refreshing,
                    error = null,
                    hasMore = true,
                    loadMoreFailed = false,
                )
            }
            try {
                val items = when (tab) {
                    HomeTab.Recommend -> {
                        freshIndex = 1
                        repository.recommend(0)
                    }

                    HomeTab.Hot -> {
                        hotPage = 1
                        repository.hot(1)
                    }

                    HomeTab.Ranking -> repository.ranking()
                }
                if (_ui.value.tab != tab) return@launch
                _ui.update {
                    it.copy(
                        items = items,
                        isLoading = false,
                        isRefreshing = false,
                        hasMore = tab != HomeTab.Ranking && items.isNotEmpty(),
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                if (_ui.value.tab != tab) return@launch
                _ui.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        error = error.userMessage(),
                    )
                }
            }
        }
    }

    private fun appendUnique(existing: List<VideoItem>, incoming: List<VideoItem>): List<VideoItem> {
        val seen = existing.mapTo(HashSet()) { it.bvid }
        return existing + incoming.filter { seen.add(it.bvid) }
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is CoreException -> message ?: "核心调用失败"
    else -> message?.takeIf { it.isNotBlank() } ?: "未知错误"
}
