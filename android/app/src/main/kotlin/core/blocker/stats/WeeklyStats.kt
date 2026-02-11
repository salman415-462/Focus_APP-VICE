package core.blocker.stats

/**
 * Aggregated statistics for a weekly period.
 * All times are in epoch millis for reliable boundary handling.
 */
data class WeeklyStats(
    val weekStartMillis: Long,
    val weekEndMillis: Long,
    val totalCompletedSessions: Int,          // completionType = NATURAL
    val totalCancelledSessions: Int,           // completionType = UNDO
    val totalSystemKillSessions: Int,          // completionType = SYSTEM_KILL
    val totalFocusMinutes: Int,                // NATURAL + mode in (FOCUS, POMODORO_FOCUS)
    val totalBypassUsedSessions: Int,          // bypassUsed = true (regardless of completionType)
    val totalSessions: Int                    // All completions (NATURAL + SYSTEM_KILL)
) {
    companion object {
        const val WEEK_DURATION_MILLIS = 7L * 24 * 60 * 60 * 1000 // 7 days
    }
}

