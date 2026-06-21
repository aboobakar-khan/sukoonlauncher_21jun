import 'package:flutter/services.dart';

/// A lightweight data holder returned by the native getLauncherApps call.
class AppInfo {
  final String packageName;
  final String name;
  const AppInfo({required this.packageName, required this.name});
}

/// 🎯 Smart 3-Layer App Filtering (Industry Best Practice)
///
/// No longer uses the `installed_apps` pub package.
/// Instead calls the native `com.sukoon.launcher/apps` MethodChannel which
/// uses packageManager.queryIntentActivities(ACTION_MAIN, CATEGORY_LAUNCHER)
/// — the correct, Play-policy-compliant approach for launchers.
class AppFilterUtils {
  AppFilterUtils._();

  static const _appsChannel = MethodChannel('com.sukoon.launcher/apps');

  // ─── Junk patterns ─────────────────────────────────────────────
  static const List<String> _junkPatterns = [
    '.updater',
    '.setup',
    '.feedback',
    '.partner',
    '.stub',
    '.test',
    '.overlay',
    'inputmethod',
    'syncadapter',
  ];

  static bool _isKnownJunk(String packageName) {
    final pkg = packageName.toLowerCase();
    return _junkPatterns.any((p) => pkg.contains(p));
  }

  static bool _shouldIncludeApp(String packageName) {
    if (packageName == 'com.sukoon.launcher') return false;
    if (_isKnownJunk(packageName)) return false;
    return true;
  }

  /// Fetch launcher-intent apps via the native channel.
  /// Returns only apps that have ACTION_MAIN + CATEGORY_LAUNCHER — Play-compliant.
  static Future<List<AppInfo>> getFilteredAppsAlternative() async {
    try {
      final raw = await _appsChannel.invokeMethod<List<dynamic>>('getLauncherApps');
      if (raw == null) return [];

      final apps = raw
          .cast<Map<dynamic, dynamic>>()
          .map((m) => AppInfo(
                packageName: (m['package'] as String?) ?? '',
                name: (m['name'] as String?) ?? '',
              ))
          .where((a) => a.packageName.isNotEmpty && _shouldIncludeApp(a.packageName))
          .toList();

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return apps;
    } catch (_) {
      return [];
    }
  }

  /// Check if a package has a whitelist override (legacy compat — no longer
  /// relevant since we only return launcher-intent apps, but kept to avoid
  /// breaking any call sites that reference it).
  static bool isInWhitelist(String packageName) => false;
}
