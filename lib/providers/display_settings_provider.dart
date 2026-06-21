import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds user preferences for homescreen display toggles.
class DisplaySettings {
  final bool showPrayerWidget;  // Show next prayer time widget card on home
  final bool showHijriDate;     // Show Hijri date on home / calendar
  final bool showFastingWidget; // Show Suhoor/Iftar fasting widget on home
  final bool showDuaWidget;     // Show Ramadan dua carousel on home
  /// Day offset for Ramadan start: -2 to +2 (handles regional moon sighting differences)
  final int ramadanDayOffset;
  /// Time format: true = 24-hour, false = 12-hour (AM/PM)
  final bool use24HourFormat;
  /// Status Bar visibility: true = shown, false = hidden (default)
  final bool showStatusBar;
  /// Type of widget to show: 'prayer_time' (default) or 'salah_wake'
  final String homePrayerWidgetType;

  const DisplaySettings({
    this.showPrayerWidget = false,  // Disabled by default - opt-in
    this.showHijriDate = false,     // Disabled by default - opt-in
    this.showFastingWidget = false, // Disabled by default - opt-in
    this.showDuaWidget = false,     // Disabled by default - opt-in
    this.ramadanDayOffset = 0,
    this.use24HourFormat = false,
    this.showStatusBar = false,
    this.homePrayerWidgetType = 'prayer_time',
  });

  DisplaySettings copyWith({
    bool? showPrayerWidget,
    bool? showHijriDate,
    bool? showFastingWidget,
    bool? showDuaWidget,
    int? ramadanDayOffset,
    bool? use24HourFormat,
    bool? showStatusBar,
    String? homePrayerWidgetType,
  }) {
    return DisplaySettings(
      showPrayerWidget: showPrayerWidget ?? this.showPrayerWidget,
      showHijriDate: showHijriDate ?? this.showHijriDate,
      showFastingWidget: showFastingWidget ?? this.showFastingWidget,
      showDuaWidget: showDuaWidget ?? this.showDuaWidget,
      ramadanDayOffset: ramadanDayOffset ?? this.ramadanDayOffset,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      homePrayerWidgetType: homePrayerWidgetType ?? this.homePrayerWidgetType,
    );
  }
}

class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  static const _keyWidget   = 'display_prayer_widget';
  static const _keyHijri    = 'display_hijri_date';
  static const _keyFasting  = 'display_fasting_widget';
  static const _keyDua      = 'display_dua_widget';
  static const _keyRamadanOffset = 'display_ramadan_day_offset';
  static const _key24Hour   = 'display_use_24hour_format';
  static const _keyStatusBar = 'display_show_status_bar';
  static const _keyHomeWidgetType = 'display_home_prayer_widget_type';

  DisplaySettingsNotifier() : super(const DisplaySettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DisplaySettings(
      showPrayerWidget:  prefs.getBool(_keyWidget)  ?? false,  // Opt-in default
      showHijriDate:     prefs.getBool(_keyHijri)   ?? false,  // Opt-in default
      showFastingWidget: prefs.getBool(_keyFasting) ?? false,  // Opt-in default
      showDuaWidget:     prefs.getBool(_keyDua)     ?? false,  // Opt-in default
      ramadanDayOffset:  prefs.getInt(_keyRamadanOffset) ?? 0,
      use24HourFormat:   prefs.getBool(_key24Hour) ?? false,
      showStatusBar:     prefs.getBool(_keyStatusBar) ?? false,
      homePrayerWidgetType: prefs.getString(_keyHomeWidgetType) ?? 'prayer_time',
    );
  }

  Future<void> setShowPrayerWidget(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWidget, value);
    state = state.copyWith(showPrayerWidget: value);
  }

  Future<void> setShowHijriDate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHijri, value);
    state = state.copyWith(showHijriDate: value);
  }

  Future<void> setShowFastingWidget(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFasting, value);
    state = state.copyWith(showFastingWidget: value);
  }

  Future<void> setShowDuaWidget(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDua, value);
    state = state.copyWith(showDuaWidget: value);
  }

  Future<void> setRamadanDayOffset(int offset) async {
    final clamped = offset.clamp(-2, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRamadanOffset, clamped);
    state = state.copyWith(ramadanDayOffset: clamped);
  }

  Future<void> setUse24HourFormat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key24Hour, value);
    state = state.copyWith(use24HourFormat: value);
  }

  Future<void> setShowStatusBar(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStatusBar, value);
    state = state.copyWith(showStatusBar: value);
  }

  Future<void> setHomePrayerWidgetType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeWidgetType, type);
    state = state.copyWith(homePrayerWidgetType: type);
  }
}

final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>(
  (ref) => DisplaySettingsNotifier(),
);
