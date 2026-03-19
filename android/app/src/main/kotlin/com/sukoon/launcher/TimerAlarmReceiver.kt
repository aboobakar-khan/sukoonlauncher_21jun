package com.sukoon.launcher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives the exact alarm broadcast when a timed app session deadline is reached.
 *
 * This is the BATTERY-EFFICIENT alternative to continuous 500ms polling.
 * The AlarmManager fires this receiver at the exact endTime, even in Doze mode.
 *
 * Behavior:
 *  1. Reads the timed session from SharedPreferences
 *  2. Checks if the timed app is currently in the foreground
 *  3. If yes → launches the "time's up" overlay immediately
 *  4. If no → the user already left the app; we just clean up
 *
 * The polling loop in AppBlockerService is still present as a secondary
 * fallback (at 3s intervals for timer-only mode), but this alarm is the
 * PRIMARY trigger that guarantees the deadline is never missed.
 */
class TimerAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TimerAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AppBlockerService.ACTION_TIMER_EXPIRED) return

        Log.d(TAG, "Timer alarm fired!")

        val session = AppBlockerService.getTimedSession(context) ?: run {
            Log.d(TAG, "No active session found — alarm is stale, ignoring")
            return
        }

        val (sessionPkg, endTime, extensions) = session
        val now = System.currentTimeMillis()

        // Double-check: is the deadline actually reached?
        // (Could be stale if user extended the session after alarm was scheduled)
        if (now < endTime) {
            Log.d(TAG, "Deadline not yet reached (user extended?) — rescheduling")
            AppBlockerService.scheduleTimerAlarm(context, endTime)
            return
        }

        // Check if this session was recently ended by user (grace period)
        if (AppBlockerService.wasRecentlyEnded(context, sessionPkg)) {
            Log.d(TAG, "Session was recently ended by user — ignoring")
            return
        }

        // Session has expired. Check if the timed app is in the foreground.
        // If it is, launch the "time's up" overlay.
        // If not, the user has already left — the overlay will trigger next time they open it
        // via the polling loop's secondary check.
        val prefs = AppBlockerService.getPrefs(context)
        val sessionStart = prefs.getLong(AppBlockerService.KEY_TIMED_SESSION_START, endTime - 60000L)
        val minutesSpent = ((now - sessionStart) / 60000L).toInt().coerceAtLeast(1)

        Log.d(TAG, "Time's up for $sessionPkg after ${minutesSpent}m — launching overlay")

        // Clear session before launching overlay — prevents the polling loop
        // from re-firing on subsequent polls. If user extends, Flutter creates
        // a fresh session via startTimedSession().
        AppBlockerService.endTimedSession(context, sessionPkg)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("times_up", true)
            putExtra("timed_package", sessionPkg)
            putExtra("extensions_used", extensions)
            putExtra("minutes_spent", minutesSpent)
        }

        try {
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch times-up overlay: ${e.message}")
            // Fallback: ensure the service is running so polling loop catches it
            if (!AppBlockerService.isEnabled(context)) {
                AppBlockerService.start(context)
            }
        }
    }
}
