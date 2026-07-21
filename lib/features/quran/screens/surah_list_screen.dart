import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/quran_provider.dart';
import '../providers/quran_search_provider.dart';
import '../models/surah.dart';
import 'surah_reader_screen.dart';
import 'quran_settings_screen.dart';
import 'quran_search_screen.dart';
import '../widgets/glass_search_bar.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';

/// Curated "Frequently Read": (surahId, label, ayah).
const _frequentlyRead = <(int, String, int)>[
  (67, 'Al-Mulk', 1),
  (18, 'Al-Kahf', 1),
  (36, 'Ya-Sin', 1),
  (2, 'Ayatul Kursi', 255),
  (55, 'Ar-Rahman', 1),
  (56, 'Al-Waqiah', 1),
];

class SurahListScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SurahListScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  bool _isTransitioning = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    });
  }

  void _navigateToSurah(Surah surah, {int? ayah}) {
    ref.read(recentReadsProvider.notifier).add(surah.id, ayah ?? 1);
    ref.read(selectedSurahProvider.notifier).state = surah;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(surah: surah, initialAyah: ayah),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(context, SearchFadeRoute(page: const QuranSearchScreen()));
  }

  Surah? _byId(List<Surah> all, int id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahsProvider);
    final tc = ref.watch(islamicThemeColorsProvider);
    final recentReads = ref.watch(recentReadsProvider);

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          bottom: false,
          child: surahsAsync.when(
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: tc.green.withValues(alpha: 0.5), strokeWidth: 2)),
            error: (e, _) => Center(
                child: Text('Error loading Quran',
                    style: TextStyle(color: tc.textSecondary))),
            data: (surahs) {
              return Stack(
                children: [
                  // ── Scrolling content (flows under the glass bar) ──
                  if (!_isTransitioning)
                    ListView(
                      padding: const EdgeInsets.fromLTRB(0, 132, 0, 28),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildReadHistory(tc, surahs, recentReads),
                        _buildFrequentlyRead(tc, surahs),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                          child: Text('All Surahs',
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: tc.text,
                                  letterSpacing: -0.3)),
                        ),
                        for (int i = 0; i < surahs.length; i++)
                          _surahRow(tc, surahs[i], i == surahs.length - 1),
                      ],
                    ),

                  // ── Pinned header + glassmorphic search bar ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildPinnedHeader(tc),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Pinned top: title row + glass search bar ──
  Widget _buildPinnedHeader(IslamicThemeColors tc) {
    return Container(
      color: tc.background,
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
            child: Row(
              children: [
                Text('Al-Quran',
                    style: GoogleFonts.notoSerif(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tc.text)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QuranSettingsScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.tune_rounded,
                        size: 22,
                        color: tc.textSecondary.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassSearchBar(tc: tc, onTap: _openSearch),
          ),
        ],
      ),
    );
  }

  // ── Read History (recent reads) ──
  Widget _buildReadHistory(
      IslamicThemeColors tc, List<Surah> all, List<String> recents) {
    final items = <(Surah, int)>[];
    for (final tok in recents) {
      final parts = tok.split(':');
      final s = _byId(all, int.tryParse(parts.first) ?? -1);
      final ayah = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      if (s != null) items.add((s, ayah));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Text('Read History',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tc.text,
                  letterSpacing: -0.3)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (s, ayah) = items[i];
              return _chip(
                tc,
                '${s.transliteration} ${s.id}:$ayah',
                () => _navigateToSurah(s, ayah: ayah),
                accent: i == 0,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Frequently Read (curated) ──
  Widget _buildFrequentlyRead(IslamicThemeColors tc, List<Surah> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Text('Frequently Read',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tc.text,
                  letterSpacing: -0.3)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _frequentlyRead.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (id, label, ayah) = _frequentlyRead[i];
              return _chip(tc, label, () {
                final s = _byId(all, id);
                if (s != null) _navigateToSurah(s, ayah: ayah);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(IslamicThemeColors tc, String label, VoidCallback onTap,
      {bool accent = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: accent
              ? tc.green.withValues(alpha: 0.10)
              : tc.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: accent
              ? Border.all(color: tc.green.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accent ? tc.green : tc.text.withValues(alpha: 0.8))),
      ),
    );
  }

  // ── Refined surah row ──
  Widget _surahRow(IslamicThemeColors tc, Surah s, bool isLast) {
    final meccan = s.type == 'meccan';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToSurah(s),
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: tc.border.withValues(alpha: 0.5), width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            // Number medallion
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: tc.green.withValues(alpha: 0.25), width: 1),
              ),
              child: Text('${s.id}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tc.green.withValues(alpha: 0.8))),
            ),
            const SizedBox(width: 16),
            // Name + meaning + makki/madani
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.transliteration,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: tc.text,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.meaning.isNotEmpty
                              ? s.meaning
                              : (meccan ? 'Meccan' : 'Medinan'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: tc.textSecondary.withValues(alpha: 0.65)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        meccan
                            ? Icons.brightness_1_rounded
                            : Icons.mosque_rounded,
                        size: meccan ? 8 : 13,
                        color: meccan
                            ? tc.accent.withValues(alpha: 0.7)
                            : tc.green.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Arabic name
            Text(s.name,
                style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 24,
                    color: tc.arabicText.withValues(alpha: 0.85)),
                textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }
}
