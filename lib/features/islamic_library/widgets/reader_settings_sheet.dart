import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/reader_settings_provider.dart';

/// Top-bar button that opens the reader settings sheet.
class ReaderSettingsButton extends ConsumerWidget {
  final ReaderPalette palette;
  const ReaderSettingsButton({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const _ReaderSettingsSheet(),
      ),
      icon: Icon(Icons.text_fields_rounded, size: 22, color: palette.text),
      splashRadius: 20,
    );
  }
}

/// Compact theme-only picker, opened from the library home.
class ReaderThemeQuickSheet extends ConsumerWidget {
  const ReaderThemeQuickSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final p = settings.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.divider, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: p.textFaint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Reading Theme',
              style: GoogleFonts.literata(
                  fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 4),
          Text('Applies across the whole library',
              style:
                  GoogleFonts.nunitoSans(fontSize: 12.5, color: p.textMuted)),
          const SizedBox(height: 20),
          _ThemeGrid(
            current: settings.theme,
            accent: p.accent,
            labelColor: p.text,
            onPick: notifier.setTheme,
          ),
        ],
      ),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    // Sheet recolours live as the theme changes.
    final p = settings.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.divider, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: p.textFaint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Reading Settings',
                style: GoogleFonts.literata(
                    fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 24),

            // ═══ Language ═══
            _SectionLabel(label: 'Language', color: p.textMuted),
            const SizedBox(height: 12),
            LanguageSegment(palette: p),
            const SizedBox(height: 24),

            // ═══ Reading theme ═══
            _SectionLabel(label: 'Reading Theme', color: p.textMuted),
            const SizedBox(height: 12),
            _ThemeGrid(
              current: settings.theme,
              accent: p.accent,
              labelColor: p.text,
              onPick: notifier.setTheme,
            ),
            const SizedBox(height: 24),

            // ═══ Font size ═══
            _SectionLabel(label: 'Font Size', color: p.textMuted),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Text('A',
                      style:
                          GoogleFonts.literata(fontSize: 14, color: p.textMuted)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: p.accent,
                        inactiveTrackColor: p.accent.withValues(alpha: 0.18),
                        thumbColor: p.accent,
                        overlayColor: p.accent.withValues(alpha: 0.12),
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: settings.fontSize,
                        min: 15,
                        max: 24,
                        divisions: 9,
                        onChanged: (v) => notifier.setFontSize(v),
                      ),
                    ),
                  ),
                  Text('A',
                      style: GoogleFonts.literata(fontSize: 22, color: p.text)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══ Line spacing ═══
            _SectionLabel(label: 'Line Spacing', color: p.textMuted),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  _SegOption(
                    label: 'Compact',
                    icon: Icons.density_small_rounded,
                    selected: settings.lineSpacing == LineSpacingMode.compact,
                    accent: p.accent,
                    textColor: p.text,
                    onTap: () => notifier.setLineSpacing(LineSpacingMode.compact),
                  ),
                  _SegOption(
                    label: 'Comfortable',
                    icon: Icons.density_medium_rounded,
                    selected:
                        settings.lineSpacing == LineSpacingMode.comfortable,
                    accent: p.accent,
                    textColor: p.text,
                    onTap: () =>
                        notifier.setLineSpacing(LineSpacingMode.comfortable),
                  ),
                  _SegOption(
                    label: 'Relaxed',
                    icon: Icons.density_large_rounded,
                    selected: settings.lineSpacing == LineSpacingMode.relaxed,
                    accent: p.accent,
                    textColor: p.text,
                    onTap: () => notifier.setLineSpacing(LineSpacingMode.relaxed),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme swatch grid ──
class _ThemeGrid extends StatelessWidget {
  final ReaderTheme current;
  final Color accent;
  final Color labelColor;
  final ValueChanged<ReaderTheme> onPick;

  const _ThemeGrid({
    required this.current,
    required this.accent,
    required this.labelColor,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardW = (width - 40 - 20) / 3; // padding 20*2, two 10px gaps
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ReaderTheme.values.map((t) {
        final pal = kReaderPalettes[t]!;
        final selected = t == current;
        return GestureDetector(
          onTap: () => onPick(t),
          child: SizedBox(
            width: cardW,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 64,
                  decoration: BoxDecoration(
                    color: pal.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? accent : pal.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          height: 5,
                          width: cardW * 0.34,
                          decoration: BoxDecoration(
                              color: pal.accent,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 6),
                      Container(
                          height: 4,
                          width: cardW * 0.6,
                          decoration: BoxDecoration(
                              color: pal.text.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 4),
                      Container(
                          height: 4,
                          width: cardW * 0.46,
                          decoration: BoxDecoration(
                              color: pal.textMuted.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(pal.label,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? accent
                            : labelColor.withValues(alpha: 0.7))),
              ],
            ),
          ),
        );
      }).toList(),
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
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: color.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _SegOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final Color textColor;
  final VoidCallback onTap;

  const _SegOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: accent.withValues(alpha: 0.4)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? accent : textColor.withValues(alpha: 0.4)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// LANGUAGE — English ⇆ Hinglish segmented control (shared by the settings
// sheet and the home quick-picker), plus the standalone quick sheet.
// ════════════════════════════════════════════════════════════════════════

class LanguageSegment extends ConsumerWidget {
  final ReaderPalette palette;
  const LanguageSegment({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(readerLanguageProvider);
    final notifier = ref.read(readerLanguageProvider.notifier);
    final p = palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider, width: 0.5),
      ),
      child: Row(
        children: [
          _LangOption(
            label: 'English',
            sub: 'Original',
            selected: lang == ReaderLanguage.english,
            accent: p.accent,
            textColor: p.text,
            onTap: () => notifier.setLanguage(ReaderLanguage.english),
          ),
          _LangOption(
            label: 'Hinglish',
            sub: 'Roman Urdu',
            selected: lang == ReaderLanguage.hinglish,
            accent: p.accent,
            textColor: p.text,
            onTap: () => notifier.setLanguage(ReaderLanguage.hinglish),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final Color accent;
  final Color textColor;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: accent.withValues(alpha: 0.4)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? accent : textColor.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.nunitoSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? accent.withValues(alpha: 0.8)
                      : textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact language-only picker, opened from the library home header.
class ReaderLanguageQuickSheet extends ConsumerWidget {
  const ReaderLanguageQuickSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(readerSettingsProvider).palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.divider, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: p.textFaint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Reading Language',
              style: GoogleFonts.literata(
                  fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 4),
          Text('Applies across the whole book',
              style:
                  GoogleFonts.nunitoSans(fontSize: 12.5, color: p.textMuted)),
          const SizedBox(height: 20),
          LanguageSegment(palette: p),
        ],
      ),
    );
  }
}
