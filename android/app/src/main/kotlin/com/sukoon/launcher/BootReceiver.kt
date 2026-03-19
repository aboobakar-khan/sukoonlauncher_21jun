package com.sukoon.launcher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts the AppBlockerService after device reboot,
 * if it was enabled before the reboot.
 * Also restores Zen Mode lock screen if Zen was active when the device rebooted.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Boot completed, checking blocker service...")
            
            val blockedPackages = AppBlockerService.getBlockedPackages(context)
            val wasEnabled = AppBlockerService.isEnabled(context)
            val wasZen = AppBlockerService.isZenMode(context)
            val hasTimedSession = AppBlockerService.getTimedSession(context) != null
            
            // Only restart if there's actual work to do (blocked apps, timer, or zen).
            // Don't restart an idle service — it just shows "running in background"
            // and wastes battery.
            if (wasEnabled && (blockedPackages.isNotEmpty() || hasTimedSession || wasZen)) {
                Log.d("BootReceiver", "Restarting blocker service with ${blockedPackages.size} blocked apps")
                AppBlockerService.start(context)
                
                // If a timed session was active, reschedule the exact alarm
                // so the deadline is still enforced after reboot
                if (hasTimedSession) {
                    val session = AppBlockerService.getTimedSession(context)
                    if (session != null) {
                        val (_, endTime, _) = session
                        val now = System.currentTimeMillis()
                        if (endTime > now) {
                            AppBlockerService.scheduleTimerAlarm(context, endTime)
                            Log.d("BootReceiver", "Timer alarm rescheduled after reboot: ${(endTime - now) / 1000}s remaining")
                        } else {
                            // Timer already expired during reboot — schedule immediate check
                            AppBlockerService.scheduleTimerAlarm(context, now + 1000)
                            Log.d("BootReceiver", "Timer expired during reboot — scheduling immediate check")
                        }
                    }
                }
            } else if (wasEnabled) {
                // Was enabled but nothing to do — clear the enabled flag
                Log.d("BootReceiver", "Service was enabled but idle — clearing flag to save battery")
                AppBlockerService.getPrefs(context).edit()
                    .putBoolean(AppBlockerService.KEY_SERVICE_ENABLED, false)
                    .apply()
            }

            // If Zen Mode was active before reboot, re-show the Zen lock screen overlay
            // so the phone wakes directly to the Zen countdown (not the normal lock screen)
            if (wasZen) {
                Log.d("BootReceiver", "Zen Mode was active — restoring ZenLockScreenActivity")
                ZenLockScreenActivity.show(context)
            }
        }
    }
}
