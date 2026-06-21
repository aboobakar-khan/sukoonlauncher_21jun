package com.sukoon.launcher

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sukoon.launcher/launcher"
    private val APP_SETTINGS_CHANNEL = "app_settings"
    private val USAGE_STATS_CHANNEL = "com.sukoon.launcher/usage_stats"
    private val BLOCKER_CHANNEL = "com.sukoon.launcher/app_blocker"
    private val DND_CHANNEL = "com.sukoon.launcher/dnd"
    private val ALARM_ACTIVITY_CHANNEL = "com.sukoon.launcher/alarm_activity"
    private val NOTIFICATION_FILTER_CHANNEL = "com.sukoon.launcher/notification_filter"
    private val NAVIGATION_CHANNEL = "com.sukoon.launcher/navigation"
    private var flashlightOn = false

    private var pendingTimesUp: Intent? = null
    private var pendingNotificationFeed: Boolean = false
    private var pendingPromptTimer: Intent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge: tell the framework NOT to fit system windows so
        // Flutter can draw behind the status bar and navigation bar.
        // WindowCompat.setDecorFitsSystemWindows is the modern, non-deprecated
        // way to achieve this on all API levels (no window.statusBarColor needed).
        WindowCompat.setDecorFitsSystemWindows(window, false)

        handleZenLockIntent(intent)
        handleTimesUpIntent(intent)
        handlePromptTimerIntent(intent)
        handleNotificationFeedIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleZenLockIntent(intent)
        handleTimesUpIntent(intent)
        handlePromptTimerIntent(intent)
        handleNotificationFeedIntent(intent)
        // When the user presses the home button while in an external app,
        // Android re-delivers ACTION_MAIN + CATEGORY_HOME to the launcher.
        // Forward this to Flutter so LauncherShell can snap back to the
        // home page and pop any pushed sub-routes (Settings, Prayer, etc.).
        handleGoHomeIntent(intent)
    }

    /** Tell Flutter to go to the home page when the home button is pressed. */
    private fun handleGoHomeIntent(intent: Intent?) {
        val isHomeIntent = intent?.action == Intent.ACTION_MAIN &&
            intent.hasCategory(Intent.CATEGORY_HOME)
        if (!isHomeIntent) return
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, NAVIGATION_CHANNEL)
                    .invokeMethod("goHome", null)
                Log.d("MainActivity", "goHome sent to Flutter (home button press)")
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "goHome channel not ready: ${e.message}")
        }
    }

    /** Handle notification hint tap — open notification feed */
    private fun handleNotificationFeedIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("open_notification_feed", false) == true) {
            intent.removeExtra("open_notification_feed")
            Log.d("MainActivity", "Notification feed intent received")
            // Try to send immediately (if Flutter engine is ready).
            // NOTE: flutterEngine getter throws NPE when called before
            // super.onCreate() because the delegate is not yet initialised.
            // Use try/catch so this is safe in both onCreate and onNewIntent.
            try {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, NOTIFICATION_FILTER_CHANNEL)
                        .invokeMethod("openNotificationFeed", null)
                    Log.d("MainActivity", "Notification feed sent to Flutter immediately")
                    return  // delivered — no need to set pending flag
                }
            } catch (_: Exception) {
                // Engine not ready yet (e.g. cold start) — fall through
            }
            // Engine wasn't ready; configureFlutterEngine will deliver it
            pendingNotificationFeed = true
        }
    }

    /** Handle "time's up" intent from AppBlockerService timed session */
    private fun handleTimesUpIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("times_up", false) == true) {
            pendingTimesUp = intent
            Log.d("MainActivity", "Times up intent received for: ${intent.getStringExtra("timed_package")}")
        }
    }

    /** Handle "prompt_timer" intent from AppBlockerService */
    private fun handlePromptTimerIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("prompt_timer", false) == true) {
            pendingPromptTimer = intent
            Log.d("MainActivity", "Prompt timer intent received for: ${intent.getStringExtra("timer_package")}")
        }
    }

    private fun handleZenLockIntent(intent: Intent?) {
        val zenLockActive = intent?.getBooleanExtra("zen_lock_active", false) ?: false
        if (zenLockActive || AppBlockerService.isZenMode(this)) {
            Log.d("MainActivity", "Zen lock intent received — showing over lock screen")
            // Ensure we display over the keyguard so the Zen countdown is visible
            // without requiring the user to unlock
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }


    private fun prefs(): SharedPreferences =
        getSharedPreferences("prayer_alarm_prefs", Context.MODE_PRIVATE)

    // ─────────────────────────────────────────────────────────────────────

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Timezone channel (replaces flutter_timezone plugin) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sukoon/timezone").setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> {
                    result.success(java.util.TimeZone.getDefault().id)
                }
                else -> result.notImplemented()
            }
        }
        
        // ── App Blocker Service channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        AppBlockerService.start(this)
                        Log.d("AppBlocker", "Service started from Flutter")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Could not start blocker service: ${e.message}", null)
                    }
                }
                "stopService" -> {
                    try {
                        AppBlockerService.stop(this)
                        Log.d("AppBlocker", "Service stopped from Flutter")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Could not stop blocker service: ${e.message}", null)
                    }
                }
                "updateBlockedPackages" -> {
                    try {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppBlockerService.updateBlockedPackages(this, packages.toSet())
                        
                        if (packages.isNotEmpty()) {
                            // Start service if not running — there are apps to block
                            if (!AppBlockerService.isEnabled(this)) {
                                AppBlockerService.start(this)
                            } else {
                                // Refresh notification text ("X apps blocked" count changed)
                                AppBlockerService.getRunningInstance()?.refreshNotification()
                            }
                        } else {
                            // No apps to block — stop the service to save battery,
                            // UNLESS there's an active timer or Zen Mode running
                            val hasTimedSession = AppBlockerService.getTimedSession(this) != null
                            val isZen = AppBlockerService.isZenMode(this)
                            if (!hasTimedSession && !isZen && AppBlockerService.isEnabled(this)) {
                                AppBlockerService.stop(this)
                                Log.d("AppBlocker", "No blocked packages — service stopped to save battery")
                            } else {
                                AppBlockerService.getRunningInstance()?.refreshNotification()
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", "Could not update blocked packages: ${e.message}", null)
                    }
                }
                "updateTimerPackages" -> {
                    try {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppBlockerService.updateTimerPackages(this, packages.toSet())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", "Could not update timer packages: ${e.message}", null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(AppBlockerService.isEnabled(this))
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open usage access settings", null)
                    }
                }
                "hasNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        result.success(
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED
                        )
                    } else {
                        result.success(true) // Not needed pre-Android 13
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                // ── Zen Mode Methods ──
                "setZenMode" -> {
                    try {
                        val active = call.argument<Boolean>("active") ?: false
                        AppBlockerService.setZenMode(this, active)
                        
                        if (active) {
                            // Ensure service is running for Zen Mode
                            if (!AppBlockerService.isEnabled(this)) {
                                AppBlockerService.start(this)
                            }
                            // Enable lock screen bypass — app shows over keyguard
                            enableZenLockScreen()
                            // Show ZenLockScreenActivity so power-button-wake shows Zen UI
                            ZenLockScreenActivity.show(this)
                        } else {
                            // Disable lock screen bypass
                            disableZenLockScreen()
                            // Dismiss Zen lock screen overlay
                            ZenLockScreenActivity.dismiss(this)
                        }
                        
                        Log.d("AppBlocker", "Zen Mode set to: $active")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ZEN_ERROR", "Failed to set Zen Mode: ${e.message}", null)
                    }
                }
                "enableZenLockScreen" -> {
                    try {
                        enableZenLockScreen()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to enable lock screen mode: ${e.message}", null)
                    }
                }
                "disableZenLockScreen" -> {
                    try {
                        disableZenLockScreen()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to disable lock screen mode: ${e.message}", null)
                    }
                }
                "enterFullImmersive" -> {
                    try {
                        enterFullImmersive()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMMERSIVE_ERROR", e.message, null)
                    }
                }
                "exitFullImmersive" -> {
                    try {
                        exitFullImmersive()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMMERSIVE_ERROR", e.message, null)
                    }
                }
                "temporaryUnpin" -> {
                    // Temporarily unpin screen for emergency call / camera
                    // onResume will re-pin when user returns
                    try {
                        stopLockTask()
                        isZenPinned = false
                        Log.d("ZenLock", "Temporarily UNPINNED for allowed action")
                        result.success(true)
                    } catch (e: Exception) {
                        isZenPinned = false
                        result.success(true) // Don't block the action
                    }
                }
                "openCamera" -> {
                    try {
                        // Unpin first (safe for non-zen too — just a no-op if not pinned)
                        try { stopLockTask(); isZenPinned = false } catch (_: Exception) { isZenPinned = false }
                        
                        // Open camera in FULL mode (not ACTION_IMAGE_CAPTURE which
                        // opens a restricted single-shot-then-return mode)
                        val cameraIntent = Intent(android.provider.MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
                        cameraIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (cameraIntent.resolveActivity(packageManager) != null) {
                            startActivity(cameraIntent)
                            result.success(true)
                        } else {
                            // Fallback: try known camera packages
                            val cameraPackages = listOf(
                                "com.android.camera",
                                "com.android.camera2", 
                                "com.google.android.GoogleCamera",
                                "com.samsung.android.camera",
                                "com.sec.android.app.camera",
                                "com.oneplus.camera",
                                "com.oppo.camera",
                                "com.coloros.camera",
                                "com.motorola.camera",
                                "com.realme.camera"
                            )
                            var launched = false
                            for (pkg in cameraPackages) {
                                val intent = packageManager.getLaunchIntentForPackage(pkg)
                                if (intent != null) {
                                    startActivity(intent)
                                    launched = true
                                    break
                                }
                            }
                            result.success(launched)
                        }
                    } catch (e: Exception) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open overlay settings: ${e.message}", null)
                    }
                }
                "lockScreen" -> {
                    try {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
                        val adminComponent = android.content.ComponentName(this, SukoonDeviceAdmin::class.java)
                        if (dpm.isAdminActive(adminComponent)) {
                            dpm.lockNow()
                            result.success(true)
                        } else {
                            // Device admin not granted — send Flutter a special code so it can show the prompt
                            result.success("needs_admin")
                        }
                    } catch (e: Exception) {
                        result.success("needs_admin")
                    }
                }
                "requestDeviceAdmin" -> {
                    try {
                        val adminComponent = android.content.ComponentName(this, SukoonDeviceAdmin::class.java)
                        val intent = Intent(android.app.admin.DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(android.app.admin.DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                            putExtra(android.app.admin.DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Allows Sukoon to lock your screen when you double-tap the home screen.")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open device admin settings: ${e.message}", null)
                    }
                }
                "isDeviceAdminActive" -> {
                    try {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
                        val adminComponent = android.content.ComponentName(this, SukoonDeviceAdmin::class.java)
                        result.success(dpm.isAdminActive(adminComponent))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "toggleFlashlight" -> {
                    try {
                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                        val cameraId = cameraManager.cameraIdList[0]
                        flashlightOn = !flashlightOn
                        cameraManager.setTorchMode(cameraId, flashlightOn)
                        result.success(flashlightOn)
                    } catch (e: Exception) {
                        result.error("FLASHLIGHT_ERROR", e.message, null)
                    }
                }
                // ── Timed Session Methods (App Time Intent) ──
                "startTimedSession" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val minutes = call.argument<Int>("minutes") ?: 15
                        AppBlockerService.startTimedSession(this, packageName, minutes)
                        // Ensure blocker service is running to enforce the timer
                        if (!AppBlockerService.isEnabled(this)) {
                            AppBlockerService.start(this)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SESSION_ERROR", "Failed to start timed session: ${e.message}", null)
                    }
                }
                "extendTimedSession" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val additionalMinutes = call.argument<Int>("additionalMinutes") ?: 5
                        AppBlockerService.extendTimedSession(this, packageName, additionalMinutes)
                        // Refresh notification so timer countdown updates immediately
                        AppBlockerService.getRunningInstance()?.refreshNotification()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SESSION_ERROR", "Failed to extend timed session: ${e.message}", null)
                    }
                }
                "endTimedSession" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        AppBlockerService.endTimedSession(this, packageName)
                        // Refresh so notification reverts to "Focus Mode" or "Sukoon Active"
                        AppBlockerService.getRunningInstance()?.refreshNotification()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SESSION_ERROR", "Failed to end timed session: ${e.message}", null)
                    }
                }
                "getPendingTimesUp" -> {
                    val intent = pendingTimesUp
                    if (intent != null) {
                        val data = mapOf(
                            "packageName" to (intent.getStringExtra("timed_package") ?: ""),
                            "extensionsUsed" to intent.getIntExtra("extensions_used", 0),
                            "minutesSpent" to intent.getIntExtra("minutes_spent", 0)
                        )
                        pendingTimesUp = null
                        result.success(data)
                    } else {
                        result.success(null)
                    }
                }
                "getPendingPromptTimer" -> {
                    val intent = pendingPromptTimer
                    if (intent != null) {
                        val data = mapOf(
                            "packageName" to (intent.getStringExtra("timer_package") ?: "")
                        )
                        pendingPromptTimer = null
                        result.success(data)
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Launcher settings channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openHomeLauncherSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open home settings: ${e.message}", null)
                    }
                }
                "isDefaultLauncher" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN)
                        intent.addCategory(Intent.CATEGORY_HOME)
                        val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                        val currentDefault = resolveInfo?.activityInfo?.packageName
                        result.success(currentDefault == packageName)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Usage Stats channel for Screen Time Analytics
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open usage access settings", null)
                    }
                }
                "getUsageStats" -> {
                    // Run on a background thread to avoid blocking the
                    // platform (UI) thread.  queryEvents iterates every
                    // UsageEvent in the window — can take 50-200 ms for a
                    // 7-day range, which is enough to drop 3-12 animation
                    // frames if run synchronously on the main thread.
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    if (!hasUsageStatsPermission()) {
                        result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val usageStats = getUsageStats(startTime, endTime)
                            Handler(Looper.getMainLooper()).post { result.success(usageStats) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                            }
                        }
                    }.start()
                }
                "getDailyUsageStats" -> {
                    val days = call.argument<Int>("days") ?: 7
                    if (!hasUsageStatsPermission()) {
                        result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val dailyStats = getDailyUsageStats(days)
                            Handler(Looper.getMainLooper()).post { result.success(dailyStats) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("ERROR", "Failed to get daily usage stats: ${e.message}", null)
                            }
                        }
                    }.start()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // App settings channel for uninstall
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "uninstallApp" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = Intent(Intent.ACTION_DELETE)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("UNAVAILABLE", "No app found to handle uninstall", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not uninstall app: ${e.message}", null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("UNAVAILABLE", "No app found to handle app settings", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open app settings: ${e.message}", null)
                    }
                }
                "launchGooglePay" -> {
                    try {
                        val packageNames = listOf(
                            "com.google.android.apps.nbu.paisa.user",
                            "com.google.android.apps.pay",
                            "com.google.android.apps.walletnfchost",
                            "com.google.android.gms"
                        )
                        
                        var launched = false
                        for (packageName in packageNames) {
                            try {
                                val intent = packageManager.getLaunchIntentForPackage(packageName)
                                if (intent != null) {
                                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    startActivity(intent)
                                    launched = true
                                    break
                                }
                            } catch (e: Exception) {
                                // Try next package name
                            }
                        }
                        
                        if (!launched) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW)
                                intent.data = Uri.parse("https://pay.google.com")
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                launched = true
                            } catch (e: Exception) {
                                // Fallback failed
                            }
                        }
                        
                        if (launched) {
                            result.success(true)
                        } else {
                            result.error("UNAVAILABLE", "Google Pay app not found", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not launch Google Pay: ${e.message}", null)
                    }
                }
                "expandNotifications" -> {
                    try {
                        @Suppress("WrongConstant")
                        val sbService = getSystemService("statusbar")
                        val statusBarClass = Class.forName("android.app.StatusBarManager")
                        val expandMethod = statusBarClass.getMethod("expandNotificationsPanel")
                        expandMethod.invoke(sbService)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not expand notifications: ${e.message}", null)
                    }
                }
                "openClock" -> {
                    try {
                        val intent = Intent(android.provider.AlarmClock.ACTION_SHOW_ALARMS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open clock: ${e.message}", null)
                    }
                }
                // ── Deep-link directly to specific Android permission settings ──
                "openPermissionSettings" -> {
                    try {
                        val permType = call.argument<String>("type") ?: "app"
                        val pkg = packageName
                        val intent: Intent = when (permType) {
                            // Location → App location permission page
                            "location" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$pkg")
                            }
                            // Notifications → App notification settings (Android 8+)
                            "notification" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                                }
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$pkg")
                                }
                            }
                            // Exact alarms → Alarms & Reminders page (Android 12+)
                            "exact_alarm" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                    data = Uri.parse("package:$pkg")
                                }
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$pkg")
                                }
                            }
                            // Draw over other apps → Display over other apps page
                            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                data = Uri.parse("package:$pkg")
                            }
                            // Usage access → Usage data access page
                            "usage_access" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            // Do Not Disturb access → DND policy access page
                            "dnd" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                            // Battery optimisation → Battery optimisation page for this app
                            "battery_optimization" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$pkg")
                            }
                            // Audio / Storage → App permission page
                            "audio", "storage" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$pkg")
                            }
                            // Fallback: general app details page
                            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$pkg")
                            }
                        }
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fall back to generic app settings if deep-link fails
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", "Could not open settings: ${e2.message}", null)
                        }
                    }
                }
                // ── Check status of special permissions that permission_handler can't read ──
                "checkSpecialPermission" -> {
                    val permType = call.argument<String>("type") ?: ""
                    val granted: Boolean = when (permType) {
                        "overlay" -> Settings.canDrawOverlays(this)
                        "usage_access" -> {
                            val appOps = getSystemService(APP_OPS_SERVICE) as android.app.AppOpsManager
                            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                appOps.unsafeCheckOpNoThrow(
                                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                                    android.os.Process.myUid(),
                                    packageName
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                appOps.checkOpNoThrow(
                                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                                    android.os.Process.myUid(),
                                    packageName
                                )
                            }
                            mode == android.app.AppOpsManager.MODE_ALLOWED
                        }
                        else -> false
                    }
                    result.success(granted)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Launcher apps channel — Play-compliant replacement for installed_apps plugin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sukoon.launcher/apps").setMethodCallHandler { call, result ->
            when (call.method) {
                "getLauncherApps" -> {
                    // Uses ACTION_MAIN + CATEGORY_LAUNCHER — only sees apps the user
                    // has intentionally installed with a launcher icon.
                    // No QUERY_ALL_PACKAGES permission required (covered by <queries> in manifest).
                    Thread {
                        try {
                            val intent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            @Suppress("DEPRECATION")
                            val resolveList = packageManager.queryIntentActivities(intent, 0)
                            val apps = resolveList
                                .filter { it.activityInfo.packageName != packageName } // exclude self
                                .map { ri ->
                                    mapOf(
                                        "package" to ri.activityInfo.packageName,
                                        "name"    to ri.loadLabel(packageManager).toString()
                                    )
                                }
                            Handler(Looper.getMainLooper()).post { result.success(apps) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("ERROR", "getLauncherApps failed: ${e.message}", null)
                            }
                        }
                    }.start()
                }
                "launchApp" -> {
                    try {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "No launch intent for: $pkg", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "launchApp failed: ${e.message}", null)
                    }
                }
                "getAppName" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    try {
                        val info = packageManager.getApplicationInfo(pkg, 0)
                        val name = packageManager.getApplicationLabel(info).toString()
                        result.success(name)
                    } catch (e: Exception) {
                        result.success(pkg) // fallback to package name
                    }
                }
                "getInstalledApps" -> {
                    // Legacy — redirect to getLauncherApps for Zen Mode compatibility
                    Thread {
                        try {
                            val intent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            @Suppress("DEPRECATION")
                            val apps = packageManager.queryIntentActivities(intent, 0)
                                .filter { it.activityInfo.packageName != packageName }
                                .map { ri -> mapOf("package" to ri.activityInfo.packageName) }
                            Handler(Looper.getMainLooper()).post { result.success(apps) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post { result.error("ERROR", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // ── DND (Do Not Disturb) channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DND_CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            when (call.method) {
                "enableDND" -> {
                    try {
                        if (notificationManager.isNotificationPolicyAccessGranted) {
                            val mode = call.argument<String>("mode") ?: "silent"
                            val filter = if (mode == "priority") {
                                // Priority mode: allows calls to ring through, blocks notifications
                                NotificationManager.INTERRUPTION_FILTER_PRIORITY
                            } else {
                                NotificationManager.INTERRUPTION_FILTER_NONE  // Total silence
                            }
                            notificationManager.setInterruptionFilter(filter)
                            Log.d("DND", "DND enabled (mode=$mode)")
                            result.success(true)
                        } else {
                            result.error("PERMISSION_DENIED", "DND permission not granted", null)
                        }
                    } catch (e: Exception) {
                        result.error("DND_ERROR", "Failed to enable DND: ${e.message}", null)
                    }
                }
                "disableDND" -> {
                    try {
                        if (notificationManager.isNotificationPolicyAccessGranted) {
                            notificationManager.setInterruptionFilter(
                                NotificationManager.INTERRUPTION_FILTER_ALL  // All notifications
                            )
                            Log.d("DND", "DND disabled (all sounds restored)")
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("DND_ERROR", "Failed to disable DND: ${e.message}", null)
                    }
                }
                "hasDndPermission" -> {
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }
                "requestDndPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open DND settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Prayer Alarm Activity channel ──
        // Lets Flutter trigger the native wake-screen alarm flow.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_ACTIVITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter schedules a NATIVE alarm via AlarmManager → AlarmBroadcastReceiver
                // This works even when app is killed — native code handles the notification + adhan.
                "scheduleNativeAlarm" -> {
                    val prayerName      = call.argument<String>("prayerName") ?: "Prayer"
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis") ?: 0L
                    val notifType       = call.argument<String>("notifType") ?: "adhan"
                    try {
                        AlarmBroadcastReceiver.scheduleAlarm(this, prayerName, triggerAtMillis, notifType)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", "Could not schedule native alarm: ${e.message}", null)
                    }
                }

                // Flutter cancels a previously scheduled native alarm
                "cancelNativeAlarm" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                    try {
                        AlarmBroadcastReceiver.cancelAlarm(this, prayerName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", "Could not cancel native alarm: ${e.message}", null)
                    }
                }

                // Cancel a notification by ID using native NotificationManager
                "cancelNotificationById" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: 0
                    try {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        nm.cancel(notificationId)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", "Could not cancel notification: ${e.message}", null)
                    }
                }

                // Open battery optimization settings directly
                "openBatterySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback: open general battery settings
                        try {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", "Could not open battery settings: ${e2.message}", null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── Notification Filter channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_FILTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(SukoonNotificationListenerService.isPermissionGranted(this))
                }
                "requestPermission" -> {
                    try {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open notification listener settings: ${e.message}", null)
                    }
                }
                "getCachedNotifications" -> {
                    try {
                        val notifications = SukoonNotificationListenerService.getCachedNotifications(this)
                        result.success(notifications)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get notifications: ${e.message}", null)
                    }
                }
                "clearNotification" -> {
                    try {
                        val key = call.argument<String>("key") ?: ""
                        SukoonNotificationListenerService.clearNotification(key)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear notification: ${e.message}", null)
                    }
                }
                "clearAll" -> {
                    try {
                        SukoonNotificationListenerService.clearAllNotifications()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear notifications: ${e.message}", null)
                    }
                }
                "launchApp" -> {
                    try {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to launch app: ${e.message}", null)
                    }
                }
                "openNotificationIntent" -> {
                    try {
                        val key = call.argument<String>("key") ?: ""
                        val opened = SukoonNotificationListenerService.openNotificationIntent(key, this)
                        result.success(opened)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open notification intent: ${e.message}", null)
                    }
                }
                "updateAllowedPackages" -> {
                    try {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        SukoonNotificationListenerService.updateAllowedPackages(packages.toSet(), enabled, this)
                        // Also explicitly show/remove the hint notification
                        SukoonNotificationListenerService.updateHintNotification(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to update allowed packages: ${e.message}", null)
                    }
                }
                "showHintNotification" -> {
                    try {
                        SukoonNotificationListenerService.updateHintNotification(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to show hint: ${e.message}", null)
                    }
                }
                "getTotalSuppressed" -> {
                    try {
                        val count = SukoonNotificationListenerService.getTotalSuppressed(this)
                        result.success(count)
                    } catch (e: Exception) {
                        result.success(0L)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Deliver pending notification feed intent (cold-start: intent arrived
        // before Flutter engine was ready)
        if (pendingNotificationFeed) {
            pendingNotificationFeed = false
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_FILTER_CHANNEL)
                .invokeMethod("openNotificationFeed", null)
        }

        // ── Power / screen state channel ─────────────────────────────────────
        // Used by Flutter's didChangeAppLifecycleState to detect screen-off/on
        // (lock/unlock) vs genuine app-switch — so the launcher never resets
        // the user's page position after they simply lock and unlock the phone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sukoon.launcher/power")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInteractive" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                            result.success(pm.isInteractive)
                        } catch (e: Exception) {
                            result.success(true) // Safe default: assume screen is on
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun getUsageStats(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager
        val windowMs = endTime - startTime  // hard cap: no app > total window

        // ── queryEvents for accurate, window-clipped usage ──────────────
        // IMPORTANT: Only use MOVE_TO_FOREGROUND (1) / MOVE_TO_BACKGROUND (2).
        // Do NOT mix in ACTIVITY_RESUMED (15) / ACTIVITY_PAUSED (23) — those
        // fire for EVERY activity transition within an app (e.g. opening a
        // sub-screen), causing unpaired events and massively inflated times.

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = android.app.usage.UsageEvents.Event()

        // Track the LAST foreground timestamp per package (overwrites are fine)
        val foregroundStart = mutableMapOf<String, Long>()
        val accumulated = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (_shouldExcludePackage(pkg)) continue

            when (event.eventType) {
                1 /* MOVE_TO_FOREGROUND */ -> {
                    // Only set if not already foreground (prevents double-open)
                    if (!foregroundStart.containsKey(pkg)) {
                        foregroundStart[pkg] = event.timeStamp.coerceAtLeast(startTime)
                    }
                }
                2 /* MOVE_TO_BACKGROUND */ -> {
                    val start = foregroundStart.remove(pkg) ?: continue
                    val duration = event.timeStamp.coerceAtMost(endTime) - start
                    if (duration > 0) {
                        accumulated[pkg] = (accumulated[pkg] ?: 0L) + duration
                    }
                }
            }
        }

        // Close any still-foreground apps at endTime, but DON'T add them
        // if endTime is far in the future (i.e. more than 5 min from now).
        // This prevents "app was opened once and never closed" from showing
        // the entire remaining day as usage.
        val now = System.currentTimeMillis()
        val closeTime = minOf(endTime, now)
        for ((pkg, start) in foregroundStart) {
            val duration = closeTime - start
            // Only count if reasonable (< 4 hours for a single unclosed session)
            if (duration in 1..14_400_000L) {
                accumulated[pkg] = (accumulated[pkg] ?: 0L) + duration
            }
        }

        val result = mutableListOf<Map<String, Any>>()
        for ((pkg, ms) in accumulated) {
            if (ms < 1000) continue
            // Hard cap: no single app can exceed the total time window
            val capped = ms.coerceAtMost(windowMs)
            val appName = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                pkg.split(".").lastOrNull() ?: pkg
            }
            result.add(mapOf(
                "packageName" to pkg,
                "appName" to appName,
                "usageTime" to capped,
                "lastUsed" to System.currentTimeMillis()
            ))
        }

        return result.sortedByDescending { it["usageTime"] as Long }
    }

    /**
     * Returns per-day usage stats for the last [days] days using queryEvents.
     *
     * Each entry: { "date": "2026-03-06", "totalMs": 12345,
     *               "apps": [ {packageName, appName, usageTime} ] }
     *
     * Uses queryEvents per day for exact window-clipped times.
     * Battery-safe: events are stored by the OS; reading them is a
     * single Binder IPC per day (7 calls for a week — trivial).
     */
    private fun getDailyUsageStats(days: Int): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager
        val cal = java.util.Calendar.getInstance()
        val result = mutableListOf<Map<String, Any>>()
        val now = System.currentTimeMillis()

        for (i in 0 until days) {
            cal.timeInMillis = now
            cal.add(java.util.Calendar.DAY_OF_YEAR, -i)
            cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            cal.set(java.util.Calendar.MINUTE, 0)
            cal.set(java.util.Calendar.SECOND, 0)
            cal.set(java.util.Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            val dayEnd = if (i == 0) now else dayStart + 86_400_000L
            val windowMs = dayEnd - dayStart

            val events = usageStatsManager.queryEvents(dayStart, dayEnd)
            val event = android.app.usage.UsageEvents.Event()

            val foregroundStart = mutableMapOf<String, Long>()
            val accumulated = mutableMapOf<String, Long>()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName ?: continue
                if (_shouldExcludePackage(pkg)) continue

                when (event.eventType) {
                    1 /* MOVE_TO_FOREGROUND */ -> {
                        if (!foregroundStart.containsKey(pkg)) {
                            foregroundStart[pkg] = event.timeStamp.coerceAtLeast(dayStart)
                        }
                    }
                    2 /* MOVE_TO_BACKGROUND */ -> {
                        val start = foregroundStart.remove(pkg) ?: continue
                        val duration = event.timeStamp.coerceAtMost(dayEnd) - start
                        if (duration > 0) {
                            accumulated[pkg] = (accumulated[pkg] ?: 0L) + duration
                        }
                    }
                }
            }

            // Close still-foreground apps — only for today, with 4hr cap
            val closeTime = minOf(dayEnd, now)
            for ((pkg, start) in foregroundStart) {
                val duration = closeTime - start
                if (duration in 1..14_400_000L) {
                    accumulated[pkg] = (accumulated[pkg] ?: 0L) + duration
                }
            }

            val appList = mutableListOf<Map<String, Any>>()
            var totalMs = 0L
            for ((pkg, ms) in accumulated) {
                if (ms < 1000) continue
                val capped = ms.coerceAtMost(windowMs)
                val appName = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    pkg.split(".").lastOrNull() ?: pkg
                }
                appList.add(mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "usageTime" to capped
                ))
                totalMs += capped
            }

            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            val dateStr = sdf.format(java.util.Date(dayStart))

            result.add(mapOf(
                "date" to dateStr,
                "totalMs" to totalMs,
                "apps" to appList.sortedByDescending { it["usageTime"] as Long }
            ))
        }

        return result
    }

    /** Packages to exclude from screen time — launchers, system UI, ourselves */
    private fun _shouldExcludePackage(pkg: String): Boolean {
        if (pkg == packageName) return true  // Our own launcher
        if (pkg.startsWith("com.android.systemui")) return true
        if (pkg.startsWith("com.android.settings")) return true
        if (pkg.startsWith("com.android.incallui")) return true
        if (pkg.startsWith("com.android.server")) return true
        if (pkg.startsWith("com.android.phone")) return true
        if (pkg.startsWith("com.android.providers")) return true
        if (pkg.startsWith("com.android.inputmethod")) return true
        if (pkg.startsWith("com.google.android.inputmethod")) return true
        if (pkg == "com.android.launcher" ||
            pkg == "com.android.launcher3" ||
            pkg == "com.google.android.launcher" ||
            pkg == "com.sec.android.app.launcher" ||
            pkg == "com.miui.home" ||
            pkg == "com.huawei.android.launcher" ||
            pkg == "com.oppo.launcher" ||
            pkg == "com.realme.launcher" ||
            pkg == "com.oneplus.launcher" ||
            pkg == "com.nothing.launcher" ||
            pkg == "com.sec.android.app.dexlauncher" ||
            pkg == "com.teslacoilsw.launcher" ||
            pkg == "com.microsoft.launcher" ||
            pkg == "com.actionlauncher.playstore" ||
            pkg == "com.lge.launcher3") return true
        // System framework processes (not user-facing apps)
        if (pkg == "android" ||
            pkg == "com.samsung.android.app.routines" ||
            pkg == "com.samsung.android.MtpApplication" ||
            pkg == "com.samsung.android.lool" ||
            pkg == "com.android.vending" /* Play Store background */ ) return true
        return false
    }

    // ════════════════════════════════════════════════════════════════
    // ZEN MODE: Lock Screen & Immersive Mode Control
    // ════════════════════════════════════════════════════════════════

    private var isZenPinned = false  // Track pinning state to avoid repeated pin/toast

    /**
     * Show Zen Mode screen OVER the lock screen.
     * Called once when Zen Mode is activated.
     */
    private fun enableZenLockScreen() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    // Show our app over lock screen (no need for setTurnScreenOn —
                    // that causes screen to auto-wake after power button)
                    setShowWhenLocked(true)
                    // Do NOT call requestDismissKeyguard — it triggers PIN dialog
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    )
                }
                
                // Pin screen ONLY if not already pinned (avoids "app pinned" toast spam)
                if (!isZenPinned) {
                    try {
                        startLockTask()
                        isZenPinned = true
                        Log.d("ZenLock", "Screen PINNED — system navigation blocked")
                    } catch (e: Exception) {
                        Log.w("ZenLock", "Screen pinning failed: ${e.message}")
                    }
                }
                
                // Immersive mode
                enterFullImmersive()
                
                Log.d("ZenLock", "Lock screen bypass ENABLED")
            } catch (e: Exception) {
                Log.e("ZenLock", "Error enabling lock screen mode: ${e.message}")
            }
        }
    }

    /**
     * Restore normal lock screen behavior when Zen Mode ends.
     */
    private fun disableZenLockScreen() {
        runOnUiThread {
            try {
                // Unpin screen
                if (isZenPinned) {
                    try {
                        stopLockTask()
                        isZenPinned = false
                        Log.d("ZenLock", "Screen UNPINNED")
                    } catch (e: Exception) {
                        Log.w("ZenLock", "Unpin error: ${e.message}")
                    }
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(false)
                    setTurnScreenOn(false)
                } else {
                    @Suppress("DEPRECATION")
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }
                // CRITICAL: Clear keep-screen-on flag — without this, the screen
                // stays on forever after Zen mode ends, draining battery fast
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                
                exitFullImmersive()
                
                Log.d("ZenLock", "Lock screen bypass DISABLED, KEEP_SCREEN_ON cleared")
            } catch (e: Exception) {
                Log.e("ZenLock", "Error disabling lock screen mode: ${e.message}")
            }
        }
    }

    /**
     * Full immersive mode — hides status bar, navigation bar,
     * and blocks all swipe gestures (notification bar, recent apps).
     */
    private fun enterFullImmersive() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.let { controller ->
                        controller.hide(
                            android.view.WindowInsets.Type.statusBars() or
                            android.view.WindowInsets.Type.navigationBars()
                        )
                        controller.systemBarsBehavior = 
                            android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    )
                }
            } catch (e: Exception) {
                Log.e("ZenLock", "Immersive mode error: ${e.message}")
            }
        }
    }

    /**
     * Exit immersive mode — restore normal status/nav bars.
     */
    private fun exitFullImmersive() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.let { controller ->
                        controller.show(
                            android.view.WindowInsets.Type.statusBars() or
                            android.view.WindowInsets.Type.navigationBars()
                        )
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
                }
            } catch (e: Exception) {
                Log.e("ZenLock", "Exit immersive error: ${e.message}")
            }
        }
    }

    /**
     * On resume: only re-enforce immersive mode (lightweight).
     * DO NOT re-call enableZenLockScreen — that would re-trigger
     * PIN dialog and "app pinned" toast.
     */
    private var hasRequestedNotifPermission = false

    override fun onResume() {
        super.onResume()

        // ── Ensure POST_NOTIFICATIONS permission on Android 13+ ──
        // Ask ONCE per app session — not on every resume. Repeated calls
        // cause a crash loop when the app isn't the default launcher,
        // because the permission dialog + Home button + launcher resolver
        // fight each other in an infinite destroy/recreate cycle.
        if (!hasRequestedNotifPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                // Only request if we're the default launcher (safe) OR
                // if onboarding is already complete. During onboarding the
                // HOME intent-filter makes permission dialogs dangerous.
                val isDefault = try {
                    val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                    val ri = packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
                    ri?.activityInfo?.packageName == packageName
                } catch (_: Exception) { false }

                if (isDefault) {
                    hasRequestedNotifPermission = true
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9999
                    )
                }
            } else {
                hasRequestedNotifPermission = true // Already granted — don't check again
            }
        }

        // ── Only start the blocker service if there's actually work to do.
        //    Don't auto-start on every resume — that causes a permanent
        //    "Running in background" notification and wastes battery.
        if (!AppBlockerService.isEnabled(this)) {
            val hasBlockedApps = AppBlockerService.getBlockedPackages(this).isNotEmpty()
            val hasTimedSession = AppBlockerService.getTimedSession(this) != null
            val isZen = AppBlockerService.isZenMode(this)
            if (hasBlockedApps || hasTimedSession || isZen) {
                try { AppBlockerService.start(this) } catch (_: Exception) {}
            }
        }

        if (AppBlockerService.isZenMode(this)) {
            // Re-apply show-over-lock-screen flag (it can be lost after certain
            // system transitions on Samsung/Xiaomi devices)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

            // Just re-enforce immersive (screen pinning persists across resume)
            enterFullImmersive()
            
            // Re-pin only if we lost pinning (e.g., after temporary unpin for camera/call)
            if (!isZenPinned) {
                try {
                    startLockTask()
                    isZenPinned = true
                    Log.d("ZenLock", "Re-pinned on resume")
                } catch (e: Exception) {
                    Log.w("ZenLock", "Re-pin failed: ${e.message}")
                }
            }
        }
    }

    // Removed onPause re-launch — it was causing screen wake-up loop.
    // The AppBlockerService already handles bringing user back.

    /**
     * Block back button during Zen Mode.
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (AppBlockerService.isZenMode(this)) {
            // Do nothing — block exit
            return
        }
        super.onBackPressed()
    }
}

