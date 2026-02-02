package core.blocker.scheduler

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

class Scheduler(private val context: Context) {
    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun scheduleNextEvaluation(targetTimeMillis: Long) {
        if (targetTimeMillis <= System.currentTimeMillis()) {
            return
        }
        val intent = createIntent()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                targetTimeMillis,
                pendingIntent
            )
        } else {
            // setExact is available on API 19+ and is appropriate fallback for older devices
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                targetTimeMillis,
                pendingIntent
            )
        }
    }

    fun cancelScheduledEvaluation() {
        val intent = createIntent()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun createIntent(): Intent {
        return Intent(context, BlockEvaluationReceiver::class.java).apply {
            action = ACTION_EVALUATE
        }
    }

    companion object {
        const val ACTION_EVALUATE = "core.blocker.scheduler.ACTION_EVALUATE"
        const val REQUEST_CODE = 1001
    }
}

