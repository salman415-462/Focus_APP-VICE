package core.blocker.events

/**
 * Represents a historical event in the focus blocking system.
 * Only two event types are tracked: TIMER_STARTED and TIMER_COMPLETED.
 * All other data (aggregations, summaries) is computed dynamically.
 */
sealed class TimerEvent {
    abstract val timestampMillis: Long
    abstract val timerId: String

    /**
     * Event recorded when a timer begins.
     */
    data class TimerStarted(
        override val timerId: String,
        override val timestampMillis: Long,
        val startTimeMillis: Long,
        val durationMinutes: Int,
        val mode: String,
        val blockedPackages: List<String>
    ) : TimerEvent()

    /**
     * Event recorded when a timer ends (naturally, via undo, bypass, or system kill).
     */
    data class TimerCompleted(
        override val timerId: String,
        override val timestampMillis: Long,
        val startTimeMillis: Long,
        val endTimeMillis: Long,
        val actualDurationMinutes: Int,
        val mode: String,
        val blockedPackages: List<String>,
        val completionType: CompletionType
    ) : TimerEvent()
}

/**
 * How a timer reached completion state.
 */
enum class CompletionType {
    /**
     * Timer ran to its natural end time without interruption.
     */
    NATURAL,

    /**
     * User cancelled via undo within grace window.
     */
    UNDO,

    /**
     * Emergency bypass was used, interrupting the timer.
     */
    BYPASS,

    /**
     * App was killed or system interrupted before natural completion.
     */
    SYSTEM_KILL
}

