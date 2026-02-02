package core.blocker.persistence

import android.content.Context
import core.blocker.engine.ActiveTimer
import core.blocker.engine.BlockRule
import core.blocker.engine.BlockRuleType
import core.blocker.engine.BypassRule
import core.blocker.engine.TimerMode
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class LocalBlockStore(private val context: Context) {
    private val lock = ReentrantLock()
    private val file: File
        get() = File(context.filesDir, STORAGE_FILE)

    fun readData(): PersistenceData = lock.withLock {
        if (!file.exists()) return PersistenceData(emptyList(), emptyList(), emptyList())
        return try {
            val json = JSONObject(file.readText())
            val blockRules = parseBlockRules(json.getJSONArray("blockRules"))
            val bypasses = parseBypasses(json.getJSONArray("bypasses"))
            val activeTimers = parseActiveTimers(json.optJSONArray("activeTimers"))
            PersistenceData(blockRules, bypasses, activeTimers)
        } catch (e: Exception) {
            throw PersistenceCorruptedException("Failed to parse storage file", e)
        }
    }

    fun writeData(data: PersistenceData) = lock.withLock {
        val json = JSONObject()
        val blockRulesArray = JSONArray()
        for (rule in data.blockRules) {
            blockRulesArray.put(serializeBlockRule(rule))
        }
        val bypassesArray = JSONArray()
        for (bypass in data.bypasses) {
            bypassesArray.put(serializeBypass(bypass))
        }
        val activeTimersArray = JSONArray()
        for (timer in data.activeTimers) {
            activeTimersArray.put(serializeActiveTimer(timer))
        }
        json.put("blockRules", blockRulesArray)
        json.put("bypasses", bypassesArray)
        json.put("activeTimers", activeTimersArray)
        file.writeText(json.toString())
    }

    private fun parseBlockRules(array: JSONArray): List<BlockRule> {
        return (0 until array.length()).map { i ->
            val ruleObj = array.getJSONObject(i)
            val id = ruleObj.getString("id")
            val targetApps = (0 until ruleObj.getJSONArray("targetApps").length()).map {
                ruleObj.getJSONArray("targetApps").getString(it)
            }.toSet()
            val priority = ruleObj.getInt("priority")
            val type = when (ruleObj.getString("type")) {
                "ONE_TIME" -> BlockRuleType.OneTime(
                    startTimeMillis = ruleObj.getLong("startTimeMillis"),
                    endTimeMillis = ruleObj.getLong("endTimeMillis")
                )
                "DAILY" -> BlockRuleType.Daily(
                    startHour = ruleObj.getInt("startHour"),
                    startMinute = ruleObj.getInt("startMinute"),
                    endHour = ruleObj.getInt("endHour"),
                    endMinute = ruleObj.getInt("endMinute"),
                    timezoneOffsetMillis = ruleObj.optLong("timezoneOffsetMillis", 0L)
                )
                "WEEKDAY" -> BlockRuleType.Weekday(
                    weekdayMask = ruleObj.getInt("weekdayMask"),
                    startHour = ruleObj.getInt("startHour"),
                    startMinute = ruleObj.getInt("startMinute"),
                    endHour = ruleObj.getInt("endHour"),
                    endMinute = ruleObj.getInt("endMinute"),
                    timezoneOffsetMillis = ruleObj.optLong("timezoneOffsetMillis", 0L)
                )
                else -> throw PersistenceCorruptedException("Unknown rule type: ${ruleObj.getString("type")}")
            }
            BlockRule(id = id, targetApps = targetApps, type = type, priority = priority)
        }
    }

    private fun serializeBlockRule(rule: BlockRule): JSONObject {
        val ruleObj = JSONObject()
        ruleObj.put("id", rule.id)
        ruleObj.put("targetApps", JSONArray(rule.targetApps.toList()))
        ruleObj.put("priority", rule.priority)
        when (val type = rule.type) {
            is BlockRuleType.OneTime -> {
                ruleObj.put("type", "ONE_TIME")
                ruleObj.put("startTimeMillis", type.startTimeMillis)
                ruleObj.put("endTimeMillis", type.endTimeMillis)
            }
            is BlockRuleType.Daily -> {
                ruleObj.put("type", "DAILY")
                ruleObj.put("startHour", type.startHour)
                ruleObj.put("startMinute", type.startMinute)
                ruleObj.put("endHour", type.endHour)
                ruleObj.put("endMinute", type.endMinute)
                ruleObj.put("timezoneOffsetMillis", type.timezoneOffsetMillis)
            }
            is BlockRuleType.Weekday -> {
                ruleObj.put("type", "WEEKDAY")
                ruleObj.put("weekdayMask", type.weekdayMask)
                ruleObj.put("startHour", type.startHour)
                ruleObj.put("startMinute", type.startMinute)
                ruleObj.put("endHour", type.endHour)
                ruleObj.put("endMinute", type.endMinute)
                ruleObj.put("timezoneOffsetMillis", type.timezoneOffsetMillis)
            }
        }
        return ruleObj
    }

    private fun parseBypasses(array: JSONArray): List<BypassRule> {
        return (0 until array.length()).map { i ->
            val bypassObj = array.getJSONObject(i)
            BypassRule(
                id = bypassObj.getString("id"),
                resourceId = bypassObj.getString("resourceId"),
                grantedAtMillis = bypassObj.getLong("grantedAtMillis"),
                durationMillis = bypassObj.getLong("durationMillis")
            )
        }
    }

    private fun serializeBypass(bypass: BypassRule): JSONObject {
        val bypassObj = JSONObject()
        bypassObj.put("id", bypass.id)
        bypassObj.put("resourceId", bypass.resourceId)
        bypassObj.put("grantedAtMillis", bypass.grantedAtMillis)
        bypassObj.put("durationMillis", bypass.durationMillis)
        return bypassObj
    }

    private fun parseActiveTimers(array: JSONArray?): List<ActiveTimer> {
        if (array == null) return emptyList()
        return (0 until array.length()).map { i ->
            val timerObj = array.getJSONObject(i)
            val packagesArray = timerObj.getJSONArray("blockedPackages")
            val packages = (0 until packagesArray.length()).map {
                packagesArray.getString(it)
            }
            // Parse mode with backward compatibility - default to FOCUS if missing
            val modeString = timerObj.optString("mode", "FOCUS")
            val mode = try {
                TimerMode.valueOf(modeString)
            } catch (e: IllegalArgumentException) {
                TimerMode.FOCUS
            }
            ActiveTimer(
                id = timerObj.getString("id"),
                startTimeMillis = timerObj.getLong("startTimeMillis"),
                durationMinutes = timerObj.getInt("durationMinutes"),
                blockedPackages = packages,
                mode = mode
            )
        }
    }

    private fun serializeActiveTimer(timer: ActiveTimer): JSONObject {
        val timerObj = JSONObject()
        timerObj.put("id", timer.id)
        timerObj.put("startTimeMillis", timer.startTimeMillis)
        timerObj.put("durationMinutes", timer.durationMinutes)
        timerObj.put("blockedPackages", JSONArray(timer.blockedPackages))
        timerObj.put("mode", timer.mode.name)
        return timerObj
    }

    fun clear() = lock.withLock {
        if (file.exists()) file.delete()
    }

    companion object {
        private const val STORAGE_FILE = "block_store.json"
    }
}

data class PersistenceData(
    val blockRules: List<BlockRule>,
    val bypasses: List<BypassRule>,
    val activeTimers: List<ActiveTimer> = emptyList()
)

class PersistenceCorruptedException(message: String, cause: Throwable? = null) : Exception(message, cause)

