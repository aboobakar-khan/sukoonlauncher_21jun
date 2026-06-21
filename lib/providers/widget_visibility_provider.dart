import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/hive_box_manager.dart';

/// Defines all toggleable widgets on the dashboard.
/// The key is the Hive storage key; label + icon are for the UI.
enum DashboardWidget {
  prayerAlarm('prayer_alarm', 'Prayer Times', 'mosque'),
  verseOfMoment('verse_of_moment', 'Verse of the Moment', 'auto_awesome'),
  dhikrSummary('dhikr_summary', 'Dhikr Counter', 'radio_button_checked'),
  prayerTracker('prayer_tracker', 'Prayer Tracker', 'check_circle'),
  qadhaTracker('qadha_tracker', 'Qadha Namaz', 'replay'),
  deenMode('deen_mode', 'Deen Mode', 'nights_stay'),
  charityLog('charity_log', 'Charity Log', 'volunteer_activism'),
  calendar('calendar', 'Calendar', 'calendar_month');

  final String key;
  final String label;
  final String iconName;

  const DashboardWidget(this.key, this.label, this.iconName);
}

/// State: a map of widget key → visible (true by default).
class WidgetVisibilityNotifier extends StateNotifier<Map<String, bool>> {
  static const _boxName = 'settingsBox';
  static const _hiveKey = 'dashboard_widget_visibility';

  Box? _box;

  WidgetVisibilityNotifier() : super({}) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get(_boxName);
    final saved = _box?.get(_hiveKey);
    if (saved != null && saved is Map) {
      state = Map<String, bool>.from(saved);
    }
  }

  /// Whether a widget is visible. charityLog defaults to false; all others default to true.
  bool isVisible(DashboardWidget widget) {
    if (state.containsKey(widget.key)) return state[widget.key]!;
    // charityLog is off by default; everything else is on
    return widget != DashboardWidget.charityLog;
  }

  /// Toggle visibility of a single widget.
  Future<void> toggle(DashboardWidget widget) async {
    final current = state[widget.key] ?? true;
    state = {...state, widget.key: !current};
    await _persist();
  }

  /// Set visibility of a single widget.
  Future<void> setVisible(DashboardWidget widget, bool visible) async {
    state = {...state, widget.key: visible};
    await _persist();
  }

  Future<void> _persist() async {
    await _box?.put(_hiveKey, state);
  }
}

final widgetVisibilityProvider =
    StateNotifierProvider<WidgetVisibilityNotifier, Map<String, bool>>(
  (ref) => WidgetVisibilityNotifier(),
);
