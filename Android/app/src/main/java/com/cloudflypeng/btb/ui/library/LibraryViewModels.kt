package com.cloudflypeng.btb.ui.library

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.DownloadItem
import com.cloudflypeng.btb.data.DownloadListData
import com.cloudflypeng.btb.data.FavFolder
import com.cloudflypeng.btb.data.HistoryCursor
import com.cloudflypeng.btb.data.HistoryVideo
import com.cloudflypeng.btb.data.VideoItem
import com.cloudflypeng.btb.data.WatchLaterEntry
import com.cloudflypeng.btb.ui.discover.userMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ListUiState<T>(
    val items: List<T> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val error: String? = null,
    val loaded: Boolean = false,
)

class HistoryViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.libraryRepository

    private val _ui = MutableStateFlow(ListUiState<HistoryVideo>())
    val ui = _ui.asStateFlow()
    private val _paused = MutableStateFlow(false)
    val paused = _paused.asStateFlow()

    private var cursor: HistoryCursor? = null
    private var job: Job? = null

    fun load(force: Boolean = false) {
        val state = _ui.value
        if (!force && (state.loaded || state.isLoading)) return
        job?.cancel()
        job = viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.items.isEmpty(), error = null) }
            try {
                val result = repository.history()
                _paused.value = runCatching { repository.historyStatus() }.getOrDefault(false)
                cursor = result.second
                _ui.update {
                    it.copy(
                        items = result.first,
                        isLoading = false,
                        loaded = true,
                        hasMore = result.second != null,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoading = false, loaded = true, error = error.userMessage("历史记录加载失败")) }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        val current = cursor ?: return
        if (state.isLoading || state.isLoadingMore || !state.hasMore) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val result = repository.history(max = current.max, viewAt = current.viewAt)
                cursor = result.second
                _ui.update {
                    it.copy(
                        items = it.items + result.first.filterNot { item ->
                            it.items.any { existing -> existing.kid == item.kid }
                        },
                        isLoadingMore = false,
                        hasMore = result.second != null,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }

    fun remove(item: HistoryVideo) {
        val kid = item.kid ?: return
        viewModelScope.launch {
            runCatching { repository.deleteHistory(kid) }
                .onSuccess { _ui.update { it.copy(items = it.items.filterNot { entry -> entry.kid == kid }) } }
        }
    }

    fun clearAll() {
        viewModelScope.launch {
            runCatching { repository.clearHistory() }
                .onSuccess { _ui.update { it.copy(items = emptyList()) } }
        }
    }

    fun setPaused(value: Boolean) {
        viewModelScope.launch {
            runCatching { repository.pauseHistory(value) }
                .onSuccess { _paused.value = value }
                .onFailure { _paused.value = !value }
        }
    }
}

class FavoritesViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.libraryRepository

    private val _ui = MutableStateFlow(ListUiState<FavFolder>())
    val ui = _ui.asStateFlow()
    val actionError = MutableStateFlow<String?>(null)

    fun load(force: Boolean = false) {
        val state = _ui.value
        if (!force && (state.loaded || state.isLoading)) return
        viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.items.isEmpty(), error = null) }
            try {
                val folders = repository.favoriteFolders()
                _ui.update { it.copy(items = folders, isLoading = false, loaded = true) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoading = false, loaded = true, error = error.userMessage("收藏夹加载失败")) }
            }
        }
    }

    fun create(title: String, onDone: () -> Unit) {
        if (title.isBlank()) return
        viewModelScope.launch {
            runCatching { repository.createFolder(title.trim()) }
                .onSuccess {
                    actionError.value = null
                    load(force = true)
                    onDone()
                }
                .onFailure { actionError.value = it.userMessage("创建失败") }
        }
    }

    fun delete(folder: FavFolder) {
        viewModelScope.launch {
            runCatching { repository.deleteFolder(folder.id) }
                .onSuccess {
                    _ui.update { state -> state.copy(items = state.items.filterNot { it.id == folder.id }) }
                    actionError.value = null
                }
                .onFailure { actionError.value = it.userMessage("删除失败") }
        }
    }
}

class WatchLaterViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.libraryRepository

    private val _ui = MutableStateFlow(ListUiState<WatchLaterEntry>())
    val ui = _ui.asStateFlow()
    private var page = 1
    private var job: Job? = null

    fun load(force: Boolean = false) {
        val state = _ui.value
        if (!force && (state.loaded || state.isLoading)) return
        job?.cancel()
        job = viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = it.items.isEmpty(), error = null) }
            try {
                val items = repository.watchLater(page = 1)
                page = 1
                _ui.update {
                    it.copy(items = items, isLoading = false, loaded = true, hasMore = items.size >= 30)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoading = false, loaded = true, error = error.userMessage("稍后再看加载失败")) }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingMore || !state.hasMore) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val items = repository.watchLater(page = page + 1)
                page += 1
                _ui.update {
                    it.copy(
                        items = it.items + items.filterNot { entry -> it.items.any { e -> e.video.bvid == entry.video.bvid } },
                        isLoadingMore = false,
                        hasMore = items.size >= 30,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }

    fun remove(entry: WatchLaterEntry) {
        if (entry.aid <= 0) return
        viewModelScope.launch {
            runCatching { repository.removeWatchLater(listOf(entry.aid)) }
                .onSuccess {
                    _ui.update { state ->
                        state.copy(items = state.items.filterNot { it.aid == entry.aid })
                    }
                }
        }
    }

    fun clearAll() {
        viewModelScope.launch {
            runCatching { repository.clearWatchLater() }
                .onSuccess { _ui.update { it.copy(items = emptyList()) } }
        }
    }
}

class DownloadsViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.libraryRepository

    private val _ui = MutableStateFlow<DownloadListData?>(null)
    val ui = _ui.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error = _error.asStateFlow()
    private val _loading = MutableStateFlow(true)
    val loading = _loading.asStateFlow()

    private var pollJob: Job? = null

    fun start() {
        load()
        pollJob?.cancel()
        pollJob = viewModelScope.launch {
            while (true) {
                delay(2_500)
                runCatching { repository.downloads() }.onSuccess { _ui.value = it }
            }
        }
    }

    fun load() {
        viewModelScope.launch {
            runCatching { container.core.start() }
            try {
                _ui.value = repository.downloads()
                _error.value = null
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _error.value = error.userMessage("下载列表加载失败")
            } finally {
                _loading.value = false
            }
        }
    }

    fun pause(item: DownloadItem) = mutate { repository.pauseDownload(item.id) }
    fun resume(item: DownloadItem) = mutate { repository.resumeDownload(item.id) }
    fun remove(item: DownloadItem) = mutate { repository.removeDownload(item.id) }

    private fun mutate(block: suspend () -> Unit) {
        viewModelScope.launch {
            runCatching { block() }
                .onSuccess { load() }
                .onFailure { _error.value = it.userMessage("操作失败") }
        }
    }

    override fun onCleared() {
        pollJob?.cancel()
        super.onCleared()
    }
}

class UploadsViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val repository = container.libraryRepository

    private val _ui = MutableStateFlow(ListUiState<VideoItem>())
    val ui = _ui.asStateFlow()
    private var mid = 0L
    private var page = 1

    fun load(mid: Long, force: Boolean = false) {
        if (this.mid == mid && _ui.value.loaded && !force) return
        this.mid = mid
        this.page = 1
        viewModelScope.launch {
            runCatching { container.core.start() }
            _ui.update { it.copy(isLoading = true, error = null) }
            try {
                val items = repository.uploads(mid, page = 1)
                _ui.update {
                    it.copy(items = items, isLoading = false, loaded = true, hasMore = items.size >= 20)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoading = false, error = error.userMessage("投稿加载失败")) }
            }
        }
    }

    fun loadMore() {
        val state = _ui.value
        if (state.isLoading || state.isLoadingMore || !state.hasMore || mid <= 0) return
        viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val items = repository.uploads(mid, page + 1)
                page += 1
                _ui.update {
                    it.copy(
                        items = it.items + items.filterNot { video -> it.items.any { e -> e.bvid == video.bvid } },
                        isLoadingMore = false,
                        hasMore = items.size >= 20,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, hasMore = false) }
            }
        }
    }
}
