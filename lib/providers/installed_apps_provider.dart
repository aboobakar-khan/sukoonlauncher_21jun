import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/installed_app.dart';
import '../utils/app_filter_utils.dart';
import '../utils/hive_box_manager.dart';

/// Provider for installed apps stored permanently in Hive
/// Loaded into memory, no cache, instant filtering
/// True minimalist architecture
class InstalledAppsNotifier extends StateNotifier<List<InstalledApp>> {
  InstalledAppsNotifier() : super([]) {
    _loadApps();
  }

  Box<InstalledApp>? _box;
  Box<String>? _riBox;
  bool _isRefreshing = false;

  /// Recently installed apps (detected on refresh)
  List<InstalledApp> _recentlyInstalled = [];
  List<InstalledApp> get recentlyInstalled => _recentlyInstalled;

  /// Hidden apps — persisted in SharedPreferences
  static const _kHiddenAppsKey = 'hidden_app_packages';
  Set<String> _hiddenPackages = {};
  Set<String> get hiddenPackages => _hiddenPackages;

  /// Load apps from Hive into memory
  Future<void> _loadApps() async {
    _box ??= await HiveBoxManager.get<InstalledApp>('installed_apps');

    // Load hidden apps set
    await _loadHiddenApps();

    // If box is empty, fetch from system
    if (_box!.isEmpty) {
      await refreshApps();
    } else {
      // Load from Hive instantly
      state = _box!.values.toList()
        ..sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
      // Load recently installed list from a separate box
      await _loadRecentlyInstalled();
    }
  }

  /// Load hidden app packages from SharedPreferences
  Future<void> _loadHiddenApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kHiddenAppsKey) ?? [];
      _hiddenPackages = list.toSet();
    } catch (_) {}
  }

  /// Save hidden app packages to SharedPreferences
  Future<void> _saveHiddenApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kHiddenAppsKey, _hiddenPackages.toList());
    } catch (_) {}
  }

  /// Hide an app from the app list
  Future<void> hideApp(String packageName) async {
    _hiddenPackages.add(packageName);
    await _saveHiddenApps();
    // Trigger state rebuild so listeners update
    state = [...state];
  }

  /// Unhide an app — make it visible again in the app list
  Future<void> unhideApp(String packageName) async {
    _hiddenPackages.remove(packageName);
    await _saveHiddenApps();
    // Trigger state rebuild so listeners update
    state = [...state];
  }

  /// Check if an app is hidden
  bool isHidden(String packageName) => _hiddenPackages.contains(packageName);

  /// Get all hidden apps (for settings screen)
  List<InstalledApp> get hiddenApps =>
      state.where((app) => _hiddenPackages.contains(app.packageName)).toList();

  /// Load recently installed apps from Hive
  Future<void> _loadRecentlyInstalled() async {
    try {
      _riBox ??= await HiveBoxManager.get<String>('recently_installed_apps');
      final packages = _riBox!.values.toList();
      _recentlyInstalled = state
          .where((app) => packages.contains(app.packageName))
          .toList();
    } catch (_) {}
  }

  /// Save recently installed apps to Hive
  Future<void> _saveRecentlyInstalled(List<String> packages) async {
    try {
      _riBox ??= await HiveBoxManager.get<String>('recently_installed_apps');
      await _riBox!.clear();
      // Batch write instead of sequential adds
      final map = <int, String>{};
      for (var i = 0; i < packages.length; i++) {
        map[i] = packages[i];
      }
      await _riBox!.putAll(map);
    } catch (_) {}
  }

  /// Refresh apps from system (call manually when needed)
  Future<void> refreshApps() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      _box ??= await HiveBoxManager.get<InstalledApp>('installed_apps');

      // Remember old package names to detect new installs
      final oldPackages = _box!.values.map((a) => a.packageName).toSet();

      // Get filtered apps from system
      final systemApps = await AppFilterUtils.getFilteredAppsAlternative();

      // Clear old data
      await _box!.clear();

      // Store in Hive — batch write instead of sequential adds
      final installedApps = systemApps
          .map(
            (app) =>
                InstalledApp(packageName: app.packageName, appName: app.name),
          )
          .toList();

      final map = <int, InstalledApp>{};
      for (var i = 0; i < installedApps.length; i++) {
        map[i] = installedApps[i];
      }
      await _box!.putAll(map);

      // Detect newly installed apps
      if (oldPackages.isNotEmpty) {
        final newPackages = installedApps
            .where((app) => !oldPackages.contains(app.packageName))
            .toList();
        _riBox ??= await HiveBoxManager.get<String>('recently_installed_apps');
        final existingRecent = _riBox!.values.toSet();
        final allRecent = <String>{
          ...newPackages.map((a) => a.packageName),
          ...existingRecent,
        }.take(10).toList();
        await _saveRecentlyInstalled(allRecent);
        _recentlyInstalled = installedApps
            .where((app) => allRecent.contains(app.packageName))
            .toList();
      }

      // Update memory
      state = installedApps
        ..sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
    } finally {
      _isRefreshing = false;
    }
  }

  /// Returns the initials of a display name.
  /// "WhatsApp"       → "w"
  /// "Google Chrome"  → "gc"
  /// "Adobe Acrobat"  → "aa"
  /// Single-word apps → first letter only.
  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words[0].isNotEmpty ? words[0][0].toLowerCase() : '';
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toLowerCase())
        .join();
  }

  /// Score an app name against a query.
  ///
  /// Tiers (lower = better rank):
  ///   0 – exact match
  ///   1 – whole display/app name starts-with the query
  ///   2 – initials / acronym match  ("wa" → "WhatsApp")
  ///   3 – any word inside the name starts with the query
  ///  -1 – no match  (loose substring / package-name matches are EXCLUDED)
  ///
  /// Deliberately NO tier-4 (contains) or tier-5 (package name) —
  /// those produce irrelevant results like "Kotak811" when typing "insta".
  static int _score(InstalledApp app, String lq) {
    final name    = app.displayName.toLowerCase();
    final rawName = app.appName.toLowerCase();

    // Tier 0 — exact
    if (name == lq || rawName == lq) return 0;

    // Tier 1 — whole name starts-with
    if (name.startsWith(lq) || rawName.startsWith(lq)) return 1;

    // Tier 2 — initials / acronym
    final initials = _initials(app.displayName);
    if (initials == lq || initials.startsWith(lq)) return 2;
    final rawInitials = _initials(app.appName);
    if (rawInitials == lq || rawInitials.startsWith(lq)) return 2;

    // Tier 3 — any word boundary starts-with (e.g. "tube" → "YouTube")
    final words = name.split(RegExp(r'[\s\-_]+'));
    if (words.any((w) => w.isNotEmpty && w.startsWith(lq))) return 3;
    final rawWords = rawName.split(RegExp(r'[\s\-_]+'));
    if (rawWords.any((w) => w.isNotEmpty && w.startsWith(lq))) return 3;

    return -1; // no match — do NOT fall through to substring/package
  }

  /// Filter apps in memory — instant, zero allocations for common cases.
  ///
  /// Returns ONLY apps whose name has a meaningful connection to the query
  /// (exact / starts-with / acronym / word-start). Loose substring matches
  /// are intentionally excluded to keep the list clean.
  ///
  /// Examples:
  ///   "insta" → Instagram (tier 1) only — Kotak, Threads are NOT shown
  ///   "wa"    → WhatsApp (tier 2 initials), Waze (tier 1) — NOT "Amazon"
  ///   "tube"  → YouTube (tier 3, word "tube") — NOT unrelated apps
  List<InstalledApp> filterApps(String query) {
    // Exclude hidden apps from results
    final visible = state.where((app) => !_hiddenPackages.contains(app.packageName)).toList();

    if (query.isEmpty) return visible;

    final lq = query.toLowerCase().trim();
    if (lq.isEmpty) return visible;

    // Score every app; drop those with no match (score == -1).
    final scored = <({InstalledApp app, int score})>[];
    for (final app in visible) {
      final s = _score(app, lq);
      if (s >= 0) scored.add((app: app, score: s));
    }

    // Stable sort — apps at the same tier keep their original alphabetic order.
    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.map((e) => e.app).toList();
  }

  /// Returns the best-scoring app for auto-launch purposes.
  ///
  /// Rules:
  ///   • Only considers tier 0 (exact) or tier 1 (starts-with) results.
  ///   • Auto-launches if exactly ONE app reaches tier 0 or 1.
  ///   • If multiple apps share the top tier, no auto-launch (ambiguous).
  InstalledApp? bestAutoLaunchMatch(String query) {
    if (query.length < 2) return null;
    final lq = query.toLowerCase().trim();
    if (lq.isEmpty) return null;

    InstalledApp? best;
    int bestTier = 99;
    int bestCount = 0; // how many apps share the best tier

    for (final app in state) {
      final s = _score(app, lq);
      if (s < 0 || s > 1) continue; // only tier 0 & 1 qualify
      if (s < bestTier) {
        bestTier = s;
        best = app;
        bestCount = 1;
      } else if (s == bestTier) {
        bestCount++;
      }
    }

    // Unambiguous single match at tier 0 or 1
    return (bestCount == 1) ? best : null;
  }

  /// Rename an app with a custom name
  Future<void> renameApp(String packageName, String newName) async {
    try {
      _box ??= await HiveBoxManager.get<InstalledApp>('installed_apps');
      
      // Find and update the app in Hive
      final key = _box!.keys.firstWhere(
        (k) => _box!.get(k)?.packageName == packageName,
        orElse: () => null,
      );
      
      if (key != null) {
        final app = _box!.get(key)!;
        final updatedApp = app.copyWith(customName: newName.isEmpty ? null : newName);
        await _box!.put(key, updatedApp);
        
        // Update memory state
        state = state.map((app) {
          if (app.packageName == packageName) {
            return updatedApp;
          }
          return app;
        }).toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
          );
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Remove an app from the installed apps list (for hide/uninstall)
  void removeApp(String packageName) {
    final updatedApps = state
        .where((app) => app.packageName != packageName)
        .toList();
    state = updatedApps;
  }

  /// Check if refresh is in progress
  bool get isRefreshing => _isRefreshing;
}

final installedAppsProvider =
    StateNotifierProvider<InstalledAppsNotifier, List<InstalledApp>>(
      (ref) => InstalledAppsNotifier(),
    );

/// Provider that exposes hidden apps for the settings screen.
/// Re-reads whenever the installed apps list changes (which fires on hide/unhide).
final hiddenAppsProvider = Provider<List<InstalledApp>>((ref) {
  // Watch the main provider so this re-evaluates on state changes
  ref.watch(installedAppsProvider);
  return ref.read(installedAppsProvider.notifier).hiddenApps;
});

/// Provider that exposes the count of hidden apps.
final hiddenAppsCountProvider = Provider<int>((ref) {
  ref.watch(installedAppsProvider);
  return ref.read(installedAppsProvider.notifier).hiddenPackages.length;
});
