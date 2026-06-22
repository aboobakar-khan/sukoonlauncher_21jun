package com.sukoon.launcher

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * Background foreground service that monitors which app is in the foreground.
 * 
 * ## Normal Mode (app blocking)
 * If a blocked app is detected, launches BlockedAppActivity overlay.
 * Polls every 500ms.
 * 
 * ## ZEN MODE (maximum lockdown)
 * When Zen Mode is active, the service:
 * 1. Polls every 200ms (faster detection)
 * 2. Re-launches our app if user leaves to ANY app (not just blocked ones)
 * 3. Adds a status-bar overlay to block notification panel pull-down
 * 4. Blocks share sheets, choosers, and system UI interactions
 * 5. Only allows: our app, camera
 */
class AppBlockerService : Service() {

    companion object {
        const val TAG = "AppBlockerService"
        const val CHANNEL_ID = "sukoon_focus_v3"   // v3 — IMPORTANCE_LOW, no status bar icon
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "app_blocker_prefs"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_ZEN_MODE = "zen_mode_active"
        const val KEY_TIMED_SESSION_PKG = "timed_session_package"
        const val KEY_TIMED_SESSION_END = "timed_session_end_time"
        const val KEY_TIMED_SESSION_START = "timed_session_start_time"
        const val KEY_TIMED_SESSION_EXTENSIONS = "timed_session_extensions"
        const val KEY_TIMER_PACKAGES = "timer_managed_packages"
        const val POLL_INTERVAL_MS = 500L
        const val ZEN_POLL_INTERVAL_MS = 200L
        const val IDLE_POLL_INTERVAL_MS = 10000L  // 10s when nothing to monitor — saves battery
        // Timer-only mode: poll less aggressively — we have an AlarmManager backup
        const val TIMER_ONLY_POLL_INTERVAL_MS = 3000L  // 3s when only timer running (no blocked apps)

        /** Weak reference to the live service instance — lets MainActivity call refreshNotification() directly. */
        private var _instance: AppBlockerService? = null
        fun getRunningInstance(): AppBlockerService? = _instance

        // Allowed packages during Zen Mode (camera only)
        private val ZEN_ALLOWED_PACKAGES = setOf(
            "com.android.camera",           // Stock camera
            "com.android.camera2",          // Stock camera 2
            "com.google.android.GoogleCamera", // Google camera
            "com.samsung.android.camera",   // Samsung camera
            "com.sec.android.app.camera",   // Samsung camera alt
            "com.motorola.camera",          // Moto camera
            "com.oneplus.camera",           // OnePlus camera
            "com.oppo.camera",             // Oppo camera  
            "com.android.systemui",         // System UI (needed but monitored)
        )

        fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        /** Update the blocked packages list from Flutter side */
        fun updateBlockedPackages(context: Context, packages: Set<String>) {
            getPrefs(context).edit()
                .putStringSet(KEY_BLOCKED_PACKAGES, packages)
                .apply()
            Log.d(TAG, "Updated blocked packages: ${packages.size} apps")
            // Force the running service to invalidate its in-memory cache
            // immediately — avoids up to 5s of stale blocking after rule expiry.
            _instance?.invalidateCache()
        }

        /** Get currently blocked packages */
        fun getBlockedPackages(context: Context): Set<String> {
            return getPrefs(context).getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        }

        /** Update the set of timer-managed packages (apps that need a session prompt) */
        fun updateTimerPackages(context: Context, packages: Set<String>) {
            getPrefs(context).edit()
                .putStringSet(KEY_TIMER_PACKAGES, packages)
                .apply()
            Log.d(TAG, "Updated timer-managed packages: ${packages.size} apps")
            _instance?.invalidateCache()
        }

        /** Get timer-managed packages */
        fun getTimerPackages(context: Context): Set<String> {
            return getPrefs(context).getStringSet(KEY_TIMER_PACKAGES, emptySet()) ?: emptySet()
        }

        // ── Accessibility-driven foreground signal (precise, instant) ──
        // Set by SukoonAccessibilityService on every window-state change. Kept in
        // memory only (never persisted/sent). getForegroundPackage() prefers it
        // while fresh, so enforcement reacts the instant an app opens — no 3s
        // UsageStats blind spot.
        @Volatile
        var a11yForegroundPkg: String? = null
        @Volatile
        var a11yForegroundAt: Long = 0L

        /** Called by the accessibility service when the foreground app changes. */
        fun reportA11yForeground(pkg: String) {
            a11yForegroundPkg = pkg
            a11yForegroundAt = System.currentTimeMillis()
            // Nudge the running service to enforce immediately (event-driven),
            // instead of waiting for the next adaptive poll tick.
            val svc = _instance ?: return
            val h = svc.handler ?: return
            h.removeCallbacks(svc.pollRunnable)
            h.post(svc.pollRunnable)
        }

        /** Enable/disable Zen Mode lockdown — also controls DND */
        fun setZenMode(context: Context, active: Boolean) {
            getPrefs(context).edit().putBoolean(KEY_ZEN_MODE, active).apply()
            Log.d(TAG, "Zen Mode set to: $active")
            // Force the running service to pick up the change immediately
            _instance?.invalidateCache()
            
            // Control DND directly from service level
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.isNotificationPolicyAccessGranted) {
                    if (active) {
                        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                        Log.d(TAG, "DND ENABLED — total silence")
                    } else {
                        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                        Log.d(TAG, "DND DISABLED — notifications restored")
                    }
                } else {
                    Log.w(TAG, "DND: notification policy access NOT granted")
                }
            } catch (e: Exception) {
                Log.e(TAG, "DND control error: ${e.message}")
            }
        }

        /** Check if Zen Mode is active */
        fun isZenMode(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_ZEN_MODE, false)
        }

        /** Start the blocker service */
        fun start(context: Context) {
            getPrefs(context).edit().putBoolean(KEY_SERVICE_ENABLED, true).apply()
            val intent = Intent(context, AppBlockerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stop the blocker service */
        fun stop(context: Context) {
            getPrefs(context).edit().putBoolean(KEY_SERVICE_ENABLED, false).apply()
            context.stopService(Intent(context, AppBlockerService::class.java))
        }

        /** Check if service should be running */
        fun isEnabled(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_SERVICE_ENABLED, false)
        }

        // ═══════════════════════════════════════════════════════════════
        // 🕐 TIMED SESSION: Per-app time limits
        // The service polls foreground app. If the timed app is in front
        // and past the deadline, we launch a "time's up" overlay.
        // ═══════════════════════════════════════════════════════════════

        /** Start a timed session for a specific app */
        fun startTimedSession(context: Context, packageName: String, minutes: Int) {
            val now = System.currentTimeMillis()
            val endTime = now + (minutes * 60 * 1000L)
            getPrefs(context).edit()
                .putString(KEY_TIMED_SESSION_PKG, packageName)
                .putLong(KEY_TIMED_SESSION_START, now)
                .putLong(KEY_TIMED_SESSION_END, endTime)
                .putInt(KEY_TIMED_SESSION_EXTENSIONS, 0)
                .remove(KEY_ENDED_SESSION_PKG)
                .remove(KEY_ENDED_SESSION_TIME)
                .apply()
            Log.d(TAG, "Timed session started: $packageName for ${minutes}m (until $endTime)")

            // Schedule an exact alarm at deadline — this is the RELIABLE wakeup
            // that fires even in Doze mode. The polling loop is just a secondary
            // check for when the user is actively using the timed app.
            scheduleTimerAlarm(context, endTime)

            // Ensure service is running to enforce the timer
            if (!isEnabled(context)) {
                start(context)   // onStartCommand will buildNotification() with fresh state
            }
            // Refresh the notification immediately so it shows "Timer · AppName"
            _instance?.refreshNotification()
        }

        /** Extend the active timed session by additional minutes */
        fun extendTimedSession(context: Context, packageName: String, additionalMinutes: Int) {
            val prefs = getPrefs(context)
            val currentPkg = prefs.getString(KEY_TIMED_SESSION_PKG, null)
            if (currentPkg != packageName) return
            val currentEnd = prefs.getLong(KEY_TIMED_SESSION_END, 0L)
            val now = System.currentTimeMillis()
            // Extend from now (if overtime) or from current deadline
            val base = if (now > currentEnd) now else currentEnd
            val newEnd = base + (additionalMinutes * 60 * 1000L)
            val extensions = prefs.getInt(KEY_TIMED_SESSION_EXTENSIONS, 0) + 1
            prefs.edit()
                .putLong(KEY_TIMED_SESSION_END, newEnd)
                .putInt(KEY_TIMED_SESSION_EXTENSIONS, extensions)
                .apply()
            Log.d(TAG, "Timed session extended: $packageName +${additionalMinutes}m (ext #$extensions)")

            // Reschedule the exact alarm to the new deadline
            scheduleTimerAlarm(context, newEnd)

            _instance?.refreshNotification()
        }

        /** End the active timed session.
         *  Fully clears the session from SharedPreferences immediately.
         *  We also record the ended package + timestamp so the polling loop
         *  won't re-fire "times up" if the user quickly re-opens the app
         *  before a new startTimedSession call arrives. */
        private const val KEY_ENDED_SESSION_PKG = "ended_session_package"
        private const val KEY_ENDED_SESSION_TIME = "ended_session_time"
        private const val ENDED_GRACE_MS = 10_000L // 10s grace after ending

        fun endTimedSession(context: Context, packageName: String) {
            val prefs = getPrefs(context)
            val currentPkg = prefs.getString(KEY_TIMED_SESSION_PKG, null)
            if (currentPkg == null || currentPkg == packageName) {
                // Cancel the exact alarm — no more wakeups needed
                cancelTimerAlarm(context)

                // Fully clear the timed session so polling loop won't see it
                prefs.edit()
                    .remove(KEY_TIMED_SESSION_PKG)
                    .remove(KEY_TIMED_SESSION_START)
                    .remove(KEY_TIMED_SESSION_END)
                    .remove(KEY_TIMED_SESSION_EXTENSIONS)
                    // Record that we just ended this package (grace period)
                    .putString(KEY_ENDED_SESSION_PKG, packageName)
                    .putLong(KEY_ENDED_SESSION_TIME, System.currentTimeMillis())
                    .apply()
                Log.d(TAG, "Timed session fully ended: $packageName")
                // Refresh notification so it reverts to "Focus Mode" or "Sukoon"
                _instance?.refreshNotification()
            }
        }

        /** Check if a session was recently ended (within grace period).
         *  Used by polling loop to avoid re-firing times-up during transitions. */
        fun wasRecentlyEnded(context: Context, packageName: String): Boolean {
            val prefs = getPrefs(context)
            val endedPkg = prefs.getString(KEY_ENDED_SESSION_PKG, null) ?: return false
            if (endedPkg != packageName) return false
            val endedTime = prefs.getLong(KEY_ENDED_SESSION_TIME, 0L)
            return (System.currentTimeMillis() - endedTime) < ENDED_GRACE_MS
        }

        /** Get active timed session info (or null if none) */
        fun getTimedSession(context: Context): Triple<String, Long, Int>? {
            val prefs = getPrefs(context)
            val pkg = prefs.getString(KEY_TIMED_SESSION_PKG, null) ?: return null
            val endTime = prefs.getLong(KEY_TIMED_SESSION_END, 0L)
            val extensions = prefs.getInt(KEY_TIMED_SESSION_EXTENSIONS, 0)
            return Triple(pkg, endTime, extensions)
        }

        // ═══════════════════════════════════════════════════════════════
        // ⏰ EXACT ALARM — battery-efficient deadline trigger
        // Instead of polling every 500ms forever, we schedule one alarm
        // at the exact endTime. When it fires, we check if the timed app
        // is still in the foreground and show the "time's up" overlay.
        // The polling loop is reduced to TIMER_ONLY_POLL_INTERVAL_MS (3s)
        // as a secondary fallback for when the user is actively switching.
        // ═══════════════════════════════════════════════════════════════

        const val ACTION_TIMER_EXPIRED = "com.sukoon.launcher.TIMER_EXPIRED"
        private const val TIMER_ALARM_REQUEST_CODE = 9001

        /** Schedule an exact alarm at the timer deadline.
         *  Uses setExactAndAllowWhileIdle — fires even in Doze. */
        fun scheduleTimerAlarm(context: Context, triggerAtMillis: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TimerAlarmReceiver::class.java).apply {
                action = ACTION_TIMER_EXPIRED
            }
            val pi = PendingIntent.getBroadcast(
                context, TIMER_ALARM_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (am.canScheduleExactAlarms()) {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                    } else {
                        // Fallback — set inexact but still allow while idle
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                    }
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
                Log.d(TAG, "Timer alarm scheduled at $triggerAtMillis (${(triggerAtMillis - System.currentTimeMillis()) / 1000}s from now)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule timer alarm: ${e.message}")
            }
        }

        /** Cancel any pending timer alarm. */
        fun cancelTimerAlarm(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TimerAlarmReceiver::class.java).apply {
                action = ACTION_TIMER_EXPIRED
            }
            val pi = PendingIntent.getBroadcast(
                context, TIMER_ALARM_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
            Log.d(TAG, "Timer alarm cancelled")
        }
    }

    // Use a background HandlerThread for polling — keeps main thread free
    // for UI work (overlay management, intents). This prevents jank.
    private var pollThread: HandlerThread? = null
    private var handler: Handler? = null
    // Main thread handler — only for operations that MUST run on main thread
    // (overlay add/remove, startActivity)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private var lastSukoonForegroundAt: Long = 0
    private var statusBarOverlay: View? = null
    private var navBarOverlay: View? = null
    
    // Cached state — avoids SharedPreferences reads on every poll
    private var cachedIsZen = false
    private var cachedBlockedPackages: Set<String> = emptySet()
    private var cacheLastRefresh: Long = 0
    private val CACHE_TTL_MS = 5000L
    private var consecutiveIdlePolls = 0
    private var isScreenOn = true

    // Notification refresh — update every 60s when timer active (shows countdown)
    private var lastNotifRefresh: Long = 0
    private val NOTIF_REFRESH_MS = 60_000L

    /** Force-refresh the in-memory cache from SharedPreferences.
     *  Called by companion updateBlockedPackages() / setZenMode() so that
     *  the very next poll uses the fresh data — zero staleness. */
    fun invalidateCache() {
        cachedIsZen = isZenMode(this)
        cachedBlockedPackages = getBlockedPackages(this)
        cacheLastRefresh = System.currentTimeMillis()
        Log.d(TAG, "Cache force-invalidated: zen=$cachedIsZen, blocked=${cachedBlockedPackages.size}")
    }

    /**
     * BroadcastReceiver for screen ON/OFF events.
     * - During Zen Mode: shows ZenLockScreenActivity on screen-on.
     * - Always: pauses/resumes foreground polling when screen turns off/on
     *   to save significant battery (no point polling when display is dark).
     */
    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON -> {
                    isScreenOn = true
                    // Resume polling on the background thread
                    handler?.removeCallbacks(pollRunnable)
                    handler?.post(pollRunnable)
                    Log.d(TAG, "Screen ON — polling resumed")

                    if (isZenMode(context)) {
                        mainHandler.postDelayed({
                            try {
                                ZenLockScreenActivity.show(context)
                                Log.d(TAG, "ZenLockScreenActivity shown over keyguard (screen ON)")
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to show ZenLockScreenActivity: ${e.message}")
                            }
                        }, 200)
                    }
                }
                Intent.ACTION_SCREEN_OFF -> {
                    isScreenOn = false
                    // Stop polling entirely — nothing to monitor when screen is off
                    handler?.removeCallbacks(pollRunnable)
                    Log.d(TAG, "Screen OFF — polling paused (battery saver)")
                }
            }
        }
    }
    private var screenStateReceiverRegistered = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            
            // Refresh cached state periodically (not every poll)
            val now = System.currentTimeMillis()
            if (now - cacheLastRefresh > CACHE_TTL_MS) {
                val prevIsZen = cachedIsZen
                val prevBlocked = cachedBlockedPackages.size
                cachedIsZen = isZenMode(this@AppBlockerService)
                cachedBlockedPackages = getBlockedPackages(this@AppBlockerService)
                cacheLastRefresh = now

                // React to Zen Mode transitions (overlay management — must run on main thread)
                if (cachedIsZen && !prevIsZen) {
                    mainHandler.post { addStatusBarOverlay() }
                    Log.d(TAG, "Zen Mode ON — overlays added")
                } else if (!cachedIsZen && prevIsZen) {
                    mainHandler.post { removeStatusBarOverlay() }
                    refreshNotification()  // Revert to "Focus Mode" or "Sukoon" when Zen ends
                    try {
                        ZenLockScreenActivity.dismiss(this@AppBlockerService)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error dismissing ZenLockScreen: ${e.message}")
                    }
                    Log.d(TAG, "Zen Mode OFF — overlays removed")
                } else if (cachedBlockedPackages.size != prevBlocked) {
                    refreshNotification()  // "X apps blocked" count changed
                }
            }

            // Refresh notification countdown while a timer session is active
            val hasActiveTimer = getTimedSession(this@AppBlockerService) != null
            if (hasActiveTimer && (now - lastNotifRefresh) >= NOTIF_REFRESH_MS) {
                lastNotifRefresh = now
                refreshNotification()  // Updates "Xm left · tap to return"
            }
            
            checkForegroundApp()
            
            // ── ADAPTIVE INTERVAL — key to battery optimization ──
            // Zen Mode: 200ms (must be instant)
            // Blocked apps active: 500ms (user could open blocked app any time)
            // Timer ONLY (no blocked apps): 3s — AlarmManager is the primary
            //   trigger; polling is just a secondary check for foreground state
            // Idle on home: 10s — nothing to monitor
            val hasBlockedApps = cachedBlockedPackages.isNotEmpty()
            val interval = when {
                cachedIsZen -> ZEN_POLL_INTERVAL_MS
                hasBlockedApps -> POLL_INTERVAL_MS  // 500ms — blocked apps need fast detection
                hasActiveTimer -> TIMER_ONLY_POLL_INTERVAL_MS  // 3s — alarm handles deadline
                consecutiveIdlePolls > 3 -> IDLE_POLL_INTERVAL_MS  // 10s ramp-down
                else -> POLL_INTERVAL_MS
            }

            // Service stays alive while there are blocked apps or a timer running.
            // When idle (no blocked apps, no timer, no zen), the service auto-stops
            // in checkForegroundApp() to save battery.

            handler?.postDelayed(this, interval)
        }
    }

    override fun onCreate() {
        super.onCreate()
        _instance = this
        createNotificationChannel()

        // Start a dedicated background thread for polling.
        // Keeps the main thread completely free for UI rendering.
        pollThread = HandlerThread("AppBlockerPoll").also { it.start() }
        handler = Handler(pollThread!!.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")

        // ── Immediate bail-out: if there's nothing to do, don't even show
        //    the foreground notification. Stop immediately to avoid the
        //    "Running in background" OS notification that alarms users.
        val hasBlockedApps = getBlockedPackages(this).isNotEmpty()
        val hasTimedSession = getTimedSession(this) != null
        val isZen = isZenMode(this)
        if (!hasBlockedApps && !hasTimedSession && !isZen) {
            Log.d(TAG, "Service started with nothing to do — stopping immediately")
            getPrefs(this).edit().putBoolean(KEY_SERVICE_ENABLED, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true

        // Always register screen state receiver — pauses polling when screen
        // is off to save battery (biggest single optimization)
        registerScreenStateReceiver()

        // Check actual screen state at start — don't poll while screen is off
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        isScreenOn = pm.isInteractive
        if (isScreenOn) {
            handler?.post(pollRunnable)
        } else {
            Log.d(TAG, "Screen is OFF at service start — polling deferred until screen-on")
        }

        // If Zen Mode is active, enforce DND, add overlay
        if (isZenMode(this)) {
            addStatusBarOverlay()
            // Re-enforce DND on service restart (e.g. after reboot)
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.isNotificationPolicyAccessGranted) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    Log.d(TAG, "DND re-enforced on service start")
                }
            } catch (e: Exception) {
                Log.e(TAG, "DND re-enforce error: ${e.message}")
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service stopped")
        _instance = null
        isRunning = false
        handler?.removeCallbacks(pollRunnable)
        // Quit the background poll thread — releases the thread entirely
        pollThread?.quitSafely()
        pollThread = null
        handler = null
        removeStatusBarOverlay()
        unregisterScreenStateReceiver()
        
        // Cancel any pending timer alarm — no zombie wakeups
        cancelTimerAlarm(this)
        
        // Restore DND when service stops
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                Log.d(TAG, "DND restored on service destroy")
            }
        } catch (e: Exception) {
            Log.e(TAG, "DND restore error: ${e.message}")
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        // ── SENIOR LOGIC: Launcher Guard ──
        // Only providing these premium lifestyle features when Sukoon is the default launcher.
        // This stops battery drain when the user isn't actively using our interface.
        if (!isSukoonDefaultLauncher()) {
            Log.d(TAG, "Not default launcher — stopping blocker service to save battery")
            stop(this)
            return
        }

        val isZen = cachedIsZen
        val blockedPackages = cachedBlockedPackages
        val hasTimedSession = getTimedSession(this) != null
        val timerPackages = getTimerPackages(this)

        // If nothing to monitor, stop the service to save battery
        if (!isZen && blockedPackages.isEmpty() && !hasTimedSession && timerPackages.isEmpty()) {
            Log.d(TAG, "Nothing to monitor — auto-stopping service")
            stop(this)
            return
        }

        val now = System.currentTimeMillis()
        val foregroundPackage = getForegroundPackage() ?: return

        // 1. Safe zone (Self, etc.)
        if (foregroundPackage == packageName || 
            foregroundPackage == "android" || 
            foregroundPackage == "com.android.systemui") {
            
            if (foregroundPackage == packageName) {
                lastSukoonForegroundAt = now
            }
            
            lastBlockedPackage = null
            consecutiveIdlePolls++
            return
        }
        consecutiveIdlePolls = 0


        // 2. Timed Session Check (Priority 1)
        val session = getTimedSession(this)
        if (session != null) {
            val (pkg, endTime, extensions) = session
            if (now >= endTime && foregroundPackage == pkg) {
                // Throttle: avoid intent storms
                if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 5000) return
                
                Log.d(TAG, "TIMED SESSION EXPIRED: $pkg — blocking")
                lastBlockedPackage = foregroundPackage
                lastBlockTime = now

                val sessionStart = getPrefs(this).getLong(KEY_TIMED_SESSION_START, endTime - 60000L)
                val minutesSpent = ((now - sessionStart) / 60000L).toInt().coerceAtLeast(1)

                // End session natively and notify Flutter via MainActivity
                endTimedSession(this@AppBlockerService, pkg)
                
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("times_up", true)
                    putExtra("timed_package", pkg)
                    putExtra("extensions_used", extensions)
                    putExtra("minutes_spent", minutesSpent)
                }
                mainHandler.post { startActivity(intent) }
                return
            }
        }

        // 3. Zen Mode (Priority 2)
        if (isZen) {
            // Block everything except Phone/Dialer/Camera
            val isAllowed = ZEN_ALLOWED_PACKAGES.contains(foregroundPackage) ||
                           foregroundPackage.contains("dialer") ||
                           foregroundPackage.contains("phone") ||
                           foregroundPackage.contains("camera")
                           
            if (!isAllowed) {
                if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 500) return
                Log.d(TAG, "ZEN BLOCK: $foregroundPackage")
                lastBlockedPackage = foregroundPackage
                lastBlockTime = now
                // Back to Sukoon
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                mainHandler.post { startActivity(intent) }
                return
            }
        }

        // 4. Blocked Collections (Priority 3)
        if (blockedPackages.contains(foregroundPackage)) {
            if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 1000) return
            Log.d(TAG, "ACCESS DENIED: $foregroundPackage")
            lastBlockedPackage = foregroundPackage
            lastBlockTime = now
            showBlockedOverlay(foregroundPackage)
            return
        }

        // 5. Timer-Managed App — opened from recents/notification WITHOUT active session (Priority 4)
        // When a timer-configured app is detected in the foreground with no active timed session,
        // redirect the user back to Sukoon so Flutter can show the "How long?" timer prompt.
        if (timerPackages.contains(foregroundPackage) && !hasTimedSession) {
            // Guard: Recent switch to Sukoon Home
            // Some devices report the OLD foreground package in UsageStats for ~500-1000ms 
            // after the user has already swiped to the Home screen.
            if (now - lastSukoonForegroundAt < 800) {
                return
            }
            if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 5000) return
            Log.d(TAG, "TIMER APP WITHOUT SESSION: $foregroundPackage — redirecting for prompt")
            lastBlockedPackage = foregroundPackage
            lastBlockTime = now

            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("prompt_timer", true)
                putExtra("timer_package", foregroundPackage)
            }
            mainHandler.post { startActivity(intent) }
        }
    }

    private fun isSukoonDefaultLauncher(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            resolveInfo?.activityInfo?.packageName == packageName
        } catch (e: Exception) {
            false
        }
    }

    private fun showBlockedOverlay(pkg: String) {
        val intent = Intent(this, BlockedAppActivity::class.java).apply {
            putExtra("blocked_package", pkg)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }
        mainHandler.post { startActivity(intent) }
    }

    /**
     * Register screen ON/OFF receiver — ALWAYS registered when service runs.
     * Handles: (1) pausing/resuming poll loop on screen off/on (battery saver)
     *          (2) showing ZenLockScreen on screen-on during Zen Mode
     */
    private fun registerScreenStateReceiver() {
        if (screenStateReceiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            registerReceiver(screenStateReceiver, filter)
            screenStateReceiverRegistered = true
            Log.d(TAG, "Screen state receiver registered (battery optimized polling)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register screen state receiver: ${e.message}")
        }
    }

    private fun unregisterScreenStateReceiver() {
        if (!screenStateReceiverRegistered) return
        try {
            unregisterReceiver(screenStateReceiver)
            screenStateReceiverRegistered = false
            Log.d(TAG, "Screen state receiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister screen state receiver: ${e.message}")
        }
    }

    /**
     * Add an invisible overlay at the top of the screen to intercept
     * notification panel swipe-down gesture.
     * Requires SYSTEM_ALERT_WINDOW permission.
     */
    private fun addStatusBarOverlay() {
        if (statusBarOverlay != null) return  // Already added

        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot add overlays: SYSTEM_ALERT_WINDOW not granted")
            return
        }

        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
            }

            // ─── TOP OVERLAY: Block notification shade pull-down ───
            statusBarOverlay = View(this).apply {
                setBackgroundColor(0x01000000) // Nearly invisible
                isClickable = true  // Consumes touch events
                isFocusable = false
            }

            val topParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                150,  // Tall enough to catch swipe-down gesture
                overlayType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 0
            }

            wm.addView(statusBarOverlay, topParams)
            Log.d(TAG, "TOP overlay ADDED (150px) — notification shade blocked")

            // ─── BOTTOM OVERLAY: Block recent apps / home swipe-up ───
            navBarOverlay = View(this).apply {
                setBackgroundColor(0x01000000) // Nearly invisible
                isClickable = true  // Consumes touch events
                isFocusable = false
            }

            val bottomParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                150,  // Tall enough to catch swipe-up gesture
                overlayType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.START
                x = 0
                y = 0
            }

            wm.addView(navBarOverlay, bottomParams)
            Log.d(TAG, "BOTTOM overlay ADDED (150px) — recent apps gesture blocked")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlays: ${e.message}")
        }
    }

    /**
     * Remove all overlays when Zen Mode ends.
     */
    private fun removeStatusBarOverlay() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        statusBarOverlay?.let { overlay ->
            try {
                wm.removeView(overlay)
                Log.d(TAG, "TOP overlay REMOVED")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing top overlay: ${e.message}")
            }
        }
        statusBarOverlay = null

        navBarOverlay?.let { overlay ->
            try {
                wm.removeView(overlay)
                Log.d(TAG, "BOTTOM overlay REMOVED")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing bottom overlay: ${e.message}")
            }
        }
        navBarOverlay = null
    }

    /**
     * Get the foreground package using UsageStatsManager.
     *
     * Strategy (precision mode):
     *  1. Query usage EVENTS for the last 10 seconds — look for the most
     *     recent ACTIVITY_RESUMED / MOVE_TO_FOREGROUND event.
     *  2. If no event found (user has been in the same app longer than 10s),
     *     fall back to queryUsageStats() and pick the app with the most
     *     recent lastTimeUsed — this always returns data even if the user
     *     hasn't switched apps.
     */
    private fun getForegroundPackage(): String? {
        // Prefer the accessibility-reported foreground app while it's fresh — it
        // is instant and precise, and covers the UsageStats 3s blind spot. Falls
        // back to UsageStats events when accessibility is off or stale.
        val aPkg = a11yForegroundPkg
        if (aPkg != null && System.currentTimeMillis() - a11yForegroundAt < 4_000L) {
            return aPkg
        }
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()

            // ── Attempt 1: Recent events (most accurate, sub-second)
            // Narrow window to 3s to avoid heavy system work when user is
            // performing UI gestures (swipes). Using a short event window
            // reduces Binder IPC and prevents UI jank observed during swipes.
            val usageEvents = usageStatsManager.queryEvents(now - 3_000, now)
            var lastForegroundPackage: String? = null
            var lastTimestamp: Long = 0

            val event = android.app.usage.UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == 1 /* MOVE_TO_FOREGROUND */) {
                    if (event.timeStamp > lastTimestamp) {
                        lastTimestamp = event.timeStamp
                        lastForegroundPackage = event.packageName
                    }
                }
            }
            if (lastForegroundPackage != null) return lastForegroundPackage
            // If no recent events found, return null — this avoids the
            // expensive queryUsageStats() fallback which can block system
            // services and produce UI jank during gestures.
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Error getting foreground package: ${e.message}")
            return null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Delete old channels only if the new channel doesn't exist yet.
            // Prevents redundant Binder IPC on every service start.
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.deleteNotificationChannel("app_blocker_channel")
                manager.deleteNotificationChannel("sukoon_focus_v2")
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Sukoon Focus",
                    NotificationManager.IMPORTANCE_LOW   // LOW = in shade but no status bar icon (less intrusive)
                ).apply {
                    description = "Shows active focus state — app timer, blocked apps"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    setSound(null, null)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    /** Rebuild and re-post the foreground notification to reflect current state.
     *  Called on service start and whenever state changes (session start/end, Zen toggle). */
    fun refreshNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to refresh notification: ${e.message}")
        }
    }

    private fun buildNotification(): Notification {
        val blockedPackages = getBlockedPackages(this)
        val session = getTimedSession(this)
        val isZen = isZenMode(this)

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Determine title + text based on priority: Timer > Zen > Blocker ──
        val hasActiveWork = session != null || isZen || blockedPackages.isNotEmpty()

        val (title, text) = when {
            session != null -> {
                val (pkg, endTime, _) = session
                val appName = try {
                    packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
                } catch (_: Exception) { pkg.split(".").last() }
                val minsLeft = ((endTime - System.currentTimeMillis()) / 60_000L).coerceAtLeast(0)
                val timeLabel = if (minsLeft > 0) "${minsLeft}m left" else "Time's up"
                "Timer · $appName" to "$timeLabel · tap to return"
            }
            isZen -> {
                "Muraqaba" to "Stay focused — all apps blocked"
            }
            blockedPackages.isNotEmpty() -> {
                "Focus Mode" to "${blockedPackages.size} app${if (blockedPackages.size > 1) "s" else ""} blocked · Stay on track"
            }
            else -> {
                // Should not reach here (service auto-stops when idle),
                // but if it does, use minimal invisible notification.
                "Sukoon" to null
            }
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .apply { if (text != null) setContentText(text) }
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .setPriority(if (hasActiveWork) NotificationCompat.PRIORITY_LOW else NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(if (hasActiveWork) NotificationCompat.VISIBILITY_PUBLIC else NotificationCompat.VISIBILITY_SECRET)
            .build()
    }
}
