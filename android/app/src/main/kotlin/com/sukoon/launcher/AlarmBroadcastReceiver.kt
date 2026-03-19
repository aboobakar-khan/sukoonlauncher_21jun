package com.sukoon.launcher

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * AlarmBroadcastReceiver — entry-point for ALL native prayer alarms.
 *
 * Mode: "adhan" (only mode now)
 *   Shows a heads-up notification with a Dismiss action.
 *   Plays adhan_madinah.mp3 via MediaPlayer at ALARM stream volume.
 *   User stops sound by: pressing volume key, tapping Dismiss, or
 *   after 228 seconds (3m48s = full adhan length).
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmBroadcastReceiver"

        // Notification channel
        const val CHANNEL_ADHAN = "prayer_adhan_native_v2" // v2 = no vibration

        // Intent extras
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_NOTIF_TYPE  = "notif_type"

        private const val ACTION = "com.sukoon.launcher.PRAYER_ALARM"

        // Static MediaPlayer so it survives across onReceive() calls and can
        // be stopped by the Dismiss PendingIntent.
        private var adhanPlayer: MediaPlayer? = null
        private var adhanStopHandler: Handler? = null
        private var adhanStopRunnable: Runnable? = null

        /** ContentObserver that watches alarm volume — fires when volume button pressed */
        private var volumeObserver: ContentObserver? = null

        // PendingIntent request codes (one per prayer)
        val prayerRequestCodes = mapOf(
            "Fajr"    to 5000,
            "Dhuhr"   to 5001,
            "Asr"     to 5002,
            "Maghrib" to 5003,
            "Isha"    to 5004,
        )
        val prayerNotificationIds = mapOf(
            "Fajr"    to 3000,
            "Dhuhr"   to 3001,
            "Asr"     to 3002,
            "Maghrib" to 3003,
            "Isha"    to 3004,
        )

        // Action for the "Dismiss" button on adhan notifications
        const val ACTION_DISMISS_ADHAN = "com.sukoon.launcher.DISMISS_ADHAN"

        /** Schedule a native alarm that fires this receiver. */
        fun scheduleAlarm(
            context: Context,
            prayerName: String,
            triggerAtMillis: Long,
            notifType: String = "adhan",
        ) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context, prayerName, notifType)

            // setAlarmClock → survives Doze, shows alarm icon, guaranteed exact
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (am.canScheduleExactAlarms()) {
                    am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
            Log.d(TAG, "Native [$notifType] alarm scheduled for $prayerName at $triggerAtMillis")
        }

        /** Cancel a previously scheduled alarm for this prayer. */
        fun cancelAlarm(context: Context, prayerName: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // Cancel both modes (we don't know which was scheduled)
            am.cancel(buildPendingIntent(context, prayerName, "adhan"))
            Log.d(TAG, "Native alarm cancelled for $prayerName")
        }

        /** Stop any currently-playing adhan sound. Called by Dismiss action. */
        fun stopAdhanSound() {
            try {
                adhanStopHandler?.removeCallbacks(adhanStopRunnable ?: return)
                adhanPlayer?.stop()
                adhanPlayer?.release()
                adhanPlayer = null
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping adhan: ${e.message}")
            }
        }

        private fun buildPendingIntent(
            context: Context,
            prayerName: String,
            notifType: String,
        ): PendingIntent {
            val intent = Intent(context, AlarmBroadcastReceiver::class.java).apply {
                action = ACTION
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_NOTIF_TYPE, notifType)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else PendingIntent.FLAG_UPDATE_CURRENT

            return PendingIntent.getBroadcast(
                context,
                prayerRequestCodes[prayerName] ?: 5000,
                intent,
                flags,
            )
        }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences("prayer_alarm_prefs", Context.MODE_PRIVATE)
    }

    override fun onReceive(context: Context, intent: Intent) {
        // Handle the Dismiss action from the adhan notification
        if (intent.action == ACTION_DISMISS_ADHAN) {
            val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
            stopAdhanSound()
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(prayerNotificationIds[prayerName] ?: 3000)
            Log.d(TAG, "Adhan dismissed for $prayerName")
            return
        }

        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        val notifType  = intent.getStringExtra(EXTRA_NOTIF_TYPE)  ?: "adhan"
        Log.d(TAG, "🕌 Native alarm fired: $prayerName [$notifType]")

        ensureChannels(context)

        // ── ADHAN MODE ──────────────────────────────────────────────────────
        // Show a heads-up notification + play adhan at ALARM stream volume.
        showAdhanNotification(context, prayerName)
        playAdhanSound(context, prayerName)
    }

    // ── ADHAN MODE helpers ────────────────────────────────────────────────────

    private fun showAdhanNotification(context: Context, prayerName: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Dismiss PendingIntent — stops sound + cancels notification
        val dismissIntent = Intent(context, AlarmBroadcastReceiver::class.java).apply {
            action = ACTION_DISMISS_ADHAN
            putExtra(EXTRA_PRAYER_NAME, prayerName)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

        val dismissPi = PendingIntent.getBroadcast(
            context, (prayerNotificationIds[prayerName] ?: 3000) + 200, dismissIntent, piFlags)

        val notification = NotificationCompat.Builder(context, CHANNEL_ADHAN)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🕌 ${prayerName.uppercase()} TIME")
            .setContentText(getPrayerMessage(prayerName))
            .setStyle(NotificationCompat.BigTextStyle().bigText(getPrayerMessage(prayerName)))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(false)
            // Add a Dismiss action so user can stop adhan from the notification shade
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Adhan", dismissPi)
            .setContentIntent(dismissPi)
            .setTimeoutAfter(228_000L)  // auto-cancel after 3m48s (full adhan)
            .build()

        nm.notify(prayerNotificationIds[prayerName] ?: 3000, notification)
        Log.d(TAG, "Adhan notification shown for $prayerName")
    }

    private fun playAdhanSound(context: Context, prayerName: String) {
        stopAdhanSound() // stop any previous adhan

        try {
            val adhanUri = Uri.parse("android.resource://${context.packageName}/raw/adhan_madinah")
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)   // plays at ALARM volume
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(context, adhanUri)
                prepare()
                setVolume(1.0f, 1.0f)
                isLooping = false
            }

            player.setOnCompletionListener {
                stopAdhanSound()
                unregisterVolumeObserver(context)
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(prayerNotificationIds[prayerName] ?: 3000)
                Log.d(TAG, "Adhan completed naturally for $prayerName")
            }

            player.start()
            adhanPlayer = player
            Log.d(TAG, "Adhan MediaPlayer started for $prayerName (ALARM stream)")

            // ── Volume-key observer (screen on OR off) ─────────────────────
            // Android routes volume-button presses to AudioManager which changes
            // Settings.System.VOLUME_ALARM. We watch this URI; any change means
            // a volume button was pressed → stop adhan immediately.
            registerVolumeObserver(context, prayerName)

            // Safety auto-stop after 228 seconds in case onCompletion never fires
            val handler = Handler(Looper.getMainLooper())
            val stopRunnable = Runnable {
                stopAdhanSound()
                unregisterVolumeObserver(context)
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(prayerNotificationIds[prayerName] ?: 3000)
            }
            handler.postDelayed(stopRunnable, 230_000L)
            adhanStopHandler  = handler
            adhanStopRunnable = stopRunnable

        } catch (e: Exception) {
            Log.e(TAG, "Failed to play adhan: ${e.message}")
        }
    }

    /**
     * Register a ContentObserver on the alarm volume URI.
     * Fires whenever the alarm volume changes (i.e. volume button is pressed).
     * Stops adhan immediately on first change — mirrors how a real alarm respects
     * volume buttons even when the screen is off.
     */
    private fun registerVolumeObserver(context: Context, prayerName: String) {
        val handler = Handler(Looper.getMainLooper())
        val observer = object : ContentObserver(handler) {
            private var initialVolume = -1
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val current = am.getStreamVolume(AudioManager.STREAM_ALARM)
                if (initialVolume < 0) {
                    initialVolume = current  // first call is registration, not a real change
                    return
                }
                if (current != initialVolume) {
                    Log.d(TAG, "Volume key detected (alarm vol $initialVolume→$current) — stopping adhan")
                    stopAdhanSound()
                    unregisterVolumeObserver(context)
                    // Also dismiss the notification
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(prayerNotificationIds[prayerName] ?: 3000)
                }
            }
        }
        val volumeUri = Settings.System.getUriFor("volume_alarm")
        context.contentResolver.registerContentObserver(volumeUri, false, observer)
        volumeObserver = observer
        Log.d(TAG, "Volume observer registered for adhan")
    }

    private fun unregisterVolumeObserver(context: Context) {
        volumeObserver?.let {
            try { context.contentResolver.unregisterContentObserver(it) } catch (_: Exception) {}
            volumeObserver = null
            Log.d(TAG, "Volume observer unregistered")
        }
    }


    // ── Channel + message helpers ─────────────────────────────────────────────

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Delete old channels from previous installs
        try { nm.deleteNotificationChannel("prayer_alarm_wake") } catch (_: Exception) {}
        try { nm.deleteNotificationChannel("prayer_adhan_native") } catch (_: Exception) {}
        try { nm.deleteNotificationChannel("prayer_alarm_wake_v2") } catch (_: Exception) {}  // old fullscreen channel

        // Adhan notification channel v2 (NO vibration — MediaPlayer handles audio)
        if (nm.getNotificationChannel(CHANNEL_ADHAN) == null) {
            val ch = NotificationChannel(CHANNEL_ADHAN, "Prayer Adhan", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notification with Adhan sound at alarm volume"
                enableVibration(false)          // ← NO vibration
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(null, null)            // MediaPlayer plays adhan, not the channel
            }
            nm.createNotificationChannel(ch)
        }
    }

    private fun getPrayerMessage(prayerName: String): String = when (prayerName) {
        "Fajr"    -> "Rise before the sun \u2014 the most beloved prayer to Allah \u2600\uFE0F"
        "Dhuhr"   -> "Pause your day, reconnect with your Lord \uD83E\uDEF6"
        "Asr"     -> "Don't let this prayer slip away \u2014 the angels are witnessing \uD83C\uDF24\uFE0F"
        "Maghrib" -> "The sun has set \u2014 rush to meet your Lord \uD83C\uDF05"
        "Isha"    -> "Close your day with peace and forgiveness \uD83C\uDF19"
        "Suhoor"  -> "Time for Suhoor \u2014 eat well, the fast begins soon \uD83C\uDF19"
        "Iftar"   -> "Alhamdulillah! Break your fast now \uD83C\uDF05"
        else      -> "It's time for $prayerName prayer"
    }
}
