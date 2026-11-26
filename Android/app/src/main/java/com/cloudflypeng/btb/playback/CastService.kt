package com.cloudflypeng.btb.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.MainActivity
import com.cloudflypeng.btb.R

/**
 * Keeps the process alive while the TV pulls its HLS stream from the embedded
 * core. Without it, closing the UI lets Android reclaim the process and the
 * cast dies with it.
 */
class CastService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "投屏", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "投屏到电视时保持连接"
                    setShowBadge(false)
                },
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                (application as? BtbApplication)?.container?.castController?.stop()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val device = intent?.getStringExtra(EXTRA_DEVICE).orEmpty()
                val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
                startForeground(NOTIFICATION_ID, buildNotification(device, title))
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(device: String, title: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, CastService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_cast_notification)
            .setContentTitle(if (device.isBlank()) "正在投屏" else "正在投屏到 $device")
            .setContentText(title.ifBlank { "电视正在播放" })
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, "停止投屏", stop)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "btb_cast"
        private const val NOTIFICATION_ID = 41
        private const val ACTION_STOP = "com.cloudflypeng.btb.cast.STOP"
        private const val EXTRA_DEVICE = "device"
        private const val EXTRA_TITLE = "title"

        fun start(context: Context, device: String, title: String) {
            val intent = Intent(context, CastService::class.java)
                .putExtra(EXTRA_DEVICE, device)
                .putExtra(EXTRA_TITLE, title)
            runCatching { ContextCompat.startForegroundService(context, intent) }
        }

        fun stop(context: Context) {
            runCatching { context.stopService(Intent(context, CastService::class.java)) }
        }
    }
}
