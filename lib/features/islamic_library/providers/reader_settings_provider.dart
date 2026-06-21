import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════
// READER SETTINGS — font size, theme, line spacing
// ══════════════════════════════════════════════════════════════════════

enum ReaderThemeMode { light, dark, system }

enum LineSpacingMode { compact, comfortable, relaxed }

class ReaderSettings {
  final double fontSize;
  final ReaderThemeMode themeMode;
  final LineSpacingMode lineSpacing;

  const ReaderSettings({
    this.fontSize = 16.0,
    this.themeMode = ReaderThemeMode.dark,
    this.lineSpacing = LineSpacingMode.comfortable,
  });

  double get lineHeight {
    switch (lineSpacing) {
      case LineSpacingMode.compact:
        return 1.4;
      case LineSpacingMode.comfortable:
        return 1.7;
      case LineSpacingMode.relaxed:
        return 2.0;
    }
  }

  ReaderSettings copyWith({
    double? fontSize,
    ReaderThemeMode? themeMode,
    LineSpacingMode? lineSpacing,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  static const _prefix = 'seerah_reader_';

  ReaderSettingsNotifier() : super(const ReaderSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ReaderSettings(
      fontSize: prefs.getDouble('${_prefix}font_size') ?? 16.0,
      themeMode: ReaderThemeMode.values[
          prefs.getInt('${_prefix}theme_mode') ?? ReaderThemeMode.dark.index],
      lineSpacing: LineSpacingMode.values[
          prefs.getInt('${_prefix}line_spacing') ??
              LineSpacingMode.comfortable.index],
    );
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(14.0, 22.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefix}font_size', state.fontSize);
  }

  Future<void> setThemeMode(ReaderThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}theme_mode', mode.index);
  }

  Future<void> setLineSpacing(LineSpacingMode spacing) async {
    state = state.copyWith(lineSpacing: spacing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}line_spacing', spacing.index);
  }

  /// Resolve actual brightness based on settings + system.
  bool isDarkMode(BuildContext context) {
    switch (state.themeMode) {
      case ReaderThemeMode.light:
        return false;
      case ReaderThemeMode.dark:
        return true;
      case ReaderThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
  (ref) => ReaderSettingsNotifier(),
);
