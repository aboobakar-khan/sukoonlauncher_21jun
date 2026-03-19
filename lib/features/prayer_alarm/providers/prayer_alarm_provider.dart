import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../utils/hive_box_manager.dart';
import '../models/prayer_alarm_config.dart';
import '../services/aladhan_api_service.dart';
import '../services/prayer_alarm_service.dart';
import '../utils/prayer_time_utils.dart';

// ─────────────────────────────────────────────────────
// Prayer Alarm State
// ─────────────────────────────────────────────────────

class PrayerAlarmState {
  final PrayerAlarmConfig config;
  final PrayerReminderSettings reminderSettings;
  final DailyPrayerTimes? todayTimes;
  final bool isLoading;
  final String? error;
  final bool isSetupComplete;

  const PrayerAlarmState({
    required this.config,
    required this.reminderSettings,
    this.todayTimes,
    this.isLoading = false,
    this.error,
    this.isSetupComplete = false,
  });

  PrayerAlarmState copyWith({
    PrayerAlarmConfig? config,
    PrayerReminderSettings? reminderSettings,
    DailyPrayerTimes? todayTimes,
    bool? isLoading,
    String? error,
    bool? isSetupComplete,
  }) {
    return PrayerAlarmState(
      config: config ?? this.config,
      reminderSettings: reminderSettings ?? this.reminderSettings,
      todayTimes: todayTimes ?? this.todayTimes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
    );
  }

  /// Get the effective time for a prayer (adjustment > override > API).
  /// Priority: manual override (if set) → API time + adjustment.
  String? effectiveTimeFor(String prayer) {
    final override = reminderSettings.overrideFor(prayer);
    if (override.isNotEmpty) return override;
    final apiTime = todayTimes?.timeFor(prayer);
    if (apiTime == null) return null;
    final adj = reminderSettings.adjustmentFor(prayer);
    if (adj == 0) return apiTime;
    return _applyAdjustment(apiTime, adj);
  }

  /// Applies a minute adjustment to an "HH:mm" time string.
  static String _applyAdjustment(String timeStr, int minutes) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return timeStr;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    var total = h * 60 + m + minutes;
    if (total < 0) total += 24 * 60;
    total = total % (24 * 60);
    final adjH = total ~/ 60;
    final adjM = total % 60;
    return '${adjH.toString().padLeft(2, '0')}:${adjM.toString().padLeft(2, '0')}';
  }

  /// Map of prayer names → enabled status.
  Map<String, bool> get enabledMap => {
        'Fajr': reminderSettings.fajrEnabled,
        'Dhuhr': reminderSettings.dhuhrEnabled,
        'Asr': reminderSettings.asrEnabled,
        'Maghrib': reminderSettings.maghribEnabled,
        'Isha': reminderSettings.ishaEnabled,
      };

  /// Map of prayer names → effective times (with adjustments/overrides applied).
  /// Includes Sunrise.
  Map<String, String> get effectiveTimesMap {
    if (todayTimes == null) return {};
    final result = <String, String>{};
    for (final prayer in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final t = effectiveTimeFor(prayer);
      if (t != null) result[prayer] = t;
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────
// Prayer Alarm Notifier
// ─────────────────────────────────────────────────────

class PrayerAlarmNotifier extends StateNotifier<PrayerAlarmState> {
  PrayerAlarmNotifier()
      : super(PrayerAlarmState(
          config: PrayerAlarmConfig(),
          reminderSettings: PrayerReminderSettings(),
        )) {
    _init();
  }

  static const _configBoxName = 'prayer_alarm_config';
  static const _timesBoxName = 'prayer_alarm_times';
  static const _settingsBoxName = 'prayer_reminder_settings';

  Box? _configBox;
  Box<DailyPrayerTimes>? _timesBox;
  Box? _settingsBox;

  Future<void> _init() async {
    try {
      _configBox = await HiveBoxManager.get(_configBoxName);
      _timesBox = await HiveBoxManager.get<DailyPrayerTimes>(_timesBoxName);
      _settingsBox = await HiveBoxManager.get(_settingsBoxName);

      // Load saved config
      final savedConfig = _configBox!.get('config');
      final config = savedConfig is PrayerAlarmConfig
          ? savedConfig
          : PrayerAlarmConfig();

      // Load saved reminder settings
      final savedSettings = _settingsBox!.get('settings');
      var settings = savedSettings is PrayerReminderSettings
          ? savedSettings
          : PrayerReminderSettings();

      // ── Migrate old mode names to new ones ──
      settings = _migrateOldModes(settings);

      // Load cached prayer times for today
      final today = todayDateKey();
      final cachedTimes = _timesBox!.get(today);

      final isSetup = config.latitude != 0.0 || config.longitude != 0.0;

      state = state.copyWith(
        config: config,
        reminderSettings: settings,
        todayTimes: cachedTimes,
        isSetupComplete: isSetup,
      );

      // Offline-first: show cached times immediately, then refresh in background
      if (isSetup) {
        if (cachedTimes != null) {
          // Always schedule alarms from cache first (fast)
          await _scheduleAlarms();
        }
        // Fetch fresh times in background if stale or missing
        if (cachedTimes == null || config.lastFetchDate != today) {
          // Don't await — let it complete in background so UI stays fast
          fetchTodayPrayerTimes();
        }

        // Prefetch tomorrow's times after 9 PM so midnight transition is seamless
        _prefetchTomorrowIfNeeded();

        // Clean up old cached entries (older than 7 days)
        _cleanStaleCacheEntries();
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  /// Prefetch tomorrow's prayer times if it's after 9 PM and not yet cached.
  /// This ensures that when midnight rolls over, the widget can immediately
  /// show tomorrow's times from cache without waiting for a network request.
  Future<void> _prefetchTomorrowIfNeeded() async {
    final now = DateTime.now();
    if (now.hour < 21) return; // Only prefetch after 9 PM

    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowKey = dateKeyFor(tomorrow);
    final cached = _timesBox?.get(tomorrowKey);
    if (cached != null) return; // Already cached

    try {
      final times = await AladhanApiService.fetchPrayerTimes(
        latitude: state.config.latitude,
        longitude: state.config.longitude,
        method: state.config.calculationMethod,
        date: tomorrow,
        school: state.config.asrCalculationSchool, // Use configured Asr school
      );

      final dailyTimes = DailyPrayerTimes(
        dateKey: tomorrowKey,
        fajr: times['Fajr'] ?? '05:00',
        sunrise: times['Sunrise'] ?? '',
        dhuhr: times['Dhuhr'] ?? '12:00',
        asr: times['Asr'] ?? '15:30',
        maghrib: times['Maghrib'] ?? '18:00',
        isha: times['Isha'] ?? '19:30',
      );

      await _timesBox?.put(tomorrowKey, dailyTimes);
    } catch (_) {
      // Non-critical — will fetch tomorrow morning instead
    }
  }

  /// Remove cached prayer time entries older than 7 days to prevent
  /// unbounded Hive box growth.
  Future<void> _cleanStaleCacheEntries() async {
    if (_timesBox == null) return;
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final cutoffKey = dateKeyFor(cutoff);
      final keysToRemove = <String>[];
      for (final key in _timesBox!.keys) {
        if (key is String && key.compareTo(cutoffKey) < 0) {
          keysToRemove.add(key);
        }
      }
      for (final key in keysToRemove) {
        await _timesBox!.delete(key);
      }
    } catch (_) {
      // Non-critical cleanup — ignore errors
    }
  }

  /// Migrate old alarm mode strings to new naming convention.
  /// silent → off, notification → notify, athan → adhan.
  PrayerReminderSettings _migrateOldModes(PrayerReminderSettings s) {
    String migrate(String old) {
      switch (old) {
        case 'silent': return 'off';
        case 'notification': return 'notify';
        case 'athan': return 'adhan';
        default: return old;
      }
    }
    final migrated = s.copyWith(
      fajrNotifType: migrate(s.fajrNotifType),
      dhuhrNotifType: migrate(s.dhuhrNotifType),
      asrNotifType: migrate(s.asrNotifType),
      maghribNotifType: migrate(s.maghribNotifType),
      ishaNotifType: migrate(s.ishaNotifType),
      sunriseNotifType: migrate(s.sunriseNotifType),
    );
    // Persist the migrated settings
    if (migrated.fajrNotifType != s.fajrNotifType ||
        migrated.dhuhrNotifType != s.dhuhrNotifType ||
        migrated.asrNotifType != s.asrNotifType ||
        migrated.maghribNotifType != s.maghribNotifType ||
        migrated.ishaNotifType != s.ishaNotifType ||
        migrated.sunriseNotifType != s.sunriseNotifType) {
      _settingsBox?.put('settings', migrated);
    }
    return migrated;
  }

  // ── API fetch ──────────────────────────────────────

  /// Fetch today's prayer times from Aladhan API and cache locally.
  Future<void> fetchTodayPrayerTimes() async {
    if (state.config.latitude == 0.0 && state.config.longitude == 0.0) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final times = await AladhanApiService.fetchPrayerTimes(
        latitude: state.config.latitude,
        longitude: state.config.longitude,
        method: state.config.calculationMethod,
        date: DateTime.now(),
        school: state.config.asrCalculationSchool, // Use configured Asr school
      );

      final today = todayDateKey();
      final dailyTimes = DailyPrayerTimes(
        dateKey: today,
        fajr: times['Fajr'] ?? '05:00',
        sunrise: times['Sunrise'] ?? '',
        dhuhr: times['Dhuhr'] ?? '12:00',
        asr: times['Asr'] ?? '15:30',
        maghrib: times['Maghrib'] ?? '18:00',
        isha: times['Isha'] ?? '19:30',
      );

      // Save to cache
      await _timesBox?.put(today, dailyTimes);

      // Update last fetch date
      final updatedConfig = state.config.copyWith(lastFetchDate: today);
      await _configBox?.put('config', updatedConfig);

      state = state.copyWith(
        todayTimes: dailyTimes,
        config: updatedConfig,
        isLoading: false,
      );

      // Reschedule alarms with new times
      await _scheduleAlarms();

      // Also prefetch tomorrow if it's evening
      _prefetchTomorrowIfNeeded();
    } catch (e) {
      // Offline-first: keep showing cached times if available
      state = state.copyWith(
        isLoading: false,
        error: state.todayTimes != null
            ? null // Silently fail if we have cached data
            : 'Could not fetch prayer times. Check your internet.',
      );
    }
  }

  /// Fetch prayer times for any specific date (for timetable date navigation).
  /// Returns cached value immediately if available, else fetches from API.
  Future<DailyPrayerTimes?> fetchTimesForDate(DateTime date) async {
    if (state.config.latitude == 0.0 && state.config.longitude == 0.0) {
      return null;
    }
    final key = dateKeyFor(date);
    // Return from cache if available
    final cached = _timesBox?.get(key);
    if (cached != null) return cached;

    try {
      final times = await AladhanApiService.fetchPrayerTimes(
        latitude: state.config.latitude,
        longitude: state.config.longitude,
        method: state.config.calculationMethod,
        date: date,
        school: state.config.asrCalculationSchool,
      );
      final dt = DailyPrayerTimes(
        dateKey: key,
        fajr: times['Fajr'] ?? '05:00',
        sunrise: times['Sunrise'] ?? '',
        dhuhr: times['Dhuhr'] ?? '12:00',
        asr: times['Asr'] ?? '15:30',
        maghrib: times['Maghrib'] ?? '18:00',
        isha: times['Isha'] ?? '19:30',
      );
      await _timesBox?.put(key, dt);
      return dt;
    } catch (_) {
      return null;
    }
  }

  // ── Config updates ─────────────────────────────────

  /// Update location + calculation method, then re-fetch.
  Future<void> updateConfig({
    required double latitude,
    required double longitude,
    required String timezone,
    required String locationLabel,
    int? calculationMethod,
  }) async {
    final updated = state.config.copyWith(
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      locationLabel: locationLabel,
      calculationMethod: calculationMethod,
    );

    await _configBox?.put('config', updated);
    state = state.copyWith(config: updated, isSetupComplete: true);

    // Fetch with new config
    await fetchTodayPrayerTimes();
  }

  /// Update calculation method only.
  Future<void> setCalculationMethod(int method) async {
    final updated = state.config.copyWith(calculationMethod: method);
    await _configBox?.put('config', updated);
    state = state.copyWith(config: updated);
    await fetchTodayPrayerTimes();
  }

  /// Update Asr calculation school (0 = Shafi'i, 1 = Hanafi).
  /// Used primarily in Indo-Pak region where Hanafi madhab is prevalent.
  Future<void> setAsrCalculationSchool(int school) async {
    final updated = state.config.copyWith(asrCalculationSchool: school);
    await _configBox?.put('config', updated);
    state = state.copyWith(config: updated);
    await fetchTodayPrayerTimes();
  }

  // ── Reminder settings ──────────────────────────────

  /// Check if required permissions are granted for scheduling alarms.
  /// Returns true if both notification and exact alarm permissions are OK.
  Future<bool> hasRequiredPermissions() async {
    final notifGranted = await Permission.notification.isGranted;
    final exactAlarm = await PrayerAlarmService.canScheduleExactAlarms();
    return notifGranted && exactAlarm;
  }

  /// Toggle a specific prayer alarm on/off.
  /// If enabling, checks permissions first. Returns false if permissions missing.
  Future<bool> togglePrayerAlarm(String prayer, bool enabled) async {
    // When enabling, verify permissions first
    if (enabled) {
      final hasPerms = await hasRequiredPermissions();
      if (!hasPerms) {
        return false; // Caller should show permission setup screen
      }
    }

    PrayerReminderSettings updated;
    switch (prayer) {
      case 'Fajr':
        updated = state.reminderSettings.copyWith(fajrEnabled: enabled);
        break;
      case 'Dhuhr':
        updated = state.reminderSettings.copyWith(dhuhrEnabled: enabled);
        break;
      case 'Asr':
        updated = state.reminderSettings.copyWith(asrEnabled: enabled);
        break;
      case 'Maghrib':
        updated = state.reminderSettings.copyWith(maghribEnabled: enabled);
        break;
      case 'Isha':
        updated = state.reminderSettings.copyWith(ishaEnabled: enabled);
        break;
      default:
        return true;
    }

    await _settingsBox?.put('settings', updated);
    state = state.copyWith(reminderSettings: updated);
    await _scheduleAlarms();
    return true;
  }

  /// Set per-prayer alarm mode: 'off', 'notify', 'adhan'.
  /// When set to 'off', also disables that prayer's alarm.
  /// When set to anything else, also enables that prayer's alarm.
  /// Returns false if permissions are missing (when enabling).
  Future<bool> setPrayerNotifType(String prayer, String type) async {
    // If switching away from off, check permissions
    if (type != 'off') {
      final hasPerms = await hasRequiredPermissions();
      if (!hasPerms) {
        return false;
      }
    }

    final updated = state.reminderSettings.withNotifType(prayer, type);

    // Also toggle enabled status based on type
    PrayerReminderSettings withEnabled;
    final shouldEnable = type != 'off';
    switch (prayer) {
      case 'Fajr':
        withEnabled = updated.copyWith(fajrEnabled: shouldEnable);
        break;
      case 'Dhuhr':
        withEnabled = updated.copyWith(dhuhrEnabled: shouldEnable);
        break;
      case 'Asr':
        withEnabled = updated.copyWith(asrEnabled: shouldEnable);
        break;
      case 'Maghrib':
        withEnabled = updated.copyWith(maghribEnabled: shouldEnable);
        break;
      case 'Isha':
        withEnabled = updated.copyWith(ishaEnabled: shouldEnable);
        break;
      default:
        withEnabled = updated;
    }

    await _settingsBox?.put('settings', withEnabled);
    state = state.copyWith(reminderSettings: withEnabled);
    await _scheduleAlarms();
    return true;
  }

  /// Cycle through alarm modes for a prayer (tap-to-cycle UI).
  /// Returns false if permissions are missing.
  Future<bool> cyclePrayerMode(String prayer) async {
    final current = state.reminderSettings.notifTypeFor(prayer);
    final isSunrise = prayer == 'Sunrise';
    final next = PrayerReminderSettings.nextMode(current, isSunrise: isSunrise);
    return setPrayerNotifType(prayer, next);
  }

  /// Set manual override time for a prayer. Pass empty string to clear.
  Future<void> setManualOverride(String prayer, String time) async {
    PrayerReminderSettings updated;
    switch (prayer) {
      case 'Fajr':
        updated = state.reminderSettings.copyWith(fajrOverride: time);
        break;
      case 'Dhuhr':
        updated = state.reminderSettings.copyWith(dhuhrOverride: time);
        break;
      case 'Asr':
        updated = state.reminderSettings.copyWith(asrOverride: time);
        break;
      case 'Maghrib':
        updated = state.reminderSettings.copyWith(maghribOverride: time);
        break;
      case 'Isha':
        updated = state.reminderSettings.copyWith(ishaOverride: time);
        break;
      default:
        return;
    }

    await _settingsBox?.put('settings', updated);
    state = state.copyWith(reminderSettings: updated);
    await _scheduleAlarms();
  }

  /// Set a per-prayer minute adjustment. No limit — user has full freedom.
  Future<void> setPrayerAdjustment(String prayer, int minutes) async {
    PrayerReminderSettings updated;
    switch (prayer) {
      case 'Fajr':
        updated = state.reminderSettings.copyWith(fajrAdjustment: minutes, fajrOverride: '');
        break;
      case 'Sunrise':
        updated = state.reminderSettings.copyWith(sunriseAdjustment: minutes);
        break;
      case 'Dhuhr':
        updated = state.reminderSettings.copyWith(dhuhrAdjustment: minutes, dhuhrOverride: '');
        break;
      case 'Asr':
        updated = state.reminderSettings.copyWith(asrAdjustment: minutes, asrOverride: '');
        break;
      case 'Maghrib':
        updated = state.reminderSettings.copyWith(maghribAdjustment: minutes, maghribOverride: '');
        break;
      case 'Isha':
        updated = state.reminderSettings.copyWith(ishaAdjustment: minutes, ishaOverride: '');
        break;
      default:
        return;
    }

    await _settingsBox?.put('settings', updated);
    state = state.copyWith(reminderSettings: updated);
    await _scheduleAlarms();
  }

  /// Update sound / vibration / volume settings.
  Future<void> updateSoundSettings({
    String? soundType,
    double? volume,
    bool? vibrationEnabled,
    int? snoozeDurationMinutes,
    String? customSoundPath,
  }) async {
    final updated = state.reminderSettings.copyWith(
      soundType: soundType,
      volume: volume,
      vibrationEnabled: vibrationEnabled,
      snoozeDurationMinutes: snoozeDurationMinutes,
      customSoundPath: customSoundPath,
    );

    await _settingsBox?.put('settings', updated);
    state = state.copyWith(reminderSettings: updated);
  }

  // ── Alarm scheduling ───────────────────────────────

  Future<void> _scheduleAlarms() async {
    // Don't schedule if permissions are missing
    final hasPerms = await hasRequiredPermissions();
    if (!hasPerms) return;

    final times = state.effectiveTimesMap;
    if (times.isEmpty) return;

    await PrayerAlarmService.scheduleDailyAlarms(
      prayerTimes: times,
      enabledPrayers: state.enabledMap,
      date: DateTime.now(),
      reminderSettings: state.reminderSettings,
    );
  }

  /// Force reschedule all alarms (e.g. after boot).
  Future<void> rescheduleAllAlarms() async {
    await _scheduleAlarms();
  }

  // ── Helpers ────────────────────────────────────────
  // Uses todayDateKey() and dateKeyFor() from prayer_time_utils.dart
}

// ─────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────

final prayerAlarmProvider =
    StateNotifierProvider<PrayerAlarmNotifier, PrayerAlarmState>(
  (ref) => PrayerAlarmNotifier(),
);
