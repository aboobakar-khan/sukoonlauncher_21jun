import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/productivity_models.dart';
import '../services/native_app_blocker_service.dart';
import '../utils/hive_box_manager.dart';

/// ─────────────────────────────────────────────
/// Zen Mode State
/// ─────────────────────────────────────────────

class ZenModeState {
  final bool isActive;
  final DateTime? startTime;
  final int durationMinutes;
  final int sessionsCompleted;

  ZenModeState({
    this.isActive = false,
    this.startTime,
    this.durationMinutes = 30,
    this.sessionsCompleted = 0,
  });

  ZenModeState copyWith({
    bool? isActive,
    DateTime? startTime,
    int? durationMinutes,
    int? sessionsCompleted,
  }) {
    return ZenModeState(
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
    );
  }

  Duration get remainingTime {
    if (!isActive || startTime == null) return Duration.zero;
    final end = startTime!.add(Duration(minutes: durationMinutes));
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasExpired {
    if (!isActive || startTime == null) return false;
    return remainingTime <= Duration.zero;
  }

  double get progress {
    if (!isActive || startTime == null) return 0.0;
    final elapsed = DateTime.now().difference(startTime!);
    final total = Duration(minutes: durationMinutes);
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  String get remainingFormatted {
    final r = remainingTime;
    final m = r.inMinutes;
    final s = r.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// ─────────────────────────────────────────────
/// Zen Mode Provider
/// ─────────────────────────────────────────────

class ZenModeNotifier extends StateNotifier<ZenModeState> {
  ZenModeNotifier() : super(ZenModeState()) {
    _init();
  }

  static const _boxName = 'zen_mode_box';
  static const _dndChannel = MethodChannel('com.sukoon.launcher/dnd');
  static const _appChannel = MethodChannel('com.sukoon.launcher/apps');
  static const _blockerChannel = MethodChannel('com.sukoon.launcher/app_blocker');

  Box? _box;
  Timer? _autoEndTimer;

  /// Schedule a periodic checker that auto-ends zen mode when expired.
  /// This is the safety net for cases where:
  ///  1. App was killed/restarted while zen was active
  ///  2. ZenModeActiveScreen was disposed without proper cleanup
  ///  3. User switches away and the active screen timer doesn't fire
  ///
  /// Only runs while zen mode is active — no battery waste otherwise.
  void _scheduleAutoEndTimer() {
    _autoEndTimer?.cancel();
    if (state.isActive) {
      _autoEndTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (state.isActive && state.hasExpired) {
          endZenMode();
        } else if (!state.isActive) {
          // Zen ended (e.g. from active screen) — stop the timer
          _autoEndTimer?.cancel();
          _autoEndTimer = null;
        }
      });
    } else {
      _autoEndTimer = null;
    }
  }

  @override
  void dispose() {
    _autoEndTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get(_boxName);

    final isActive = _box!.get('isActive', defaultValue: false) as bool;
    final startMillis = _box!.get('startTime') as int?;
    final duration = _box!.get('durationMinutes', defaultValue: 30) as int;
    final sessions = _box!.get('sessionsCompleted', defaultValue: 0) as int;

    final startTime = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : null;

    state = ZenModeState(
      isActive: isActive,
      startTime: startTime,
      durationMinutes: duration,
      sessionsCompleted: sessions,
    );

    // If was active but timer expired (e.g. app was killed), end it
    if (isActive && state.hasExpired) {
      await endZenMode();
    } else if (isActive) {
      // Still active and not expired — start the safety-net auto-end timer
      _scheduleAutoEndTimer();
    }
  }

  /// Start Zen Mode — blocks ALL apps, enables DND
  Future<void> startZenMode(int durationMinutes) async {
    // 1. Get all installed app packages
    List<String> allPackages = [];
    try {
      final result = await _appChannel.invokeMethod('getInstalledApps');
      if (result is List) {
        allPackages = result
            .map((app) => (app as Map)['package'] as String)
            .where((pkg) =>
                pkg != 'com.sukoon.launcher' && // our app
                !pkg.startsWith('com.android.server') &&
                pkg != 'com.android.camera' &&
                pkg != 'com.android.camera2')
            .toList();
      }
    } catch (e) {
      // If can't get packages, use a broad block approach
    }

    // 2. Send to native blocker
    if (allPackages.isNotEmpty) {
      await NativeAppBlockerService.updateBlockedPackages(allPackages);
    }

    // 3. Enable Zen Mode in native service (aggressive lockdown)
    try {
      await _blockerChannel.invokeMethod('setZenMode', {'active': true});
    } catch (_) {}

    // 4. Enable DND — silences all notifications and alerts
    try {
      await _dndChannel.invokeMethod('enableDND', {'mode': 'total_silence'});
    } catch (_) {
      // Fallback: try without args (older implementations)
      try {
        await _dndChannel.invokeMethod('enableDND');
      } catch (_) {}
    }

    // 5. Update state
    final now = DateTime.now();
    state = state.copyWith(
      isActive: true,
      startTime: now,
      durationMinutes: durationMinutes,
    );

    // 6. Persist — use the SAME timestamp as state so no drift
    await _box?.put('isActive', true);
    await _box?.put('startTime', now.millisecondsSinceEpoch);
    await _box?.put('durationMinutes', durationMinutes);

    // 7. Start safety-net auto-end timer
    _scheduleAutoEndTimer();
  }

  /// End Zen Mode — unblocks all apps, disables DND
  Future<void> endZenMode() async {
    // 0. Stop the safety-net timer immediately
    _autoEndTimer?.cancel();
    _autoEndTimer = null;

    // 1. Disable Zen Mode in native service
    try {
      await _blockerChannel.invokeMethod('setZenMode', {'active': false});
    } catch (_) {}

    // 2. Restore app-block rules instead of nuking to empty.
    //    Zen Mode temporarily overwrote the blocked-packages list with ALL
    //    apps. Now we must restore only the packages that are actively
    //    blocked by AppBlockRuleNotifier rules — NOT an empty list, which
    //    would silently wipe legitimate block rules.
    await _restoreAppBlockRules();

    // 3. Disable DND
    try {
      await _dndChannel.invokeMethod('disableDND');
    } catch (_) {}

    // 4. Increment sessions
    final newSessions = state.sessionsCompleted + 1;

    // 5. Update state
    state = state.copyWith(
      isActive: false,
      sessionsCompleted: newSessions,
    );

    // 6. Persist
    await _box?.put('isActive', false);
    await _box?.put('sessionsCompleted', newSessions);
  }

  /// Restore the native blocked-packages list from active AppBlockRules.
  /// This prevents Zen Mode from wiping productivity-hub block rules on exit.
  Future<void> _restoreAppBlockRules() async {
    try {
      final ruleBox = await HiveBoxManager.get<AppBlockRule>('app_block_rules');
      final now = DateTime.now();
      final activePackages = <String>{};

      for (final rule in ruleBox.values) {
        if (!rule.isEnabled) continue;

        // Check expiry
        if (rule.expiresAt != null && now.isAfter(rule.expiresAt!)) continue;

        // Check time-based schedule
        if (rule.isTimeBased) {
          if (rule.startHour == null || rule.endHour == null) continue;
          if (!rule.activeDays.contains(now.weekday)) continue;
          final startMin = rule.startHour! * 60 + (rule.startMinute ?? 0);
          final endMin = rule.endHour! * 60 + (rule.endMinute ?? 0);
          final nowMin = now.hour * 60 + now.minute;
          bool inWindow;
          if (startMin <= endMin) {
            inWindow = nowMin >= startMin && nowMin < endMin;
          } else {
            inWindow = nowMin >= startMin || nowMin < endMin;
          }
          if (!inWindow) continue;
        }

        activePackages.addAll(rule.blockedPackages);
      }

      await NativeAppBlockerService.updateBlockedPackages(activePackages.toList());
    } catch (_) {
      // Fallback: if Hive read fails, clear to empty (safe default)
      await NativeAppBlockerService.updateBlockedPackages([]);
    }
  }

  /// Set duration for next session
  void setDuration(int minutes) {
    state = state.copyWith(durationMinutes: minutes);
    _box?.put('durationMinutes', minutes);
  }

  /// Check & auto-end if expired
  bool checkAndAutoEnd() {
    if (state.isActive && state.hasExpired) {
      endZenMode();
      return true;
    }
    return false;
  }
}

/// Provider
final zenModeProvider = StateNotifierProvider<ZenModeNotifier, ZenModeState>(
  (ref) => ZenModeNotifier(),
);
