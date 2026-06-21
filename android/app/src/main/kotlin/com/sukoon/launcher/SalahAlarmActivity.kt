package com.sukoon.launcher

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * SalahAlarmActivity — full-screen lock-screen alarm UI for prayer times.
 *
 * Features:
 *  • Shown on lock screen via FLAG_SHOW_WHEN_LOCKED (works screen-off too)
 *  • Volume UP/DOWN → stops adhan immediately
 *  • Power/Side button (short press) → snoozes 5 minutes
 *  • "Dismiss" button → stops adhan + closes
 *  • "Snooze 5 min" button → re-schedules alarm, stops current sound
 *  • Auto-dismisses 5 s after adhan completes naturally
 */
class SalahAlarmActivity : Activity() {

    companion object {
        private const val TAG = "SalahAlarmActivity"

        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val ACTION_SNOOZE     = "com.sukoon.launcher.SNOOZE_ADHAN"
        const val SNOOZE_MINUTES    = 5L

        /** Launch this activity from a BroadcastReceiver context. */
        fun launch(context: Context, prayerName: String) {
            val intent = Intent(context, SalahAlarmActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK         or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP       or
                    Intent.FLAG_ACTIVITY_NO_HISTORY
                )
                putExtra(EXTRA_PRAYER_NAME, prayerName)
            }
            context.startActivity(intent)
        }
    }

    private val prayerName: String get() =
        intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"

    private val autoDismissHandler = Handler(Looper.getMainLooper())
    private val autoDismissRunnable = Runnable { finishAndStop() }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Show over lock screen, keep screen on, turn screen on ──────────
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED   or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON         or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD       or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        // ── Build UI programmatically (no XML layout needed) ────────────────
        setContentView(buildLayout())

        Log.d(TAG, "SalahAlarmActivity created for $prayerName")

        // Auto-dismiss 8 seconds after adhan completes (AdhanPlayer calls
        // stopAdhanSound() on completion; we give a short grace window).
        scheduleAutoDismiss(238_000L) // 3m58s = adhan duration + 10 s grace
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        autoDismissHandler.removeCallbacks(autoDismissRunnable)
    }

    // ── Physical button interception ─────────────────────────────────────────

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            // Volume buttons → stop adhan immediately (no dismiss, just mute)
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_UP -> {
                Log.d(TAG, "Volume key $keyCode → stopping adhan")
                AlarmBroadcastReceiver.stopAdhanSound()
                true // consume — prevents system volume change UI
            }

            // Power/side button short press → snooze
            KeyEvent.KEYCODE_POWER -> {
                Log.d(TAG, "Power key → snoozing adhan")
                snoozeAlarm()
                true
            }

            else -> super.onKeyDown(keyCode, event)
        }
    }

    // Without this override Android handles KEYCODE_VOLUME_* at the window level.
    // Returning true in dispatchKeyEvent prevents the VolumePanel UI from showing.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_UP -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    AlarmBroadcastReceiver.stopAdhanSound()
                }
                true
            }
            else -> super.dispatchKeyEvent(event)
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    private fun dismissAlarm() {
        Log.d(TAG, "Dismiss tapped for $prayerName")
        AlarmBroadcastReceiver.stopAdhanSound()
        cancelNotification()
        finishAndStop()
    }

    private fun snoozeAlarm() {
        Log.d(TAG, "Snooze tapped for $prayerName — re-scheduling in $SNOOZE_MINUTES min")
        AlarmBroadcastReceiver.stopAdhanSound()
        cancelNotification()

        // Re-schedule the alarm SNOOZE_MINUTES from now
        val triggerAt = System.currentTimeMillis() + SNOOZE_MINUTES * 60_000L
        AlarmBroadcastReceiver.scheduleAlarm(this, prayerName, triggerAt)

        finishAndStop()
    }

    private fun cancelNotification() {
        val notifId = AlarmBroadcastReceiver.prayerNotificationIds[prayerName] ?: 3000
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notifId)
    }

    private fun finishAndStop() {
        autoDismissHandler.removeCallbacks(autoDismissRunnable)
        finish()
    }

    private fun scheduleAutoDismiss(delayMs: Long) {
        autoDismissHandler.removeCallbacks(autoDismissRunnable)
        autoDismissHandler.postDelayed(autoDismissRunnable, delayMs)
    }

    // ── UI builder ────────────────────────────────────────────────────────────

    private data class PrayerTheme(
        val gradientColors: IntArray,
        val iconResId: Int,
        val accentColor: Int,
        val titleColor: Int
    )

    private fun getPrayerTheme(name: String): PrayerTheme = when (name) {
        "Fajr" -> PrayerTheme(
            intArrayOf(0xFF051122.toInt(), 0xFF1A3859.toInt()), R.drawable.ic_prayer_fajr, 0xFF8AB4F8.toInt(), 0xFFE8F0FE.toInt()
        )
        "Dhuhr" -> PrayerTheme(
            intArrayOf(0xFF1C1304.toInt(), 0xFF54380C.toInt()), R.drawable.ic_prayer_dhuhr, 0xFFFCD663.toInt(), 0xFFFEF7E0.toInt()
        )
        "Asr" -> PrayerTheme(
            intArrayOf(0xFF200C06.toInt(), 0xFF7A2E12.toInt()), R.drawable.ic_prayer_asr, 0xFFFCAD70.toInt(), 0xFFFCE8E0.toInt()
        )
        "Maghrib" -> PrayerTheme(
            intArrayOf(0xFF12031B.toInt(), 0xFF4A1041.toInt()), R.drawable.ic_prayer_maghrib, 0xFFFF8BCB.toInt(), 0xFFFCE8F5.toInt()
        )
        "Isha" -> PrayerTheme(
            intArrayOf(0xFF000000.toInt(), 0xFF0B1426.toInt()), R.drawable.ic_prayer_isha, 0xFFD4A017.toInt(), 0xFFF5F0E8.toInt()
        )
        "Suhoor" -> PrayerTheme(
            intArrayOf(0xFF051122.toInt(), 0xFF1A3859.toInt()), R.drawable.ic_prayer_mosque, 0xFF8AB4F8.toInt(), 0xFFE8F0FE.toInt()
        )
        "Iftar" -> PrayerTheme(
            intArrayOf(0xFF200C06.toInt(), 0xFF7A2E12.toInt()), R.drawable.ic_prayer_mosque, 0xFFFCAD70.toInt(), 0xFFFCE8E0.toInt()
        )
        else -> PrayerTheme(
            intArrayOf(0xFF0A0A0A.toInt(), 0xFF1A1A1A.toInt()), R.drawable.ic_prayer_mosque, 0xFFD4A017.toInt(), 0xFFF5F0E8.toInt()
        )
    }

    private fun buildLayout(): View {
        val ctx = this
        val theme = getPrayerTheme(prayerName)

        // Root — dynamic gradient background
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                theme.gradientColors
            )
            gravity = android.view.Gravity.CENTER
        }

        // ── Prayer icon ──
        val icon = android.widget.ImageView(ctx).apply {
            setImageResource(theme.iconResId)
            setColorFilter(theme.accentColor, android.graphics.PorterDuff.Mode.SRC_IN)
            layoutParams = LinearLayout.LayoutParams(
                (64 * resources.displayMetrics.density).toInt(),
                (64 * resources.displayMetrics.density).toInt()
            ).apply {
                setMargins(0, 0, 0, (24 * resources.displayMetrics.density).toInt())
                gravity = android.view.Gravity.CENTER
            }
        }
        root.addView(icon)

        // ── Prayer time label ──
        val timeLabel = TextView(ctx).apply {
            text = "${prayerName.uppercase()} PRAYER"
            textSize = 12f
            letterSpacing = 0.3f
            setTextColor(theme.accentColor)
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 8)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
        }
        root.addView(timeLabel)

        // ── Prayer name ──
        val nameLabel = TextView(ctx).apply {
            text = prayerName
            textSize = 42f
            setTextColor(theme.titleColor)
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 16)
            typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
        }
        root.addView(nameLabel)

        // ── Inspirational message ──
        val msg = TextView(ctx).apply {
            text = prayerMessage(prayerName)
            textSize = 15f
            setTextColor(0xCCFFFFFF.toInt())
            gravity = android.view.Gravity.CENTER
            setPadding(48, 8, 48, 64)
            setLineSpacing(0f, 1.6f)
            typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
        }
        root.addView(msg)

        // ── Button row ──
        val btnRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER
        }

        val snoozeBtn = buildButton(ctx, "Snooze 5m", 0x33FFFFFF.toInt(), theme.titleColor) {
            snoozeAlarm()
        }

        val dismissBtn = buildButton(ctx, "Dismiss", theme.accentColor, 0xFF0A0A0A.toInt()) {
            dismissAlarm()
        }

        val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            setMargins(24, 0, 12, 0)
        }
        val lp2 = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            setMargins(12, 0, 24, 0)
        }

        snoozeBtn.layoutParams = lp
        dismissBtn.layoutParams = lp2
        btnRow.addView(snoozeBtn)
        btnRow.addView(dismissBtn)
        root.addView(btnRow)

        // ── Volume hint ──
        val hint = TextView(ctx).apply {
            text = "Press volume key to mute  ·  Power to snooze"
            textSize = 11f
            setTextColor(0x66FFFFFF.toInt())
            gravity = android.view.Gravity.CENTER
            setPadding(0, 48, 0, 48)
            letterSpacing = 0.05f
        }
        root.addView(hint)

        return root
    }

    private fun buildButton(
        ctx: Context,
        label: String,
        bgColor: Int,
        textColor: Int,
        onClick: () -> Unit,
    ): TextView {
        return TextView(ctx).apply {
            text = label
            textSize = 14f
            setTextColor(textColor)
            gravity = android.view.Gravity.CENTER
            setPadding(0, 36, 0, 36)
            background = buildButtonBg(bgColor)
            setOnClickListener { onClick() }
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
        }
    }

    private fun buildButtonBg(color: Int): android.graphics.drawable.Drawable {
        val shape = android.graphics.drawable.GradientDrawable()
        shape.setColor(color)
        shape.cornerRadius = 48f
        return shape
    }

    private fun prayerMessage(name: String): String = when (name) {
        "Fajr"    -> "The world is asleep, but you chose Him.\nBreathe in the dawn and find your peace."
        "Dhuhr"   -> "A momentary pause in your worldly pursuit.\nRecharge your soul before the day consumes you."
        "Asr"     -> "The day is fading, and so is time.\nSecure your tranquility before the sun sets."
        "Maghrib" -> "The day is done. Return to the One\nwho sustained you through it all."
        "Isha"    -> "End your day in His presence.\nLet your soul rest in true serenity."
        "Suhoor"  -> "A blessed beginning.\nNourish your body to elevate your spirit."
        "Iftar"   -> "Alhamdulillah for the strength to fast.\nSavor the joy of breaking it now."
        else      -> "Answer the call to success.\nYour Lord is waiting."
    }
}
