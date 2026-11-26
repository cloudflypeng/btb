package com.cloudflypeng.btb.ui.discover

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.SearchAllResult
import com.cloudflypeng.btb.data.SearchChunk
import com.cloudflypeng.btb.data.SearchFilters
import com.cloudflypeng.btb.data.SearchHotWord
import com.cloudflypeng.btb.data.SearchSuggestItem
import com.cloudflypeng.btb.data.SearchTab
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class SearchUiState(
    val attempted: Boolean = false,
    val keyword: String = "",
    val tab: SearchTab = SearchTab.All,
    val filters: SearchFilters = SearchFilters(),
    val all: SearchAllResult? = null,
    val chunk: SearchChunk? = null,
    val page: Int = 1,
    val hasMore: Boolean = false,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
    val total: Int = 0,
    val hotWords: List<SearchHotWord> = emptyList(),
    val history: List<String> = emptyList(),
    val suggestions: List<SearchSuggestItem> = emptyList(),
    val isSuggesting: Boolean = false,
)

class SearchViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.searchRepository
    private val historyStore = container.searchHistory

    private val _ui = MutableStateFlow(SearchUiState(history = historyStore.load()))
    val ui = _ui.asStateFlow()

    private var searchJob: Job? = null
    private var moreJob: Job? = null
    private var suggestJob: Job? = null
    private val coreMutex = Mutex()

    fun loadDiscoveryData() {
        if (_ui.value.hotWords.isNotEmpty()) return
        viewModelScope.launch {
            ensureCore()
            val hot = runCatching { repository.hotWords() }.getOrDefault(emptyList())
            _ui.update { it.copy(hotWords = hot, history = historyStore.load()) }
        }
    }

    fun suggest(term: String) {
        val value = term.trim()
        if (value.isEmpty() || value == _ui.value.keyword) {
            suggestJob?.cancel()
            _ui.update { it.copy(suggestions = emptyList(), isSuggesting = false) }
            return
        }
        suggestJob?.cancel()
        suggestJob = viewModelScope.launch {
            _ui.update { it.copy(isSuggesting = true) }
            val items = runCatching { repository.suggest(value) }.getOrDefault(emptyList())
            if (_ui.value.keyword == value) {
                _ui.update { it.copy(isSuggesting = false) }
                return@launch
            }
            _ui.update { it.copy(suggestions = items, isSuggesting = false) }
        }
    }

    fun submit(keyword: String) {
        val value = keyword.trim()
        if (value.isEmpty()) return
        val history = historyStore.remember(value)
        _ui.update {
            it.copy(
                attempted = true,
                keyword = value,
                suggestions = emptyList(),
                history = history,
            )
        }
        loadFirstPage()
    }

    fun selectTab(tab: SearchTab) {
        val state = _ui.value
        if (state.tab == tab && (state.all != null || state.chunk != null || state.isLoading)) return
        _ui.update { it.copy(tab = tab) }
        if (state.attempted) loadFirstPage()
    }

    fun updateFilters(filters: SearchFilters) {
        if (_ui.value.filters == filters) return
        _ui.update { it.copy(filters = filters) }
        if (_ui.value.attempted && _ui.value.tab == SearchTab.Video) loadFirstPage()
    }

    fun retry() {
        if (_ui.value.attempted) loadFirstPage()
    }

    fun loadMore() {
        val state = _ui.value
        if (!state.attempted ||
            state.tab == SearchTab.All ||
            state.isLoading ||
            state.isLoadingMore ||
            !state.hasMore
        ) {
            return
        }
        val tab = state.tab
        val keyword = state.keyword
        val nextPage = state.page + 1
        moreJob = viewModelScope.launch {
            _ui.update { it.copy(isLoadingMore = true) }
            try {
                val chunk = repository.page(
                    keyword = keyword,
                    tab = tab,
                    page = nextPage,
                    pageSize = PAGE_SIZE,
                    filters = state.filters,
                )
                val current = _ui.value
                if (current.keyword != keyword || current.tab != tab) return@launch
                val merged = mergeChunk(current.chunk, chunk)
                _ui.update {
                    it.copy(
                        chunk = merged,
                        page = nextPage,
                        hasMore = chunk.hasMore(nextPage, PAGE_SIZE),
                        isLoadingMore = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update { it.copy(isLoadingMore = false, error = error.userMessage("搜索失败")) }
            }
        }
    }

    fun clearHistory() {
        historyStore.clear()
        _ui.update { it.copy(history = emptyList()) }
    }

    fun reset() {
        searchJob?.cancel()
        moreJob?.cancel()
        _ui.update {
            it.copy(
                attempted = false,
                keyword = "",
                all = null,
                chunk = null,
                page = 1,
                hasMore = false,
                isLoading = false,
                isLoadingMore = false,
                error = null,
                total = 0,
                suggestions = emptyList(),
            )
        }
    }

    private fun loadFirstPage() {
        val state = _ui.value
        val keyword = state.keyword
        if (keyword.isEmpty()) return
        val tab = state.tab
        val filters = state.filters
        searchJob?.cancel()
        moreJob?.cancel()
        searchJob = viewModelScope.launch {
            ensureCore()
            _ui.update {
                it.copy(
                    isLoading = true,
                    isLoadingMore = false,
                    error = null,
                    all = null,
                    chunk = null,
                    page = 1,
                    hasMore = false,
                    total = 0,
                )
            }
            try {
                if (tab == SearchTab.All) {
                    val result = repository.all(keyword)
                    val current = _ui.value
                    if (current.keyword != keyword || current.tab != tab) return@launch
                    _ui.update {
                        it.copy(all = result, isLoading = false, total = result.total)
                    }
                } else {
                    val chunk = repository.page(keyword, tab, 1, PAGE_SIZE, filters)
                    val current = _ui.value
                    if (current.keyword != keyword || current.tab != tab) return@launch
                    _ui.update {
                        it.copy(
                            chunk = chunk,
                            isLoading = false,
                            total = chunk.total,
                            page = 1,
                            hasMore = chunk.hasMore(1, PAGE_SIZE),
                        )
                    }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                val current = _ui.value
                if (current.keyword != keyword || current.tab != tab) return@launch
                _ui.update { it.copy(isLoading = false, error = error.userMessage("搜索失败")) }
            }
        }
    }

    private suspend fun ensureCore() {
        coreMutex.withLock { runCatching { core.start() } }
    }

    private fun mergeChunk(existing: SearchChunk?, incoming: SearchChunk): SearchChunk {
        if (existing == null) return incoming
        val seenVideo = existing.videos.mapTo(HashSet()) { it.bvid }
        val seenUser = existing.users.mapTo(HashSet()) { it.mid }
        val seenMedia = existing.media.mapTo(HashSet()) { it.resolvedSeasonId }
        val seenLive = existing.liveRooms.mapTo(HashSet()) { it.roomId }
        val seenArticle = existing.articles.mapTo(HashSet()) { it.id }
        return SearchChunk(
            videos = existing.videos + incoming.videos.filter { seenVideo.add(it.bvid) },
            users = existing.users + incoming.users.filter { seenUser.add(it.mid) },
            media = existing.media + incoming.media.filter { seenMedia.add(it.resolvedSeasonId) },
            liveRooms = existing.liveRooms + incoming.liveRooms.filter { seenLive.add(it.roomId) },
            articles = existing.articles + incoming.articles.filter { seenArticle.add(it.id) },
            total = incoming.total,
            numPages = incoming.numPages,
        )
    }

    private companion object {
        const val PAGE_SIZE = 20
    }
}
