import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_provider.dart';
import '../providers/quran_settings_provider.dart';
import '../services/alquran_api_service.dart';
import '../../../providers/arabic_font_provider.dart';
import '../../../providers/tafseer_edition_provider.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';

/// Quran settings screen — language, reciter, translation toggle, offline downloads
class QuranSettingsScreen extends ConsumerWidget {
  const QuranSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(quranSettingsProvider);
    final tc = ref.watch(islamicThemeColorsProvider);

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(context, tc),

              // ── Settings List ──
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // ── TRANSLATION Section ──
                    _buildSectionLabel('TRANSLATION', tc),
                    const SizedBox(height: 10),

                    // Translation toggle
                    _buildToggleTile(
                      tc: tc,
                      icon: Icons.translate_rounded,
                      title: 'Show Translation',
                      subtitle: 'Display verse translation below Arabic',
                      value: settings.showTranslation,
                      onChanged: (val) {
                        ref.read(quranSettingsProvider.notifier).setShowTranslation(val);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Language selector
                    _LanguageSelectorTile(settings: settings, tc: tc),
                    const SizedBox(height: 28),

                    // ── AUDIO Section ──
                    _buildSectionLabel('AUDIO RECITATION', tc),
                    const SizedBox(height: 10),
                    _ReciterSelectorTile(settings: settings, tc: tc),
                    const SizedBox(height: 28),

                    // ── READING Section ──
                    _buildSectionLabel('READING', tc),
                    const SizedBox(height: 10),

                    // Arabic Font selector
                    _ArabicFontSelectorTile(tc: tc),
                    const SizedBox(height: 8),

                    // Tafseer Edition selector
                    _TafseerEditionSelectorTile(tc: tc),
                    const SizedBox(height: 28),

                    // ── OFFLINE Section ──
                    _buildSectionLabel('OFFLINE DOWNLOADS', tc),
                    const SizedBox(height: 10),
                    _OfflineDownloadSection(tc: tc),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, IslamicThemeColors tc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      color: tc.background,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: tc.text, size: 22),
          ),
          const SizedBox(width: 4),
          Icon(Icons.settings_rounded, color: tc.accent.withValues(alpha: 0.6), size: 20),
          const SizedBox(width: 8),
          Text(
            'Quran Settings',
            style: TextStyle(
              color: tc.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IslamicThemeColors tc) {
    return Text(
      label,
      style: TextStyle(
        color: tc.textSecondary.withValues(alpha: 0.45),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildToggleTile({
    required IslamicThemeColors tc,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tc.green.withValues(alpha: 0.6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: tc.text.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.45),
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tc.green,
            activeTrackColor: tc.green.withValues(alpha: 0.3),
            inactiveThumbColor: tc.textSecondary.withValues(alpha: 0.3),
            inactiveTrackColor: tc.surface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Language Selector Tile
// ─────────────────────────────────────────────

class _LanguageSelectorTile extends ConsumerWidget {
  final QuranSettings settings;
  final IslamicThemeColors tc;

  const _LanguageSelectorTile({required this.settings, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showLanguagePicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.language_rounded,
                  color: tc.accent.withValues(alpha: 0.6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Translation Language',
                      style: TextStyle(
                        color: tc.text.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 2),
                  Text(settings.translationName,
                      style: TextStyle(
                        color: tc.green.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.textSecondary.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final tc = ref.read(islamicThemeColorsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (ctx, innerRef, _) {
            final settings = innerRef.watch(quranSettingsProvider);
            final langsValue = innerRef.watch(quranLanguagesProvider);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: tc.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.language_rounded,
                          color: tc.accent.withValues(alpha: 0.6), size: 20),
                      const SizedBox(width: 8),
                      Text('Translation Language',
                          style: TextStyle(
                            color: tc.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Select the language for Quran translation',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      )),
                  const SizedBox(height: 16),
                  Expanded(
                    child: langsValue.when(
                      data: (languages) {
                        if (languages.isEmpty) {
                          return Center(
                            child: Text('No languages available',
                                style: TextStyle(
                                    color: tc.textSecondary.withValues(alpha: 0.5))),
                          );
                        }
                        return ListView.builder(
                          controller: scrollCtrl,
                          itemCount: languages.length,
                          itemBuilder: (ctx, i) {
                            final lang = languages[i];
                            final isSelected =
                                settings.translationLang == lang.code;
                            return GestureDetector(
                              onTap: () {
                                innerRef
                                    .read(quranSettingsProvider.notifier)
                                    .setTranslationLanguage(
                                        lang.code, lang.name);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? tc.green.withValues(alpha: 0.08)
                                      : tc.surface.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? tc.green.withValues(alpha: 0.3)
                                        : tc.surface.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(lang.name,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? tc.text
                                                    : tc.textSecondary,
                                                fontSize: 15,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              )),
                                          if (lang.nativeName.isNotEmpty &&
                                              lang.nativeName != lang.name)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2),
                                              child: Text(
                                                lang.nativeName,
                                                style: TextStyle(
                                                  color: tc.textSecondary
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 13,
                                                ),
                                                textDirection: lang.isRtl
                                                    ? TextDirection.rtl
                                                    : TextDirection.ltr,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (lang.isRtl)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: Text('RTL',
                                            style: TextStyle(
                                              color: tc.accent.withValues(alpha: 0.4),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded,
                                          color: tc.green.withValues(alpha: 0.7),
                                          size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => Center(
                        child: CircularProgressIndicator(
                            color: tc.green.withValues(alpha: 0.5)),
                      ),
                      error: (_, _) => Center(
                        child: Text('Could not load languages',
                            style: TextStyle(color: tc.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reciter Selector Tile
// ─────────────────────────────────────────────

class _ReciterSelectorTile extends ConsumerWidget {
  final QuranSettings settings;
  final IslamicThemeColors tc;

  const _ReciterSelectorTile({required this.settings, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showReciterPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.headphones_rounded,
                  color: tc.green.withValues(alpha: 0.6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audio Reciter',
                      style: TextStyle(
                        color: tc.text.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 2),
                  Text(settings.selectedReciterName,
                      style: TextStyle(
                        color: tc.green.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.textSecondary.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  void _showReciterPicker(BuildContext context, WidgetRef ref) {
    final tc = ref.read(islamicThemeColorsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, innerRef, _) {
          final settings = innerRef.watch(quranSettingsProvider);
          final recitersAsync = innerRef.watch(availableRecitersProvider);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: tc.textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.headphones_rounded,
                        color: tc.green.withValues(alpha: 0.6), size: 20),
                    const SizedBox(width: 8),
                    Text('Audio Reciter',
                        style: TextStyle(
                          color: tc.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Choose your preferred Quran reciter',
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.5),
                      fontSize: 13,
                    )),
                const SizedBox(height: 16),
                recitersAsync.when(
                  data: (reciters) {
                    return Column(
                      children: reciters.map((reciter) {
                        final isSelected =
                            settings.selectedReciterKey == reciter.key;
                        return GestureDetector(
                          onTap: () {
                            innerRef
                                .read(quranSettingsProvider.notifier)
                                .setReciter(reciter.key, reciter.name);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tc.green.withValues(alpha: 0.08)
                                  : tc.surface.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? tc.green.withValues(alpha: 0.3)
                                    : tc.surface.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? tc.green
                                      : tc.textSecondary.withValues(alpha: 0.3),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(reciter.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? tc.text
                                            : tc.textSecondary,
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: tc.green.withValues(alpha: 0.5)),
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not load reciters',
                        style: TextStyle(color: tc.textSecondary)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Arabic Font Selector Tile
// ─────────────────────────────────────────────

class _ArabicFontSelectorTile extends ConsumerWidget {
  final IslamicThemeColors tc;

  const _ArabicFontSelectorTile({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabicFont = ref.watch(arabicFontProvider);

    return GestureDetector(
      onTap: () => _showFontPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.text_fields_rounded,
                  color: tc.accent.withValues(alpha: 0.6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arabic Font',
                      style: TextStyle(
                        color: tc.text.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 2),
                  Text(arabicFont.name,
                      style: TextStyle(
                        color: tc.green.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.textSecondary.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  void _showFontPicker(BuildContext context, WidgetRef ref) {
    final tc = ref.read(islamicThemeColorsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (ctx, innerRef, _) {
            final arabicFont = innerRef.watch(arabicFontProvider);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: tc.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.text_fields_rounded,
                          color: tc.accent.withValues(alpha: 0.6), size: 20),
                      const SizedBox(width: 8),
                      Text('Arabic Font',
                          style: TextStyle(
                            color: tc.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Choose your preferred Quran Arabic font',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      )),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: ArabicFonts.all.length,
                      itemBuilder: (ctx, i) {
                        final font = ArabicFonts.all[i];
                        final isSelected = arabicFont.name == font.name;
                        return GestureDetector(
                          onTap: () {
                            innerRef.read(arabicFontProvider.notifier).setFont(font);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tc.accent.withValues(alpha: 0.1)
                                  : tc.surface.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? tc.accent.withValues(alpha: 0.4)
                                    : tc.surface.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(font.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? tc.text
                                                : tc.textSecondary,
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(
                                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                        style: TextStyle(
                                          color: tc.text.withValues(alpha: 0.6),
                                          fontSize: 18,
                                          fontFamily: font.fontFamily,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: tc.green.withValues(alpha: 0.7),
                                      size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tafseer Edition Selector Tile
// ─────────────────────────────────────────────

class _TafseerEditionSelectorTile extends ConsumerWidget {
  final IslamicThemeColors tc;

  const _TafseerEditionSelectorTile({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEdition = ref.watch(selectedTafseerEditionProvider);

    return GestureDetector(
      onTap: () => _showEditionPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_rounded,
                  color: tc.green.withValues(alpha: 0.6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tafseer Edition',
                      style: TextStyle(
                        color: tc.text.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 2),
                  Text(selectedEdition.name,
                      style: TextStyle(
                        color: tc.green.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.textSecondary.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  void _showEditionPicker(BuildContext context, WidgetRef ref) {
    final tc = ref.read(islamicThemeColorsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (ctx, innerRef, _) {
            final selectedEdition = innerRef.watch(selectedTafseerEditionProvider);
            final editionsAsync = innerRef.watch(tafseerEditionsProvider);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: tc.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          color: tc.green.withValues(alpha: 0.6), size: 20),
                      const SizedBox(width: 8),
                      Text('Tafseer Edition',
                          style: TextStyle(
                            color: tc.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Choose your preferred tafseer commentary',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      )),
                  const SizedBox(height: 16),
                  Expanded(
                    child: editionsAsync.when(
                      data: (editions) {
                        final sorted = [...editions];
                        sorted.sort((a, b) {
                          if (a.language.toLowerCase() == 'english' &&
                              b.language.toLowerCase() != 'english') {
                            return -1;
                          }
                          if (a.language.toLowerCase() != 'english' &&
                              b.language.toLowerCase() == 'english') {
                            return 1;
                          }
                          return a.name.compareTo(b.name);
                        });
                        return ListView.builder(
                          controller: scrollCtrl,
                          itemCount: sorted.length,
                          itemBuilder: (ctx, i) {
                            final edition = sorted[i];
                            final isSelected =
                                selectedEdition.slug == edition.slug;
                            return _TafseerEditionTile(
                              tc: tc,
                              edition: edition,
                              isSelected: isSelected,
                              onSelect: () {
                                innerRef
                                    .read(selectedTafseerEditionProvider
                                        .notifier)
                                    .setEdition(edition);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      },
                      loading: () => Center(
                        child: CircularProgressIndicator(
                            color: tc.green.withValues(alpha: 0.5)),
                      ),
                      error: (_, _) => Center(
                        child: Text('Could not load editions',
                            style: TextStyle(color: tc.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TafseerEditionTile extends ConsumerStatefulWidget {
  final IslamicThemeColors tc;
  final TafseerEdition edition;
  final bool isSelected;
  final VoidCallback onSelect;

  const _TafseerEditionTile({
    required this.tc,
    required this.edition,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  ConsumerState<_TafseerEditionTile> createState() =>
      _TafseerEditionTileState();
}

class _TafseerEditionTileState extends ConsumerState<_TafseerEditionTile> {
  bool _isDownloading = false;
  bool? _isDownloaded;
  int _downloadedCount = 0;

  @override
  void initState() {
    super.initState();
    _checkDownload();
  }

  Future<void> _checkDownload() async {
    final service = ref.read(tafseerServiceProvider);
    final isFullDownloaded = await service.isFullTafseerDownloaded(
      edition: widget.edition.slug,
    );
    final count = await service.getDownloadedSurahCount(
      edition: widget.edition.slug,
    );
    if (mounted) {
      setState(() {
        _isDownloaded = isFullDownloaded;
        _downloadedCount = count;
      });
    }
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    final service = ref.read(tafseerServiceProvider);
    final success = await service.downloadFullTafseer(
      edition: widget.edition.slug,
      onProgress: (completed, total) {
        if (mounted) setState(() => _downloadedCount = completed);
      },
    );
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${widget.edition.name} – Tafseer downloaded!'
              : 'Some surahs failed. Tap to retry.'),
          backgroundColor: success ? const Color(0xFFA67B5B) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final downloaded = _isDownloaded ?? false;

    return GestureDetector(
      onTap: widget.onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? tc.green.withValues(alpha: 0.08)
              : tc.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected
                ? tc.green.withValues(alpha: 0.3)
                : tc.surface.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.edition.name,
                    style: TextStyle(
                      color: widget.isSelected ? tc.text : tc.textSecondary,
                      fontSize: 14,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.edition.authorName} • ${widget.edition.language}',
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download / downloaded indicator
            if (_isDownloading)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_downloadedCount/114',
                    style: TextStyle(
                        color: tc.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: tc.accent,
                    ),
                  ),
                ],
              )
            else if (downloaded)
              Icon(Icons.cloud_done_rounded,
                  color: tc.green.withValues(alpha: 0.7), size: 20)
            else
              GestureDetector(
                onTap: _download,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tc.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_download_outlined,
                          color: tc.accent, size: 16),
                      if (_downloadedCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$_downloadedCount/114',
                          style: TextStyle(
                              color: tc.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (widget.isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded,
                  color: tc.green.withValues(alpha: 0.7), size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Offline Download Section
// ─────────────────────────────────────────────

class _OfflineDownloadSection extends ConsumerWidget {
  final IslamicThemeColors tc;

  const _OfflineDownloadSection({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(quranSettingsProvider);
    final downloadState = ref.watch(translationDownloadProvider);
    final langsAsync = ref.watch(quranLanguagesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tc.accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: tc.accent.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Download translations to read the Quran offline in any language.',
                  style: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Download progress (if active)
        if (downloadState.isDownloading) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.green.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tc.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Downloading... ${downloadState.completed}/${downloadState.total}',
                        style: TextStyle(
                          color: tc.text.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: downloadState.progress,
                    backgroundColor: tc.surface.withValues(alpha: 0.5),
                    color: tc.green,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Language download tiles
        langsAsync.when(
          data: (languages) {
            return Column(
              children: languages.map((lang) {
                final count =
                    downloadState.downloadedCounts[lang.code] ?? 0;
                final isFullyDownloaded = count >= 114;
                final isCurrentLang =
                    settings.translationLang == lang.code;

                return _DownloadLanguageTile(
                  tc: tc,
                  language: lang,
                  downloadedCount: count,
                  isFullyDownloaded: isFullyDownloaded,
                  isCurrentLang: isCurrentLang,
                  isDownloading: downloadState.isDownloading,
                );
              }).toList(),
            );
          },
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: tc.green.withValues(alpha: 0.5)),
            ),
          ),
          error: (_, _) => Text('Could not load languages',
              style: TextStyle(color: tc.textSecondary)),
        ),
      ],
    );
  }
}

class _DownloadLanguageTile extends ConsumerWidget {
  final IslamicThemeColors tc;
  final QuranLanguage language;
  final int downloadedCount;
  final bool isFullyDownloaded;
  final bool isCurrentLang;
  final bool isDownloading;

  const _DownloadLanguageTile({
    required this.tc,
    required this.language,
    required this.downloadedCount,
    required this.isFullyDownloaded,
    required this.isCurrentLang,
    required this.isDownloading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentLang
            ? tc.green.withValues(alpha: 0.05)
            : tc.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentLang
              ? tc.green.withValues(alpha: 0.2)
              : tc.surface.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(language.name,
                        style: TextStyle(
                          color: tc.text.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                    if (isCurrentLang) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tc.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Active',
                            style: TextStyle(
                              color: tc.green.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ],
                ),
                if (language.nativeName.isNotEmpty &&
                    language.nativeName != language.name)
                  Text(language.nativeName,
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                      textDirection:
                          language.isRtl ? TextDirection.rtl : TextDirection.ltr),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isFullyDownloaded)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded,
                    color: tc.green.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(context, ref),
                  child: Icon(Icons.delete_outline_rounded,
                      color: tc.textSecondary.withValues(alpha: 0.3), size: 18),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: isDownloading
                  ? null
                  : () {
                      ref
                          .read(translationDownloadProvider.notifier)
                          .downloadTranslation(language.code);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDownloading
                      ? tc.surface.withValues(alpha: 0.3)
                      : tc.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_download_outlined,
                        color: isDownloading
                            ? tc.textSecondary.withValues(alpha: 0.3)
                            : tc.accent,
                        size: 16),
                    if (downloadedCount > 0) ...[
                      const SizedBox(width: 4),
                      Text('$downloadedCount/114',
                          style: TextStyle(
                            color: tc.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tc.border),
        ),
        title: Text('Delete ${language.name} Translation?',
            style: TextStyle(color: tc.text, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'This will remove the offline translation. You can re-download it later.',
          style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(translationDownloadProvider.notifier)
                  .deleteTranslation(language.code);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: TextStyle(color: Colors.red.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }
}
