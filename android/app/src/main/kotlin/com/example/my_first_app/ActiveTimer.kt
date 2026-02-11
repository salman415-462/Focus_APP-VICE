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
    var pausedUntilMillis: Long? = null,
    // Grace window for undo - null means grace period has expired or was already used
    val graceExpiresAt: Long? = null
) {
    companion object {
        const val GRACE_WINDOW_DURATION_MILLIS = 30_000L // 30 seconds
    }

    init {
        require(id.isNotBlank()) { "Timer ID must not be blank" }
        require(durationMinutes > 0) { "Duration must be positive" }
        require(startTimeMillis >= 0) { "Start time must be non-negative" }
        // graceExpiresAt can be null (backward compatibility or grace expired)
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

    /**
     * Returns true if the timer can still be undone within the grace window.
     * Once grace has expired, this returns false permanently.
     */
    fun canUndo(currentTimeMillis: Long): Boolean {
        return graceExpiresAt != null && currentTimeMillis <= graceExpiresAt
    }

    /**
     * Creates a new ActiveTimer with grace window set.
     */
    fun withGraceWindow(): ActiveTimer {
        return copy(graceExpiresAt = startTimeMillis + GRACE_WINDOW_DURATION_MILLIS)
    }
}

