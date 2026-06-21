package com.sukoon.launcher

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * NotificationListenerService that captures notifications from all apps.
 *
 * Design principles:
 * - Native-side caching: notifications stored in a static list in memory
 * - No background Flutter isolate — Flutter pulls data on demand via MethodChannel
 * - Battery efficient: only runs when user has granted permission
 * - Respects user's chosen filter list (filtering is done on Flutter side)
 *
 * Required manifest entry:
 *   <service android:name=".SukoonNotificationListenerService"
 *            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
 *            android:exported="true">
 *       <intent-filter>
 *           <action android:name="android.service.notification.NotificationListenerService" />
 *       </intent-filter>
 *   </service>
 */
class SukoonNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "SukoonNotifListener"
        private const val MAX_CACHED = 200 // Max notifications to keep in memory
        private const val PREFS_NAME = "sukoon_notif_filter"
        private const val PREFS_KEY_ENABLED = "filter_enabled"
        private const val PREFS_KEY_ALLOWED = "allowed_packages"
        private const val PREFS_KEY_SUPPRESSED = "total_suppressed"
        private const val PREFS_KEY_SESSION_SUPPRESSED = "session_suppressed"
        private const val HINT_CHANNEL_ID = "sukoon_filter_v2"   // v2 — IMPORTANCE_DEFAULT so icon shows in status bar
        private const val HINT_NOTIFICATION_ID = 99001

        // In-memory cache of recent notifications (thread-safe via synchronized)
        private val cachedNotifications = mutableListOf<Map<String, Any?>>()

        // Store contentIntent PendingIntents keyed by notification key so we can
        // fire the original deep-link when the user taps a cached notification.
        private val contentIntents = mutableMapOf<String, PendingIntent>()

        // Keys of notifications WE suppressed (so onNotificationRemoved won't purge them)
        private val suppressedKeys = mutableSetOf<String>()

        // Packages whose notifications should pass through (not suppressed).
        private val allowedPackages = mutableSetOf<String>()

        // Whether the notification filter feature is enabled
        @Volatile
        var filterEnabled: Boolean = false

        // Lifetime count of suppressed notifications
        @Volatile
        var totalSuppressed: Long = 0

        // Session count — resets each time filter is toggled ON
        @Volatile
        var sessionSuppressed: Long = 0

        // Reference to the live service instance (for sweeping active notifications)
        @Volatile
        private var serviceInstance: SukoonNotificationListenerService? = null

        /** Check if Sukoon is the default home launcher */
        private fun isSukoonDefaultLauncher(context: Context?): Boolean {
            val ctx = context ?: return false
            return try {
                val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
                val resolveInfo = ctx.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                resolveInfo?.activityInfo?.packageName == ctx.packageName
            } catch (e: Exception) {
                false
            }
        }

        /** Update the set of allowed packages and persist + sweep active notifications */
        fun updateAllowedPackages(packages: Set<String>, enabled: Boolean, context: Context? = null) {
            val wasEnabled = filterEnabled
            synchronized(allowedPackages) {
                allowedPackages.clear()
                allowedPackages.addAll(packages)
                filterEnabled = enabled
            }
            // Reset session counter when filter is freshly turned ON
            if (enabled && !wasEnabled) {
                sessionSuppressed = 0
                context?.let {
                    it.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().putLong(PREFS_KEY_SESSION_SUPPRESSED, 0).apply()
                }
            }
            // Update wasSuppressed flags in cached notifications:
            // - Newly allowed apps → mark wasSuppressed = false (un-suppress)
            // - Newly non-allowed apps → will be handled by sweepActiveNotifications below
            synchronized(cachedNotifications) {
                for (i in cachedNotifications.indices) {
                    val pkg = cachedNotifications[i]["packageName"] as? String ?: continue
                    val currentlySuppressed = cachedNotifications[i]["wasSuppressed"] as? Boolean ?: false
                    if (packages.contains(pkg) && currentlySuppressed) {
                        // App was re-allowed — un-suppress its cached notifications
                        cachedNotifications[i] = cachedNotifications[i].toMutableMap().apply {
                            put("wasSuppressed", false)
                        }
                    }
                }
            }
            // Persist so the listener reads them immediately on next connect
            context?.let { ctx ->
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putBoolean(PREFS_KEY_ENABLED, enabled)
                    .putStringSet(PREFS_KEY_ALLOWED, packages)
                    .apply()
            }
            // Sweep currently active notifications — cancel any that are now non-allowed
            serviceInstance?.sweepActiveNotifications()
            // Update hint notification
            context?.let { updateHintNotification(it) }
        }

        /** Load persisted allowed packages from SharedPreferences into memory. */
        private fun loadFromPrefs(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(PREFS_KEY_ENABLED, false)
            val packages = prefs.getStringSet(PREFS_KEY_ALLOWED, emptySet()) ?: emptySet()
            totalSuppressed = prefs.getLong(PREFS_KEY_SUPPRESSED, 0)
            sessionSuppressed = prefs.getLong(PREFS_KEY_SESSION_SUPPRESSED, 0)
            synchronized(allowedPackages) {
                filterEnabled = enabled
                allowedPackages.clear()
                allowedPackages.addAll(packages)
            }
            Log.d(TAG, "Loaded from prefs: enabled=$enabled, allowed=${packages.size} apps, session=$sessionSuppressed, total=$totalSuppressed")
        }

        /** Get the total number of suppressed notifications */
        fun getTotalSuppressed(context: Context): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getLong(PREFS_KEY_SUPPRESSED, 0)
        }

        /** Increment suppressed counter and persist */
        private fun incrementSuppressed(context: Context) {
            totalSuppressed++
            sessionSuppressed++
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putLong(PREFS_KEY_SUPPRESSED, totalSuppressed)
                .putLong(PREFS_KEY_SESSION_SUPPRESSED, sessionSuppressed)
                .apply()
        }

        /** Show or update the persistent "filter active" hint in the notification shade */
        fun updateHintNotification(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (!filterEnabled) {
                // Remove hint when filter is off
                nm.cancel(HINT_NOTIFICATION_ID)
                Log.d(TAG, "Hint notification removed (filter OFF)")
                return
            }

            // Create channel (Android 8+) — delete legacy channel only once
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val existing = nm.getNotificationChannel(HINT_CHANNEL_ID)
                if (existing == null) {
                    // Kill old channel whose importance is stuck at LOW
                    nm.deleteNotificationChannel("sukoon_filter_hint")
                    val channel = NotificationChannel(
                        HINT_CHANNEL_ID,
                        "Sukoon Filter Status",
                        NotificationManager.IMPORTANCE_DEFAULT   // Shows icon in status bar
                    ).apply {
                        description = "Shows when Sukoon notification filter is active"
                        setShowBadge(false)
                        enableLights(false)
                        enableVibration(false)
                        setSound(null, null)   // No sound even at DEFAULT
                    }
                    nm.createNotificationChannel(channel)
                    Log.d(TAG, "Created notification channel: $HINT_CHANNEL_ID")
                }
            }

            // Build a PendingIntent that opens notification feed when tapped
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("open_notification_feed", true)
            }
            val pendingIntent = if (launchIntent != null) {
                PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else null

            val count = sessionSuppressed
            val countText = if (count == 0L) "Active · filtering distracting notifications"
                           else "Active · $count notification${if (count > 1) "s" else ""} filtered"

            val notification = NotificationCompat.Builder(context, HINT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)   // white-on-transparent vector
                .setContentTitle("Sukoon filter active")
                .setContentText(countText)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)   // Shows icon in status bar
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setShowWhen(false)
                .apply { if (pendingIntent != null) setContentIntent(pendingIntent) }
                .build()

            nm.notify(HINT_NOTIFICATION_ID, notification)
            Log.d(TAG, "Hint notification posted/updated: $countText")
        }

        /** Check if notification listener permission is granted */
        fun isPermissionGranted(context: Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            val componentName = ComponentName(context, SukoonNotificationListenerService::class.java)
            return flat.contains(componentName.flattenToString())
        }

        /** Get cached notifications as List<Map> for MethodChannel */
        fun getCachedNotifications(context: Context): List<Map<String, Any?>> {
            synchronized(cachedNotifications) {
                val pm = context.packageManager
                return cachedNotifications.map { notif ->
                    val pkg = notif["packageName"] as? String ?: ""
                    val appName = try {
                        pm.getApplicationLabel(
                            pm.getApplicationInfo(pkg, 0)
                        ).toString()
                    } catch (e: PackageManager.NameNotFoundException) {
                        pkg.split(".").lastOrNull() ?: pkg
                    }
                    notif.toMutableMap().apply { put("appName", appName) }
                }
            }
        }

        /**
         * Clear a specific notification by key.
         * Also cancels it from the Android system notification bar (in case it is still visible)
         * and removes its PendingIntent so there are no memory leaks.
         */
        fun clearNotification(key: String) {
            // Remove from in-memory feed cache
            synchronized(cachedNotifications) {
                cachedNotifications.removeAll { it["key"] == key }
            }
            // Remove stored deep-link intent — prevents memory leak
            contentIntents.remove(key)
            // Remove from suppressed tracking set
            synchronized(suppressedKeys) {
                suppressedKeys.remove(key)
            }
            // Cancel from Android system notification bar if it somehow reappeared
            try {
                serviceInstance?.cancelNotification(key)
            } catch (_: Exception) {}
        }

        /**
         * Clear ALL cached notifications.
         * Also cancels every suppressed notification from the Android system bar
         * and wipes all stored PendingIntents to free memory.
         */
        fun clearAllNotifications() {
            val keysToCancel: List<String>
            synchronized(cachedNotifications) {
                keysToCancel = cachedNotifications.mapNotNull { it["key"] as? String }
                cachedNotifications.clear()
            }
            contentIntents.clear()
            synchronized(suppressedKeys) {
                suppressedKeys.clear()
            }
            // Cancel every entry from the Android system notification bar
            keysToCancel.forEach { key ->
                try {
                    serviceInstance?.cancelNotification(key)
                } catch (_: Exception) {}
            }
        }

        /**
         * Fire the original notification's contentIntent (deep-link).
         * Returns true if the PendingIntent was found and sent (or fallback app launched).
         *
         * Strategy:
         *  1. Fire the PendingIntent (deep-link) via pi.send().
         *  2. Because pi.send() may not bring the target app to the foreground
         *     when called from our Activity (the fill-in Intent is ignored on
         *     immutable PendingIntents from Android 12+), we also launch the
         *     app's main activity via getLaunchIntentForPackage as a "bring to
         *     front" nudge.  The deep-link from step 1 is still processed by
         *     the target app so the user lands on the right screen.
         *  3. If there was no PendingIntent at all, we fall back to just
         *     launching the app normally.
         */
        fun openNotificationIntent(key: String, context: Context): Boolean {
            Log.d(TAG, "openNotificationIntent called for key=$key")
            val pi = contentIntents[key]
            var opened = false

            // Resolve the target package — from the PI or from cached data
            val targetPkg: String? = pi?.creatorPackage
                ?: synchronized(cachedNotifications) {
                    cachedNotifications.firstOrNull { it["key"] == key }?.get("packageName") as? String
                }

            if (pi != null) {
                try {
                    // Fire the deep-link PendingIntent
                    pi.send()
                    opened = true
                    Log.d(TAG, "PendingIntent sent for key=$key (target=$targetPkg)")
                } catch (e: PendingIntent.CanceledException) {
                    Log.w(TAG, "PendingIntent cancelled for key=$key: ${e.message}")
                    contentIntents.remove(key)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send PendingIntent for key=$key: ${e.message}")
                }
            } else {
                Log.w(TAG, "No PendingIntent for key=$key (contentIntents size=${contentIntents.size})")
            }

            // Bring target app to foreground.
            // Even when pi.send() succeeds, the target Activity may not come to
            // the front because the PendingIntent is immutable.  Launching the
            // main Activity ensures the user sees the app.
            if (targetPkg != null) {
                try {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(targetPkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                        )
                        context.startActivity(launchIntent)
                        opened = true
                        Log.d(TAG, "Brought $targetPkg to foreground for key=$key")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to bring $targetPkg to foreground: ${e.message}")
                }
            }

            if (!opened) {
                Log.w(TAG, "Could not open anything for key=$key")
            }

            Log.d(TAG, "openNotificationIntent result: opened=$opened for key=$key")
            return opened
        }
    }

    /** Cancel all currently active system notifications from non-allowed apps */
    fun sweepActiveNotifications() {
        if (!filterEnabled) return
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                if (sbn.packageName == packageName) continue
                if (sbn.packageName == "android" || sbn.packageName == "com.android.systemui") continue

                // Never suppress ongoing notifications (media players, downloads, navigation, etc.)
                // Cancelling an ongoing media notification tells Android to pause playback.
                // Check both sbn.isOngoing AND the raw notification flags to catch all media players.
                val notification = sbn.notification
                val isOngoingNotification = sbn.isOngoing ||
                    (notification != null && (notification.flags and android.app.Notification.FLAG_ONGOING_EVENT != 0)) ||
                    (notification != null && (notification.flags and android.app.Notification.FLAG_FOREGROUND_SERVICE != 0))

                if (isOngoingNotification) {
                    Log.d(TAG, "Skipping ongoing notification from ${sbn.packageName}")
                    continue
                }

                val isAllowed = synchronized(allowedPackages) {
                    allowedPackages.contains(sbn.packageName)
                }
                if (!isAllowed) {
                    // Mark as suppressed BEFORE cancelling
                    synchronized(suppressedKeys) {
                        suppressedKeys.add(sbn.key)
                    }
                    // Update the cached entry's wasSuppressed flag so Flutter sees it
                    synchronized(cachedNotifications) {
                        val idx = cachedNotifications.indexOfFirst { it["key"] == sbn.key }
                        if (idx >= 0) {
                            cachedNotifications[idx] = cachedNotifications[idx].toMutableMap().apply {
                                put("wasSuppressed", true)
                            }
                        }
                    }
                    try {
                        cancelNotification(sbn.key)
                        incrementSuppressed(applicationContext)
                        Log.d(TAG, "Swept notification: ${sbn.packageName}")
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not sweep: ${e.message}")
                    }
                }
            }
            updateHintNotification(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Error sweeping notifications: ${e.message}")
        }
    }

    private fun isSukoonDefaultLauncher() = isSukoonDefaultLauncher(applicationContext)

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        // ── SENIOR LOGIC: Launcher Guard ──
        // Only provide the notification filtering service if Sukoon is the active home.
        // If the user has switched launchers, let all notifications pass through normally.
        if (!isSukoonDefaultLauncher()) {
            return
        }

        // Skip our own notifications (blocker service, alarms, hint, etc.)
        if (sbn.packageName == packageName) return

        // Skip system UI notifications
        if (sbn.packageName == "android" || sbn.packageName == "com.android.systemui") return

        val notification = sbn.notification ?: return
        val extras = notification.extras

        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""

        // Skip empty notifications
        if (title.isBlank() && text.isBlank()) return

        // Determine if this notification is "ongoing" via BOTH the SBN flag AND
        // the raw Notification.flags bitmask. Some media players (YouTube, Spotify,
        // VLC) post notifications where sbn.isOngoing is momentarily false but the
        // FLAG_ONGOING_EVENT / FLAG_FOREGROUND_SERVICE bit is set in notification.flags.
        // Cancelling such a notification pauses playback — so we must check both.
        val isOngoingNotification = sbn.isOngoing ||
            (notification.flags and android.app.Notification.FLAG_ONGOING_EVENT != 0) ||
            (notification.flags and android.app.Notification.FLAG_FOREGROUND_SERVICE != 0)

        // Decide suppression — but NEVER suppress ongoing notifications.
        // Ongoing notifications include media players (YouTube, Spotify), active downloads,
        // navigation, etc. Cancelling a media notification tells Android to pause playback.
        val shouldSuppress = synchronized(allowedPackages) {
            filterEnabled && !allowedPackages.contains(sbn.packageName) && !isOngoingNotification
        }

        // ALWAYS cache FIRST (before cancelling — because cancel triggers onNotificationRemoved)
        val notifMap = mapOf<String, Any?>(
            "key" to sbn.key,
            "packageName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "postedAt" to sbn.postTime,
            "isOngoing" to isOngoingNotification,
            "wasSuppressed" to shouldSuppress
        )

        synchronized(cachedNotifications) {
            cachedNotifications.removeAll { it["key"] == sbn.key }
            cachedNotifications.add(0, notifMap)
            while (cachedNotifications.size > MAX_CACHED) {
                val removed = cachedNotifications.removeAt(cachedNotifications.size - 1)
                val removedKey = removed["key"] as? String
                if (removedKey != null) contentIntents.remove(removedKey)
            }
        }

        // Store the contentIntent so we can deep-link when the user taps
        notification.contentIntent?.let { pi ->
            contentIntents[sbn.key] = pi
            Log.d(TAG, "Stored contentIntent for key=${sbn.key} from ${sbn.packageName}")
        }
        if (notification.contentIntent == null) {
            Log.w(TAG, "No contentIntent for key=${sbn.key} from ${sbn.packageName} — $title")
        }

        // If suppressing, mark the key so onNotificationRemoved won't purge it, then cancel
        if (shouldSuppress) {
            synchronized(suppressedKeys) {
                suppressedKeys.add(sbn.key)
            }
            try {
                cancelNotification(sbn.key)
                incrementSuppressed(applicationContext)
                updateHintNotification(applicationContext)
                Log.d(TAG, "Suppressed notification: ${sbn.packageName} — $title")
            } catch (e: Exception) {
                Log.w(TAG, "Could not cancel notification: ${e.message}")
            }
        }

        Log.d(TAG, "Notification captured: ${sbn.packageName} — $title (suppressed=$shouldSuppress)")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return

        // If WE suppressed this notification, do NOT remove from cache — keep it for the feed
        val wasSuppressedByUs = synchronized(suppressedKeys) {
            suppressedKeys.remove(sbn.key)
        }
        if (wasSuppressedByUs) {
            Log.d(TAG, "Notification removed (by us, kept in cache): ${sbn.packageName}")
            return
        }

        // Otherwise (user swiped it, or app cancelled it) — remove from cache
        synchronized(cachedNotifications) {
            cachedNotifications.removeAll { it["key"] == sbn.key }
        }
        Log.d(TAG, "Notification removed (external, purged from cache): ${sbn.packageName}")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        serviceInstance = this
        Log.d(TAG, "Notification listener CONNECTED")

        // Load persisted filter settings immediately — before Flutter syncs
        loadFromPrefs(applicationContext)

        // Show hint notification if filter is active
        if (filterEnabled) {
            updateHintNotification(applicationContext)
        }

        // Pre-populate with currently active notifications (will suppress blocked ones)
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                onNotificationPosted(sbn)
            }
            Log.d(TAG, "Pre-populated ${active.size} active notifications")
        } catch (e: Exception) {
            Log.e(TAG, "Error pre-populating: ${e.message}")
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        serviceInstance = null
        Log.d(TAG, "Notification listener DISCONNECTED")
    }
}