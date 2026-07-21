import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';
import '../services/native_app_blocker_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🕐 SCREEN TIME — App Session Timer + Usage Awareness
//
// Psychology-informed design:
//  • "How long?" prompt before opening addictive apps → creates INTENTION
//  • "Time's up" overlay uses compassion, not shame ("You've been here 30m")
//  • Shows daily + 7-day usage data → builds AWARENESS without judgement
//  • Extension chips use friction: "+5m easy, +15m requires reflection"
//  • Session history helps users see patterns themselves (self-insight)
//
// Battery efficiency:
//  • No background timer — we compute elapsed from saved session start time
//  • Relies on AppBlockerService polling (already running) for enforcement
//  • SharedPreferences for active session (fast native read from Kotlin)
//  • Hive for settings/history (fast, lazy-loaded)
// ═══════════════════════════════════════════════════════════════════════════════

/// Per-app session timer configuration
class AppTimerConfig {
  final String packageName;
  final bool enabled;                 // User opted-in for this app
  final int defaultMinutes;           // Last chosen session length (remembers)
  final bool alwaysAsk;               // Show prompt every time vs use default

  const AppTimerConfig({
    required this.packageName,
    this.enabled = true,
    this.defaultMinutes = 15,
    this.alwaysAsk = true,
  });

  Map<String, dynamic> toJson() => {
    'pkg': packageName,
    'on': enabled,
    'mins': defaultMinutes,
    'ask': alwaysAsk,
  };

  factory AppTimerConfig.fromJson(Map<String, dynamic> json) => AppTimerConfig(
    packageName: json['pkg'] as String,
    enabled: json['on'] as bool? ?? true,
    defaultMinutes: json['mins'] as int? ?? 15,
    alwaysAsk: json['ask'] as bool? ?? true,
  );

  AppTimerConfig copyWith({
    bool? enabled,
    int? defaultMinutes,
    bool? alwaysAsk,
  }) => AppTimerConfig(
    packageName: packageName,
    enabled: enabled ?? this.enabled,
    defaultMinutes: defaultMinutes ?? this.defaultMinutes,
    alwaysAsk: alwaysAsk ?? this.alwaysAsk,
  );
}

/// Tracks an active app session (one app at a time)
class ActiveSession {
  final String packageName;
  final String appName;
  final DateTime startedAt;
  final int allowedMinutes;
  final int extensionsUsed;      // How many "+5m" extensions taken

  const ActiveSession({
    required this.packageName,
    required this.appName,
    required this.startedAt,
    required this.allowedMinutes,
    this.extensionsUsed = 0,
  });

  /// Minutes elapsed since session started
  int get elapsedMinutes => DateTime.now().difference(startedAt).inMinutes;

  /// Seconds remaining
  int get remainingSeconds {
    final totalAllowed = Duration(minutes: allowedMinutes);
    final elapsed = DateTime.now().difference(startedAt);
    return (totalAllowed - elapsed).inSeconds.clamp(0, 999999);
  }

  /// Whether the allowed time has been exceeded
  bool get isOvertime => DateTime.now().difference(startedAt).inMinutes >= allowedMinutes;

  ActiveSession copyWith({int? allowedMinutes, int? extensionsUsed}) => ActiveSession(
    packageName: packageName,
    appName: appName,
    startedAt: startedAt,
    allowedMinutes: allowedMinutes ?? this.allowedMinutes,
    extensionsUsed: extensionsUsed ?? this.extensionsUsed,
  );
}

/// App usage entry (from native UsageStatsManager)
class AppUsageEntry {
  final String packageName;
  final String appName;
  final Duration usageTime;
  final DateTime lastUsed;

  const AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.usageTime,
    required this.lastUsed,
  });
}

/// Single day's usage — total + per-app breakdown
class DailyUsageStat {
  final String date;          // "2026-03-06"
  final Duration totalTime;
  final List<AppUsageEntry> apps;

  const DailyUsageStat({
    required this.date,
    required this.totalTime,
    required this.apps,
  });

  factory DailyUsageStat.fromMap(Map<String, dynamic> map) {
    final rawApps = map['apps'] as List? ?? [];
    final apps = rawApps.map((a) {
      final m = Map<String, dynamic>.from(a as Map);
      return AppUsageEntry(
        packageName: m['packageName'] as String? ?? '',
        appName: m['appName'] as String? ?? '',
        usageTime: Duration(milliseconds: (m['usageTime'] as int?) ?? 0),
        lastUsed: DateTime.now(),
      );
    }).where((e) => e.usageTime.inSeconds > 0).toList();
    return DailyUsageStat(
      date: map['date'] as String? ?? '',
      totalTime: Duration(milliseconds: (map['totalMs'] as int?) ?? 0),
      apps: apps,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Time State
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeState {
  final bool featureEnabled;          // Master toggle
  final Map<String, AppTimerConfig> appConfigs;   // Per-app timer configs
  final ActiveSession? activeSession;              // Currently timed app
  final List<AppUsageEntry> todayUsage;
  final List<AppUsageEntry> weekUsage;
  final List<DailyUsageStat> dailyStats;          // 7-day per-day breakdown

  const ScreenTimeState({
    this.featureEnabled = false,
    this.appConfigs = const {},
    this.activeSession,
    this.todayUsage = const [],
    this.weekUsage = const [],
    this.dailyStats = const [],
  });

  ScreenTimeState copyWith({
    bool? featureEnabled,
    Map<String, AppTimerConfig>? appConfigs,
    ActiveSession? activeSession,
    bool clearSession = false,
    List<AppUsageEntry>? todayUsage,
    List<AppUsageEntry>? weekUsage,
    List<DailyUsageStat>? dailyStats,
  }) => ScreenTimeState(
    featureEnabled: featureEnabled ?? this.featureEnabled,
    appConfigs: appConfigs ?? this.appConfigs,
    activeSession: clearSession ? null : (activeSession ?? this.activeSession),
    todayUsage: todayUsage ?? this.todayUsage,
    weekUsage: weekUsage ?? this.weekUsage,
    dailyStats: dailyStats ?? this.dailyStats,
  );

  /// Check if a specific app has an active timer config
  bool hasTimerFor(String packageName) => appConfigs.containsKey(packageName) &&
      (appConfigs[packageName]?.enabled ?? false);

  /// Whether the active session should show the "how long?" prompt
  bool shouldPrompt(String packageName) {
    final config = appConfigs[packageName];
    if (config == null || !config.enabled) return false;
    return config.alwaysAsk;
  }

  /// Today's total screen time across all tracked apps
  Duration get todayTotal => todayUsage.fold(
    Duration.zero, (sum, e) => sum + e.usageTime,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Time Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeNotifier extends StateNotifier<ScreenTimeState> {
  Box? _configBox;

  ScreenTimeNotifier() : super(const ScreenTimeState()) {
    _init();
  }

  Future<void> _init() async {
    _configBox = await HiveBoxManager.get('screen_time_config');
    
    final enabled = _configBox!.get('featureEnabled', defaultValue: false) as bool;
    final configsRaw = _configBox!.get('appConfigs', defaultValue: <dynamic, dynamic>{});
    
    final configs = <String, AppTimerConfig>{};
    if (configsRaw is Map) {
      for (final entry in configsRaw.entries) {
        try {
          final json = Map<String, dynamic>.from(entry.value as Map);
          configs[entry.key as String] = AppTimerConfig.fromJson(json);
        } catch (_) {}
      }
    }

    state = state.copyWith(
      featureEnabled: enabled,
      appConfigs: configs,
    );

    // Always refresh usage stats on startup when feature is enabled so the
    // widget never shows yesterday's stale totals on a cold or warm start.
    if (enabled) {
      await refreshUsageStats();
    }
  }

  Future<void> _save() async {
    _configBox ??= await HiveBoxManager.get('screen_time_config');
    _configBox!.put('featureEnabled', state.featureEnabled);
    
    final raw = <String, Map<String, dynamic>>{};
    final nativePackages = <String>[];
    for (final entry in state.appConfigs.entries) {
      raw[entry.key] = entry.value.toJson();
      if (entry.value.enabled) {
        nativePackages.add(entry.key);
      }
    }
    _configBox!.put('appConfigs', raw);
    
    // Sync to native so it can intercept recents
    NativeAppBlockerService.updateTimerPackages(state.featureEnabled ? nativePackages : []);
  }

  // ── Master toggle ──

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      // Turning OFF — clean up any active session so the native service
      // doesn't fire "time's up" after the user disabled the feature.
      final session = state.activeSession;
      if (session != null) {
        NativeAppBlockerService.endTimedSession(session.packageName);
      }
      state = state.copyWith(featureEnabled: false, clearSession: true);
      // If no other features need the service, it will auto-stop on next poll
      // (checkForegroundApp detects nothing to monitor → calls stopSelf)
    } else {
      state = state.copyWith(featureEnabled: true);
    }
    await _save();
    if (enabled) await refreshUsageStats();
  }

  // ── Per-app config ──

  Future<void> addAppTimer(String packageName, {int defaultMinutes = 15, bool alwaysAsk = true}) async {
    final config = AppTimerConfig(
      packageName: packageName,
      defaultMinutes: defaultMinutes,
      alwaysAsk: alwaysAsk,
    );
    final updated = Map<String, AppTimerConfig>.from(state.appConfigs);
    updated[packageName] = config;
    // Adding an app to monitor implies the feature should be active — otherwise
    // _save() syncs an empty package set to native and nothing is ever watched,
    // so the "how long?" prompt never fires. Enabling here is the explicit
    // intent of adding a limit (this is the only caller now).
    state = state.copyWith(appConfigs: updated, featureEnabled: true);
    await _save();
  }

  Future<void> removeAppTimer(String packageName) async {
    // If there's an active session for this app, end it on native side
    final session = state.activeSession;
    if (session != null && session.packageName == packageName) {
      NativeAppBlockerService.endTimedSession(packageName);
      state = state.copyWith(clearSession: true);
    }
    final updated = Map<String, AppTimerConfig>.from(state.appConfigs);
    updated.remove(packageName);
    state = state.copyWith(appConfigs: updated);
    await _save();
  }

  Future<void> updateAppTimer(String packageName, {int? defaultMinutes, bool? alwaysAsk, bool? enabled}) async {
    final current = state.appConfigs[packageName];
    if (current == null) return;
    // If disabling this specific app's timer, end any active session for it
    if (enabled == false) {
      final session = state.activeSession;
      if (session != null && session.packageName == packageName) {
        NativeAppBlockerService.endTimedSession(packageName);
        state = state.copyWith(clearSession: true);
      }
    }
    final updated = Map<String, AppTimerConfig>.from(state.appConfigs);
    updated[packageName] = current.copyWith(
      defaultMinutes: defaultMinutes,
      alwaysAsk: alwaysAsk,
      enabled: enabled,
    );
    state = state.copyWith(appConfigs: updated);
    await _save();
  }

  // ── Session management ──

  /// Start a timed session for an app
  void startSession(String packageName, String appName, int minutes) {
    final session = ActiveSession(
      packageName: packageName,
      appName: appName,
      startedAt: DateTime.now(),
      allowedMinutes: minutes,
    );
    state = state.copyWith(activeSession: session);

    // Remember this as the default for next time
    final config = state.appConfigs[packageName];
    if (config != null && config.defaultMinutes != minutes) {
      final updated = Map<String, AppTimerConfig>.from(state.appConfigs);
      updated[packageName] = config.copyWith(defaultMinutes: minutes);
      state = state.copyWith(appConfigs: updated);
      _save();
    }

    // Notify native blocker about the session so it can enforce the limit
    NativeAppBlockerService.startTimedSession(packageName, minutes);
  }

  /// Extend current session by additional minutes (+5m extension)
  void extendSession(int additionalMinutes) {
    final session = state.activeSession;
    if (session == null) return;

    final extended = session.copyWith(
      allowedMinutes: session.allowedMinutes + additionalMinutes,
      extensionsUsed: session.extensionsUsed + 1,
    );
    state = state.copyWith(activeSession: extended);

    // Notify native blocker about extension
    NativeAppBlockerService.extendTimedSession(extended.packageName, additionalMinutes);
  }

  /// End current session (user returned home or closed app)
  void endSession() {
    final session = state.activeSession;
    if (session != null) {
      NativeAppBlockerService.endTimedSession(session.packageName);
    }
    state = state.copyWith(clearSession: true);
  }

  // ── Usage Stats ──

  /// Fetch usage stats from native Android UsageStatsManager
  Future<void> refreshUsageStats() async {
    try {
      final hasPermission = await NativeAppBlockerService.hasUsageStatsPermission();
      if (!hasPermission) return;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 7));

      // Today's usage
      final todayRaw = await NativeAppBlockerService.getUsageStats(
        todayStart.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      final todayEntries = _parseUsageStats(todayRaw);

      // 7-day usage
      final weekRaw = await NativeAppBlockerService.getUsageStats(
        weekStart.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      final weekEntries = _parseUsageStats(weekRaw);

      state = state.copyWith(
        todayUsage: todayEntries,
        weekUsage: weekEntries,
      );

      // Also refresh daily breakdown
      await refreshDailyStats();
    } catch (_) {}
  }

  /// Fetch per-day stats (7 days) — for usage analytics screen
  Future<void> refreshDailyStats() async {
    try {
      final hasPermission = await NativeAppBlockerService.hasUsageStatsPermission();
      if (!hasPermission) return;
      final raw = await NativeAppBlockerService.getDailyUsageStats(days: 7);
      final daily = raw.map((m) => DailyUsageStat.fromMap(m)).toList();
      state = state.copyWith(dailyStats: daily);
    } catch (_) {}
  }

  List<AppUsageEntry> _parseUsageStats(List<Map<String, dynamic>> raw) {
    return raw.map((map) => AppUsageEntry(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      usageTime: Duration(milliseconds: (map['usageTime'] as int?) ?? 0),
      lastUsed: DateTime.fromMillisecondsSinceEpoch((map['lastUsed'] as int?) ?? 0),
    )).where((e) => e.usageTime.inMinutes > 0).toList()
      ..sort((a, b) => b.usageTime.compareTo(a.usageTime));
  }

  /// Get today's usage for a specific app
  Duration getTodayUsage(String packageName) {
    final entry = state.todayUsage.where((e) => e.packageName == packageName).firstOrNull;
    return entry?.usageTime ?? Duration.zero;
  }

  /// Get 7-day usage for a specific app
  Duration getWeekUsage(String packageName) {
    final entry = state.weekUsage.where((e) => e.packageName == packageName).firstOrNull;
    return entry?.usageTime ?? Duration.zero;
  }
}

final screenTimeProvider = StateNotifierProvider<ScreenTimeNotifier, ScreenTimeState>(
  (ref) => ScreenTimeNotifier(),
);
