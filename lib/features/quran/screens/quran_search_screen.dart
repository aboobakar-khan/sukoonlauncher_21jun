import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../providers/quran_provider.dart';
import '../providers/quran_search_provider.dart';
import '../widgets/glass_search_bar.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'surah_reader_screen.dart';

class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  static final _verseRe = RegExp(r'^(\d{1,3})\s*:\s*(\d{1,3})$');

  @override
  void initState() {
    super.initState();
    // Focus after the Hero/fade transition settles for a smooth keyboard rise.
    Future.delayed(const Duration(milliseconds: 340), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSurah(Surah surah, {int ayah = 1, required String recordQuery}) {
    ref.read(recentSearchesProvider.notifier).add(recordQuery);
    ref.read(recentReadsProvider.notifier).add(surah.id, ayah);
    ref.read(selectedSurahProvider.notifier).state = surah;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(surah: surah, initialAyah: ayah),
      ),
    );
  }

  List<Surah> _surahMatches(List<Surah> all, String q) {
    if (q.isEmpty) return const [];
    final lower = q.toLowerCase();
    return all
        .where((s) =>
            s.transliteration.toLowerCase().contains(lower) ||
            s.meaning.toLowerCase().contains(lower) ||
            s.name.contains(q) ||
            s.id.toString() == q)
        .take(20)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final surahsAsync = ref.watch(surahsProvider);
    final recents = ref.watch(recentSearchesProvider);

    final all = surahsAsync.valueOrNull ?? const <Surah>[];
    final verseMatch = _verseRe.firstMatch(_query.trim());
    Surah? verseSurah;
    int? verseAyah;
    if (verseMatch != null) {
      final sid = int.parse(verseMatch.group(1)!);
      final ay = int.parse(verseMatch.group(2)!);
      final found = all.where((s) => s.id == sid);
      if (found.isNotEmpty && ay >= 1 && ay <= found.first.totalVerses) {
        verseSurah = found.first;
        verseAyah = ay;
      }
    }
    final surahResults = _surahMatches(all, _query.trim());

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                  Text('Search',
                      style: GoogleFonts.notoSerif(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: tc.text)),
                ],
              ),
            ),

            // ── Glass search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: GlassSearchBar(
                tc: tc,
                editable: true,
                focused: true,
                controller: _controller,
                focusNode: _focus,
                showClear: _query.isNotEmpty,
                onClear: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  if (verseSurah != null) {
                    _openSurah(verseSurah,
                        ayah: verseAyah!, recordQuery: v.trim());
                  } else if (surahResults.isNotEmpty) {
                    _openSurah(surahResults.first, recordQuery: v.trim());
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Try chapter name (Al-Kahf) or chapter:verse (2:188)',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: tc.textSecondary.withValues(alpha: 0.55)),
                ),
              ),
            ),

            Expanded(
              child: _query.trim().isEmpty
                  ? _buildRecents(tc, recents, all)
                  : _buildResults(tc, surahResults, verseSurah, verseAyah),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent searches ──
  Widget _buildRecents(
      IslamicThemeColors tc, List<String> recents, List<Surah> all) {
    if (recents.isEmpty) {
      return Center(
        child: Text('Search the Quran by name or verse',
            style: GoogleFonts.inter(
                color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 14)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent searches',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: tc.text)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
              child: Text('Clear',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tc.green)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final q in recents) _recentRow(tc, q),
      ],
    );
  }

  Widget _recentRow(IslamicThemeColors tc, String q) {
    final isVerse = _verseRe.hasMatch(q.trim());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _controller.text = q;
        _controller.selection =
            TextSelection.collapsed(offset: q.length);
        setState(() => _query = q);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: tc.border.withValues(alpha: 0.6), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(isVerse ? Icons.menu_book_rounded : Icons.history_rounded,
                size: 18, color: tc.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: tc.text.withValues(alpha: 0.9))),
                  const SizedBox(height: 1),
                  Text(isVerse ? 'Verse' : 'Chapter name',
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: tc.textSecondary.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.north_west_rounded,
                size: 16, color: tc.textSecondary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // ── Results ──
  Widget _buildResults(IslamicThemeColors tc, List<Surah> surahs,
      Surah? verseSurah, int? verseAyah) {
    if (surahs.isEmpty && verseSurah == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded,
              size: 36, color: tc.textSecondary.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text('No results',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: tc.textSecondary.withValues(alpha: 0.5))),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (verseSurah != null)
          _verseResult(tc, verseSurah, verseAyah!),
        for (final s in surahs) _surahResult(tc, s),
      ],
    );
  }

  Widget _verseResult(IslamicThemeColors tc, Surah s, int ayah) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openSurah(s, ayah: ayah, recordQuery: '${s.id}:$ayah'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tc.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.green.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 20, color: tc.green.withValues(alpha: 0.85)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go to ${s.id}:$ayah',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tc.green)),
                  const SizedBox(height: 2),
                  Text('${s.transliteration} · verse $ayah',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: tc.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: tc.green.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _surahResult(IslamicThemeColors tc, Surah s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openSurah(s, recordQuery: s.transliteration),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text('${s.id}',
                  style: GoogleFonts.inter(
                      color: tc.green.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.transliteration,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tc.text.withValues(alpha: 0.9))),
                  const SizedBox(height: 1),
                  Text(
                      s.meaning.isNotEmpty
                          ? s.meaning
                          : (s.type == 'meccan' ? 'Meccan' : 'Medinan'),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: tc.textSecondary.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(s.name,
                style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20,
                    color: tc.text.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }
}
