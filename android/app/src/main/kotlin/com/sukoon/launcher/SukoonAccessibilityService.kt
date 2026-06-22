package com.sukoon.launcher

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Precise foreground-app detector for the App Timer.
 *
 * Listens ONLY for window-state changes and reports the foreground package name
 * to [AppBlockerService], which uses it for instant, event-driven limit
 * enforcement — far more precise than the 3-second UsageStats lookback, and it
 * reacts the moment an app comes to the front.
 *
 * Privacy: it never reads screen content (canRetrieveWindowContent=false in the
 * config), only the package name of the window that just opened. Nothing is
 * stored to disk, logged, or sent anywhere — it lives in memory and feeds the
 * on-device timer alone. 100% offline.
 */
class SukoonAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg.isBlank() || pkg == packageName) return
        AppBlockerService.reportA11yForeground(pkg)
    }

    override fun onInterrupt() {
        // No-op: we don't hold any feedback to interrupt.
    }
}
