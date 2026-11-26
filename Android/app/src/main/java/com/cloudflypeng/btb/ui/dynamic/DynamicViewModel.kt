package com.cloudflypeng.btb.ui.dynamic

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreStatus
import com.cloudflypeng.btb.data.DynamicCard
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class DynamicTab(val label: String, val type: String) {
    All("全部", "all"),
    Video("视频", "video"),
    Pgc("番剧", "pgc"),
    Up("UP主", "up"),
}

data class DynamicUiState(
    val coreStatus: CoreStatus = CoreStatus.Starting,
    val hasAccount: Boolean? = null,
    val tab: DynamicTab = DynamicTab.All,
    val items: List<DynamicCard> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val error: String? = null,
    val offset: String? = null,
)

class DynamicViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.dynamicRepository
    private val accountRepository = container.accountRepository

    private val _ui = MutableStateFlow(DynamicUiState())
    val ui = _ui.asStateFlow()

    private var bootstrapJob: Job? = null
    private var loadJob: Job? = null
    private var started = false

    fun start(force: Boolean = false) {
        if (started && !force) return
        started = true
        bootstrap()
    }

    fun accountChanged() {
        _ui.update {
            it.copy(
                items = emptyList(),
                offset = null,
                hasMore = true,
                error = null,
            )
        }
        started = true
        bootstrap()
    }

    fun retry() {
        if (_ui.value.coreStatus == CoreStatus.Ready && _ui.value.hasAccount == true) {
            load(reset = true)
        } else {
            bootstrap()
        }
    }

    fun refresh() {
        if (_ui.value.hasAccount == true && _ui.value.coreStatus == CoreStatus.Ready) {
            load(reset = true)
        } else {
            start(force = true)
        }
    }

    fun selectTab(tab: DynamicTab) {
        if (_ui.value.tab == tab && _ui.value.error == null) return
        _ui.update {
            it.copy(
                tab = tab,
                items = emptyList(),
                offset = null,
                hasMore = true,
                error = null,
            )
        }
        load(reset = true)
    }

    fun loadMore() {
        val state = _ui.value
        if (state.hasAccount != true ||
            state.isLoading ||
            state.isRefreshing ||
            state.isLoadingMore ||
            !state.hasMore ||
            state.items.isEmpty()
        ) {
            return
        }
        load(reset = false)
    }

    fun toggleLike(card: DynamicCard) {
        if (_ui.value.hasAccount != true) return
        val target = !card.liked
        updateCard(card.id) {
            it.copy(
                liked = target,
                likeCount = (it.likeCount + if (target) 1 else -1).coerceAtLeast(0),
            )
        }
        viewModelScope.launch {
            try {
                repository.like(card.id, target)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                updateCard(card.id) {
                    it.copy(liked = !target, likeCount = card.likeCount)
                }
            }
        }
    }

    private fun updateCard(id: String, transform: (DynamicCard) -> DynamicCard) {
        _ui.update { state ->
            state.copy(items = state.items.map { if (it.id == id) transform(it) else it })
        }
    }

    private fun bootstrap() {
        if (bootstrapJob?.isActive == true) return
        bootstrapJob = viewModelScope.launch {
            _ui.update { it.copy(coreStatus = CoreStatus.Starting, error = null) }
            try {
                core.start()
                core.call("core.ping")
                val accounts = accountRepository.accounts()
                val hasAccount = accounts.activeMid > 0 || accounts.accounts.any { it.active == true }
                _ui.update {
                    it.copy(
                        coreStatus = CoreStatus.Ready,
                        hasAccount = hasAccount,
                        isLoading = false,
                    )
                }
                if (hasAccount) load(reset = true)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(
                        coreStatus = CoreStatus.Failed(error.userMessage()),
                        isLoading = false,
                    )
                }
            }
        }
    }

    private fun load(reset: Boolean) {
        val state = _ui.value
        if (state.hasAccount != true || state.coreStatus != CoreStatus.Ready) return
        if (!reset && !state.hasMore) return
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            val tab = state.tab
            _ui.update {
                it.copy(
                    isLoading = reset && it.items.isEmpty(),
                    isRefreshing = reset && it.items.isNotEmpty(),
                    isLoadingMore = !reset,
                    error = null,
                )
            }
            try {
                val page = repository.feed(tab.type, if (reset) null else state.offset)
                if (_ui.value.tab != tab) return@launch
                val merged = if (reset) {
                    page.items
                } else {
                    (state.items + page.items).distinctBy { it.id }
                }
                _ui.update {
                    it.copy(
                        items = merged,
                        offset = page.offset,
                        hasMore = page.hasMore && page.items.isNotEmpty(),
                        isLoading = false,
                        isRefreshing = false,
                        isLoadingMore = false,
                        error = null,
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
                        isLoadingMore = false,
                        error = error.userMessage(),
                    )
                }
            }
        }
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is CoreException -> message?.takeIf { it.isNotBlank() } ?: "动态加载失败"
    else -> message?.takeIf { it.isNotBlank() } ?: "动态加载失败"
}
