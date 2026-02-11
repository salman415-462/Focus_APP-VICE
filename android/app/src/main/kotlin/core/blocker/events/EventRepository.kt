package core.blocker.events

import android.content.Context
import core.blocker.events.CompletionType
import core.blocker.events.TimerEvent
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Repository for persisting timer events (TIMER_STARTED, TIMER_COMPLETED).
 * 
 * Events are stored in block_events.json (separate from block_store.json).
 * Append-only pattern for performance.
 * 
 * This repository is independent from enforcement logic.
 * It only records facts that happened; aggregations are computed elsewhere.
 */
class EventRepository(private val context: Context) {

    private val lock = ReentrantLock()
    private val eventsFile: File
        get() = File(context.filesDir, EVENTS_FILE)

    /**
     * Record a TIMER_STARTED event.
     * Called immediately after successfully saving an active timer.
     */
    fun recordTimerStarted(
        timerId: String,
        startTimeMillis: Long,
        durationMinutes: Int,
        mode: String,
        blockedPackages: List<String>
    ) {
        val event = TimerEvent.TimerStarted(
            timerId = timerId,
            timestampMillis = startTimeMillis,
            startTimeMillis = startTimeMillis,
            durationMinutes = durationMinutes,
            mode = mode,
            blockedPackages = blockedPackages
        )
        appendEvent(event)
    }

    /**
     * Record a TIMER_COMPLETED event.
     * Called during expiration cleanup to ensure no missed completions.
     * 
     * Idempotency: If a TIMER_COMPLETED event already exists for this timerId,
     * this method returns early without recording a duplicate.
     * 
     * @param bypassUsed Whether an emergency bypass was used during this timer session
     */
    fun recordTimerCompleted(
        timerId: String,
        startTimeMillis: Long,
        endTimeMillis: Long,
        actualDurationMinutes: Int,
        mode: String,
        blockedPackages: List<String>,
        completionType: CompletionType,
        bypassUsed: Boolean
    ) {
        // Idempotency guard: check if completion event already exists
        if (hasTimerCompletedEvent(timerId)) {
            return
        }

        val event = TimerEvent.TimerCompleted(
            timerId = timerId,
            timestampMillis = endTimeMillis,
            startTimeMillis = startTimeMillis,
            endTimeMillis = endTimeMillis,
            actualDurationMinutes = actualDurationMinutes,
            mode = mode,
            blockedPackages = blockedPackages,
            completionType = completionType,
            bypassUsed = bypassUsed
        )
        appendEvent(event)
    }

    /**
     * Check if a TIMER_COMPLETED event already exists for the given timerId.
     * Used for idempotency checks to prevent duplicate events.
     * 
     * @param timerId The timer ID to check
     * @return true if a completion event already exists, false otherwise
     */
    fun hasTimerCompletedEvent(timerId: String): Boolean {
        return lock.withLock {
            if (!eventsFile.exists()) return@withLock false

            try {
                val json = JSONObject(eventsFile.readText())
                val eventsArray = json.getJSONArray("events")

                for (i in 0 until eventsArray.length()) {
                    val eventObj = eventsArray.getJSONObject(i)
                    val type = eventObj.optString("type", "")
                    
                    // Only check TIMER_COMPLETED events
                    if (type == "TIMER_COMPLETED") {
                        val existingTimerId = eventObj.optString("timerId", "")
                        if (existingTimerId == timerId) {
                            return@withLock true
                        }
                    }
                }

                false
            } catch (e: Exception) {
                false
            }
        }
    }

    /**
     * Get all events within a time range.
     * Used by aggregation layer for stats computation.
     */
    fun getEventsInRange(startMillis: Long, endMillis: Long): List<TimerEvent> {
        return lock.withLock {
            if (!eventsFile.exists()) return@withLock emptyList()

            try {
                val json = JSONObject(eventsFile.readText())
                val eventsArray = json.getJSONArray("events")
                val result = mutableListOf<TimerEvent>()

                for (i in 0 until eventsArray.length()) {
                    val eventObj = eventsArray.getJSONObject(i)
                    val timestamp = eventObj.getLong("timestampMillis")

                    if (timestamp in startMillis..endMillis) {
                        result.add(parseEvent(eventObj))
                    }
                }

                result
            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    /**
     * Get all events (for cleanup or full rebuild if needed).
     */
    fun getAllEvents(): List<TimerEvent> {
        return lock.withLock {
            if (!eventsFile.exists()) return@withLock emptyList()

            try {
                val json = JSONObject(eventsFile.readText())
                val eventsArray = json.getJSONArray("events")
                val result = mutableListOf<TimerEvent>()

                for (i in 0 until eventsArray.length()) {
                    result.add(parseEvent(eventsArray.getJSONObject(i)))
                }

                result
            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    /**
     * Prune events older than the specified timestamp.
     * Called periodically to prevent unlimited growth.
     * 
     * @return Number of events removed
     */
    fun pruneEventsOlderThan(thresholdMillis: Long): Int {
        return lock.withLock {
            if (!eventsFile.exists()) return@withLock 0

            try {
                val json = JSONObject(eventsFile.readText())
                val eventsArray = json.getJSONArray("events")
                val keptEvents = JSONArray()

                for (i in 0 until eventsArray.length()) {
                    val eventObj = eventsArray.getJSONObject(i)
                    val timestamp = eventObj.getLong("timestampMillis")

                    if (timestamp >= thresholdMillis) {
                        keptEvents.put(eventObj)
                    }
                }

                val removedCount = eventsArray.length() - keptEvents.length()
                
                if (removedCount > 0) {
                    val newJson = JSONObject()
                    newJson.put("events", keptEvents)
                    newJson.put("lastCleanupTimestampMillis", System.currentTimeMillis())
                    eventsFile.writeText(newJson.toString())
                }

                removedCount
            } catch (e: Exception) {
                0
            }
        }
    }

    /**
     * Get count of events (for diagnostics).
     */
    fun getEventCount(): Int {
        return lock.withLock {
            if (!eventsFile.exists()) return@withLock 0

            try {
                val json = JSONObject(eventsFile.readText())
                json.getJSONArray("events").length()
            } catch (e: Exception) {
                0
            }
        }
    }

    private fun appendEvent(event: TimerEvent) {
        lock.withLock {
            val json: JSONObject = if (eventsFile.exists()) {
                try {
                    JSONObject(eventsFile.readText())
                } catch (e: Exception) {
                    JSONObject().apply {
                        put("events", JSONArray())
                    }
                }
            } else {
                JSONObject().apply {
                    put("events", JSONArray())
                }
            }

            val eventsArray = json.getJSONArray("events")
            eventsArray.put(serializeEvent(event))

            eventsFile.writeText(json.toString())
        }
    }

    private fun serializeEvent(event: TimerEvent): JSONObject {
        return when (event) {
            is TimerEvent.TimerStarted -> {
                JSONObject().apply {
                    put("type", "TIMER_STARTED")
                    put("timestampMillis", event.timestampMillis)
                    put("timerId", event.timerId)
                    put("startTimeMillis", event.startTimeMillis)
                    put("durationMinutes", event.durationMinutes)
                    put("mode", event.mode)
                    put("blockedPackages", JSONArray(event.blockedPackages))
                }
            }
            is TimerEvent.TimerCompleted -> {
                JSONObject().apply {
                    put("type", "TIMER_COMPLETED")
                    put("timestampMillis", event.timestampMillis)
                    put("timerId", event.timerId)
                    put("startTimeMillis", event.startTimeMillis)
                    put("endTimeMillis", event.endTimeMillis)
                    put("actualDurationMinutes", event.actualDurationMinutes)
                    put("mode", event.mode)
                    put("blockedPackages", JSONArray(event.blockedPackages))
                    put("completionType", event.completionType.name)
                    put("bypassUsed", event.bypassUsed)
                }
            }
        }
    }

    private fun parseEvent(obj: JSONObject): TimerEvent {
        val type = obj.getString("type")

        return when (type) {
            "TIMER_STARTED" -> {
                TimerEvent.TimerStarted(
                    timerId = obj.getString("timerId"),
                    timestampMillis = obj.getLong("timestampMillis"),
                    startTimeMillis = obj.getLong("startTimeMillis"),
                    durationMinutes = obj.getInt("durationMinutes"),
                    mode = obj.getString("mode"),
                    blockedPackages = parseStringList(obj.getJSONArray("blockedPackages"))
                )
            }
            "TIMER_COMPLETED" -> {
                // Parse bypassUsed with backward compatibility (default to false for old events)
                val bypassUsed = obj.optBoolean("bypassUsed", false)
                
                TimerEvent.TimerCompleted(
                    timerId = obj.getString("timerId"),
                    timestampMillis = obj.getLong("timestampMillis"),
                    startTimeMillis = obj.getLong("startTimeMillis"),
                    endTimeMillis = obj.getLong("endTimeMillis"),
                    actualDurationMinutes = obj.getInt("actualDurationMinutes"),
                    mode = obj.getString("mode"),
                    blockedPackages = parseStringList(obj.getJSONArray("blockedPackages")),
                    completionType = CompletionType.valueOf(obj.getString("completionType")),
                    bypassUsed = bypassUsed
                )
            }
            else -> throw IllegalArgumentException("Unknown event type: $type")
        }
    }

    private fun parseStringList(array: JSONArray): List<String> {
        return (0 until array.length()).map { array.getString(it) }
    }

    /**
     * Clear all events (for testing or user-initiated data clear).
     */
    fun clearAllEvents() {
        lock.withLock {
            if (eventsFile.exists()) {
                eventsFile.delete()
            }
        }
    }

    companion object {
        private const val EVENTS_FILE = "block_events.json"
    }
}

