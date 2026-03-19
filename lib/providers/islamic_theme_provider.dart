import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Theme mode for Islamic content screens (Quran, Hadith, Dua)
enum IslamicThemeMode {
  light,
  dark,
}

extension IslamicThemeModeExtension on IslamicThemeMode {
  String get label => this == IslamicThemeMode.light ? 'Light' : 'Dark';
  IconData get icon => this == IslamicThemeMode.light
      ? Icons.light_mode_rounded
      : Icons.dark_mode_rounded;
}

/// Colors for Islamic content screens
class IslamicThemeColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color accent;       // gold
  final Color green;        // islamic green
  final Color greenLight;   // lighter green variant
  final Color arabicText;
  final Brightness statusBarBrightness;

  const IslamicThemeColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.accent,
    required this.green,
    required this.greenLight,
    required this.arabicText,
    required this.statusBarBrightness,
  });

  /// Warm cream light mode (current default)
  static const light = IslamicThemeColors(
    background: Color(0xFFFDF6EC),
    surface: Color(0xFFF5E6C8),
    text: Color(0xFF2C1810),
    textSecondary: Color(0xFF5C4033),
    textTertiary: Color(0xFF8B7355),
    border: Color(0xFFE8D5B8),
    accent: Color(0xFFC2A366),
    green: Color(0xFF2E7D32),
    greenLight: Color(0xFF43A047),
    arabicText: Color(0xFF2C1810),
    statusBarBrightness: Brightness.dark,
  );

  /// Pure black dark mode — AMOLED-friendly
  static const dark = IslamicThemeColors(
    background: Color(0xFF000000),
    surface: Color(0xFF111111),
    text: Color(0xFFE8E0D4),
    textSecondary: Color(0xFFA89880),
    textTertiary: Color(0xFF6B6055),
    border: Color(0xFF1A1A1A),
    accent: Color(0xFFC2A366),
    green: Color(0xFFC2A366),      // camel/gold — consistent with accent, replaces bright green
    greenLight: Color(0xFFD4B87A), // lighter camel for hover/highlight states
    arabicText: Color(0xFFF0E8DC),
    statusBarBrightness: Brightness.light,
  );

  static IslamicThemeColors fromMode(IslamicThemeMode mode) {
    return mode == IslamicThemeMode.light ? light : dark;
  }
}

/// Provider for Islamic content theme mode
final islamicThemeProvider =
    StateNotifierProvider<IslamicThemeNotifier, IslamicThemeMode>((ref) {
  return IslamicThemeNotifier();
});

/// Convenience provider for resolved colors
final islamicThemeColorsProvider = Provider<IslamicThemeColors>((ref) {
  final mode = ref.watch(islamicThemeProvider);
  return IslamicThemeColors.fromMode(mode);
});

class IslamicThemeNotifier extends StateNotifier<IslamicThemeMode> {
  static const String _boxName = 'settings';
  static const String _key = 'islamicThemeMode';
  Box? _box;

  IslamicThemeNotifier() : super(IslamicThemeMode.light) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final saved = _box?.get(_key) as String?;
      if (saved == 'dark') {
        state = IslamicThemeMode.dark;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    final newMode = state == IslamicThemeMode.light
        ? IslamicThemeMode.dark
        : IslamicThemeMode.light;
    state = newMode;
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_key, newMode.name);
  }

  Future<void> setMode(IslamicThemeMode mode) async {
    state = mode;
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_key, mode.name);
  }
}
