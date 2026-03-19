package com.sukoon.launcher

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager

/**
 * AlarmActivity — native trampoline that wakes the screen and shows the alarm
 * DIRECTLY OVER the lock screen — exactly like the Android stock alarm clock.
 *
 * KEY DESIGN:
 *   1. Acquire a FULL_WAKE_LOCK + ACQUIRE_CAUSES_WAKEUP to force the screen ON,
 *      even from deep Doze / screen-off state.
 *   2. Use setShowWhenLocked(true) + setTurnScreenOn(true) so the alarm
 *      appears over the keyguard without asking the user to unlock first.
 *   3. Use requestDismissKeyguard ONLY on non-secure keyguards (swipe lock);
 *      for PIN/pattern/fingerprint, the alarm renders over the keyguard.
 *   4. FLAG_KEEP_SCREEN_ON keeps the display lit while the alarm is shown.
 *
 * Flow:
 *   AlarmBroadcastReceiver (wakelock + fullScreenIntent + startActivity)
 *     → AlarmActivity (wakes screen, shows over lock screen)
 *       → MainActivity (inherits flags, Flutter shows alarm UI)
 *         → user taps "Prayed / Snooze / Dismiss" → alarm cleared
 */
class AlarmActivity : Activity() {

    companion object {
        private const val TAG = "AlarmActivity"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val PREFS_NAME = "prayer_alarm_prefs"
        const val PREFS_KEY_PRAYER = "pending_prayer_name"

        fun createIntent(context: Context, prayerName: String): Intent =
            Intent(context, AlarmActivity::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                // CLEAR_TOP ensures if an old AlarmActivity exists, it gets refreshed
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // ① Acquire a FULL wake lock FIRST — this physically turns the screen ON
        //    before any window flags are applied. Critical for screen-off scenarios.
        acquireScreenWakeLock()

        // ② Apply window-level wake/lock-screen-overlay flags
        applyWakeFlags()
        super.onCreate(savedInstanceState)

        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        Log.d(TAG, "AlarmActivity fired for: $prayerName — waking screen + showing over lock screen")

        // ③ Persist to SharedPreferences so Flutter reads it on cold/warm start.
        prefs().edit().putString(PREFS_KEY_PRAYER, prayerName).apply()

        // ④ Dismiss non-secure keyguard (swipe lock) if possible
        //    For secure keyguards (PIN/pattern/fingerprint), we just show over it.
        dismissKeyguardIfPossible()

        // ⑤ Launch MainActivity — it will also show over the lock screen
        launchMainActivity(prayerName)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        prefs().edit().putString(PREFS_KEY_PRAYER, prayerName).apply()
        launchMainActivity(prayerName)
    }

    private fun launchMainActivity(prayerName: String) {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(mainIntent)

        // Keep this Activity alive long enough for the wake flags to persist
        // until MainActivity's window is fully ready (Samsung / Xiaomi quirk).
        Handler(Looper.getMainLooper()).postDelayed({
            releaseWakeLock()
            finish()
        }, 3000)
    }

    private fun acquireScreenWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "sukoon:alarm_activity_wake"
            )
            wakeLock?.acquire(30_000L) // 30 seconds max
            Log.d(TAG, "FULL_WAKE_LOCK acquired — screen should be ON")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire wake lock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "Wake lock released")
            }
        } catch (_: Exception) {}
        wakeLock = null
    }

    private fun applyWakeFlags() {
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
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    /**
     * Dismiss the keyguard if it's non-secure (swipe lock screen).
     * For secure keyguards (PIN/pattern/bio), we do NOT dismiss —
     * the alarm appears directly over the lock screen.
     */
    private fun dismissKeyguardIfPossible() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (!km.isDeviceSecure) {
                // Non-secure keyguard — dismiss it so user sees the alarm directly
                km.requestDismissKeyguard(this, null)
            }
            // For secure keyguards: do nothing — setShowWhenLocked renders over it
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
