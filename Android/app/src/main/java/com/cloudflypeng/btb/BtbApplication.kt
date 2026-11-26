package com.cloudflypeng.btb

import android.app.Application
import com.cloudflypeng.btb.core.CoreTransport
import com.cloudflypeng.btb.core.EmbeddedCoreTransport
import com.cloudflypeng.btb.data.AccountRepository
import com.cloudflypeng.btb.data.CastRepository
import com.cloudflypeng.btb.data.CommentRepository
import com.cloudflypeng.btb.data.DanmakuRepository
import com.cloudflypeng.btb.data.DiscoverRepository
import com.cloudflypeng.btb.data.DynamicRepository
import com.cloudflypeng.btb.data.FeedRepository
import com.cloudflypeng.btb.data.LibraryRepository
import com.cloudflypeng.btb.data.LiveRepository
import com.cloudflypeng.btb.data.MessageRepository
import com.cloudflypeng.btb.data.PgcRepository
import com.cloudflypeng.btb.data.PlaybackRepository
import com.cloudflypeng.btb.data.SearchHistoryStore
import com.cloudflypeng.btb.data.SearchRepository
import com.cloudflypeng.btb.data.SettingsStore
import com.cloudflypeng.btb.data.SocialRepository
import com.cloudflypeng.btb.playback.CastController

class BtbApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}

class AppContainer(context: Application) {
    val core: CoreTransport = EmbeddedCoreTransport(context)
    val feedRepository = FeedRepository(core)
    val playbackRepository = PlaybackRepository(core)
    val accountRepository = AccountRepository(core)
    val danmakuRepository = DanmakuRepository(core)
    val commentRepository = CommentRepository(core)
    val dynamicRepository = DynamicRepository(core)
    val messageRepository = MessageRepository(core)
    val discoverRepository = DiscoverRepository(core)
    val searchRepository = SearchRepository(core)
    val searchHistory = SearchHistoryStore(context)
    val liveRepository = LiveRepository(core)
    val pgcRepository = PgcRepository(core)
    val libraryRepository = LibraryRepository(core)
    val socialRepository = SocialRepository(core)
    val castRepository = CastRepository(core)
    val castController = CastController(context, castRepository)
    val settings = SettingsStore(context)
}
