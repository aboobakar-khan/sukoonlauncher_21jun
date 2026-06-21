import 'package:intl/intl.dart';
import '../providers/prayer_alarm_provider.dart';

/// Shared prayer time utilities — eliminates duplicate code across
/// prayer_time_widget, dashboard_card, and settings_screen.

/// Today's date as 'yyyy-MM-dd' key for Hive caching.
String todayDateKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Date key for any given [date].
String dateKeyFor(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Convert "17:20" or "5:20 PM" → always "5:20 PM" (12-hour format).
String fmt12h(String s) {
  final str = s.trim();
  try {
    final parts = str.split(':');
    if (parts.length == 2 && !str.contains(' ')) {
      final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt);
    }
    return str; // already 12h
  } catch (_) {
    return str;
  }
}

/// Parse a "HH:mm" time string into hour and minute.
/// Returns null if parsing fails.
({int hour, int minute})? parseTimeStr(String timeStr) {
  final parts = timeStr.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return (hour: h, minute: m);
}

/// Find the next upcoming prayer from the alarm state.
/// Returns { 'name': 'Maghrib', 'time': '18:20' } or null if all prayers passed.
Map<String, String>? findNextPrayer(PrayerAlarmState state, {bool onlyEnabled = false}) {
  final now = DateTime.now();
  final times = state.effectiveTimesMap;
  final enabled = state.enabledMap;

  for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
    if (onlyEnabled && !(enabled[prayer] ?? true)) continue;
    final timeStr = times[prayer];
    if (timeStr == null) continue;

    final parsed = parseTimeStr(timeStr);
    if (parsed == null) continue;

    final prayerTime = DateTime(
      now.year, now.month, now.day,
      parsed.hour, parsed.minute,
    );

    if (prayerTime.isAfter(now)) {
      return {'name': prayer, 'time': timeStr};
    }
  }

  // If all prayers today have passed, return tomorrow's Fajr.
  if (onlyEnabled && !(enabled['Fajr'] ?? true)) return null;
  final tomorrow = now.add(const Duration(days: 1));
  final tomorrowFajr = state.effectiveTimeFor('Fajr', tomorrow);
  if (tomorrowFajr != null) {
    return {'name': 'Fajr', 'time': tomorrowFajr};
  }

  return null;
}

/// Format a "HH:mm" time string into the user's preferred format.
String formatPrayerTime(String timeStr, {bool use24h = false}) {
  final parsed = parseTimeStr(timeStr);
  if (parsed == null) return timeStr;
  final dt = DateTime(0, 1, 1, parsed.hour, parsed.minute);
  return DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(dt);
}
