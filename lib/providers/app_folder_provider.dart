import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/installed_app.dart';
import '../utils/app_category_utils.dart';
import 'installed_apps_provider.dart';

/// State for the app folder system
class AppFolderState {
  /// Whether the folder feature is enabled
  final bool enabled;

  /// Currently selected folder (null = show all)
  final String? activeFolder;

  /// Names of user-created custom folders (order preserved)
  final List<String> customFolders;

  /// Manual overrides: packageName → folderName
  /// Takes priority over auto-categorization
  final Map<String, String> customAssignments;

  const AppFolderState({
    this.enabled = true,
    this.activeFolder,
    this.customFolders = const [],
    this.customAssignments = const {},
  });

  AppFolderState copyWith({
    bool? enabled,
    String? Function()? activeFolder,
    List<String>? customFolders,
    Map<String, String>? customAssignments,
  }) {
    return AppFolderState(
      enabled: enabled ?? this.enabled,
      activeFolder: activeFolder != null ? activeFolder() : this.activeFolder,
      customFolders: customFolders ?? this.customFolders,
      customAssignments: customAssignments ?? this.customAssignments,
    );
  }
}

/// Manages folder state, categorization, and persistence
class AppFolderNotifier extends StateNotifier<AppFolderState> {
  AppFolderNotifier() : super(const AppFolderState()) {
    _load();
  }

  static const _kEnabledKey = 'app_folders_enabled';
  static const _kCustomFoldersKey = 'app_folders_custom';
  static const _kAssignmentsKey = 'app_folders_assignments';

  /// Load persisted state
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      final customFoldersJson = prefs.getString(_kCustomFoldersKey);
      final assignmentsJson = prefs.getString(_kAssignmentsKey);

      List<String> customFolders = [];
      if (customFoldersJson != null) {
        customFolders = (jsonDecode(customFoldersJson) as List).cast<String>();
      }

      Map<String, String> assignments = {};
      if (assignmentsJson != null) {
        assignments = (jsonDecode(assignmentsJson) as Map).cast<String, String>();
      }

      state = AppFolderState(
        enabled: enabled,
        customFolders: customFolders,
        customAssignments: assignments,
      );
    } catch (_) {}
  }

  /// Save state to SharedPreferences
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, state.enabled);
      await prefs.setString(_kCustomFoldersKey, jsonEncode(state.customFolders));
      await prefs.setString(_kAssignmentsKey, jsonEncode(state.customAssignments));
    } catch (_) {}
  }

  /// Toggle the feature on/off
  Future<void> toggleFeature() async {
    state = state.copyWith(
      enabled: !state.enabled,
      activeFolder: () => null,
    );
    await _save();
  }

  /// Set feature enabled/disabled
  Future<void> setEnabled(bool value) async {
    state = state.copyWith(
      enabled: value,
      activeFolder: () => value ? state.activeFolder : null,
    );
    await _save();
  }

  /// Select a folder to filter by, or null for all
  void selectFolder(String? name) {
    state = state.copyWith(activeFolder: () => name);
  }

  /// Create a custom folder
  Future<void> createFolder(String name) async {
    if (name.trim().isEmpty) return;
    final trimmed = name.trim();
    // Don't allow duplicates (case-insensitive check)
    final exists = state.customFolders.any(
      (f) => f.toLowerCase() == trimmed.toLowerCase(),
    ) || AppCategories.defaultNames.any(
      (f) => f.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;

    state = state.copyWith(
      customFolders: [...state.customFolders, trimmed],
    );
    await _save();
  }

  /// Delete a custom folder (only user-created)
  Future<void> deleteFolder(String name) async {
    // Can't delete default categories
    if (AppCategories.defaultNames.contains(name)) return;

    final updatedFolders = state.customFolders
        .where((f) => f != name)
        .toList();

    // Remove assignments pointing to deleted folder
    final updatedAssignments = Map<String, String>.from(state.customAssignments)
      ..removeWhere((_, v) => v == name);

    state = state.copyWith(
      customFolders: updatedFolders,
      customAssignments: updatedAssignments,
      activeFolder: () => state.activeFolder == name ? null : state.activeFolder,
    );
    await _save();
  }

  /// Rename a custom folder
  Future<void> renameFolder(String oldName, String newName) async {
    if (newName.trim().isEmpty) return;
    if (AppCategories.defaultNames.contains(oldName)) return;

    final trimmed = newName.trim();
    final updatedFolders = state.customFolders
        .map((f) => f == oldName ? trimmed : f)
        .toList();

    // Update assignments pointing to old name
    final updatedAssignments = state.customAssignments.map(
      (k, v) => MapEntry(k, v == oldName ? trimmed : v),
    );

    state = state.copyWith(
      customFolders: updatedFolders,
      customAssignments: updatedAssignments,
      activeFolder: () => state.activeFolder == oldName ? trimmed : state.activeFolder,
    );
    await _save();
  }

  /// Override: move an app to a specific folder
  Future<void> moveAppToFolder(String packageName, String folderName) async {
    final updated = Map<String, String>.from(state.customAssignments);
    updated[packageName] = folderName;
    state = state.copyWith(customAssignments: updated);
    await _save();
  }

  /// Remove manual override — revert to auto-categorization
  Future<void> removeAppFromFolder(String packageName) async {
    final updated = Map<String, String>.from(state.customAssignments);
    updated.remove(packageName);
    state = state.copyWith(customAssignments: updated);
    await _save();
  }

  /// Get the category for a specific app (custom override > auto)
  String? getCategoryFor(String packageName) {
    // Manual override takes priority
    if (state.customAssignments.containsKey(packageName)) {
      return state.customAssignments[packageName];
    }
    // Auto-categorize
    return AppCategories.categorize(packageName);
  }

  /// Get all folder names that have at least one app
  /// Returns ordered list: default categories first, then custom folders
  List<String> getActiveFolders(List<InstalledApp> apps) {
    final result = <String>[];
    final counts = <String, int>{};

    // Count apps per folder
    for (final app in apps) {
      final cat = getCategoryFor(app.packageName);
      if (cat != null) {
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
    }

    // Add default categories that have apps
    for (final cat in AppCategories.defaults) {
      if (counts.containsKey(cat.name) && counts[cat.name]! > 0) {
        result.add(cat.name);
      }
    }

    // Add custom folders that have apps
    for (final folder in state.customFolders) {
      if (counts.containsKey(folder) && counts[folder]! > 0) {
        result.add(folder);
      }
    }

    // Also add custom folders with no apps (user created them intentionally)
    for (final folder in state.customFolders) {
      if (!result.contains(folder)) {
        result.add(folder);
      }
    }

    return result;
  }

  /// Filter apps by the active folder
  List<InstalledApp> filterByActiveFolder(List<InstalledApp> apps) {
    if (!state.enabled || state.activeFolder == null) return apps;
    return apps.where((app) {
      return getCategoryFor(app.packageName) == state.activeFolder;
    }).toList();
  }

  /// Get all available folder names (for "move to" dialog)
  List<String> getAllFolderNames() {
    final names = <String>[...AppCategories.defaultNames, ...state.customFolders];
    return names;
  }

  /// Check if a folder is a default (non-deletable) category
  bool isDefaultFolder(String name) {
    return AppCategories.defaultNames.contains(name);
  }
}

/// Provider
final appFolderProvider =
    StateNotifierProvider<AppFolderNotifier, AppFolderState>(
  (ref) => AppFolderNotifier(),
);
