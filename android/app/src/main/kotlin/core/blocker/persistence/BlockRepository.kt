package core.blocker.persistence

import core.blocker.engine.ActiveTimer
import core.blocker.engine.BlockRule
import core.blocker.engine.BypassRule

class BlockRepository(private val store: LocalBlockStore) {

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
}

