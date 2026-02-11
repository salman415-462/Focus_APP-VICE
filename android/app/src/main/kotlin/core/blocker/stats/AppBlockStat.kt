package core.blocker.stats

/**
 * Per-application blocked duration statistics.
 * Blocked time is calculated by merging overlapping intervals.
 * 
 * @param packageName The app's package name
 * @param totalBlockedMinutes Total minutes the app was blocked (merged intervals)
 */
data class AppBlockStat(
    val packageName: String,
    val totalBlockedMinutes: Int
)

/**
 * Represents a time interval for blocked period merging.
 */
private data class BlockedInterval(
    val startMillis: Long,
    val endMillis: Long
) {
    val durationMillis: Long
        get() = endMillis - startMillis
}

