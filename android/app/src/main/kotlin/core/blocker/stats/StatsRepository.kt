package core.blocker.stats

import core.blocker.events.CompletionType
import core.blocker.events.EventRepository
import core.blocker.events.TimerEvent

/**
 * Aggregation layer for timer event statistics.
 * 
 * This repository reads events from EventRepository and computes:
 * - Weekly statistics
 * - Monthly statistics with weekly breakdown
 * - Per-app blocked duration with interval merging
 * 
 * All calculations are based on epoch millis for reliable boundary handling.
 * Interval merging ensures no double-counting of overlapping blocked periods.
 * 
 * IMPORTANT: Sessions are aggregated by COMPLETION TIME (endTimeMillis).
 * A timer that starts Sunday 23:00 and completes Monday 01:00 counts for Monday's week.
 * This ensures definite outcome is known before attribution.
 */
class StatsRepository(
    private val eventRepository: EventRepository
) {

    // ==================== Weekly Stats ====================

    /**
     * Get aggregated statistics for a week.
     * 
     * Week range: [weekStartMillis, weekStartMillis + 7 days)
     * 
     * @param weekStartMillis The epoch millis for the start of the week (00:00:00.000)
     * @return WeeklyStats containing all aggregated metrics
     */
    fun getWeeklyStats(weekStartMillis: Long): WeeklyStats {
        val weekEndMillis = weekStartMillis + WeeklyStats.WEEK_DURATION_MILLIS
        
        val events = eventRepository.getEventsInRange(weekStartMillis, weekEndMillis)
        val completedEvents = events.filterIsInstance<TimerEvent.TimerCompleted>()
        
        var totalCompletedSessions = 0
        var totalCancelledSessions = 0
        var totalSystemKillSessions = 0
        var totalFocusMinutes = 0
        var totalBypassUsedSessions = 0
        
        completedEvents.forEach { event ->
            // Count by completion type
            when (event.completionType) {
                CompletionType.NATURAL -> {
                    totalCompletedSessions++
                    // Focus minutes only count NATURAL completions
                    if (isFocusMode(event.mode)) {
                        totalFocusMinutes += event.actualDurationMinutes
                    }
                }
                CompletionType.UNDO -> {
                    totalCancelledSessions++
                }
                CompletionType.SYSTEM_KILL -> {
                    totalSystemKillSessions++
                    // SYSTEM_KILL uses actualDurationMinutes (partial time)
                    if (isFocusMode(event.mode)) {
                        totalFocusMinutes += event.actualDurationMinutes
                    }
                }
            }
            
            // Count bypass usage (independent of completion type)
            if (event.bypassUsed) {
                totalBypassUsedSessions++
            }
        }
        
        val totalSessions = totalCompletedSessions + totalSystemKillSessions
        
        return WeeklyStats(
            weekStartMillis = weekStartMillis,
            weekEndMillis = weekEndMillis,
            totalCompletedSessions = totalCompletedSessions,
            totalCancelledSessions = totalCancelledSessions,
            totalSystemKillSessions = totalSystemKillSessions,
            totalFocusMinutes = totalFocusMinutes,
            totalBypassUsedSessions = totalBypassUsedSessions,
            totalSessions = totalSessions
        )
    }

    // ==================== Monthly Stats ====================

    /**
     * Get aggregated statistics for a month.
     * 
     * Month range: [monthStartMillis, nextMonthStartMillis)
     * Automatically calculates month boundaries from epoch millis.
     * 
     * @param monthStartMillis Any epoch millis within the target month
     * @return MonthlyStats with weekly breakdown
     */
    fun getMonthlyStats(monthStartMillis: Long): MonthlyStats {
        val (monthStart, monthEnd) = MonthlyStats.getMonthBoundaries(monthStartMillis)
        
        // Generate weekly breakdown
        val weeklyStats = generateWeeklyBreakdown(monthStart, monthEnd)
        
        // Aggregate totals from weekly stats
        var totalCompletedSessions = 0
        var totalFocusMinutes = 0
        var totalBypassUsedSessions = 0
        
        weeklyStats.forEach { week ->
            totalCompletedSessions += week.totalCompletedSessions
            totalFocusMinutes += week.totalFocusMinutes
            totalBypassUsedSessions += week.totalBypassUsedSessions
        }
        
        return MonthlyStats(
            monthStartMillis = monthStart,
            monthEndMillis = monthEnd,
            totalCompletedSessions = totalCompletedSessions,
            totalFocusMinutes = totalFocusMinutes,
            totalBypassUsedSessions = totalBypassUsedSessions,
            weeklyBreakdown = weeklyStats
        )
    }

    /**
     * Generate weekly breakdown for a month.
     */
    private fun generateWeeklyBreakdown(monthStart: Long, monthEnd: Long): List<WeeklyStats> {
        val weeks = mutableListOf<WeeklyStats>()
        var currentWeekStart = monthStart
        
        while (currentWeekStart < monthEnd) {
            val weekStats = getWeeklyStats(currentWeekStart)
            weeks.add(weekStats)
            currentWeekStart += WeeklyStats.WEEK_DURATION_MILLIS
        }
        
        return weeks
    }

    // ==================== Per-App Block Stats ====================

    /**
     * Get blocked duration statistics per application.
     * 
     * Uses interval merging to correctly calculate blocked time without
     * double-counting overlapping blocked periods.
     * 
     * Algorithm:
     * 1. Filter TIMER_COMPLETED events within range
     * 2. Only consider events with completionType = NATURAL (UNDO doesn't count as blocked)
     * 3. For each package, collect all [startTimeMillis, endTimeMillis] intervals
     * 4. Merge overlapping intervals per package
     * 5. Sum merged durations and convert to minutes
     * 
     * @param startMillis Start of the range (inclusive)
     * @param endMillis End of the range (exclusive)
     * @return List of AppBlockStat sorted by totalBlockedMinutes descending
     */
    fun getPerAppBlockStats(startMillis: Long, endMillis: Long): List<AppBlockStat> {
        val events = eventRepository.getEventsInRange(startMillis, endMillis)
        val completedEvents = events.filterIsInstance<TimerEvent.TimerCompleted>()
        
        // Build intervals per package
        // Key: packageName, Value: list of [start, end] intervals
        val packageIntervals = mutableMapOf<String, MutableList<BlockedInterval>>()
        
        completedEvents.forEach { event ->
            // Only count NATURAL completions for blocked time
            // UNDO means user cancelled, not actually blocked
            if (event.completionType != CompletionType.NATURAL) {
                return@forEach
            }
            
            // Create interval for each blocked package
            event.blockedPackages.forEach { packageName ->
                val interval = BlockedInterval(
                    startMillis = event.startTimeMillis,
                    endMillis = event.endTimeMillis
                )
                packageIntervals.getOrPut(packageName) { mutableListOf() }.add(interval)
            }
        }
        
        // Merge intervals and calculate total blocked time per package
        return packageIntervals.map { (packageName, intervals) ->
            val mergedDurationMillis = mergeIntervalsAndSum(intervals)
            val totalBlockedMinutes = (mergedDurationMillis / (60 * 1000)).toInt()
            AppBlockStat(
                packageName = packageName,
                totalBlockedMinutes = totalBlockedMinutes
            )
        }.sortedByDescending { it.totalBlockedMinutes }
    }

    // ==================== Interval Merging Algorithm ====================

    /**
     * Merges overlapping intervals and returns total duration.
     * 
     * How merging works:
     * 1. Sort intervals by start time
     * 2. Iterate through sorted intervals
     * 3. If current interval overlaps with previous merged interval, extend the merge
     * 4. Otherwise, add previous merged interval to result and start new merge
     * 5. Sum all merged interval durations
     * 
     * Why double counting is impossible:
     * - Overlapping intervals are merged into a single continuous interval
     * - Each time point belongs to at most one merged interval
     * - The merged set represents the union of all original intervals
     * 
     * Example:
     *   Intervals: [10:00-10:30], [10:15-10:45], [11:00-11:30]
     *   Merged:    [10:00-10:45], [11:00-11:30]
     *   Total:     45 + 30 = 75 minutes (not 30+30+30 = 90)
     * 
     * @param intervals List of time intervals to merge
     * @return Total duration of merged intervals in millis
     */
    private fun mergeIntervalsAndSum(intervals: List<BlockedInterval>): Long {
        if (intervals.isEmpty()) return 0L
        
        // Sort intervals by start time
        val sorted = intervals.sortedBy { it.startMillis }
        
        // Start with first interval
        val merged = mutableListOf<BlockedInterval>()
        var currentStart = sorted.first().startMillis
        var currentEnd = sorted.first().endMillis
        
        // Iterate through remaining intervals
        for (i in 1 until sorted.size) {
            val interval = sorted[i]
            
            if (interval.startMillis <= currentEnd) {
                // Overlapping or contiguous - extend current interval
                currentEnd = maxOf(currentEnd, interval.endMillis)
            } else {
                // Non-overlapping - save current and start new
                merged.add(BlockedInterval(currentStart, currentEnd))
                currentStart = interval.startMillis
                currentEnd = interval.endMillis
            }
        }
        
        // Add the last interval
        merged.add(BlockedInterval(currentStart, currentEnd))
        
        // Sum durations
        return merged.sumOf { it.durationMillis }
    }

    // ==================== Helper Functions ====================

    /**
     * Check if the timer mode counts toward focus time.
     * 
     * Focus modes: FOCUS, POMODORO_FOCUS
     * Non-focus: POMODORO_BREAK (break time doesn't count as focus)
     */
    private fun isFocusMode(mode: String): Boolean {
        return mode == "FOCUS" || mode == "POMODORO_FOCUS"
    }

    // ==================== Utility Functions ====================

    /**
     * Get stats for the current week (starting from Monday 00:00:00.000).
     */
    fun getCurrentWeekStats(): WeeklyStats {
        val calendar = java.util.Calendar.getInstance()
        
        // Set to start of week (Monday)
        calendar.set(java.util.Calendar.DAY_OF_WEEK, java.util.Calendar.MONDAY)
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        
        return getWeeklyStats(calendar.timeInMillis)
    }

    /**
     * Get stats for the current month.
     */
    fun getCurrentMonthStats(): MonthlyStats {
        val calendar = java.util.Calendar.getInstance()
        return getMonthlyStats(calendar.timeInMillis)
    }

    /**
     * Get per-app block stats for the current month.
     */
    fun getCurrentMonthPerAppStats(): List<AppBlockStat> {
        val calendar = java.util.Calendar.getInstance()
        val (monthStart, monthEnd) = MonthlyStats.getMonthBoundaries(calendar.timeInMillis)
        return getPerAppBlockStats(monthStart, monthEnd)
    }
}

