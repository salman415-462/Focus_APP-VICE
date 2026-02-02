package core.blocker.scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import core.blocker.persistence.BlockRepository
import core.blocker.persistence.LocalBlockStore

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val store = LocalBlockStore(context)
        val repository = BlockRepository(store)
        val scheduler = Scheduler(context)
        val currentTimeMillis = System.currentTimeMillis()
        val rules = repository.getAllBlockRules()
        val bypasses = repository.getAllBypasses()
        val nextEvalTime = TimeEngine.calculateNextEvaluation(rules, bypasses, currentTimeMillis)
        if (nextEvalTime != null) {
            scheduler.scheduleNextEvaluation(nextEvalTime)
        }

        // Start monitor service to keep process healthy and notify user if accessibility dies
        try {
            val intent = Intent(context, core.blocker.enforcement.BlockMonitorService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            android.util.Log.d("BootReceiver", "Requested start of BlockMonitorService on boot")
        } catch (e: Exception) {
            android.util.Log.w("BootReceiver", "Failed to start BlockMonitorService on boot", e)
        }
    }
}

