package core.blocker.enforcement

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import java.io.IOException
import java.util.ArrayDeque
import android.view.accessibility.AccessibilityEvent
import core.blocker.engine.ActiveTimer
import core.blocker.engine.BlockDecisionEngine
import core.blocker.engine.Decision
import core.blocker.engine.TimerMode
import core.blocker.persistence.BlockRepository
import core.blocker.persistence.LocalBlockStore

class BlockAccessibilityService : AccessibilityService() {

    private lateinit var repository: BlockRepository
    private lateinit var overlayController: OverlayController
    private var lastBlockedPackage: String? = null
    private var lastEnforcedPackage: String? = null
    private var lastEnforceTimeMs: Long = 0
    private val enforcementCooldownMs: Long = 500
    private var isBlockingOverlayShowing: Boolean = false
    private var blockSuppressed: Boolean = false
    private var hasEnforcedSinceLastHome: Boolean = false
    private var removeOverlayRunnable: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())

    // Kill queue and rate limiting to avoid aggressive repeated force-stops
    private val killQueue: ArrayDeque<String> = ArrayDeque()
    private var processingKill: Boolean = false
    private val lastKillTimes: MutableMap<String, Long> = mutableMapOf()
    private val killDelayMs: Long = 500
    private val minKillIntervalMs: Long = 2000

    private var heartbeatRunnable: Runnable? = null

    private val prefs by lazy { getSharedPreferences("blocker_prefs", Context.MODE_PRIVATE) }

    override fun onCreate() {
        super.onCreate()
        val store = LocalBlockStore(applicationContext)
        repository = BlockRepository(store)
        overlayController = OverlayController(applicationContext)
        // Improve survivability: start a foreground monitor and heartbeat logging
        ensureMonitorStarted()
        startHeartbeat()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        // Set connection state for MIUI compatibility
        prefs.edit().putBoolean("accessibility_connected", true).apply()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // DEBUG: Log event received
        Log.d(TAG, "DEBUG: Received event type=${event.eventType} package=${event.packageName}")

        // Process only relevant events
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return
        if (isSystemUiPackage(packageName)) {
            // Ignore system UI packages
            return
        }

        // DEBUG: Log event received
        Log.d(TAG, "DEBUG: onAccessibilityEvent pkg=$packageName suppressed=$blockSuppressed enforced=$hasEnforcedSinceLastHome")

        // Home detection: only clear suppression, do NOT remove overlay
        val homePackage = getHomePackageName()
        if (packageName == homePackage) {
            // Clear suppression and reset enforcement flag when Home is detected
            blockSuppressed = true
            hasEnforcedSinceLastHome = false
            Log.d(TAG, "DEBUG: Home detected, suppression reset")
            return
        }

        // If suppression is active AND we've already enforced once, skip all processing
        // This guarantees first blocked app always runs, repeated spam is suppressed
        if (blockSuppressed && hasEnforcedSinceLastHome) {
            Log.d(TAG, "DEBUG: Suppression active, skipping enforcement")
            return
        }

        // Evaluate blocking only for app windows (non-home)
        evaluateAndEnforce(packageName)

        // Pomodoro timer overlay management (separate from blocking overlay)
        // Do not show timer overlay while blocking suppression is active
        val currentTimeMillis = System.currentTimeMillis()
        val activePomodoroTimers = repository.getActiveTimers().filter {
            it.isActive(currentTimeMillis) && (it.mode == TimerMode.POMODORO_FOCUS || it.mode == TimerMode.POMODORO_BREAK)
        }
        
        // FIX: Never overwrite blocking overlay with pomodoro overlay
        if (activePomodoroTimers.isNotEmpty() && !isBlockingOverlayShowing && !blockSuppressed) {
            // Only show pomodoro if blocking overlay is NOT showing
            if (!overlayController.isShowing()) {
                overlayController.showOverlay("Pomodoro Timer is running")
            }
        } else {
            // Only remove pomodoro overlay if blocking overlay is not showing
            if (!isBlockingOverlayShowing && !overlayController.isShowing()) {
                overlayController.removeOverlay()
            }
        }
    }

    override fun onInterrupt() {
        // Service interrupted - no action needed
    }

    override fun onUnbind(intent: Intent?): Boolean {
        // Clear connection state
        prefs.edit().putBoolean("accessibility_connected", false).apply()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy called")
        stopHeartbeat()
        super.onDestroy()
    }

    private fun evaluateAndEnforce(packageName: String) {
        val currentTimeMillis = System.currentTimeMillis()

        // Rate-limit repeated enforcement for the same package
        if (packageName == lastEnforcedPackage && (currentTimeMillis - lastEnforceTimeMs) < enforcementCooldownMs) {
            Log.d(TAG, "DEBUG: Cooldown active, skipping $packageName")
            return
        }

        // Check active bypasses first - highest priority
        val activeBypasses = repository.getAllBypasses()
        val activeBypass = activeBypasses.find { it.resourceId == packageName && it.isActive(currentTimeMillis) }
        
        // Check active timers
        val activeTimers = repository.getActiveTimers().filter { it.isActive(currentTimeMillis) }
        val blockingTimer = activeTimers.firstOrNull { packageName in it.blockedPackages }

        // DECISION ORDER: bypass → timer → normal rules
        if (activeBypass != null) {
            // Emergency bypass active - allow through
            Log.d(TAG, "DEBUG: Emergency bypass active for $packageName, allowing")
            lastBlockedPackage = null
            return
        }

        if (blockingTimer != null) {
            // Timer active - hard block, no bypass check
            Log.d(TAG, "DEBUG: Timer active for $packageName, enforcing block")
            lastBlockedPackage = packageName
            lastEnforcedPackage = packageName
            lastEnforceTimeMs = currentTimeMillis
            enforceBlock(packageName, blockingTimer)
            return
        }

        // No bypass, no timer - check normal rules
        val activeBlockRules = repository.getAllBlockRules()
        val result = BlockDecisionEngine.evaluate(
            resourceId = packageName,
            currentTimeMillis = currentTimeMillis,
            activeBlockRules = activeBlockRules,
            activeBypasses = activeBypasses
        )

        Log.d(TAG, "DEBUG: BlockDecisionEngine final decision=${result.decision}")

        when (result.decision) {
            Decision.BLOCK -> {
                lastBlockedPackage = packageName
                lastEnforcedPackage = packageName
                lastEnforceTimeMs = currentTimeMillis
                enforceBlock(packageName, null)
            }
            Decision.ALLOW -> {
                lastBlockedPackage = null
                Log.d(TAG, "DEBUG: Decision ALLOW, no block enforced")
            }
        }
    }

    private fun enforceBlock(packageName: String, blockingTimer: ActiveTimer?) {
        Log.d(TAG, "BLOCK detected for $packageName - overlay requested")

        // Consume timer if this was a timer-based block
        if (blockingTimer != null) {
            Log.d(TAG, "DEBUG: Consuming timer ${blockingTimer.id} for $packageName")
            repository.clearActiveTimer(blockingTimer.id)
        }

        // Mark that enforcement has happened since last Home
        hasEnforcedSinceLastHome = true

        // Show overlay IMMEDIATELY first (while blocked app is still foreground)
        showBlockingOverlay()

        // Delay Home slightly to let overlay attach to blocked app window
        // 200ms gives more time for view to render before Home takes focus
        handler.postDelayed({
            sendToHome()
            scheduleKill(packageName)
        }, HOME_DELAY_MS)

        // Ensure we don't quickly re-process the same package
        lastEnforcedPackage = packageName
        lastEnforceTimeMs = System.currentTimeMillis()

        // Clear any previous suppression (we are actively enforcing)
        blockSuppressed = false
    }

    private fun showBlockingOverlay() {
        Log.d(TAG, "DEBUG: showBlockingOverlay checking permission")

        // Check overlay permission before showing
        val hasOverlayPermission = Settings.canDrawOverlays(this)
        Log.d(TAG, "DEBUG: canDrawOverlays=$hasOverlayPermission")

        if (!hasOverlayPermission) {
            Log.w(TAG, "showBlockingOverlay: permission not granted, skipping")
            return
        }

        // Show overlay and mark state
        try {
            overlayController.showOverlay("This app is blocked")
            isBlockingOverlayShowing = true
            Log.d(TAG, "showBlockingOverlay: overlay shown successfully")
        } catch (e: Exception) {
            Log.w(TAG, "showBlockingOverlay: showOverlay failed", e)
            isBlockingOverlayShowing = false
            return
        }

        // Schedule removal after 2000ms (time-based only, no early cancellation)
        removeOverlayRunnable?.let { handler.removeCallbacks(it) }
        removeOverlayRunnable = Runnable {
            val wasShowing = isBlockingOverlayShowing
            try {
                overlayController.removeOverlay()
                Log.d(TAG, "showBlockingOverlay: overlay removed (timeout)")
            } catch (e: Exception) {
                Log.w(TAG, "showBlockingOverlay: removeOverlay failed", e)
            }
            // Only set flag false if overlay was actually showing
            if (wasShowing) {
                isBlockingOverlayShowing = false
            }
        }
        handler.postDelayed(removeOverlayRunnable!!, OVERLAY_TIMEOUT_MS)
    }

    private fun sendToHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        Log.d(TAG, "DEBUG: sendToHome intent sent")
    }

    private fun scheduleKill(packageName: String) {
        val now = System.currentTimeMillis()
        val last = lastKillTimes[packageName] ?: 0L
        if ((now - last) < minKillIntervalMs) {
            Log.d(TAG, "Skipping kill for $packageName due to cooldown")
            return
        }
        synchronized(killQueue) {
            killQueue.addLast(packageName)
            lastKillTimes[packageName] = now
            if (!processingKill) {
                processingKill = true
                processNextKill()
            }
        }
    }

    private fun processNextKill() {
        val pkg: String? = synchronized(killQueue) {
            if (killQueue.isEmpty()) {
                processingKill = false
                null
            } else killQueue.removeFirst()
        }
        if (pkg == null) return
        handler.post {
            performKill(pkg)
            handler.postDelayed({ processNextKill() }, killDelayMs)
        }
    }

    private fun performKill(packageName: String) {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.killBackgroundProcesses(packageName)
            Log.d(TAG, "killBackgroundProcesses requested for $packageName")
        } catch (e: Exception) {
            Log.w(TAG, "killBackgroundProcesses failed for $packageName", e)
        }
        try {
            Runtime.getRuntime().exec(arrayOf("am", "force-stop", packageName))
            Log.d(TAG, "force-stop executed for $packageName")
        } catch (e: IOException) {
            Log.w(TAG, "force-stop failed for $packageName", e)
        }
    }

    private fun startHeartbeat() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable = Runnable {
            Log.d(TAG, "heartbeat: service alive")
            handler.postDelayed(heartbeatRunnable!!, 30_000)
        }
        handler.postDelayed(heartbeatRunnable!!, 30_000)
    }

    private fun stopHeartbeat() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable = null
    }

    private fun ensureMonitorStarted() {
        try {
            val intent = Intent(this, BlockMonitorService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "BlockMonitorService start requested")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start BlockMonitorService", e)
        }
    }

    private fun getHomePackageName(): String? {
        val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
        val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName
    }

    private fun clearBlockingState() {
        // Cancel scheduled overlay removal runnable
        removeOverlayRunnable?.let { handler.removeCallbacks(it) }
        removeOverlayRunnable = null

        // Reset state - do NOT remove overlay here (it will timeout naturally)
        // Only reset flag if overlay is not actually showing
        if (!overlayController.isShowing()) {
            isBlockingOverlayShowing = false
        }
        lastBlockedPackage = null
        lastEnforcedPackage = null
        lastEnforceTimeMs = 0

        // Suppress further overlays until a blocked app is opened again
        blockSuppressed = true

        Log.d(TAG, "clearBlockingState: state cleared, overlay will timeout naturally")
    }

    private fun isPackageBlocked(packageName: String): Boolean {
        val currentTimeMillis = System.currentTimeMillis()
        
        // Check bypass first - bypass overrides blocking
        val activeBypasses = repository.getAllBypasses()
        val activeBypass = activeBypasses.find { it.resourceId == packageName && it.isActive(currentTimeMillis) }
        if (activeBypass != null) return false
        
        // Check timers - timer blocks if active
        val activeTimers = repository.getActiveTimers().filter { it.isActive(currentTimeMillis) }
        if (activeTimers.any { packageName in it.blockedPackages }) return true

        // Check normal rules
        val activeBlockRules = repository.getAllBlockRules()
        val result = BlockDecisionEngine.evaluate(
            resourceId = packageName,
            currentTimeMillis = currentTimeMillis,
            activeBlockRules = activeBlockRules,
            activeBypasses = activeBypasses
        )
        return result.decision == Decision.BLOCK
    }

    private fun isSystemUiPackage(packageName: String): Boolean {
        return packageName in SYSTEM_UI_PACKAGES
    }

    companion object {
        private val SYSTEM_UI_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.google.android.launcher",
            "com.android.launcher3",
            "com.sec.android.app.launcher",
            "com.android.keyguard",
            "com.google.android.apps.nexuslauncher",
            "com.oneplus.launcher"
        )

        private const val TAG = "BlockAccessibilitySvc"

        /**
         * Delay before sending user to Home after showing overlay.
         * Gives overlay time to attach to blocked app window before Home takes focus.
         */
        private const val HOME_DELAY_MS = 200L

        /**
         * How long the blocking overlay stays visible before auto-removal.
         */
        private const val OVERLAY_TIMEOUT_MS = 2000L

        fun isServiceConnected(context: Context): Boolean {
            val prefs = context.getSharedPreferences("blocker_prefs", Context.MODE_PRIVATE)
            return prefs.getBoolean("accessibility_connected", false)
        }

        private var instance: BlockAccessibilityService? = null
    }

    init {
        instance = this
    }
}

