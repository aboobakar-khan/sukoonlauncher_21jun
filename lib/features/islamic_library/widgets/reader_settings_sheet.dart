import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/reader_settings_provider.dart';

/// Floating action button + bottom sheet for reader settings.
class ReaderSettingsButton extends ConsumerWidget {
  final bool isDark;
  const ReaderSettingsButton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gold = Color(0xFFD4A017);
    return FloatingActionButton.small(
      heroTag: 'reader_settings_fab',
      backgroundColor: isDark ? const Color(0xFF1A2B22) : Colors.white,
      elevation: 4,
      onPressed: () => _showSettingsSheet(context, ref),
      child: const Icon(Icons.text_fields_rounded, size: 20, color: gold),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReaderSettingsSheet(isDark: isDark),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  final bool isDark;
  const _ReaderSettingsSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    const gold = Color(0xFFD4A017);

    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF9F6EE);
    final surfaceColor = isDark ? const Color(0xFF1A2B22) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFF5F0E8) : const Color(0xFF1C1C1E);
    final mutedText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: mutedText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Title ──
          Text(
            'Reader Settings',
            style: GoogleFonts.nunitoSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),

          // ═══ Font Size ═══
          _SectionLabel(label: 'Font Size', color: mutedText),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text('A',
                    style: GoogleFonts.literata(
                        fontSize: 14, color: mutedText)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: gold,
                      inactiveTrackColor: gold.withValues(alpha: 0.15),
                      thumbColor: gold,
                      overlayColor: gold.withValues(alpha: 0.1),
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: settings.fontSize,
                      min: 14,
                      max: 22,
                      divisions: 8,
                      onChanged: (v) => notifier.setFontSize(v),
                    ),
                  ),
                ),
                Text('A',
                    style: GoogleFonts.literata(
                        fontSize: 22, color: textColor)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ═══ Theme ═══
          _SectionLabel(label: 'Theme', color: mutedText),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  selected: settings.themeMode == ReaderThemeMode.light,
                  textColor: textColor,
                  onTap: () => notifier.setThemeMode(ReaderThemeMode.light),
                ),
                _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  selected: settings.themeMode == ReaderThemeMode.dark,
                  textColor: textColor,
                  onTap: () => notifier.setThemeMode(ReaderThemeMode.dark),
                ),
                _ThemeOption(
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                  selected: settings.themeMode == ReaderThemeMode.system,
                  textColor: textColor,
                  onTap: () => notifier.setThemeMode(ReaderThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ═══ Line Spacing ═══
          _SectionLabel(label: 'Line Spacing', color: mutedText),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _ThemeOption(
                  label: 'Compact',
                  icon: Icons.density_small_rounded,
                  selected: settings.lineSpacing == LineSpacingMode.compact,
                  textColor: textColor,
                  onTap: () =>
                      notifier.setLineSpacing(LineSpacingMode.compact),
                ),
                _ThemeOption(
                  label: 'Comfortable',
                  icon: Icons.density_medium_rounded,
                  selected:
                      settings.lineSpacing == LineSpacingMode.comfortable,
                  textColor: textColor,
                  onTap: () =>
                      notifier.setLineSpacing(LineSpacingMode.comfortable),
                ),
                _ThemeOption(
                  label: 'Relaxed',
                  icon: Icons.density_large_rounded,
                  selected: settings.lineSpacing == LineSpacingMode.relaxed,
                  textColor: textColor,
                  onTap: () =>
                      notifier.setLineSpacing(LineSpacingMode.relaxed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunitoSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A017);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? gold.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: gold.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? gold : textColor.withValues(alpha: 0.4)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? gold : textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
