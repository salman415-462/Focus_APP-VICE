package core.blocker.persistence

import core.blocker.engine.ActiveTimer
import core.blocker.engine.BlockRule
import core.blocker.engine.BypassRule
import core.blocker.events.CompletionType
import core.blocker.events.EventRepository

/**
 * Repository for managing active timers, block rules, and bypasses.
 * 
 * Integrates with EventRepository to record TIMER_STARTED and TIMER_COMPLETED events
 * for historical stats. This integration is transparent to enforcement logic.
 */
class BlockRepository(
    private val store: LocalBlockStore,
    private val eventRepository: EventRepository? = null
) {

    fun getAllBlockRules(): List<BlockRule> {
        return store.readData().blockRules
    }

    fun getAllBypasses(): List<BypassRule> {
        return store.readData().bypasses
    }

    fun saveBlockRules(rules: List<BlockRule>) {
        val currentData = store.readData()
        store.writeData(PersistenceData(rules, currentData.bypasses, currentData.activeTimers))
    }

    fun saveBypasses(bypasses: List<BypassRule>) {
        val currentData = store.readData()
        store.writeData(PersistenceData(currentData.blockRules, bypasses, currentData.activeTimers))
    }

    fun clearExpiredBypasses(currentTimeMillis: Long): Int {
        val data = store.readData()
        val before = data.bypasses.size
        val validBypasses = data.bypasses.filter { !it.isExpired(currentTimeMillis) }
        val removed = before - validBypasses.size
        store.writeData(PersistenceData(data.blockRules, validBypasses, data.activeTimers))
        return removed
    }

    // Active Timer methods
    fun getActiveTimers(): List<ActiveTimer> {
        val currentTimeMillis = System.currentTimeMillis()
        val data = store.readData()
        
        // Remove expired timers AND filter out paused timers
        // Paused timers should not be considered "active" for blocking purposes
        val validTimers = data.activeTimers.filter { timer ->
            !timer.isExpired(currentTimeMillis) && !timer.isPaused(currentTimeMillis)
        }
        
        // Also clean up any completely expired timers from storage
        val nonExpiredTimers = data.activeTimers.filter { !it.isExpired(currentTimeMillis) }
        
        // Persist the cleaned list so expired timers don't accumulate
        if (nonExpiredTimers.size != data.activeTimers.size) {
            store.writeData(PersistenceData(data.blockRules, data.bypasses, nonExpiredTimers))
        }
        
        return validTimers
    }

    fun saveActiveTimer(timer: ActiveTimer): Boolean {
        val currentData = store.readData()
        val currentTimeMillis = System.currentTimeMillis()

        // Remove any expired timers first
        val validTimers = currentData.activeTimers.filter { it.isActive(currentTimeMillis) }

        // Check if timer already exists
        if (validTimers.any { it.id == timer.id }) {
            return false
        }

        // Record TIMER_STARTED event before saving
        // This is the single source of truth for timer start events
        eventRepository?.recordTimerStarted(
            timerId = timer.id,
            startTimeMillis = timer.startTimeMillis,
            durationMinutes = timer.durationMinutes,
            mode = timer.mode.name,
            blockedPackages = timer.blockedPackages
        )

        // Allow multiple timers even if they block the same packages
        store.writeData(PersistenceData(currentData.blockRules, currentData.bypasses, validTimers + timer))
        return true
    }

    fun clearExpiredTimers(): Int {
        val currentTimeMillis = System.currentTimeMillis()
        val data = store.readData()
        val before = data.activeTimers.size
        val validTimers = data.activeTimers.filter { !it.isExpired(currentTimeMillis) }
        val removed = before - validTimers.size
        store.writeData(PersistenceData(data.blockRules, data.bypasses, validTimers))
        return removed
    }

    /**
     * Clears expired timers and records TIMER_COMPLETED events for each.
     * This is the preferred method for cleanup as it preserves historical data.
     * 
     * @return Number of timers cleared and recorded
     */
    fun clearExpiredTimersWithEvents(): Int {
        val currentTimeMillis = System.currentTimeMillis()
        val data = store.readData()
        
        // Find expired timers (excluding those that are paused)
        val expiredTimers = data.activeTimers.filter { 
            it.isExpired(currentTimeMillis) && !it.isPaused(currentTimeMillis)
        }
        
        // Record TIMER_COMPLETED event for each expired timer
        expiredTimers.forEach { timer ->
            val completionType = determineCompletionType(timer, currentTimeMillis)
            val actualDuration = calculateActualDuration(timer, currentTimeMillis, completionType)
            
            eventRepository?.recordTimerCompleted(
                timerId = timer.id,
                startTimeMillis = timer.startTimeMillis,
                endTimeMillis = currentTimeMillis,
                actualDurationMinutes = actualDuration,
                mode = timer.mode.name,
                blockedPackages = timer.blockedPackages,
                completionType = completionType
            )
        }
        
        // Also handle paused-but-expired timers
        val pausedExpiredTimers = data.activeTimers.filter {
            it.isExpired(currentTimeMillis) && it.isPaused(currentTimeMillis)
        }
        
        pausedExpiredTimers.forEach { timer ->
            // Paused timers that expired during pause - record as interrupted
            val completionType = CompletionType.BYPASS // Paused by bypass = interrupted
            val pausedEndTime = timer.pausedUntilMillis ?: timer.endTimeMillis
            val actualDuration = ((pausedEndTime - timer.startTimeMillis) / (60 * 1000)).toInt()
            
            eventRepository?.recordTimerCompleted(
                timerId = timer.id,
                startTimeMillis = timer.startTimeMillis,
                endTimeMillis = pausedEndTime,
                actualDurationMinutes = actualDuration,
                mode = timer.mode.name,
                blockedPackages = timer.blockedPackages,
                completionType = completionType
            )
        }
        
        // Remove all expired timers from storage
        val nonExpiredTimers = data.activeTimers.filter { !it.isExpired(currentTimeMillis) }
        if (nonExpiredTimers.size != data.activeTimers.size) {
            store.writeData(PersistenceData(data.blockRules, data.bypasses, nonExpiredTimers))
        }
        
        return expiredTimers.size + pausedExpiredTimers.size
    }

    /**
     * Determines the completion type for a timer based on its state.
     */
    private fun determineCompletionType(timer: ActiveTimer, currentTimeMillis: Long): CompletionType {
        return when {
            // If currently paused (by bypass), treat as bypass interruption
            timer.isPaused(currentTimeMillis) -> CompletionType.BYPASS
            // If within grace window and user undoes, it will be caught by undoTimer()
            // Here we just check if grace has expired
            timer.graceExpiresAt != null && currentTimeMillis > timer.graceExpiresAt -> {
                // Grace expired - timer ran naturally or was bypassed
                // Check if bypass was active during this timer
                if (hasActiveBypassDuringTimer(timer)) {
                    CompletionType.BYPASS
                } else {
                    CompletionType.NATURAL
                }
            }
            else -> CompletionType.NATURAL
        }
    }

    /**
     * Check if any bypass was active during the timer period.
     */
    private fun hasActiveBypassDuringTimer(timer: ActiveTimer): Boolean {
        val data = store.readData()
        val bypasses = data.bypasses
        
        // Check if any bypass overlaps with timer period
        return bypasses.any { bypass ->
            bypass.isActive(timer.startTimeMillis) ||
            bypass.isActive(timer.endTimeMillis)
        }
    }

    /**
     * Calculates the actual duration of a timer based on completion type.
     */
    private fun calculateActualDuration(
        timer: ActiveTimer,
        currentTimeMillis: Long,
        completionType: CompletionType
    ): Int {
        return when (completionType) {
            CompletionType.NATURAL -> {
                // Timer ran to completion
                timer.durationMinutes
            }
            CompletionType.UNDO -> {
                // Timer was cancelled - calculate time until undo
                val elapsed = ((currentTimeMillis - timer.startTimeMillis) / (60 * 1000)).toInt()
                elapsed.coerceAtMost(timer.durationMinutes)
            }
            CompletionType.BYPASS -> {
                // Timer was interrupted by bypass
                val elapsed = ((currentTimeMillis - timer.startTimeMillis) / (60 * 1000)).toInt()
                elapsed.coerceAtMost(timer.durationMinutes)
            }
            CompletionType.SYSTEM_KILL -> {
                // App killed - use actual elapsed time
                val elapsed = ((currentTimeMillis - timer.startTimeMillis) / (60 * 1000)).toInt()
                elapsed.coerceAtMost(timer.durationMinutes)
            }
        }
    }

    fun clearAllActiveTimers() {
        val data = store.readData()
        store.writeData(PersistenceData(data.blockRules, data.bypasses, emptyList()))
    }

    fun clearActiveTimer(timerId: String) {
        val data = store.readData()
        val filteredTimers = data.activeTimers.filter { it.id != timerId }
        store.writeData(PersistenceData(data.blockRules, data.bypasses, filteredTimers))
    }

    fun updateActiveTimer(timer: ActiveTimer) {
        val currentData = store.readData()
        val currentTimeMillis = System.currentTimeMillis()

        // Remove any expired timers first
        val validTimers = currentData.activeTimers.filter { it.isActive(currentTimeMillis) }

        // Find and replace the timer with the same ID
        val updatedTimers = validTimers.map {
            if (it.id == timer.id) timer else it
        }

        store.writeData(PersistenceData(currentData.blockRules, currentData.bypasses, updatedTimers))
    }

    /**
     * Checks if a timer can still be undone within its grace window.
     * @param timerId The ID of the timer to check
     * @return true if undo is allowed, false otherwise (expired, not found, or already undone)
     */
    fun canUndo(timerId: String): Boolean {
        val currentTimeMillis = System.currentTimeMillis()
        val data = store.readData()
        val timer = data.activeTimers.find { it.id == timerId } ?: return false

        // Timer must have a graceExpiresAt and current time must be within the window
        return timer.graceExpiresAt != null && currentTimeMillis <= timer.graceExpiresAt
    }

    /**
     * Removes a timer if it is still within its grace window.
     * This is a one-time operation - once grace expires, undo is permanently blocked.
     * @param timerId The ID of the timer to undo
     * @return true if the timer was successfully removed, false if grace has expired or timer not found
     */
    fun undoTimer(timerId: String): Boolean {
        val currentTimeMillis = System.currentTimeMillis()
        val data = store.readData()
        val timer = data.activeTimers.find { it.id == timerId } ?: return false

        // Check if grace window is still valid
        if (timer.graceExpiresAt == null || currentTimeMillis > timer.graceExpiresAt) {
            // Grace window has expired - cannot undo
            return false
        }

        // Record TIMER_COMPLETED(UNDO) event before removing
        val elapsedMinutes = ((currentTimeMillis - timer.startTimeMillis) / (60 * 1000)).toInt()
        
        eventRepository?.recordTimerCompleted(
            timerId = timer.id,
            startTimeMillis = timer.startTimeMillis,
            endTimeMillis = currentTimeMillis,
            actualDurationMinutes = elapsedMinutes.coerceAtMost(timer.durationMinutes),
            mode = timer.mode.name,
            blockedPackages = timer.blockedPackages,
            completionType = CompletionType.UNDO
        )

        // Remove the timer
        val filteredTimers = data.activeTimers.filter { it.id != timerId }
        store.writeData(PersistenceData(data.blockRules, data.bypasses, filteredTimers))
        return true
    }

    /**
     * Gets a timer by its ID, including those that may have expired.
     * Useful for checking grace window status.
     */
    fun getTimerById(timerId: String): ActiveTimer? {
        return store.readData().activeTimers.find { it.id == timerId }
    }

    /**
     * Gets the remaining grace time in milliseconds for a timer.
     * Returns 0 if grace has expired or timer not found.
     */
    fun getRemainingGraceMillis(timerId: String): Long {
        val currentTimeMillis = System.currentTimeMillis()
        val timer = getTimerById(timerId) ?: return 0
        val graceExpiresAt = timer.graceExpiresAt ?: return 0
        val remaining = graceExpiresAt - currentTimeMillis
        return remaining.coerceAtLeast(0)
    }
}

