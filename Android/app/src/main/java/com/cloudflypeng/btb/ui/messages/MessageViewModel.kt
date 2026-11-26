package com.cloudflypeng.btb.ui.messages

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreStatus
import com.cloudflypeng.btb.data.MessageEntry
import com.cloudflypeng.btb.data.MessageFeedPage
import com.cloudflypeng.btb.data.MessageTab
import com.cloudflypeng.btb.data.MessageUnread
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MessageFeedUiState(
    val items: List<MessageEntry> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val loaded: Boolean = false,
    val error: String? = null,
    val cursorId: Long = 0,
    val cursorTime: Long = 0,
)

data class MessagesUiState(
    val coreStatus: CoreStatus = CoreStatus.Starting,
    val hasAccount: Boolean? = null,
    val selected: MessageTab = MessageTab.Replies,
    val unread: MessageUnread = MessageUnread(),
    val feeds: Map<MessageTab, MessageFeedUiState> = emptyMap(),
) {
    fun feed(tab: MessageTab): MessageFeedUiState = feeds[tab] ?: MessageFeedUiState()

    val currentFeed: MessageFeedUiState
        get() = feed(selected)

    val unreadTotal: Int
        get() = unread.total
}

class MessageViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as BtbApplication).container
    private val core = container.core
    private val repository = container.messageRepository
    private val accountRepository = container.accountRepository

    private val _ui = MutableStateFlow(MessagesUiState())
    val ui = _ui.asStateFlow()

    private val jobs = mutableMapOf<MessageTab, Job>()
    private var bootstrapJob: Job? = null
    private var started = false

    fun start(force: Boolean = false) {
        if (started && !force) return
        started = true
        bootstrap(force)
    }

    fun accountChanged() {
        _ui.update {
            it.copy(
                feeds = emptyMap(),
                unread = MessageUnread(),
            )
        }
        started = true
        bootstrap(force = true)
    }

    fun refresh() {
        if (_ui.value.hasAccount == true && _ui.value.coreStatus == CoreStatus.Ready) {
            refreshUnread()
            load(_ui.value.selected, reset = true)
        } else {
            start(force = true)
        }
    }

    fun retry() {
        if (_ui.value.hasAccount == true && _ui.value.coreStatus == CoreStatus.Ready) {
            refreshUnread()
            load(_ui.value.selected, reset = true)
        } else {
            bootstrap(force = true)
        }
    }

    fun select(tab: MessageTab) {
        if (_ui.value.selected == tab) return
        _ui.update { it.copy(selected = tab) }
        if (_ui.value.hasAccount == true && !_ui.value.feed(tab).loaded) {
            load(tab, reset = true)
        }
    }

    fun loadMore() {
        val tab = _ui.value.selected
        val feed = _ui.value.feed(tab)
        if (feed.isLoading || feed.isLoadingMore || !feed.hasMore || feed.items.isEmpty()) return
        load(tab, reset = false)
    }

    private fun bootstrap(force: Boolean) {
        if (bootstrapJob?.isActive == true) return
        bootstrapJob = viewModelScope.launch {
            _ui.update { it.copy(coreStatus = CoreStatus.Starting) }
            try {
                core.start()
                core.call("core.ping")
                val accounts = accountRepository.accounts()
                val hasAccount = accounts.activeMid > 0 || accounts.accounts.any { it.active == true }
                _ui.update {
                    it.copy(
                        coreStatus = CoreStatus.Ready,
                        hasAccount = hasAccount,
                        feeds = if (force) emptyMap() else it.feeds,
                    )
                }
                if (hasAccount) {
                    refreshUnread()
                    load(_ui.value.selected, reset = true)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                _ui.update {
                    it.copy(coreStatus = CoreStatus.Failed(error.userMessage()))
                }
            }
        }
    }

    private fun refreshUnread() {
        viewModelScope.launch {
            try {
                val unread = repository.unread()
                _ui.update { it.copy(unread = unread) }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                // Unread counts are best-effort.
            }
        }
    }

    private fun load(tab: MessageTab, reset: Boolean) {
        val state = _ui.value
        if (state.hasAccount != true || state.coreStatus != CoreStatus.Ready) return
        val feed = state.feed(tab)
        if (feed.isLoading || feed.isLoadingMore) return
        if (!reset && !feed.hasMore) return

        jobs[tab]?.cancel()
        updateFeed(tab) {
            it.copy(
                isLoading = reset && it.items.isEmpty(),
                isLoadingMore = !reset,
                error = null,
            )
        }
        jobs[tab] = viewModelScope.launch {
            try {
                val page = when (tab) {
                    MessageTab.Replies -> repository.replies(
                        cursorId = if (reset) 0 else feed.cursorId,
                        cursorTime = if (reset) 0 else feed.cursorTime,
                    )

                    MessageTab.Ats -> repository.ats(
                        cursorId = if (reset) 0 else feed.cursorId,
                        cursorTime = if (reset) 0 else feed.cursorTime,
                    )

                    MessageTab.Likes -> repository.likes(
                        cursorId = if (reset) 0 else feed.cursorId,
                        cursorTime = if (reset) 0 else feed.cursorTime,
                    )

                    MessageTab.System -> {
                        val page = repository.system(cursor = if (reset) 0 else feed.cursorId)
                        MessageFeedPage(
                            items = page.items,
                            cursorId = page.nextCursor,
                            cursorTime = 0,
                            hasMore = page.hasMore,
                        )
                    }
                }
                val merged = if (reset) {
                    page.items
                } else {
                    (feed.items + page.items).distinctBy { it.id }
                }
                updateFeed(tab) {
                    it.copy(
                        items = merged,
                        isLoading = false,
                        isLoadingMore = false,
                        hasMore = page.hasMore && page.items.isNotEmpty(),
                        loaded = true,
                        error = null,
                        cursorId = page.cursorId,
                        cursorTime = page.cursorTime,
                    )
                }
                if (reset) refreshUnread()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                updateFeed(tab) {
                    it.copy(
                        isLoading = false,
                        isLoadingMore = false,
                        error = error.userMessage(),
                    )
                }
            }
        }
    }

    private fun updateFeed(tab: MessageTab, transform: (MessageFeedUiState) -> MessageFeedUiState) {
        _ui.update { state ->
            state.copy(feeds = state.feeds + (tab to transform(state.feed(tab))))
        }
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is CoreException -> message?.takeIf { it.isNotBlank() } ?: "消息加载失败"
    else -> message?.takeIf { it.isNotBlank() } ?: "消息加载失败"
}
