package core.blocker.engine

data class BlockRule(
    val id: String,
    val targetApps: Set<String>,
    val type: BlockRuleType,
    val priority: Int = 0
) : Comparable<BlockRule> {

    init {
        require(id.isNotBlank()) { "Rule ID must not be blank" }
        require(targetApps.isNotEmpty()) { "Target apps set must not be empty" }
        require(priority >= 0) { "Priority must be non-negative" }
    }

    fun isBlocked(resourceId: String, currentTimeMillis: Long): Boolean {
        if (resourceId !in targetApps) return false
        return type.evaluate(currentTimeMillis)
    }

    override fun compareTo(other: BlockRule): Int {
        val priorityDiff = other.priority - this.priority
        if (priorityDiff != 0) return priorityDiff
        return this.id.compareTo(other.id)
    }
}

sealed class BlockRuleType {
    abstract fun evaluate(currentTimeMillis: Long): Boolean

    data class OneTime(
        val startTimeMillis: Long,
        val endTimeMillis: Long
    ) : BlockRuleType() {
        init {
            require(startTimeMillis < endTimeMillis) { "Start time must be before end time" }
        }

        override fun evaluate(currentTimeMillis: Long): Boolean {
            return currentTimeMillis in startTimeMillis until endTimeMillis
        }
    }

    data class Daily(
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val timezoneOffsetMillis: Long = 0L
    ) : BlockRuleType() {
        init {
            require(startHour in 0..23) { "Start hour must be 0-23" }
            require(endHour in 0..23) { "End hour must be 0-23" }
            require(startMinute in 0..59) { "Start minute must be 0-59" }
            require(endMinute in 0..59) { "End minute must be 0-59" }
        }

        private fun timeToMillis(hour: Int, minute: Int): Long {
            return ((hour * 60 + minute) * 60 * 1000L) + timezoneOffsetMillis
        }

        override fun evaluate(currentTimeMillis: Long): Boolean {
            val dayMillis = 24L * 60 * 60 * 1000
            val normalizedTime = ((currentTimeMillis - timezoneOffsetMillis) % dayMillis + dayMillis) % dayMillis
            val startMillis = timeToMillis(startHour, startMinute)
            val endMillis = timeToMillis(endHour, endMinute)
            return if (startMillis <= endMillis) {
                normalizedTime in startMillis until endMillis
            } else {
                normalizedTime >= startMillis || normalizedTime < endMillis
            }
        }
    }

    data class Weekday(
        val weekdayMask: Int,
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val timezoneOffsetMillis: Long = 0L
    ) : BlockRuleType() {
        init {
            require(weekdayMask in 1..127) { "Weekday mask must be 1-127 (bits 0-6 for Sun-Sat)" }
            require(startHour in 0..23) { "Start hour must be 0-23" }
            require(endHour in 0..23) { "End hour must be 0-23" }
            require(startMinute in 0..59) { "Start minute must be 0-59" }
            require(endMinute in 0..59) { "End minute must be 0-59" }
        }

        private fun timeToMillis(hour: Int, minute: Int): Long {
            return ((hour * 60 + minute) * 60 * 1000L) + timezoneOffsetMillis
        }

        override fun evaluate(currentTimeMillis: Long): Boolean {
            val dayMillis = 24L * 60 * 60 * 1000
            val weekdayIndex = ((currentTimeMillis / dayMillis) % 7).toInt()
            val weekdayBit = 1 shl weekdayIndex
            if (weekdayMask and weekdayBit == 0) return false
            val normalizedTime = ((currentTimeMillis - timezoneOffsetMillis) % dayMillis + dayMillis) % dayMillis
            val startMillis = timeToMillis(startHour, startMinute)
            val endMillis = timeToMillis(endHour, endMinute)
            return if (startMillis <= endMillis) {
                normalizedTime in startMillis until endMillis
            } else {
                normalizedTime >= startMillis || normalizedTime < endMillis
            }
        }
    }
}

