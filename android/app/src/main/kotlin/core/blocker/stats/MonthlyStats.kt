package core.blocker.stats

/**
 * Aggregated statistics for a monthly period.
 * Contains weekly breakdown for granular analysis.
 */
data class MonthlyStats(
    val monthStartMillis: Long,
    val monthEndMillis: Long,
    val totalCompletedSessions: Int,        // completionType = NATURAL
    val totalFocusMinutes: Int,             // NATURAL + mode in (FOCUS, POMODORO_FOCUS)
    val totalBypassUsedSessions: Int,       // bypassUsed = true
    val weeklyBreakdown: List<WeeklyStats> // Stats for each week in the month
) {
    companion object {
        /**
         * Calculate month boundaries from epoch millis.
         * Uses calendar to find first millisecond of the month.
         */
        fun getMonthBoundaries(monthStartMillis: Long): Pair<Long, Long> {
            val calendar = java.util.Calendar.getInstance()
            calendar.timeInMillis = monthStartMillis
            
            // Set to first day of month at 00:00:00.000
            calendar.set(java.util.Calendar.DAY_OF_MONTH, 1)
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val start = calendar.timeInMillis
            
            // Move to first day of next month
            calendar.add(java.util.Calendar.MONTH, 1)
            val end = calendar.timeInMillis
            
            return Pair(start, end)
        }
    }
}

