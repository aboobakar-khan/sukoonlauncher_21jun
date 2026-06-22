import 'package:flutter/material.dart';

/// Single source of truth for the Seerah reader's colour palette.
///
/// Surfaces follow the app's light / "midnight" mode (kept in sync with the
/// shared `islamicThemeProvider`), while [accent] is the user's selected theme
/// colour (Pink, Gold, Blue …) coming from `themeColorProvider`. This keeps the
/// book reader visually consistent with the Quran and Hadith sections.
class ReaderPalette {
  final bool isDark;
  final Color accent;

  final Color bg;          // page background
  final Color surface;     // cards / sheets
  final Color surfaceHigh; // raised elements (option chips, FAB)
  final Color text;        // primary reading text
  final Color textSecondary;
  final Color textTertiary; // labels, hints
  final Color border;
  final Color arabic;

  const ReaderPalette._({
    required this.isDark,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.arabic,
  });

  factory ReaderPalette(bool isDark, Color accent) {
    if (isDark) {
      return ReaderPalette._(
        isDark: true,
        accent: accent,
        bg: const Color(0xFF000000),
        surface: const Color(0xFF121212),
        surfaceHigh: const Color(0xFF1C1C1E),
        text: const Color(0xFFEDE6D8),
        textSecondary: const Color(0xFFA8A095),
        textTertiary: const Color(0xFF6E665C),
        border: const Color(0xFF24241F),
        arabic: const Color(0xFFF2EBDD),
      );
    }
    return ReaderPalette._(
      isDark: false,
      accent: accent,
      bg: const Color(0xFFFBF6EC),
      surface: const Color(0xFFF3EBDA),
      surfaceHigh: Colors.white,
      text: const Color(0xFF2A1E12),
      textSecondary: const Color(0xFF6E5E4C),
      textTertiary: const Color(0xFF9C8B76),
      border: const Color(0xFFE8DDC9),
      arabic: const Color(0xFF2A1E12),
    );
  }
}
