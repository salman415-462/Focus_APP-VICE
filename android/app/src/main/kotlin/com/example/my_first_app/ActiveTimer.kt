package core.blocker.engine

enum class TimerMode {
    FOCUS,
    POMODORO_FOCUS,
    POMODORO_BREAK
}

data class ActiveTimer(
    val id: String,
    val startTimeMillis: Long,
    val durationMinutes: Int,
    val blockedPackages: List<String>,
    val mode: TimerMode = TimerMode.FOCUS,
    var pausedUntilMillis: Long? = null
) {
    init {
        require(id.isNotBlank()) { "Timer ID must not be blank" }
        require(durationMinutes > 0) { "Duration must be positive" }
        require(startTimeMillis >= 0) { "Start time must be non-negative" }
    }

    val endTimeMillis: Long
        get() = startTimeMillis + (durationMinutes * 60 * 1000L)

    val durationMillis: Long
        get() = durationMinutes * 60 * 1000L

    fun getRemainingSeconds(currentTimeMillis: Long): Int {
        val remaining = (endTimeMillis - currentTimeMillis) / 1000
        return remaining.coerceAtLeast(0).toInt()
    }

    fun isExpired(currentTimeMillis: Long): Boolean {
        return currentTimeMillis >= endTimeMillis
    }

    fun isPaused(currentTimeMillis: Long): Boolean {
        return pausedUntilMillis != null && currentTimeMillis < pausedUntilMillis!!
    }

    fun isActive(currentTimeMillis: Long): Boolean {
        if (isPaused(currentTimeMillis)) return false
        return currentTimeMillis in startTimeMillis until endTimeMillis
    }
}

