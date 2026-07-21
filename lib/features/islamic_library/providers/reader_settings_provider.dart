import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════
// READER SETTINGS — reading theme (palette), font size, line spacing
// ══════════════════════════════════════════════════════════════════════

enum LineSpacingMode { compact, comfortable, relaxed }

/// A complete reading-surface palette. Each [ReaderTheme] resolves to one of
/// these, so the whole reader (page, bars, sheets, text tiers, headings) shares
/// a single consistent, book-grade colour set.
class ReaderPalette {
  final String label;
  final IconData icon;
  final Color bg; // page background
  final Color surface; // bars / sheets / cards
  final Color text; // body text
  final Color textMuted; // secondary text
  final Color textFaint; // tertiary / labels
  final Color accent; // headings, highlights, progress
  final Color divider; // hairlines
  final bool isDark; // drives status-bar icon brightness

  const ReaderPalette({
    required this.label,
    required this.icon,
    required this.bg,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.divider,
    required this.isDark,
  });
}

/// Six dedicated reading themes — two light (Paper, Sepia) and four dark
/// (Night, Black, Nord, Forest). Tuned for long-form reading: gentle contrast,
/// warm or cool calm tones, no pure-white-on-pure-black glare.
enum ReaderTheme { paper, sepia, night, black, nord, forest }

const Map<ReaderTheme, ReaderPalette> kReaderPalettes = {
  ReaderTheme.paper: ReaderPalette(
    label: 'Paper',
    icon: Icons.article_outlined,
    bg: Color(0xFFFBFAF7),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF23211D),
    textMuted: Color(0xFF6E6A62),
    textFaint: Color(0xFFA8A39A),
    accent: Color(0xFFB07A2E),
    divider: Color(0xFFECE8E0),
    isDark: false,
  ),
  ReaderTheme.sepia: ReaderPalette(
    label: 'Sepia',
    icon: Icons.menu_book_rounded,
    bg: Color(0xFFF3E9D6),
    surface: Color(0xFFF8F1E2),
    text: Color(0xFF4A3B2A),
    textMuted: Color(0xFF897359),
    textFaint: Color(0xFFB3A187),
    accent: Color(0xFF9A6E3A),
    divider: Color(0xFFE2D4BC),
    isDark: false,
  ),
  ReaderTheme.night: ReaderPalette(
    label: 'Night',
    icon: Icons.nightlight_round,
    bg: Color(0xFF16161A),
    surface: Color(0xFF1E1E24),
    text: Color(0xFFDAD4C8),
    textMuted: Color(0xFF9A958A),
    textFaint: Color(0xFF6A655C),
    accent: Color(0xFFD8B26A),
    divider: Color(0xFF2A2A30),
    isDark: true,
  ),
  ReaderTheme.black: ReaderPalette(
    label: 'Black',
    icon: Icons.contrast_rounded,
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E0E),
    text: Color(0xFFD6D1C6),
    textMuted: Color(0xFF8C887E),
    textFaint: Color(0xFF5A574F),
    accent: Color(0xFFC9A24B),
    divider: Color(0xFF1A1A1A),
    isDark: true,
  ),
  ReaderTheme.nord: ReaderPalette(
    label: 'Nord',
    icon: Icons.ac_unit_rounded,
    bg: Color(0xFF2E3440),
    surface: Color(0xFF3B4252),
    text: Color(0xFFE5E9F0),
    textMuted: Color(0xFFA9B2C3),
    textFaint: Color(0xFF6E7689),
    accent: Color(0xFF88C0D0),
    divider: Color(0xFF434C5E),
    isDark: true,
  ),
  ReaderTheme.forest: ReaderPalette(
    label: 'Forest',
    icon: Icons.forest_rounded,
    bg: Color(0xFF14201A),
    surface: Color(0xFF1C2A22),
    text: Color(0xFFDCE7DD),
    textMuted: Color(0xFF97A99A),
    textFaint: Color(0xFF677A6A),
    accent: Color(0xFFA3C9A8),
    divider: Color(0xFF25382C),
    isDark: true,
  ),
};

class ReaderSettings {
  final double fontSize;
  final ReaderTheme theme;
  final LineSpacingMode lineSpacing;

  const ReaderSettings({
    this.fontSize = 17.0,
    this.theme = ReaderTheme.night,
    this.lineSpacing = LineSpacingMode.comfortable,
  });

  ReaderPalette get palette => kReaderPalettes[theme]!;
  bool get isDark => palette.isDark;

  double get lineHeight {
    switch (lineSpacing) {
      case LineSpacingMode.compact:
        return 1.5;
      case LineSpacingMode.comfortable:
        return 1.8;
      case LineSpacingMode.relaxed:
        return 2.1;
    }
  }

  ReaderSettings copyWith({
    double? fontSize,
    ReaderTheme? theme,
    LineSpacingMode? lineSpacing,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
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
    final themeIdx = prefs.getInt('${_prefix}theme');
    state = ReaderSettings(
      fontSize: prefs.getDouble('${_prefix}font_size') ?? 17.0,
      theme: (themeIdx != null && themeIdx >= 0 && themeIdx < ReaderTheme.values.length)
          ? ReaderTheme.values[themeIdx]
          : ReaderTheme.night,
      lineSpacing: LineSpacingMode.values[
          prefs.getInt('${_prefix}line_spacing') ??
              LineSpacingMode.comfortable.index],
    );
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(15.0, 24.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefix}font_size', state.fontSize);
  }

  Future<void> setTheme(ReaderTheme theme) async {
    state = state.copyWith(theme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}theme', theme.index);
  }

  Future<void> setLineSpacing(LineSpacingMode spacing) async {
    state = state.copyWith(lineSpacing: spacing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}line_spacing', spacing.index);
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
  (ref) => ReaderSettingsNotifier(),
);

// ══════════════════════════════════════════════════════════════════════
// READER LANGUAGE — English vs Hinglish (Roman Urdu)
// Kept deliberately separate from [ReaderSettings] so the book only
// reloads when the language changes — not on every font / theme tweak.
// ══════════════════════════════════════════════════════════════════════

enum ReaderLanguage { english, hinglish }

extension ReaderLanguageX on ReaderLanguage {
  /// Asset filename prefix for this language's chapter JSON files,
  /// e.g. 'ar_raheeq' → assets/ar_raheeq_ch2.json,
  ///      'ar_raheeq_hi' → assets/ar_raheeq_hi_ch2.json
  String get assetPrefix =>
      this == ReaderLanguage.hinglish ? 'ar_raheeq_hi' : 'ar_raheeq';

  /// Full label shown in pickers.
  String get label => this == ReaderLanguage.hinglish ? 'Hinglish' : 'English';
}

class ReaderLanguageNotifier extends StateNotifier<ReaderLanguage> {
  static const _key = 'seerah_reader_language';

  ReaderLanguageNotifier() : super(ReaderLanguage.english) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_key);
    if (idx != null && idx >= 0 && idx < ReaderLanguage.values.length) {
      state = ReaderLanguage.values[idx];
    }
  }

  Future<void> setLanguage(ReaderLanguage lang) async {
    if (state == lang) return;
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, lang.index);
  }
}

final readerLanguageProvider =
    StateNotifierProvider<ReaderLanguageNotifier, ReaderLanguage>(
  (ref) => ReaderLanguageNotifier(),
);
