package core.blocker.enforcement

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log

class BlockMonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var checkRunnable: Runnable? = null
    private val checkIntervalMs = 30_000L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(1001, buildNotification("Block monitor running"))
        startChecks()
        Log.d("BlockMonitorSvc", "created and started foreground")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        stopChecks()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun startChecks() {
        checkRunnable?.let { handler.removeCallbacks(it) }
        checkRunnable = Runnable {
            val connected = BlockAccessibilityService.isServiceConnected(applicationContext)
            Log.d("BlockMonitorSvc", "health check - accessibility connected: $connected")
            if (!connected) {
                notifyAccessibilityDisabled()
            }
            handler.postDelayed(checkRunnable!!, checkIntervalMs)
        }
        handler.postDelayed(checkRunnable!!, checkIntervalMs)
    }

    private fun stopChecks() {
        checkRunnable?.let { handler.removeCallbacks(it) }
        checkRunnable = null
    }

    private fun notifyAccessibilityDisabled() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notif = buildNotification("Accessibility service disabled — tap to re-enable", pending)
        nm.notify(1002, notif)
        Log.w("BlockMonitorSvc", "Accessibility disabled; notified user")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel("block_monitor", "Block Monitor", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String, pending: PendingIntent? = null): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "block_monitor")
                .setContentTitle("Block Monitor")
                .setContentText(content)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pending)
                .setOngoing(true)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("Block Monitor")
                .setContentText(content)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pending)
                .setOngoing(true)
                .build()
        }
    }
}
