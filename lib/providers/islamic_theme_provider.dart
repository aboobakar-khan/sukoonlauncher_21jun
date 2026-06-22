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

// ═══════════════════════════════════════════════════════════════════════════
//  MASTER THEMES — named palettes, each with a light + dark variant.
//  Makhtut is the original manuscript look; the rest are developer-loved
//  palettes adapted to the Islamic reading tokens.
// ═══════════════════════════════════════════════════════════════════════════

enum MasterTheme { makhtut, catppuccin, tokyoNight, rosePine, gruvbox, oneDark }

class MasterThemeDef {
  final String label;
  final String description;
  final List<Color> dots; // 3 preview swatches
  final IslamicThemeColors light;
  final IslamicThemeColors dark;
  const MasterThemeDef({
    required this.label,
    required this.description,
    required this.dots,
    required this.light,
    required this.dark,
  });
}

const Map<MasterTheme, MasterThemeDef> kMasterThemes = {
  MasterTheme.makhtut: MasterThemeDef(
    label: 'Makhtut',
    description: 'Manuscript warmth, classic default',
    dots: [Color(0xFFC2A366), Color(0xFFA67B5B), Color(0xFF2E7D32)],
    light: IslamicThemeColors.light,
    dark: IslamicThemeColors.dark,
  ),
  MasterTheme.catppuccin: MasterThemeDef(
    label: 'Catppuccin',
    description: 'Pastel modern tones, calm and clean',
    dots: [Color(0xFFCBA6F7), Color(0xFF89B4FA), Color(0xFFA6E3A1)],
    light: IslamicThemeColors(
      background: Color(0xFFEFF1F5), surface: Color(0xFFDCE0E8),
      text: Color(0xFF4C4F69), textSecondary: Color(0xFF5C5F77),
      textTertiary: Color(0xFF8C8FA1), border: Color(0xFFCCD0DA),
      accent: Color(0xFF8839EF), green: Color(0xFF40A02B),
      greenLight: Color(0xFF179299), arabicText: Color(0xFF4C4F69),
      statusBarBrightness: Brightness.dark,
    ),
    dark: IslamicThemeColors(
      background: Color(0xFF1E1E2E), surface: Color(0xFF313244),
      text: Color(0xFFCDD6F4), textSecondary: Color(0xFFA6ADC8),
      textTertiary: Color(0xFF7F849C), border: Color(0xFF45475A),
      accent: Color(0xFFCBA6F7), green: Color(0xFFA6E3A1),
      greenLight: Color(0xFF94E2D5), arabicText: Color(0xFFCDD6F4),
      statusBarBrightness: Brightness.light,
    ),
  ),
  MasterTheme.tokyoNight: MasterThemeDef(
    label: 'Tokyo Night',
    description: 'Neon-night contrast, modern and focused',
    dots: [Color(0xFF7AA2F7), Color(0xFF7DCFFF), Color(0xFF9ECE6A)],
    light: IslamicThemeColors(
      background: Color(0xFFE1E2E7), surface: Color(0xFFD0D5E3),
      text: Color(0xFF343B58), textSecondary: Color(0xFF6172B0),
      textTertiary: Color(0xFF848CB5), border: Color(0xFFC4C8DA),
      accent: Color(0xFF9854F1), green: Color(0xFF587539),
      greenLight: Color(0xFF387068), arabicText: Color(0xFF343B58),
      statusBarBrightness: Brightness.dark,
    ),
    dark: IslamicThemeColors(
      background: Color(0xFF1A1B26), surface: Color(0xFF24283B),
      text: Color(0xFFC0CAF5), textSecondary: Color(0xFF9AA5CE),
      textTertiary: Color(0xFF565F89), border: Color(0xFF2F3549),
      accent: Color(0xFFBB9AF7), green: Color(0xFF9ECE6A),
      greenLight: Color(0xFF73DACA), arabicText: Color(0xFFC0CAF5),
      statusBarBrightness: Brightness.light,
    ),
  ),
  MasterTheme.rosePine: MasterThemeDef(
    label: 'Rose Pine',
    description: 'Elegant and soft contrast palette',
    dots: [Color(0xFF31748F), Color(0xFF9CCFD8), Color(0xFFEBBCBA)],
    light: IslamicThemeColors(
      background: Color(0xFFFAF4ED), surface: Color(0xFFFFFAF3),
      text: Color(0xFF575279), textSecondary: Color(0xFF797593),
      textTertiary: Color(0xFF9893A5), border: Color(0xFFDFDAD9),
      accent: Color(0xFFEA9D34), green: Color(0xFF286983),
      greenLight: Color(0xFF56949F), arabicText: Color(0xFF575279),
      statusBarBrightness: Brightness.dark,
    ),
    dark: IslamicThemeColors(
      background: Color(0xFF191724), surface: Color(0xFF1F1D2E),
      text: Color(0xFFE0DEF4), textSecondary: Color(0xFF908CAA),
      textTertiary: Color(0xFF6E6A86), border: Color(0xFF26233A),
      accent: Color(0xFFF6C177), green: Color(0xFF31748F),
      greenLight: Color(0xFF9CCFD8), arabicText: Color(0xFFE0DEF4),
      statusBarBrightness: Brightness.light,
    ),
  ),
  MasterTheme.gruvbox: MasterThemeDef(
    label: 'Gruvbox',
    description: 'Earthy vintage contrast theme',
    dots: [Color(0xFFB8BB26), Color(0xFFFABD2F), Color(0xFF8EC07C)],
    light: IslamicThemeColors(
      background: Color(0xFFFBF1C7), surface: Color(0xFFF2E5BC),
      text: Color(0xFF3C3836), textSecondary: Color(0xFF504945),
      textTertiary: Color(0xFF7C6F64), border: Color(0xFFEBDBB2),
      accent: Color(0xFFB57614), green: Color(0xFF79740E),
      greenLight: Color(0xFF98971A), arabicText: Color(0xFF3C3836),
      statusBarBrightness: Brightness.dark,
    ),
    dark: IslamicThemeColors(
      background: Color(0xFF282828), surface: Color(0xFF3C3836),
      text: Color(0xFFEBDBB2), textSecondary: Color(0xFFBDAE93),
      textTertiary: Color(0xFF928374), border: Color(0xFF504945),
      accent: Color(0xFFFABD2F), green: Color(0xFFB8BB26),
      greenLight: Color(0xFF8EC07C), arabicText: Color(0xFFEBDBB2),
      statusBarBrightness: Brightness.light,
    ),
  ),
  MasterTheme.oneDark: MasterThemeDef(
    label: 'One Dark',
    description: 'Developer favorite neutral palette',
    dots: [Color(0xFF61AFEF), Color(0xFFC678DD), Color(0xFF98C379)],
    light: IslamicThemeColors(
      background: Color(0xFFFAFAFA), surface: Color(0xFFECECEC),
      text: Color(0xFF383A42), textSecondary: Color(0xFF696C77),
      textTertiary: Color(0xFFA0A1A7), border: Color(0xFFD4D4D5),
      accent: Color(0xFFC18401), green: Color(0xFF50A14F),
      greenLight: Color(0xFF6BBF59), arabicText: Color(0xFF383A42),
      statusBarBrightness: Brightness.dark,
    ),
    dark: IslamicThemeColors(
      background: Color(0xFF282C34), surface: Color(0xFF21252B),
      text: Color(0xFFABB2BF), textSecondary: Color(0xFF828997),
      textTertiary: Color(0xFF5C6370), border: Color(0xFF3B4048),
      accent: Color(0xFFE5C07B), green: Color(0xFF98C379),
      greenLight: Color(0xFF56B6C2), arabicText: Color(0xFFABB2BF),
      statusBarBrightness: Brightness.light,
    ),
  ),
};

extension MasterThemeX on MasterTheme {
  MasterThemeDef get def => kMasterThemes[this]!;
  IslamicThemeColors colorsFor(IslamicThemeMode mode) =>
      mode == IslamicThemeMode.light ? def.light : def.dark;
}

/// Selected master palette (persisted). Combined with [islamicThemeProvider]
/// (the effective light/dark brightness) by [islamicThemeColorsProvider].
final masterThemeProvider =
    StateNotifierProvider<MasterThemeNotifier, MasterTheme>((ref) {
  return MasterThemeNotifier();
});

class MasterThemeNotifier extends StateNotifier<MasterTheme> {
  static const String _boxName = 'settings';
  static const String _key = 'islamicMasterTheme';
  Box? _box;

  MasterThemeNotifier() : super(MasterTheme.makhtut) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final saved = _box?.get(_key) as String?;
      if (saved != null) {
        state = MasterTheme.values.firstWhere(
          (t) => t.name == saved,
          orElse: () => MasterTheme.makhtut,
        );
      }
    } catch (_) {}
  }

  Future<void> select(MasterTheme theme) async {
    state = theme;
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_key, theme.name);
  }
}

/// How light/dark is chosen. `system` follows the OS at selection/launch time.
enum AppearanceMode { system, light, dark }

extension AppearanceModeX on AppearanceMode {
  String get label => switch (this) {
        AppearanceMode.system => 'System',
        AppearanceMode.light => 'Light',
        AppearanceMode.dark => 'Dark',
      };
  String get subtitle => switch (this) {
        AppearanceMode.system => 'Follow your device setting',
        AppearanceMode.light => 'Always use light mode',
        AppearanceMode.dark => 'Always use dark mode',
      };
}

final appearanceModeProvider =
    StateNotifierProvider<AppearanceModeNotifier, AppearanceMode>((ref) {
  return AppearanceModeNotifier();
});

class AppearanceModeNotifier extends StateNotifier<AppearanceMode> {
  static const String _boxName = 'settings';
  static const String _key = 'islamicAppearanceMode';
  Box? _box;

  AppearanceModeNotifier() : super(AppearanceMode.system) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final saved = _box?.get(_key) as String?;
      if (saved != null) {
        state = AppearanceMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => AppearanceMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> set(AppearanceMode mode) async {
    state = mode;
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_key, mode.name);
  }
}

/// Resolve [AppearanceMode] → concrete light/dark using the OS brightness for
/// `system`. Reads the platform brightness at call time.
IslamicThemeMode resolveAppearance(AppearanceMode mode) {
  switch (mode) {
    case AppearanceMode.light:
      return IslamicThemeMode.light;
    case AppearanceMode.dark:
      return IslamicThemeMode.dark;
    case AppearanceMode.system:
      final b =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return b == Brightness.dark
          ? IslamicThemeMode.dark
          : IslamicThemeMode.light;
  }
}

/// Provider for Islamic content theme mode
final islamicThemeProvider =
    StateNotifierProvider<IslamicThemeNotifier, IslamicThemeMode>((ref) {
  return IslamicThemeNotifier();
});

/// Convenience provider for resolved colors — combines the selected
/// [masterThemeProvider] palette with the effective light/dark brightness.
final islamicThemeColorsProvider = Provider<IslamicThemeColors>((ref) {
  final mode = ref.watch(islamicThemeProvider);
  final master = ref.watch(masterThemeProvider);
  return master.colorsFor(mode);
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
      // Prefer the new AppearanceMode (resolves `system` → OS brightness).
      final appearanceStr = _box?.get('islamicAppearanceMode') as String?;
      if (appearanceStr != null) {
        state = resolveAppearance(AppearanceMode.values.firstWhere(
          (m) => m.name == appearanceStr,
          orElse: () => AppearanceMode.system,
        ));
        return;
      }
      // Legacy fallback: explicit light/dark saved before AppearanceMode existed.
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
