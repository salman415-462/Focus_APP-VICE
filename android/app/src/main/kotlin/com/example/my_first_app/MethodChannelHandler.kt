package com.example.my_first_app

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import android.util.Log
import core.blocker.engine.ActiveTimer
import core.blocker.engine.BlockDecisionEngine
import core.blocker.engine.BlockRule
import core.blocker.engine.BlockRuleType
import core.blocker.engine.BypassRule
import core.blocker.enforcement.BlockAdminReceiver
import core.blocker.enforcement.BlockAccessibilityService
import core.blocker.persistence.BlockRepository
import core.blocker.persistence.LocalBlockStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class MethodChannelHandler(private val context: Context) {

    private val repository: BlockRepository by lazy {
        BlockRepository(LocalBlockStore(context))
    }

    private val excludedPackages: Set<String> by lazy {
        setOf(
            context.packageName,
            "com.android.systemui",
            "com.android.launcher",
            "com.google.android.launcher",
            "com.android.launcher3",
            "com.sec.android.app.launcher",
            "com.android.keyguard",
            "com.google.android.apps.nexuslauncher",
            "com.oneplus.launcher",
            "com.android.settings",
            "com.android.phone",
            "com.android.mms",
            "com.android.dialer",
            "com.google.android.dialer",
            "com.samsung.android.dialer",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.contacts",
            "com.android.calendar",
            "com.android.deskclock",
            "com.android.alarmclock"
        )
    }

    companion object {
        const val CHANNEL_NAME = "core.blocker/channel"
        private const val BYPASS_DURATION_MILLIS = 2L * 60 * 1000
        const val METHOD_REFRESH_PERMISSIONS = "refreshPermissions"
        
        // SharedPreferences keys
        const val PREFS_NAME = "core_blocker_prefs"
        const val KEY_REFRESH_PERMISSIONS = "refresh_permissions"
        const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getPermissionStatus" -> getPermissionStatus(result)
                "getInstalledApps" -> getInstalledApps(result)
                "getBlockStatus" -> getBlockStatus(result)
                "saveBlockRules" -> {
                    val rulesJson = call.argument<String>("rulesJson")
                    if (rulesJson == null) {
                        result.success(false)
                    } else {
                        saveBlockRules(rulesJson, result)
                    }
                }
                "requestEmergencyBypass" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.success(false)
                    } else {
                        requestEmergencyBypass(packageName, result)
                    }
                }
                "startOneTimeTimer" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes")
                    val blockedPackages = call.argument<List<String>>("blockedPackages")
                    if (durationMinutes == null || blockedPackages == null) {
                        result.success(false)
                    } else {
                        startOneTimeTimer(durationMinutes, blockedPackages, result)
                    }
                }
                "startCustomDurationTimer" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes")
                    val blockedPackages = call.argument<List<String>>("blockedPackages")
                    if (durationMinutes == null || blockedPackages == null) {
                        result.success(false)
                    } else {
                        startCustomDurationTimer(durationMinutes, blockedPackages, result)
                    }
                }
                "startPomodoroFocusTimer" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes")
                    if (durationMinutes == null) {
                        result.success(false)
                    } else {
                        startPomodoroFocusTimer(durationMinutes, result)
                    }
                }
                "startPomodoroBreakTimer" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes")
                    if (durationMinutes == null) {
                        result.success(false)
                    } else {
                        startPomodoroBreakTimer(durationMinutes, result)
                    }
                }
                "getActiveTimers" -> getActiveTimers(result)
                "openAccessibilitySettings" -> openAccessibilitySettings(result)
                "openOverlaySettings" -> openOverlaySettings(result)
                "openDeviceAdminSettings" -> openDeviceAdminSettings(result)
                "isAccessibilityServiceRunning" -> isAccessibilityServiceRunning(result)
                "refreshPermissions" -> {
                    // Used by DeviceAdminBridgeActivity to notify Flutter to refresh permissions
                    refreshPermissions(result)
                }
                "isOnboardingComplete" -> isOnboardingComplete(result)
                "setOnboardingComplete" -> setOnboardingComplete(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e("MethodChannelHandler", "handleMethodCall error: ${e.message}", e)
            result.error("NATIVE_ERROR", "Native exception: ${e.message}", null)
        }
    }

    private fun getPermissionStatus(result: MethodChannel.Result) {
        Log.d("MethodChannelHandler", "getPermissionStatus called")

        val currentTimeMillis = System.currentTimeMillis()
        val activeBlockRules = repository.getAllBlockRules()
        val activeBypasses = repository.getAllBypasses()
        val bypasses = repository.clearExpiredBypasses(currentTimeMillis)

        val accessibilityEnabled = isAccessibilityServiceEnabled()
        Log.d("MethodChannelHandler", "Accessibility enabled: $accessibilityEnabled")

        val overlayEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
        Log.d("MethodChannelHandler", "Overlay enabled: $overlayEnabled")

        val adminEnabled = isDeviceAdminActive()
        Log.d("MethodChannelHandler", "Device Admin enabled: $adminEnabled")

        val isBlockActive = activeBlockRules.isNotEmpty() &&
            activeBlockRules.any { rule ->
                rule.isBlocked("", currentTimeMillis) ||
                rule.targetApps.isNotEmpty()
            }

        val bypassActive = activeBypasses.any { it.isActive(currentTimeMillis) }

        val status = mapOf(
            "accessibility_enabled" to accessibilityEnabled,
            "overlay_enabled" to overlayEnabled,
            "device_admin_enabled" to adminEnabled,
            "is_block_active" to isBlockActive,
            "bypass_active" to bypassActive
        )

        Log.d("MethodChannelHandler", "Returning permission status: $status")
        result.success(status)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager

        val enabledServices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.ICE_CREAM_SANDWICH) {
            accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        } else {
            @Suppress("DEPRECATION")
            accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        }

        Log.d("MethodChannelHandler", "isAccessibilityServiceEnabled: Number of enabled services: ${enabledServices.size}")

        for (serviceInfo in enabledServices) {
            val serviceName = serviceInfo.resolveInfo.serviceInfo.name
            Log.d("MethodChannelHandler", "isAccessibilityServiceEnabled: Enabled service: $serviceName")
        }

        val expectedComponentName = ComponentName(context, core.blocker.enforcement.BlockAccessibilityService::class.java)
        Log.d("MethodChannelHandler", "isAccessibilityServiceEnabled: Expected component: $expectedComponentName")

        val isEnabled = enabledServices.any { serviceInfo ->
            val serviceComponentName = ComponentName(
                serviceInfo.resolveInfo.serviceInfo.packageName,
                serviceInfo.resolveInfo.serviceInfo.name
            )
            Log.d("MethodChannelHandler", "isAccessibilityServiceEnabled: Checking service component: $serviceComponentName, match: ${serviceComponentName == expectedComponentName}")
            serviceComponentName == expectedComponentName
        }

        // MIUI FIX: Accessibility is only considered enabled if both enabled in settings AND connected
        val isConnected = core.blocker.enforcement.BlockAccessibilityService.isServiceConnected(context)
        val finalResult = isEnabled && isConnected

        Log.d("MethodChannelHandler", "isAccessibilityServiceEnabled: Enabled: $isEnabled, Connected: $isConnected, Final result: $finalResult")

        return finalResult
    }

    /// Check if the accessibility service is actually running (not just enabled)
    private fun isAccessibilityServiceRunning(result: MethodChannel.Result) {
        try {
            val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val runningServices = accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)

            val expectedComponentName = ComponentName(context, core.blocker.enforcement.BlockAccessibilityService::class.java)
            Log.d("MethodChannelHandler", "isAccessibilityServiceRunning: Expected component: $expectedComponentName")

            val isRunning = runningServices.any { serviceInfo ->
                val serviceComponentName = ComponentName(
                    serviceInfo.resolveInfo.serviceInfo.packageName,
                    serviceInfo.resolveInfo.serviceInfo.name
                )
                Log.d("MethodChannelHandler", "isAccessibilityServiceRunning: Service component: $serviceComponentName, match: ${serviceComponentName == expectedComponentName}")
                serviceComponentName == expectedComponentName
            }

            Log.d("MethodChannelHandler", "isAccessibilityServiceRunning: $isRunning")
            result.success(isRunning)
        } catch (e: Exception) {
            Log.e("MethodChannelHandler", "isAccessibilityServiceRunning error: ${e.message}", e)
            result.success(false)
        }
    }

    private fun isDeviceAdminActive(): Boolean {
        val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

        // MIUI FIX: Ensure ComponentName EXACTLY matches the receiver declared in AndroidManifest.xml
        val adminComponentName = ComponentName(context, core.blocker.enforcement.BlockAdminReceiver::class.java)
        Log.d("MethodChannelHandler", "isDeviceAdminActive: Checking admin component: $adminComponentName")

        try {
            val isActive = devicePolicyManager.isAdminActive(adminComponentName)
            Log.d("MethodChannelHandler", "isDeviceAdminActive: $isActive")
            return isActive
        } catch (e: Exception) {
            Log.e("MethodChannelHandler", "isDeviceAdminActive error: ${e.message}", e)
            return false
        }
    }

    private fun refreshPermissions(result: MethodChannel.Result) {
        // This method is called from DeviceAdminBridgeActivity to notify Flutter
        // that permissions should be refreshed. The actual refresh happens on Flutter side.
        Log.d("MethodChannelHandler", "refreshPermissions called")
        result.success(true)
    }

    private fun isOnboardingComplete(result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isComplete = prefs.getBoolean(KEY_ONBOARDING_COMPLETE, false)
        result.success(isComplete)
    }

    private fun setOnboardingComplete(result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_ONBOARDING_COMPLETE, true).apply()
        result.success(true)
    }

    private fun getInstalledApps(result: MethodChannel.Result) {
        val packageManager = context.packageManager
        val apps = mutableListOf<Map<String, String>>()

        // Use queryIntentActivities as single source of truth for launchable apps
        // This is most reliable across Android versions and MIUI
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = packageManager.queryIntentActivities(launcherIntent, 0)

        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo.packageName
            
            // Skip explicitly excluded packages only
            if (packageName in excludedPackages) continue

            // Skip own app
            if (packageName == context.packageName) continue

            val appName = resolveInfo.loadLabel(packageManager).toString()
            if (packageName.isBlank() || appName.isBlank()) continue

            val appInfoMap = mapOf(
                "packageName" to packageName,
                "appName" to appName
            )
            apps.add(appInfoMap)
        }

        result.success(apps)
    }

    private fun shouldExcludeApp(appInfo: android.content.pm.ApplicationInfo): Boolean {
        // Apps are now filtered by launch intent availability in getInstalledApps()
        // This function kept for backward compatibility
        return appInfo.packageName in excludedPackages
    }

    private fun getBlockStatus(result: MethodChannel.Result) {
        val currentTimeMillis = System.currentTimeMillis()

        repository.clearExpiredBypasses(currentTimeMillis)
        repository.clearExpiredTimers()

        val activeBlockRules = repository.getAllBlockRules()
        val activeBypasses = repository.getAllBypasses()
        val activeTimers = repository.getActiveTimers().filter { it.isActive(currentTimeMillis) }

        val decision = BlockDecisionEngine.evaluate(
            resourceId = "",
            currentTimeMillis = currentTimeMillis,
            activeBlockRules = activeBlockRules,
            activeBypasses = activeBypasses
        )

        // Get blocked packages from block rules
        val blockedPackagesFromRules = activeBlockRules
            .filter { rule ->
                rule.targetApps.isNotEmpty() &&
                rule.isBlocked("", currentTimeMillis)
            }
            .flatMap { it.targetApps }
            .toSet()

        // Get blocked packages from active timers
        val blockedPackagesFromTimers = activeTimers
            .flatMap { it.blockedPackages }
            .toSet()

        // Combine both sources
        val allBlockedPackages = blockedPackagesFromRules + blockedPackagesFromTimers

        val bypassActive = activeBypasses.any { it.isActive(currentTimeMillis) }

        val isBlockActive = (decision.decision == core.blocker.engine.Decision.BLOCK) || activeTimers.isNotEmpty()

        val status = mapOf(
            "isBlockActive" to isBlockActive,
            "blockedApps" to allBlockedPackages.toList(),
            "bypassActive" to bypassActive
        )

        result.success(status)
    }

    private fun saveBlockRules(rulesJson: String, result: MethodChannel.Result) {
        val currentTimeMillis = System.currentTimeMillis()

        val activeBlockRules = repository.getAllBlockRules()
        val activeBypasses = repository.getAllBypasses()

        val currentBlockActive = activeBlockRules.any { rule ->
            rule.targetApps.isNotEmpty() &&
            (rule.isBlocked("", currentTimeMillis) ||
             activeBypasses.any { it.isActive(currentTimeMillis) })
        }

        if (currentBlockActive) {
            result.success(false)
            return
        }

        val rules = parseBlockRules(rulesJson)
        if (rules == null) {
            result.success(false)
            return
        }

        repository.saveBlockRules(rules)
        result.success(true)
    }

    private fun parseBlockRules(json: String): List<BlockRule>? {
        return try {
            val jsonArray = JSONArray(json)
            val rules = mutableListOf<BlockRule>()

            for (i in 0 until jsonArray.length()) {
                val ruleObj = jsonArray.getJSONObject(i)

                val id = ruleObj.optString("id", UUID.randomUUID().toString())
                val targetAppsArray = ruleObj.getJSONArray("targetApps")
                val targetApps = (0 until targetAppsArray.length()).map {
                    targetAppsArray.getString(it)
                }.toSet()

                if (targetApps.isEmpty()) continue

                val priority = ruleObj.optInt("priority", 0)
                val type = parseBlockRuleType(ruleObj) ?: continue

                rules.add(BlockRule(id, targetApps, type, priority))
            }

            rules
        } catch (e: Exception) {
            null
        }
    }

    private fun parseBlockRuleType(ruleObj: JSONObject): BlockRuleType? {
        return try {
            val type = ruleObj.getString("type")
            when (type) {
                "ONE_TIME" -> {
                    BlockRuleType.OneTime(
                        startTimeMillis = ruleObj.getLong("startTimeMillis"),
                        endTimeMillis = ruleObj.getLong("endTimeMillis")
                    )
                }
                "DAILY" -> {
                    BlockRuleType.Daily(
                        startHour = ruleObj.getInt("startHour"),
                        startMinute = ruleObj.getInt("startMinute"),
                        endHour = ruleObj.getInt("endHour"),
                        endMinute = ruleObj.getInt("endMinute"),
                        timezoneOffsetMillis = ruleObj.optLong("timezoneOffsetMillis", 0L)
                    )
                }
                "WEEKDAY" -> {
                    BlockRuleType.Weekday(
                        weekdayMask = ruleObj.getInt("weekdayMask"),
                        startHour = ruleObj.getInt("startHour"),
                        startMinute = ruleObj.getInt("startMinute"),
                        endHour = ruleObj.getInt("endHour"),
                        endMinute = ruleObj.getInt("endMinute"),
                        timezoneOffsetMillis = ruleObj.optLong("timezoneOffsetMillis", 0L)
                    )
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun requestEmergencyBypass(packageName: String, result: MethodChannel.Result) {
        if (packageName.isBlank()) {
            result.success(false)
            return
        }

        val currentTimeMillis = System.currentTimeMillis()

        repository.clearExpiredBypasses(currentTimeMillis)
        repository.clearExpiredTimers()

        val activeBypasses = repository.getAllBypasses()

        val hasActiveBypass = activeBypasses.any { it.isActive(currentTimeMillis) }
        if (hasActiveBypass) {
            result.success(false)
            return
        }

        val bypass = BypassRule(
            id = UUID.randomUUID().toString(),
            resourceId = packageName,
            grantedAtMillis = currentTimeMillis,
            durationMillis = BYPASS_DURATION_MILLIS
        )

        repository.saveBypasses(activeBypasses + bypass)

        // Pause any active timers that block this package
        pauseTimersForPackage(packageName, currentTimeMillis)

        result.success(true)
    }

    private fun pauseTimersForPackage(packageName: String, currentTimeMillis: Long) {
        val activeTimers = repository.getActiveTimers()
        
        // Find timers that block this package, or all timers if wildcard '*'
        val timersToPause = if (packageName == "*") {
            // Wildcard - pause ALL active timers
            activeTimers
        } else {
            // Specific package - pause only timers that block this package
            activeTimers.filter { timer ->
                packageName in timer.blockedPackages
            }
        }

        // Pause each timer for the bypass duration
        timersToPause.forEach { timer ->
            timer.pausedUntilMillis = currentTimeMillis + BYPASS_DURATION_MILLIS
            repository.updateActiveTimer(timer)
        }

        if (timersToPause.isNotEmpty()) {
            Log.d("MethodChannelHandler", "Paused ${timersToPause.size} timer(s) for emergency bypass of $packageName")
        }
    }

    private fun startOneTimeTimer(
        durationMinutes: Int,
        blockedPackages: List<String>,
        result: MethodChannel.Result
    ) {
        // Validate duration
        if (durationMinutes <= 0) {
            result.success(false)
            return
        }

        // Validate blocked packages
        if (blockedPackages.isEmpty()) {
            result.success(false)
            return
        }

        val currentTimeMillis = System.currentTimeMillis()

        // Parse mode with backward compatibility - default to FOCUS if missing or invalid
        val modeString = "FOCUS" // Reserved for future: call.argument<String>("mode") ?: "FOCUS"
        val mode = try {
            core.blocker.engine.TimerMode.valueOf(modeString)
        } catch (e: IllegalArgumentException) {
            core.blocker.engine.TimerMode.FOCUS
        }

        // Create the timer
        val timer = ActiveTimer(
            id = UUID.randomUUID().toString(),
            startTimeMillis = currentTimeMillis,
            durationMinutes = durationMinutes,
            blockedPackages = blockedPackages,
            mode = mode
        )

        // Save the timer (multiple timers are allowed)
        val saved = repository.saveActiveTimer(timer)
        result.success(saved)
    }

    private fun startCustomDurationTimer(
        durationMinutes: Int,
        blockedPackages: List<String>,
        result: MethodChannel.Result
    ) {
        // Validate duration
        if (durationMinutes <= 0) {
            result.success(false)
            return
        }

        // Validate blocked packages
        if (blockedPackages.isEmpty()) {
            result.success(false)
            return
        }

        val currentTimeMillis = System.currentTimeMillis()

        // Create the timer with mode FOCUS for custom duration
        val timer = ActiveTimer(
            id = UUID.randomUUID().toString(),
            startTimeMillis = currentTimeMillis,
            durationMinutes = durationMinutes,
            blockedPackages = blockedPackages,
            mode = core.blocker.engine.TimerMode.FOCUS
        )

        // Save the timer (multiple timers are allowed)
        val saved = repository.saveActiveTimer(timer)
        result.success(saved)
    }

    private fun startPomodoroFocusTimer(
        durationMinutes: Int,
        result: MethodChannel.Result
    ) {
        // Validate duration
        if (durationMinutes <= 0) {
            result.success(false)
            return
        }

        val currentTimeMillis = System.currentTimeMillis()

        // Create the timer with mode POMODORO_FOCUS and empty blocked packages
        val timer = ActiveTimer(
            id = UUID.randomUUID().toString(),
            startTimeMillis = currentTimeMillis,
            durationMinutes = durationMinutes,
            blockedPackages = emptyList(),
            mode = core.blocker.engine.TimerMode.POMODORO_FOCUS
        )

        // Save the timer (multiple timers are allowed)
        val saved = repository.saveActiveTimer(timer)
        result.success(saved)
    }

    private fun startPomodoroBreakTimer(
        durationMinutes: Int,
        result: MethodChannel.Result
    ) {
        // Validate duration
        if (durationMinutes <= 0) {
            result.success(false)
            return
        }

        val currentTimeMillis = System.currentTimeMillis()

        // Create the timer with mode POMODORO_BREAK and empty blocked packages
        val timer = ActiveTimer(
            id = UUID.randomUUID().toString(),
            startTimeMillis = currentTimeMillis,
            durationMinutes = durationMinutes,
            blockedPackages = emptyList(),
            mode = core.blocker.engine.TimerMode.POMODORO_BREAK
        )

        // Save the timer (multiple timers are allowed)
        val saved = repository.saveActiveTimer(timer)
        result.success(saved)
    }

    private fun getActiveTimers(result: MethodChannel.Result) {
        val currentTimeMillis = System.currentTimeMillis()

        // Clear expired timers first
        repository.clearExpiredTimers()

        // Get active timers from repository
        val timers = repository.getActiveTimers()

        // Convert to map for Flutter
        val timersList = timers.map { timer ->
            mapOf(
                "id" to timer.id,
                "mode" to timer.mode.name,
                "startTimeMillis" to timer.startTimeMillis,
                "durationMinutes" to timer.durationMinutes,
                "remainingSeconds" to timer.getRemainingSeconds(currentTimeMillis),
                "blockedPackages" to timer.blockedPackages
            )
        }

        result.success(timersList)
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", "Could not open accessibility settings: ${e.message}", null)
        }
    }

    private fun openOverlaySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", "Could not open overlay settings: ${e.message}", null)
        }
    }

    private fun openDeviceAdminSettings(result: MethodChannel.Result) {
        try {
            val admin = ComponentName(context, BlockAdminReceiver::class.java)
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required to prevent app deletion and enforce focus lock.")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", "Could not open device admin settings: ${e.message}", null)
        }
    }
}

