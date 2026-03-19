import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../utils/hive_box_manager.dart';
import '../models/prayer_alarm_config.dart';

// ─────────────────────────────────────────────────────
// TOP-LEVEL alarm callback (MUST be top-level for AOT)
// ─────────────────────────────────────────────────────

/// Called by AndroidAlarmManager in a background isolate.
/// MUST be a top-level function, NOT a static class method.
///
/// Behaviour by alarm mode:
///  'notify'       → shows a banner notification (no sound, no wake screen)
///  'adhan'        → native AlarmBroadcastReceiver handles wake + adhan audio
///  'fullscreen'   → native AlarmBroadcastReceiver handles wake + full-screen alarm
///  'off'          → never scheduled, so this never fires.
@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(int alarmId) async {
  // In isolate — re-init Hive
  try {
    await Hive.initFlutter();
  } catch (_) {}

  Box? box;
  try {
    box = await Hive.openBox('prayer_pending_alarms');
  } catch (_) {
    // Can't read box — fire a plain notification as last resort
    await PrayerAlarmService._showPrayerNotification('Prayer', 'notify');
    return;
  }

  // Look up the prayer name AND notifType by the alarm ID
  String prayerName = 'Prayer';
  String notifType = 'notify';
  final data = box.get(alarmId.toString());
  if (data is Map) {
    prayerName = data['prayer'] as String? ?? 'Prayer';
    notifType = data['notifType'] as String? ?? 'notify';
  } else {
    // Fallback: derive from alarm ID
    const idToPrayer = {
      1000: 'Fajr',
      1001: 'Dhuhr',
      1002: 'Asr',
      1003: 'Maghrib',
      1004: 'Isha',
      1005: 'Fajr',
      1006: 'Dhuhr',
      1007: 'Asr',
      1008: 'Maghrib',
      1009: 'Isha',
    };
    prayerName = idToPrayer[alarmId] ?? 'Prayer';
  }

  // 'adhan' and 'fullscreen' are both handled by the native AlarmBroadcastReceiver.
  // This Flutter callback is ONLY scheduled for 'notify' mode.
  if (notifType == 'adhan' || notifType == 'fullscreen') return;

  // 'notify' → show a system-sound notification banner.
  await PrayerAlarmService._showPrayerNotification(prayerName, notifType);
}

/// Prayer alarm scheduling + notification service.
///
/// Design:
/// 1. Uses AndroidAlarmManager for exact background wakeup.
/// 2. Uses flutter_local_notifications for heads-up alarm notification.
/// 3. Notification tap opens the prayer alarm screen via Navigator payload.
/// 4. No persistent background service — only 5 exact alarms per day.
///
/// Battery impact: ~3-5% daily (same as Google Calendar reminders).
class PrayerAlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Channel to communicate with AlarmActivity (native wake-screen activity).
  static const _alarmActivityChannel =
      MethodChannel('com.sukoon.launcher/alarm_activity');

  static bool _initialized = false;

  /// Called when the alarm screen is requested by native.
  static Function(String prayerName)? onAlarmScreenRequested;

  /// Called when native requests sound to be stopped (e.g. volume key press).
  /// Set this in PrayerAlarmScreen.initState and cleared in dispose.
  static VoidCallback? onStopAlarmSoundRequested;

  /// Guard: recently dismissed prayers won't re-open the alarm screen.
  /// Maps prayer name → dismissal timestamp. Prevents resume-triggered re-open.
  static final Map<String, DateTime> _recentlyDismissed = {};

  /// Guard: prevents multiple alarm screens from being pushed simultaneously.
  /// This is the SINGLE lock that prevents the triple-screen bug.
  /// Set to the prayer name when an alarm screen is showing; null when not.
  static String? _alarmScreenShowing;

  /// Call this when the alarm screen is opened.
  /// Also tells MainActivity to start intercepting volume keys.
  static void markAlarmScreenShowing(String prayerName) {
    _alarmScreenShowing = prayerName;
    _setNativeAlarmScreenActive(true);
  }

  /// Call this when the alarm screen is closed (dismissed/prayed/snoozed).
  /// Also tells MainActivity to stop intercepting volume keys.
  static void markAlarmScreenClosed() {
    _alarmScreenShowing = null;
    _setNativeAlarmScreenActive(false);
  }

  /// Notifies native MainActivity whether the alarm screen is currently visible.
  /// This gates the volume-key interception in dispatchKeyEvent.
  static void _setNativeAlarmScreenActive(bool active) {
    try {
      _alarmActivityChannel.invokeMethod('setAlarmScreenActive', active);
    } catch (_) {}
  }

  /// Whether an alarm screen is currently being displayed.
  static bool get isAlarmScreenShowing => _alarmScreenShowing != null;

  // ── Initialization ──────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();
    // Get device timezone name via platform channel (avoids flutter_timezone plugin)
    String currentTz;
    try {
      const platform = MethodChannel('sukoon/timezone');
      currentTz = await platform.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
    } catch (_) {
      // Fallback: try common Android timezone API via DateTime
      currentTz = DateTime.now().timeZoneName;
      // timeZoneName returns abbreviations like 'IST', convert to IANA if needed
      if (!tz.timeZoneDatabase.locations.containsKey(currentTz)) {
        currentTz = 'UTC';
      }
    }
    try {
      tz.setLocalLocation(tz.getLocation(currentTz));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Initialize alarm manager
    await AndroidAlarmManager.initialize();

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Channel 1: 'prayer_reminder' — notify mode: system sound banner
    const reminderChannel = AndroidNotificationChannel(
      'prayer_reminder',
      'Prayer Reminders',
      description: 'Banner with system sound — Notify mode',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Channel 2: 'prayer_adhan' — adhan mode: plays adhan mp3 from res/raw
    // Sound URI references android/app/src/main/res/raw/adhan_madinah.mp3
    final adhanChannel = AndroidNotificationChannel(
      'prayer_adhan',
      'Prayer Adhan',
      description: 'Notification with Adhan sound — Adhan mode',
      importance: Importance.high,
      playSound: true,
      sound: UriAndroidNotificationSound('android.resource://com.sukoon.launcher/raw/adhan_madinah'),
      enableVibration: true,
      showBadge: true,
    );

    // Channel 3: 'prayer_alarm' — fullscreen mode: native handles sound, no
    // flutter sound on this channel (the native AlarmBroadcastReceiver plays
    // audio via AudioManager on the ALARM stream which overrides DND).
    const alarmChannel = AndroidNotificationChannel(
      'prayer_alarm',
      'Prayer Full Alarm',
      description: 'Full-screen alarm wake — Full Alarm mode',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(reminderChannel);
    await androidPlugin?.createNotificationChannel(adhanChannel);
    await androidPlugin?.createNotificationChannel(alarmChannel);

    // Listen for calls pushed from native (MainActivity)
    _alarmActivityChannel.setMethodCallHandler((call) async {
      if (call.method == 'showAlarmScreen') {
        final prayerName = call.arguments as String? ?? 'Prayer';
        debugPrint('🕌 Native pushed showAlarmScreen: $prayerName');
        // Clear SharedPrefs so checkNativeAlarmPending doesn't double-fire
        try {
          await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
        } catch (_) {}
        // Guard: don't push if alarm screen is already showing
        if (_alarmScreenShowing == null) {
          // Check if recently dismissed
          final dismissed = _recentlyDismissed[prayerName];
          if (dismissed != null &&
              DateTime.now().difference(dismissed).inMinutes < 10) {
            return;
          }
          onAlarmScreenRequested?.call(prayerName);
        }
      } else if (call.method == 'stopAlarmSound') {
        // Volume key pressed in MainActivity while alarm is visible.
        // Delegate to the alarm screen's stop callback.
        debugPrint('🔇 Volume key stop requested from native');
        onStopAlarmSoundRequested?.call();
      }
    });

    _initialized = true;
  }

  /// Read the prayer name written by AlarmActivity into SharedPreferences.
  /// Call this on app startup and on resume — covers both cold-start and
  /// background-resume scenarios. Clears the value after reading so it
  /// isn't replayed on the next resume.
  static Future<void> checkNativeAlarmPending() async {
    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    try {
      final name = await _alarmActivityChannel
          .invokeMethod<String?>('pendingPrayerName');
      if (name != null && name.isNotEmpty) {
        // Guard: don't push if alarm screen is already showing
        if (_alarmScreenShowing != null) return;
        // Check if this prayer was recently dismissed (within 10 min)
        final dismissed = _recentlyDismissed[name];
        if (dismissed != null &&
            DateTime.now().difference(dismissed).inMinutes < 10) {
          // Already dismissed — clear the SharedPrefs and skip
          await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
          return;
        }
        // Clear immediately so we don't re-show on the next resume
        await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
        // Brief delay to let the widget tree finish any pending frame
        await Future.delayed(const Duration(milliseconds: 200));
        onAlarmScreenRequested?.call(name);
      }
    } catch (_) {
      // Platform channel not available (e.g. on iOS / desktop) — ignore
    }
  }

  /// Dismiss the keep-screen-on flag after the user acts on the alarm.
  static Future<void> dismissAlarmWakeFlags() async {
    try {
      await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
    } catch (_) {}
  }

  /// Check if app was launched by tapping a prayer notification.
  /// Call this AFTER setting [onAlarmScreenRequested].
  static Future<void> checkPendingNotificationLaunch() async {
    if (_alarmScreenShowing != null) return;

    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse != null) {
      final payload = details.notificationResponse!.payload;
      if (payload != null && payload.isNotEmpty) {
        if (_alarmScreenShowing != null) return;
        // Small delay to let the MaterialApp finish building
        await Future.delayed(const Duration(milliseconds: 500));
        if (_alarmScreenShowing != null) return;
        onAlarmScreenRequested?.call(payload);
      }
    }
  }

  /// Check for active native alarm notifications and open the alarm screen.
  /// Call this when the app comes to foreground.
  /// Only reacts to native AlarmBroadcastReceiver notifications (IDs 3000-3004)
  /// which correspond to 'fullscreen' mode. Flutter notify/adhan notifications
  /// (IDs 2000-2004) are intentionally ignored — those should NOT open the
  /// full-screen alarm screen, they just play a sound in the notification bar.
  static Future<void> checkActiveNotifications() async {
    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final activeNotifications = await android.getActiveNotifications();
        for (final notification in activeNotifications) {
          if (notification.id == null) continue;
          final id = notification.id!;
          // ONLY native AlarmBroadcastReceiver notifications (IDs 3000-3004)
          // should trigger the full-screen alarm screen.
          // Flutter notify/adhan notifications (2000-2004) are silent banners
          // and should NEVER open the alarm screen.
          const nativeToPrayer = {
            3000: 'Fajr', 3001: 'Dhuhr', 3002: 'Asr',
            3003: 'Maghrib', 3004: 'Isha',
          };
          final prayerName = nativeToPrayer[id];
          if (prayerName != null) {
            // Check if recently dismissed — don't re-open
            final dismissed = _recentlyDismissed[prayerName];
            if (dismissed != null &&
                DateTime.now().difference(dismissed).inMinutes < 10) {
              continue;
            }
            if (_alarmScreenShowing != null) return;
            onAlarmScreenRequested?.call(prayerName);
            return; // Open only the first one found
          }
        }
      }
    } catch (_) {
      // If checking fails, do nothing
    }
  }

  // ── Schedule alarms ─────────────────────────────────

  /// Schedule all prayer alarms for a given day.
  ///
  /// Alarm paths based on per-prayer mode:
  ///
  ///  'notify'      → Flutter AndroidAlarmManager only.
  ///                  Silent banner notification. Does NOT wake the screen.
  ///
  ///  'adhan'       → Native AlarmManager → AlarmBroadcastReceiver.
  ///                  Notification + adhan audio playback.
  ///
  ///  'fullscreen'  → Native AlarmManager → AlarmBroadcastReceiver.
  ///                  Wakes screen, full-page alarm + adhan audio.
  ///
  ///  'off'         → Nothing is scheduled.
  static Future<void> scheduleDailyAlarms({
    required Map<String, String> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required DateTime date,
    PrayerReminderSettings? reminderSettings,
  }) async {
    // Verify permissions before scheduling
    final notifGranted = await Permission.notification.isGranted;
    final exactAlarm = await canScheduleExactAlarms();
    if (!notifGranted || !exactAlarm) {
      debugPrint('PrayerAlarmService: Missing permissions, skipping schedule');
      return;
    }

    // Cancel previous alarms first
    await cancelAllAlarms();

    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      final prayerName = entry.key;
      final timeStr = entry.value;
      final enabled = enabledPrayers[prayerName] ?? true;

      if (!enabled) continue;

      // Check per-prayer alarm mode — skip if off
      final notifType = reminderSettings?.notifTypeFor(prayerName) ?? 'notify';
      if (notifType == 'off') continue;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final alarmTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      // Don't schedule alarms in the past
      if (alarmTime.isBefore(now)) continue;

      final alarmId = _alarmIdForPrayer(prayerName);

      if (notifType == 'notify') {
        // ── NOTIFY PATH ─────────────────────────────────────────────────────
        // Flutter AlarmManager → prayerAlarmCallback → system-sound notification.
        await _storePendingAlarm(alarmId, prayerName, timeStr, notifType: notifType);

        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          alarmId,
          prayerAlarmCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      } else if (notifType == 'adhan' || notifType == 'fullscreen') {
        // ── ADHAN / FULLSCREEN PATH ──────────────────────────────────────────
        // Both go through the native AlarmBroadcastReceiver which runs even
        // from Doze mode. The receiver reads 'notifType' to decide:
        //   'adhan'      → notification + MediaPlayer adhan at ALARM stream, no wake.
        //   'fullscreen' → full wake + fullScreenIntent + Flutter alarm screen.
        await _storePendingAlarm(alarmId, prayerName, timeStr, notifType: notifType);

        try {
          await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
            'prayerName': prayerName,
            'triggerAtMillis': alarmTime.millisecondsSinceEpoch,
            'notifType': notifType,   // ← pass mode to native
          });
        } catch (e) {
          debugPrint('Warning: Could not schedule native alarm for $prayerName: $e');
        }
      }
    }
  }

  /// Schedule a snooze alarm (re-notify after N minutes).
  ///
  /// [notifType] determines the path — same rules as [scheduleDailyAlarms]:
  ///  'notify'      → Flutter callback only (banner notification)
  ///  'adhan'/'fullscreen' → Native AlarmManager (full-screen wake alarm)
  static Future<void> scheduleSnooze({
    required String prayerName,
    required int minutes,
    String notifType = 'fullscreen',
  }) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final alarmId = _alarmIdForPrayer('${prayerName}_snooze');

    await _storePendingAlarm(alarmId, prayerName, '', notifType: notifType);

    if (notifType == 'notify') {
      // Banner notification path — no screen wake needed for snooze
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
    } else {
      // 'adhan'/'fullscreen' alarm path
      // Flutter callback as safety net
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      // Native alarm → wake screen
      try {
        await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
          'prayerName': prayerName,
          'triggerAtMillis': snoozeTime.millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Warning: Could not schedule native snooze alarm: $e');
      }
    }
  }

  /// Cancel all scheduled prayer alarms.
  static Future<void> cancelAllAlarms() async {
    for (int i = 0; i < 12; i++) {
      await AndroidAlarmManager.cancel(1000 + i);
    }
    // Cancel native alarms (prayers + fasting)
    const alarmLabels = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Suhoor', 'Iftar'];
    for (final label in alarmLabels) {
      try {
        await _alarmActivityChannel.invokeMethod('cancelNativeAlarm', {
          'prayerName': label,
        });
      } catch (_) {}
    }
    // Clear pending alarm data
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.clear();
    } catch (_) {}
  }

  // ── Fasting alarms (Suhoor / Iftar) ─────────────────

  /// Store fasting alarm info so the background callback can read it.
  static Future<void> storeFastingAlarm(
      int alarmId, String label, DateTime alarmTime) async {
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.put(alarmId.toString(), {
        'prayer': label,
        'time':
            '${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}',
      });
    } catch (_) {}
  }

  /// Schedule a Suhoor or Iftar alarm using the same system as prayer alarms.
  /// Uses IDs 1010 (Suhoor) and 1011 (Iftar).
  static Future<void> scheduleFastingAlarm({
    required String label,
    required DateTime alarmTime,
    required int alarmId,
  }) async {
    // ① AndroidAlarmManager — fires Dart callback in background isolate
    await AndroidAlarmManager.oneShotAt(
      alarmTime,
      alarmId,
      prayerAlarmCallback,  // same top-level callback — reads label from Hive
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );

    // ② Native AlarmManager → AlarmBroadcastReceiver (wake screen + sound)
    try {
      await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
        'prayerName': label,
        'triggerAtMillis': alarmTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Warning: Could not schedule native fasting alarm for $label: $e');
    }
  }

  // ── Show notification ───────────────────────────────

  /// Shows a prayer notification appropriate for the given [notifType].
  ///
  ///  'notify' → silent banner notification, no sound, no full-screen.
  ///
  ///  anything else → safety fallback banner if native was cancelled.
  static Future<void> _showPrayerNotification(
    String prayerName,
    String notifType,
  ) async {
    // Ensure notifications plugin is initialized (in background isolate context)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // Register the 'prayer_reminder' channel in the background isolate.
    // Only 'notify' mode reaches here — 'adhan' and 'fullscreen' are handled
    // entirely by the native AlarmBroadcastReceiver (MediaPlayer at alarm stream).
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'prayer_reminder',
        'Prayer Reminders',
        description: 'Banner with system notification sound — Notify mode',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // Show a standard system-sound notification banner.
    final androidDetails = AndroidNotificationDetails(
      'prayer_reminder',
      'Prayer Reminders',
      channelDescription: 'Banner with system notification sound',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ongoing: false,
      playSound: true,        // uses channel default = device notification sound
      sound: null,            // null = channel default sound
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      fullScreenIntent: false, // never full-screen from this path
      timeoutAfter: 120000,
      styleInformation: BigTextStyleInformation(
        _getPrayerMessage(prayerName),
        contentTitle: '🕌 ${prayerName.toUpperCase()} TIME',
        summaryText: 'Tap to dismiss',
      ),
    );

    await _notifications.show(
      _notificationIdForPrayer(prayerName),
      '🕌 ${prayerName.toUpperCase()} TIME',
      _getPrayerMessage(prayerName),
      NotificationDetails(android: androidDetails),
      payload: prayerName,
    );
  }

  // ── Notification tap → open alarm screen ────────────

  static void _onNotificationTapped(NotificationResponse response) {
    final prayerName = response.payload ?? 'Prayer';

    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    // Always cancel/dismiss the notification when tapped — this stops
    // the adhan sound for the 'adhan' channel (system cancels channel audio).
    _cancelNotificationNative(_notificationIdForPrayer(prayerName));

    // Look up what mode this prayer was set to.
    // For 'notify' and 'adhan', tapping just dismisses the notification.
    // The adhan sound stops automatically when the notification is cancelled.
    // Only the 'fullscreen' path should open the alarm screen, but those
    // notifications come from the native AlarmBroadcastReceiver (IDs 3000+),
    // NOT through here (Flutter notifications are IDs 2000-2004).
    // So: do NOT open the alarm screen from here.
    // (The fullscreen alarm screen opens via the native 'showAlarmScreen' call.)
  }

  /// Dismiss the active notification for a prayer and mark as dismissed.
  static Future<void> dismissNotification(String prayerName) async {
    // Mark as recently dismissed so resume doesn't re-open the alarm
    _recentlyDismissed[prayerName] = DateTime.now();

    // Clear the alarm-screen-showing guard
    _alarmScreenShowing = null;

    // Cancel Flutter notification (ID 2000-2004) via native NotificationManager
    // (bypasses flutter_local_notifications v18 "Missing type parameter" bug)
    await _cancelNotificationNative(_notificationIdForPrayer(prayerName));

    // Cancel native AlarmBroadcastReceiver notification (ID 3000-3004)
    const nativeIds = {
      'Fajr': 3000, 'Dhuhr': 3001, 'Asr': 3002,
      'Maghrib': 3003, 'Isha': 3004,
    };
    final nativeId = nativeIds[prayerName];
    if (nativeId != null) {
      await _cancelNotificationNative(nativeId);
    }

    // Clear SharedPrefs so checkNativeAlarmPending doesn't re-fire
    try {
      await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
    } catch (_) {}
  }

  /// Cancel a notification by ID using native Android NotificationManager.
  /// This bypasses the flutter_local_notifications v18 bug entirely.
  static Future<void> _cancelNotificationNative(int notificationId) async {
    try {
      await _alarmActivityChannel.invokeMethod('cancelNotificationById', {
        'notificationId': notificationId,
      });
    } catch (e) {
      // Fallback: try flutter_local_notifications anyway
      try {
        await _notifications.cancel(notificationId);
      } catch (_) {}
    }
  }

  // ── Helpers ─────────────────────────────────────────

  static int _alarmIdForPrayer(String name) {
    const prayerIds = {
      'Fajr': 1000,
      'Dhuhr': 1001,
      'Asr': 1002,
      'Maghrib': 1003,
      'Isha': 1004,
      'Fajr_snooze': 1005,
      'Dhuhr_snooze': 1006,
      'Asr_snooze': 1007,
      'Maghrib_snooze': 1008,
      'Isha_snooze': 1009,
    };
    return prayerIds[name] ?? (name.hashCode.abs() % 500 + 1000);
  }

  static int _notificationIdForPrayer(String name) {
    const ids = {
      'Fajr': 2000,
      'Dhuhr': 2001,
      'Asr': 2002,
      'Maghrib': 2003,
      'Isha': 2004,
    };
    return ids[name] ?? 2000;
  }

  static Future<void> _storePendingAlarm(
    int alarmId,
    String prayerName,
    String time, {
    String notifType = 'notify',
  }) async {
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.put(alarmId.toString(), {
        'prayer': prayerName,
        'time': time,
        'notifType': notifType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static String _getPrayerMessage(String prayerName) {
    const messages = {
      'Fajr': 'Rise before the sun — the most beloved prayer to Allah ☀️',
      'Dhuhr': 'Pause your day, reconnect with your Lord 🫶',
      'Asr': 'Don\'t let this prayer slip away — the angels are witnessing 🌤️',
      'Maghrib': 'The sun has set — rush to meet your Lord 🌅',
      'Isha': 'Close your day with peace and forgiveness 🌙',
    };
    return messages[prayerName] ?? 'It\'s time for $prayerName prayer';
  }

  /// Request notification permission (Android 13+).
  static Future<bool> requestNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Check if exact alarms are permitted (Android 12+).
  static Future<bool> canScheduleExactAlarms() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? true;
  }

  /// Open battery optimization settings directly for this app.
  /// Uses native intent ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
  static Future<void> openBatterySettings() async {
    try {
      await _alarmActivityChannel.invokeMethod('openBatterySettings');
    } catch (_) {
      // Fallback: try permission_handler
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  /// Check if full-screen intent permission is granted (Android 14+).
  /// On older versions, this always returns true.
  /// Without this permission, the alarm notification's fullScreenIntent
  /// won't launch the alarm Activity over the lock screen.
  static Future<bool> canUseFullScreenIntent() async {
    try {
      final result = await _alarmActivityChannel
          .invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (_) {
      return true; // Assume granted if channel unavailable
    }
  }

  /// Open system settings for the user to grant full-screen intent permission.
  /// Only relevant on Android 14+ (API 34+).
  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _alarmActivityChannel.invokeMethod('openFullScreenIntentSettings');
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  // ── Test / Preview helpers ──────────────────────────────────────────

  /// Show an instant preview notification banner for the given prayer.
  /// Uses the standard notification channel — no sound or full-screen.
  static Future<void> showPreviewNotification(String prayerName) async {
    await initialize();

    const channel = AndroidNotificationChannel(
      'prayer_alarm_preview',
      'Prayer Alarm Preview',
      description: 'Example alarm notifications',
      importance: Importance.high,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          _getPrayerMessage(prayerName),
          contentTitle: '🕌 $prayerName — Example Preview',
        ),
      ),
    );

    // Use unique ID based on timestamp to avoid overwriting
    await _notifications.show(
      99900 + DateTime.now().millisecondsSinceEpoch % 100,
      '🕌 $prayerName — Example Preview',
      _getPrayerMessage(prayerName),
      details,
    );
  }

  /// Schedule a test alarm at a custom time using native AlarmManager.
  /// Returns true if successful.
  static Future<bool> scheduleTestAlarm({
    required String prayerName,
    required DateTime triggerAt,
  }) async {
    try {
      final millis = triggerAt.millisecondsSinceEpoch;
      await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
        'prayerName': prayerName,
        'triggerAtMillis': millis,
      });
      debugPrint('⏰ Test alarm scheduled at $triggerAt');
      return true;
    } catch (e) {
      debugPrint('❌ Test alarm scheduling failed: $e');
      return false;
    }
  }
}
