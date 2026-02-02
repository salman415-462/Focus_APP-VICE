package core.blocker.scheduler

import core.blocker.engine.BlockDecisionEngine
import core.blocker.engine.BlockRule
import core.blocker.engine.BypassRule

object TimeEngine {

    fun calculateNextEvaluation(
        rules: List<BlockRule>,
        bypasses: List<BypassRule>,
        currentTimeMillis: Long
    ): Long? {
        val decision = BlockDecisionEngine.evaluate(
            resourceId = "",
            currentTimeMillis = currentTimeMillis,
            activeBlockRules = rules,
            activeBypasses = bypasses
        )
        return decision.nextEvaluationTimeMillis
    }
}

