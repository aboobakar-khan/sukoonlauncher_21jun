import 'package:flutter/services.dart';

/// Bridge to native Android AppBlockerService.
///
/// This service runs a foreground service that monitors the foreground app
/// every 500ms. If a blocked app is detected (even opened via notification
/// tap or recent apps), it immediately shows a blocking overlay.
///
/// Requires USAGE_STATS permission (user must grant in settings).
class NativeAppBlockerService {
  static const _channel = MethodChannel('com.sukoon.launcher/app_blocker');

  /// Start the native foreground blocker service
  static Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod('startService');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the native foreground blocker service
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod('stopService');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Sync the list of blocked packages to the native service.
  /// Call this whenever block rules change.
  /// If the list is empty, the service will auto-stop.
  /// If non-empty and service isn't running, it will auto-start.
  static Future<bool> updateBlockedPackages(List<String> packages) async {
    try {
      final result = await _channel.invokeMethod('updateBlockedPackages', {
        'packages': packages,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the native blocker service is currently running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if Usage Stats permission is granted (required for foreground detection)
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod('hasUsageStatsPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Open system settings to grant Usage Stats permission
  static Future<bool> requestUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod('requestUsageStatsPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if notification permission is granted (Android 13+ requires this)
  static Future<bool> hasNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod('hasNotificationPermission');
      return result == true;
    } catch (e) {
      return true; // Assume granted on older Android
    }
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod('requestNotificationPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  // ── Special permissions via the shared `app_settings` channel ──
  // (accessibility / overlay can't be read by permission_handler)
  static const _settingsChannel = MethodChannel('app_settings');

  /// Whether Sukoon's AccessibilityService (precise foreground detection) is on.
  static Future<bool> hasAccessibilityPermission() async {
    try {
      final r = await _settingsChannel.invokeMethod<bool>(
          'checkSpecialPermission', {'type': 'accessibility'});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Open the system Accessibility settings so the user can enable our service.
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _settingsChannel
          .invokeMethod('openPermissionSettings', {'type': 'accessibility'});
    } catch (_) {}
  }

  /// Whether "appear on top" / draw-over-other-apps is granted.
  static Future<bool> hasOverlayPermission() async {
    try {
      final r = await _settingsChannel.invokeMethod<bool>(
          'checkSpecialPermission', {'type': 'overlay'});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Open the "Display over other apps" settings page.
  static Future<void> requestOverlayPermission() async {
    try {
      await _settingsChannel
          .invokeMethod('openPermissionSettings', {'type': 'overlay'});
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🕐 Timed Session Bridge (App Time Intent feature)
  // ═══════════════════════════════════════════════════════════════════════════

  static const _usageChannel = MethodChannel('com.sukoon.launcher/usage_stats');

  /// Start a timed session — native service will show overlay when limit expires
  static Future<bool> startTimedSession(String packageName, int minutes) async {
    try {
      final result = await _channel.invokeMethod('startTimedSession', {
        'packageName': packageName,
        'minutes': minutes,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Extend an active timed session by additional minutes
  static Future<bool> extendTimedSession(String packageName, int additionalMinutes) async {
    try {
      final result = await _channel.invokeMethod('extendTimedSession', {
        'packageName': packageName,
        'additionalMinutes': additionalMinutes,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// End a timed session (user returned to launcher)
  static Future<bool> endTimedSession(String packageName) async {
    try {
      final result = await _channel.invokeMethod('endTimedSession', {
        'packageName': packageName,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Update the list of timer-managed packages
  static Future<void> updateTimerPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod('updateTimerPackages', {'packages': packages});
    } catch (_) {}
  }

  /// Check if there's a pending "time's up" event from the native side
  static Future<Map<String, dynamic>?> getPendingTimesUp() async {
    try {
      final result = await _channel.invokeMethod('getPendingTimesUp');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if there's a pending "prompt timer" event from the native side
  static Future<Map<String, dynamic>?> getPendingPromptTimer() async {
    try {
      final result = await _channel.invokeMethod('getPendingPromptTimer');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get usage stats from native UsageStatsManager
  static Future<List<Map<String, dynamic>>> getUsageStats(int startTime, int endTime) async {
    try {
      final result = await _usageChannel.invokeMethod('getUsageStats', {
        'startTime': startTime,
        'endTime': endTime,
      });
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get per-day usage stats for the last [days] days.
  /// Returns list of DailyUsageStat — index 0 = today, index 1 = yesterday, etc.
  static Future<List<Map<String, dynamic>>> getDailyUsageStats({int days = 7}) async {
    try {
      final result = await _usageChannel.invokeMethod('getDailyUsageStats', {
        'days': days,
      });
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📬 Notification Filter Bridge
  // ═══════════════════════════════════════════════════════════════════════════

  static const _notifChannel = MethodChannel('com.sukoon.launcher/notification_filter');

  /// Check if Notification Listener permission is granted
  static Future<bool> hasNotificationListenerPermission() async {
    try {
      final result = await _notifChannel.invokeMethod('hasPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Open system settings to grant Notification Listener permission
  static Future<bool> requestNotificationListenerPermission() async {
    try {
      final result = await _notifChannel.invokeMethod('requestPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Get currently cached notifications from the native listener
  static Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    try {
      final result = await _notifChannel.invokeMethod('getCachedNotifications');
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Clear a specific notification by key
  static Future<bool> clearNotification(String key) async {
    try {
      final result = await _notifChannel.invokeMethod('clearNotification', {'key': key});
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached notifications
  static Future<bool> clearAllNotifications() async {
    try {
      final result = await _notifChannel.invokeMethod('clearAll');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Launch an app by its package name
  static Future<bool> launchApp(String packageName) async {
    try {
      final result = await _notifChannel.invokeMethod('launchApp', {'packageName': packageName});
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Open a notification's original contentIntent (deep-link).
  /// Falls back to launching the app if the PendingIntent expired.
  static Future<bool> openNotificationIntent(String key) async {
    try {
      final result = await _notifChannel.invokeMethod('openNotificationIntent', {'key': key});
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Push the allowed packages list to the native service so it can suppress
  /// notifications from non-allowed apps in the Android system notification bar.
  static Future<bool> updateAllowedPackages(List<String> packages, {bool enabled = true}) async {
    try {
      final result = await _notifChannel.invokeMethod('updateAllowedPackages', {
        'packages': packages,
        'enabled': enabled,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Get the total number of notifications suppressed since filter was enabled
  static Future<int> getTotalSuppressed() async {
    try {
      final result = await _notifChannel.invokeMethod('getTotalSuppressed');
      return (result as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Show or update the persistent hint notification in the system notification bar
  static Future<bool> showHintNotification() async {
    try {
      final result = await _notifChannel.invokeMethod('showHintNotification');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
