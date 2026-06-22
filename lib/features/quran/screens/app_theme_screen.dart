import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  APP THEME — Master Theme palette picker + Appearance Mode.
//  The whole screen recolours live as you select, since it reads
//  islamicThemeColorsProvider (master palette × light/dark).
// ═══════════════════════════════════════════════════════════════════════════

class AppThemeScreen extends ConsumerWidget {
  const AppThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final selectedTheme = ref.watch(masterThemeProvider);
    final appearance = ref.watch(appearanceModeProvider);

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 24, color: tc.text.withValues(alpha: 0.8)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('App Theme',
                        style: GoogleFonts.notoSerif(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: tc.text,
                          letterSpacing: 0.2,
                        )),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
                  children: [
                    // ── MASTER THEME ──
                    _SectionCard(
                      tc: tc,
                      title: 'Master Theme',
                      subtitle: 'Pick the visual personality',
                      children: [
                        for (final theme in MasterTheme.values)
                          _ThemeRow(
                            tc: tc,
                            def: theme.def,
                            selected: theme == selectedTheme,
                            onTap: () => ref
                                .read(masterThemeProvider.notifier)
                                .select(theme),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── APPEARANCE MODE ──
                    _SectionCard(
                      tc: tc,
                      title: 'Appearance Mode',
                      subtitle: 'Choose how light/dark should apply',
                      children: [
                        for (final mode in AppearanceMode.values)
                          _AppearanceRow(
                            tc: tc,
                            mode: mode,
                            selected: mode == appearance,
                            onTap: () {
                              ref
                                  .read(appearanceModeProvider.notifier)
                                  .set(mode);
                              ref
                                  .read(islamicThemeProvider.notifier)
                                  .setMode(resolveAppearance(mode));
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── A titled grouping panel ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IslamicThemeColors tc;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _SectionCard({
    required this.tc,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tc.text,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: tc.textSecondary.withValues(alpha: 0.8))),
          const SizedBox(height: 14),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ── A selectable theme row: swatches · name + desc · radio ────────────────
class _ThemeRow extends StatelessWidget {
  final IslamicThemeColors tc;
  final MasterThemeDef def;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeRow({
    required this.tc,
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? tc.green.withValues(alpha: 0.10)
              : tc.background.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tc.green.withValues(alpha: 0.40) : tc.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            // 3 overlapping swatches
            SizedBox(
              width: 44,
              height: 14,
              child: Stack(
                children: [
                  for (int i = 0; i < def.dots.length; i++)
                    Positioned(
                      left: i * 15.0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: def.dots[i],
                          border: Border.all(
                              color: tc.surface.withValues(alpha: 0.6),
                              width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.label,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: selected ? tc.green : tc.text,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(def.description,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: tc.textSecondary.withValues(alpha: 0.85),
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Radio(selected: selected, color: tc.green, border: tc.border),
          ],
        ),
      ),
    );
  }
}

// ── A selectable appearance row: icon · name + sub · radio ────────────────
class _AppearanceRow extends StatelessWidget {
  final IslamicThemeColors tc;
  final AppearanceMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _AppearanceRow({
    required this.tc,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => switch (mode) {
        AppearanceMode.system => Icons.contrast_rounded,
        AppearanceMode.light => Icons.wb_sunny_rounded,
        AppearanceMode.dark => Icons.nightlight_round,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? tc.green.withValues(alpha: 0.10)
              : tc.background.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tc.green.withValues(alpha: 0.40) : tc.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (selected ? tc.green : tc.textSecondary)
                    .withValues(alpha: 0.12),
              ),
              child: Icon(_icon,
                  size: 17,
                  color: selected
                      ? tc.green
                      : tc.textSecondary.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: selected ? tc.green : tc.text,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(mode.subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: tc.textSecondary.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Radio(selected: selected, color: tc.green, border: tc.border),
          ],
        ),
      ),
    );
  }
}

// ── Filled-when-selected radio ────────────────────────────────────────────
class _Radio extends StatelessWidget {
  final bool selected;
  final Color color;
  final Color border;
  const _Radio(
      {required this.selected, required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : border,
          width: 1.6,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            )
          : null,
    );
  }
}
