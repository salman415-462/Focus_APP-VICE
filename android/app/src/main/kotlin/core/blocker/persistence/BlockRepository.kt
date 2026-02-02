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
        
        // Remove expired timers FIRST and persist the cleaned list
        val validTimers = data.activeTimers.filter { it.isActive(currentTimeMillis) }
        
        // Persist the cleaned list so expired timers don't accumulate
        if (validTimers.size != data.activeTimers.size) {
            store.writeData(PersistenceData(data.blockRules, data.bypasses, validTimers))
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
}

