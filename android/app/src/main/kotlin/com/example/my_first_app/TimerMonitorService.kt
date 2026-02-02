package com.example.my_first_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import core.blocker.persistence.BlockRepository
import core.blocker.persistence.LocalBlockStore
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class TimerMonitorService : Service() {

    private lateinit var repository: BlockRepository
    private lateinit var executor: ScheduledExecutorService
    private lateinit var handler: Handler
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        repository = BlockRepository(LocalBlockStore(applicationContext))
        executor = Executors.newSingleThreadScheduledExecutor()
        handler = Handler(Looper.getMainLooper())

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startTimerMonitoring()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        executor.shutdown()
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow()
            }
        } catch (e: InterruptedException) {
            executor.shutdownNow()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startTimerMonitoring() {
        executor.scheduleWithFixedDelay({
            try {
                monitorTimers()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, 0, 30, TimeUnit.SECONDS)
    }

    private fun monitorTimers() {
        val currentTimeMillis = System.currentTimeMillis()

        repository.clearExpiredBypasses(currentTimeMillis)
        repository.clearExpiredTimers()

        val activeTimers = repository.getActiveTimers()
        val expiredTimers = activeTimers.filter { !it.isActive(currentTimeMillis) }

        if (expiredTimers.isNotEmpty()) {
            updateNotification(activeTimers.size - expiredTimers.size)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Timer Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors active timers in the background"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): android.app.Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Guard Active")
            .setContentText("Monitoring timers in the background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(activeTimerCount: Int) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Guard Active")
            .setContentText("Active timers: $activeTimerCount")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val CHANNEL_ID = "timer_monitor_channel"
        private const val NOTIFICATION_ID = 1001
    }
}
