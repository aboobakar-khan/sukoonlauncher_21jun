import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/reader_settings_provider.dart';
import 'reader_palette.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../providers/theme_provider.dart';

/// "Aa" reader-settings affordance + bottom sheet (font, theme, spacing).
class ReaderSettingsButton extends ConsumerWidget {
  final ReaderPalette p;
  const ReaderSettingsButton({super.key, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showSettingsSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Aa',
          style: GoogleFonts.literata(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: p.accent,
            height: 1,
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ReaderSettingsSheet(),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final accent = ref.watch(themeColorProvider).color;
    final p = ReaderPalette(isDark, accent);

    return Container(
      padding: EdgeInsets.fromLTRB(
          22, 12, 22, MediaQuery.paddingOf(context).bottom + 28),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: p.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Text(
              'Reading',
              style: GoogleFonts.literata(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Font size ──
          _Label(text: 'Text Size', p: p),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text('A',
                    style:
                        GoogleFonts.literata(fontSize: 14, color: p.textTertiary)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: p.accent,
                      inactiveTrackColor: p.accent.withValues(alpha: 0.16),
                      thumbColor: p.accent,
                      overlayColor: p.accent.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: settings.fontSize,
                      min: 14,
                      max: 22,
                      divisions: 8,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        notifier.setFontSize(v);
                      },
                    ),
                  ),
                ),
                Text('A',
                    style: GoogleFonts.literata(fontSize: 22, color: p.text)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Theme (drives the shared app light/dark) ──
          _Label(text: 'Theme', p: p),
          const SizedBox(height: 8),
          _Segmented(
            p: p,
            options: [
              _SegOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                selected: !isDark,
                onTap: () => ref
                    .read(islamicThemeProvider.notifier)
                    .setMode(IslamicThemeMode.light),
              ),
              _SegOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                selected: isDark,
                onTap: () => ref
                    .read(islamicThemeProvider.notifier)
                    .setMode(IslamicThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Line spacing ──
          _Label(text: 'Line Spacing', p: p),
          const SizedBox(height: 8),
          _Segmented(
            p: p,
            options: [
              _SegOption(
                label: 'Compact',
                icon: Icons.density_small_rounded,
                selected: settings.lineSpacing == LineSpacingMode.compact,
                onTap: () => notifier.setLineSpacing(LineSpacingMode.compact),
              ),
              _SegOption(
                label: 'Cozy',
                icon: Icons.density_medium_rounded,
                selected: settings.lineSpacing == LineSpacingMode.comfortable,
                onTap: () =>
                    notifier.setLineSpacing(LineSpacingMode.comfortable),
              ),
              _SegOption(
                label: 'Relaxed',
                icon: Icons.density_large_rounded,
                selected: settings.lineSpacing == LineSpacingMode.relaxed,
                onTap: () => notifier.setLineSpacing(LineSpacingMode.relaxed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final ReaderPalette p;
  const _Label({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.nunitoSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: p.textTertiary,
      ),
    );
  }
}

class _SegOption {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  _SegOption(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
}

class _Segmented extends StatelessWidget {
  final ReaderPalette p;
  final List<_SegOption> options;
  const _Segmented({required this.p, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((o) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                o.onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: o.selected
                      ? p.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.icon,
                        size: 18,
                        color: o.selected ? p.accent : p.textTertiary),
                    const SizedBox(height: 4),
                    Text(
                      o.label,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight:
                            o.selected ? FontWeight.w800 : FontWeight.w600,
                        color: o.selected ? p.accent : p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
