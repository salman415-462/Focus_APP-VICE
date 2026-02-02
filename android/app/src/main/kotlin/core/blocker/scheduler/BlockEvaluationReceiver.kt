package core.blocker.scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import core.blocker.persistence.BlockRepository
import core.blocker.persistence.LocalBlockStore

class BlockEvaluationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
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
    }
}

