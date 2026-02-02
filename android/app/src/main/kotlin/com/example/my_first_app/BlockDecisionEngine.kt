package core.blocker.engine

object BlockDecisionEngine {

    fun evaluate(
        resourceId: String,
        currentTimeMillis: Long,
        activeBlockRules: List<BlockRule>,
        activeBypasses: List<BypassRule>
    ): DecisionResult {
        val sortedRules = activeBlockRules.sorted()
        val activeBypass = findActiveBypass(resourceId, currentTimeMillis, activeBypasses)
        val blockingRule = findBlockingRule(resourceId, currentTimeMillis, sortedRules)

        return when {
            activeBypass != null && blockingRule != null -> {
                DecisionResult(
                    decision = Decision.ALLOW,
                    reason = Reason.Bypass(activeBypass.id, blockingRule.id),
                    nextEvaluationTimeMillis = activeBypass.expiresAtMillis
                )
            }
            activeBypass != null -> {
                DecisionResult(
                    decision = Decision.ALLOW,
                    reason = Reason.Bypass(activeBypass.id, null),
                    nextEvaluationTimeMillis = activeBypass.expiresAtMillis
                )
            }
            blockingRule != null -> {
                val nextEval = calculateNextEvaluationTime(resourceId, currentTimeMillis, sortedRules)
                DecisionResult(
                    decision = Decision.BLOCK,
                    reason = Reason.Block(blockingRule.id),
                    nextEvaluationTimeMillis = nextEval
                )
            }
            else -> {
                DecisionResult(
                    decision = Decision.ALLOW,
                    reason = Reason.None,
                    nextEvaluationTimeMillis = null
                )
            }
        }
    }

    private fun findActiveBypass(
        resourceId: String,
        currentTimeMillis: Long,
        bypasses: List<BypassRule>
    ): BypassRule? {
        return bypasses.find { it.resourceId == resourceId && it.isActive(currentTimeMillis) }
    }

    private fun findBlockingRule(
        resourceId: String,
        currentTimeMillis: Long,
        rules: List<BlockRule>
    ): BlockRule? {
        return rules.find { it.isBlocked(resourceId, currentTimeMillis) }
    }

    private fun calculateNextEvaluationTime(
        resourceId: String,
        currentTimeMillis: Long,
        rules: List<BlockRule>
    ): Long? {
        val dayMillis = 24L * 60 * 60 * 1000
        var nextTime: Long? = null

        for (rule in rules) {
            if (resourceId !in rule.targetApps) continue

            val ruleNextTime = when (val type = rule.type) {
                is BlockRuleType.OneTime -> {
                    if (currentTimeMillis < type.startTimeMillis) {
                        type.startTimeMillis
                    } else if (currentTimeMillis < type.endTimeMillis) {
                        type.endTimeMillis
                    } else {
                        null
                    }
                }
                is BlockRuleType.Daily -> {
                    calculateNextDailyEvaluation(type, currentTimeMillis)
                }
                is BlockRuleType.Weekday -> {
                    calculateNextWeekdayEvaluation(type, currentTimeMillis)
                }
            }

            if (ruleNextTime != null) {
                nextTime = if (nextTime == null) ruleNextTime else minOf(nextTime, ruleNextTime)
            }
        }

        return nextTime
    }

    private fun calculateNextDailyEvaluation(type: BlockRuleType.Daily, currentTimeMillis: Long): Long {
        val dayMillis = 24L * 60 * 60 * 1000
        val startMillis = ((type.startHour * 60 + type.startMinute) * 60 * 1000L) + type.timezoneOffsetMillis
        val endMillis = ((type.endHour * 60 + type.endMinute) * 60 * 1000L) + type.timezoneOffsetMillis
        val normalizedTime = ((currentTimeMillis - type.timezoneOffsetMillis) % dayMillis + dayMillis) % dayMillis

        val nextBoundary = when {
            normalizedTime < startMillis -> startMillis
            normalizedTime < endMillis -> endMillis
            else -> startMillis + dayMillis
        }

        return currentTimeMillis + (nextBoundary - normalizedTime)
    }

    private fun calculateNextWeekdayEvaluation(type: BlockRuleType.Weekday, currentTimeMillis: Long): Long {
        val dayMillis = 24L * 60 * 60 * 1000
        val startMillis = ((type.startHour * 60 + type.startMinute) * 60 * 1000L) + type.timezoneOffsetMillis
        val endMillis = ((type.endHour * 60 + type.endMinute) * 60 * 1000L) + type.timezoneOffsetMillis
        val normalizedTime = ((currentTimeMillis - type.timezoneOffsetMillis) % dayMillis + dayMillis) % dayMillis
        val currentWeekday = ((currentTimeMillis / dayMillis) % 7).toInt()

        for (offset in 0..7) {
            val checkWeekday = (currentWeekday + offset) % 7
            val weekdayBit = 1 shl checkWeekday

            if (type.weekdayMask and weekdayBit != 0) {
                val baseDayStart = currentTimeMillis - (normalizedTime - type.timezoneOffsetMillis) + (offset * dayMillis)
                val dayStartWithOffset = baseDayStart + type.timezoneOffsetMillis

                val checkStart = dayStartWithOffset + startMillis
                val checkEnd = dayStartWithOffset + endMillis

                if (offset == 0) {
                    if (normalizedTime < startMillis) {
                        return checkStart
                    } else if (normalizedTime < endMillis) {
                        return checkEnd
                    }
                } else {
                    return checkStart
                }
            }
        }

        return currentTimeMillis + (7 * dayMillis)
    }
}

enum class Decision {
    BLOCK,
    ALLOW
}

sealed class Reason {
    data class Block(val ruleId: String) : Reason()
    data class Bypass(val bypassId: String, val blockedByRuleId: String?) : Reason()
    object None : Reason()
}

data class DecisionResult(
    val decision: Decision,
    val reason: Reason,
    val nextEvaluationTimeMillis: Long?
) {
    init {
        require(!(decision == Decision.BLOCK && reason !is Reason.Block)) { "BLOCK decision requires Reason.Block" }
        require(!(decision == Decision.BLOCK && nextEvaluationTimeMillis == null)) { "BLOCK decision requires next evaluation time" }
        require(!(decision == Decision.ALLOW && reason is Reason.Block)) { "ALLOW decision must not have Reason.Block" }
    }
}

