import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surah.dart';
import '../providers/quran_provider.dart';
import '../providers/quran_settings_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../widgets/tafseer_bottom_sheet.dart';
import '../services/word_by_word_service.dart';
import '../providers/quran_search_provider.dart';
import '../../../providers/arabic_font_provider.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';
import 'quran_settings_screen.dart';

class SurahReaderScreen extends ConsumerStatefulWidget {
  final Surah surah;
  final int? initialAyah;

  const SurahReaderScreen({
    super.key, 
    required this.surah,
    this.initialAyah,
  });

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PageController _focusController;

  // For tracking visible verse
  int _currentVisibleAyah = 1;
  bool _hasScrolledToInitial = false;
  
  // Reading progress (0.0 to 1.0)
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _currentVisibleAyah = widget.initialAyah ?? 1;
    _focusController =
        PageController(initialPage: (widget.initialAyah ?? 1) - 1);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Debounce scroll events to avoid excessive saves
    // We'll save progress when a new ayah comes into view
  }

  void _saveReadingProgress(int ayahNumber) {
    if (ayahNumber != _currentVisibleAyah) {
      _currentVisibleAyah = ayahNumber;
      ref.read(readingProgressProvider.notifier).saveProgress(
        surahId: widget.surah.id,
        surahName: widget.surah.name,
        surahTransliteration: widget.surah.transliteration,
        ayahNumber: ayahNumber,
        totalVerses: widget.surah.totalVerses,
      );
    }
  }

  void _scrollToAyah(int ayahNumber, int totalVerses) {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;

    // Calculate approximate scroll position
    // Each verse card is roughly 200-300 pixels tall
    const estimatedCardHeight = 280.0;
    final scrollPosition = (ayahNumber - 1) * estimatedCardHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetPosition = scrollPosition.clamp(0.0, maxScroll);
        
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final versesAsync = ref.watch(versesProvider(widget.surah.id));
    final arabicFont = ref.watch(arabicFontProvider);
    final tc = ref.watch(islamicThemeColorsProvider);
    final settings = ref.watch(quranSettingsProvider);
    final audioState = ref.watch(quranAudioProvider);
    final wbw = ref.watch(wordByWordServiceProvider).valueOrNull;
    final mode = ref.watch(quranReaderModeProvider);

    return SwipeBackWrapper(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: tc.background,
        statusBarIconBrightness: tc.statusBarBrightness,
        systemNavigationBarColor: tc.background,
        systemNavigationBarIconBrightness: tc.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: versesAsync.when(
            data: (verses) {
              if (verses.isEmpty) {
                return Center(
                  child: Text('No verses available', style: TextStyle(color: tc.textSecondary)),
                );
              }
              if (widget.initialAyah != null && !_hasScrolledToInitial) {
                _scrollToAyah(widget.initialAyah!, verses.length);
              }
              return Column(
                children: [
                  // ── Top Bar ──
                  _buildTopBar(tc, mode, verses.length),
                  // ── Audio Player Bar ──
                  _buildAudioBar(tc, settings, audioState),
                  // ── Sub-header ──
                  _buildSubHeader(tc),
                  // ── Reading mode switcher ──
                  _buildModeSwitcher(tc, mode),
                  // ── Progress bar ──
                  _buildProgressBar(tc),
                  // ── Verses (mode-specific body) ──
                  Expanded(
                    child: _buildBody(
                        verses, arabicFont, tc, settings, wbw, mode),
                  ),
                ],
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(color: tc.accent, strokeWidth: 2),
            ),
            error: (error, stack) => Center(
              child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    ),  // SwipeBackWrapper
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // MODE BODIES — Classic (list) · Focus (one ayah/page) · Mushaf (page)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildBody(List verses, dynamic arabicFont, IslamicThemeColors tc,
      QuranSettings settings, WordByWordService? wbw, String mode) {
    if (mode == 'focus') {
      return _buildFocusView(verses, arabicFont, tc, settings);
    }
    if (mode == 'mushaf') {
      return _buildMushafView(verses, arabicFont, tc);
    }
    return _buildClassicList(verses, arabicFont, tc, settings, wbw);
  }

  // ── Classic: scrolling word-by-word list ──
  Widget _buildClassicList(List verses, dynamic arabicFont,
      IslamicThemeColors tc, QuranSettings settings, WordByWordService? wbw) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.maxScrollExtent > 0) {
          final progress =
              notification.metrics.pixels / notification.metrics.maxScrollExtent;
          setState(() => _readingProgress = progress.clamp(0.0, 1.0));
          final visibleAyah = (progress * verses.length).ceil();
          final clampedAyah = visibleAyah.clamp(1, verses.length);
          _saveReadingProgress(progress >= 0.95 ? verses.length : clampedAyah);
        } else {
          _saveReadingProgress(verses.length);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        cacheExtent: 800,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: verses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildSurahBanner(tc);
          final verse = verses[index - 1];
          final isHighlighted =
              widget.initialAyah != null && verse.id == widget.initialAyah;
          final isLast = index == verses.length;
          return _buildVerseItem(verse, arabicFont, isHighlighted, isLast, tc,
              settings, wbw, 'classic');
        },
      ),
    );
  }

  // ── Focus: one ayah per page, swipe up/down ──
  Widget _buildFocusView(List verses, dynamic arabicFont,
      IslamicThemeColors tc, QuranSettings settings) {
    return PageView.builder(
      controller: _focusController,
      scrollDirection: Axis.vertical,
      itemCount: verses.length,
      onPageChanged: (index) {
        final ayah = index + 1;
        setState(() {
          _currentVisibleAyah = ayah;
          _readingProgress =
              verses.length > 1 ? index / (verses.length - 1) : 1.0;
        });
        _saveReadingProgress(ayah);
      },
      itemBuilder: (context, index) =>
          _buildFocusCard(verses[index], arabicFont, tc, settings),
    );
  }

  Widget _buildFocusCard(dynamic verse, dynamic arabicFont,
      IslamicThemeColors tc, QuranSettings settings) {
    final hasTranslation = verse.translation != null &&
        (verse.translation as String).isNotEmpty &&
        settings.showTranslation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tc.surface.withValues(alpha: 0.65)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('✦',
                        style: TextStyle(
                            color: tc.accent.withValues(alpha: 0.3),
                            fontSize: 13)),
                    const Spacer(),
                    _focusIcon(Icons.bookmark_border_rounded, tc,
                        () => _saveReadingProgress(verse.id)),
                    _focusIcon(
                        Icons.menu_book_rounded,
                        tc,
                        () => TafseerBottomSheet.show(context,
                            surahId: widget.surah.id,
                            ayahId: verse.id,
                            surahName: widget.surah.transliteration),
                        active: true),
                    _focusIcon(Icons.more_horiz_rounded, tc,
                        () => _showVerseMenu(verse)),
                    const Spacer(),
                    Text('✦',
                        style: TextStyle(
                            color: tc.accent.withValues(alpha: 0.3),
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('${widget.surah.transliteration}  •  ${widget.surah.id}:${verse.id}',
                    style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 26),
                Text(
                  verse.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: tc.arabicText,
                    fontSize: 30,
                    height: 1.95,
                    fontWeight: FontWeight.w400,
                    fontFamily: arabicFont.fontFamily,
                  ),
                ),
                const SizedBox(height: 20),
                _buildVerseDivider(tc),
                if (hasTranslation) ...[
                  const SizedBox(height: 20),
                  Text(
                    verse.translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: tc.text.withValues(alpha: 0.75),
                        fontSize: 16,
                        height: 1.7),
                  ),
                ],
                const SizedBox(height: 14),
                _buildVerseMarker(verse.id, tc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _focusIcon(IconData icon, IslamicThemeColors tc, VoidCallback onTap,
      {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? tc.green.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Icon(icon,
            size: 19,
            color: active
                ? tc.green
                : tc.textSecondary.withValues(alpha: 0.6)),
      ),
    );
  }

  void _showVerseMenu(dynamic verse) {
    final tc = ref.read(islamicThemeColorsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: tc.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: tc.text),
              title: Text('Copy verse', style: TextStyle(color: tc.text)),
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text:
                        '${verse.arabic}\n\n${verse.translation ?? ''}'.trim()));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: tc.text),
              title: Text('Tafseer', style: TextStyle(color: tc.text)),
              onTap: () {
                Navigator.pop(context);
                TafseerBottomSheet.show(context,
                    surahId: widget.surah.id,
                    ayahId: verse.id,
                    surahName: widget.surah.transliteration);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Mushaf: continuous justified page with inline verse markers ──
  Widget _buildMushafView(
      List verses, dynamic arabicFont, IslamicThemeColors tc) {
    final showBismillah = widget.surah.id != 1 && widget.surah.id != 9;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.maxScrollExtent > 0) {
          final progress = n.metrics.pixels / n.metrics.maxScrollExtent;
          setState(() => _readingProgress = progress.clamp(0.0, 1.0));
          final ayah = (progress * verses.length).ceil().clamp(1, verses.length);
          _saveReadingProgress(progress >= 0.95 ? verses.length : ayah);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 44),
        child: Column(
          children: [
            _buildMushafHeader(tc),
            if (showBismillah) ...[
              const SizedBox(height: 20),
              Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: tc.arabicText,
                    fontSize: 23,
                    height: 2.0,
                    fontFamily: arabicFont.fontFamily),
              ),
            ],
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  for (final v in verses) ...[
                    TextSpan(
                      text: '${v.arabic} ',
                      style: TextStyle(
                        color: tc.arabicText,
                        fontSize: 27,
                        height: 2.15,
                        fontWeight: FontWeight.w400,
                        fontFamily: arabicFont.fontFamily,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _mushafMarker(v.id, tc),
                    ),
                    const TextSpan(text: ' '),
                  ],
                ],
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 30),
            _buildVerseDivider(tc),
          ],
        ),
      ),
    );
  }

  Widget _buildMushafHeader(IslamicThemeColors tc) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tc.accent.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('❁',
              style: TextStyle(
                  color: tc.accent.withValues(alpha: 0.55), fontSize: 16)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              'سورة ${widget.surah.name}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tc.text,
                fontSize: 22,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text('❁',
              style: TextStyle(
                  color: tc.accent.withValues(alpha: 0.55), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _mushafMarker(int n, IslamicThemeColors tc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tc.green.withValues(alpha: 0.10),
        border: Border.all(color: tc.accent.withValues(alpha: 0.4), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _toArabicNumber(n),
        style: TextStyle(
            color: tc.accent.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  String _toArabicNumber(int n) {
    const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((d) => e[int.parse(d)]).join();
  }

  // ── Top Bar — centered pill with the live verse indicator ──
  Widget _buildTopBar(IslamicThemeColors tc, String mode, int verseCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      color: tc.background,
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_rounded, tc, () => Navigator.pop(context)),
          const SizedBox(width: 8),
          // Center pill — Arabic name + "Transliteration : currentVerse"
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showVerseJump(mode, verseCount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: tc.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.surah.name,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tc.text,
                              fontSize: 18,
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${widget.surah.transliteration} : $_currentVisibleAyah',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tc.textSecondary.withValues(alpha: 0.7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: tc.textSecondary.withValues(alpha: 0.6), size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _circleBtn(Icons.tune_rounded, tc, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuranSettingsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, IslamicThemeColors tc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: tc.text, size: 21),
      ),
    );
  }

  // ── Verse jump sheet (tap the header pill) ──
  void _showVerseJump(String mode, int verseCount) {
    final tc = ref.read(islamicThemeColorsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: tc.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Text('Jump to verse',
                  style: TextStyle(
                      color: tc.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${widget.surah.transliteration} · $verseCount verses',
                  style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.4,
                ),
                itemCount: verseCount,
                itemBuilder: (context, i) {
                  final ayah = i + 1;
                  final active = ayah == _currentVisibleAyah;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _jumpToVerse(ayah, mode, verseCount);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: active
                            ? tc.green.withValues(alpha: 0.18)
                            : tc.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: active
                            ? Border.all(
                                color: tc.green.withValues(alpha: 0.5))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('$ayah',
                          style: TextStyle(
                              color: active ? tc.green : tc.text,
                              fontSize: 14,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToVerse(int ayah, String mode, int verseCount) {
    setState(() => _currentVisibleAyah = ayah);
    _saveReadingProgress(ayah);
    if (mode == 'focus') {
      _focusController.jumpToPage(ayah - 1);
    } else if (_scrollController.hasClients) {
      final frac = verseCount > 1 ? (ayah - 1) / (verseCount - 1) : 0.0;
      final target = frac * _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    }
  }

  // ── Audio Player Bar ──
  Widget _buildAudioBar(IslamicThemeColors tc, QuranSettings settings, QuranAudioPlaybackState audioState) {
    // Only show when playing, paused, or loading for the current surah
    if (audioState.isIdle && audioState.currentSurahId != widget.surah.id) {
      // Show a compact play button instead
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: tc.background,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _playAudio(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: tc.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tc.green.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_filled, color: tc.green.withValues(alpha: 0.7), size: 20),
                    const SizedBox(width: 6),
                    Text('Play Recitation',
                      style: TextStyle(color: tc.green.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Full audio bar when active
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(color: tc.surface.withValues(alpha: 0.8), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause/Loading
              if (audioState.isLoading)
                SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tc.green),
                )
              else
                GestureDetector(
                  onTap: () {
                    if (audioState.isPlaying) {
                      ref.read(quranAudioProvider.notifier).pause();
                    } else if (audioState.isPaused) {
                      ref.read(quranAudioProvider.notifier).resume();
                    } else {
                      _playAudio();
                    }
                  },
                  child: Icon(
                    audioState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: tc.green,
                    size: 34,
                  ),
                ),
              const SizedBox(width: 10),
              // Reciter name + surah
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audioState.currentReciter ?? settings.selectedReciterName,
                      style: TextStyle(color: tc.text, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.surah.transliteration,
                      style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Stop button
              GestureDetector(
                onTap: () {
                  ref.read(quranAudioProvider.notifier).stop();
                },
                child: Icon(Icons.stop_circle_outlined, color: tc.textSecondary.withValues(alpha: 0.5), size: 28),
              ),
            ],
          ),
          // Seek bar
          if (audioState.duration.inSeconds > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDuration(audioState.position),
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: tc.green.withValues(alpha: 0.6),
                      inactiveTrackColor: tc.surface,
                      thumbColor: tc.green,
                      overlayColor: tc.green.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: audioState.progress,
                      onChanged: (v) {
                        final newPos = Duration(
                          milliseconds: (v * audioState.duration.inMilliseconds).round(),
                        );
                        ref.read(quranAudioProvider.notifier).seek(newPos);
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(audioState.duration),
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  /// Load audio for current surah and play it
  Future<void> _playAudio() async {
    final settings = ref.read(quranSettingsProvider);
    final apiService = ref.read(alQuranApiServiceProvider);

    try {
      // Fetch the surah detail to get audio URLs
      final surahDetail = await apiService.getSurah(
        widget.surah.id,
        lang: settings.translationLang,
      );

      if (surahDetail == null || surahDetail.audio.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Audio not available for this surah'),
              backgroundColor: Colors.red.withValues(alpha: 0.8),
            ),
          );
        }
        return;
      }

      // Find the selected reciter's audio
      final reciterKey = settings.selectedReciterKey;
      final audioEntry = surahDetail.audio[reciterKey] ?? surahDetail.audio.values.first;
      final reciterName = audioEntry.reciter;
      final audioUrl = audioEntry.url;

      if (audioUrl.isEmpty) return;

      await ref.read(quranAudioProvider.notifier).play(
        surahId: widget.surah.id,
        reciterName: reciterName,
        audioUrl: audioUrl,
      );
    } catch (e) {
      debugPrint('SurahReader: Failed to load audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load audio recitation'),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }

  // ── Sub-header: surah meaning + reading goal ──
  Widget _buildSubHeader(IslamicThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
      child: Row(
        children: [
          Text(
            '${widget.surah.id}. ${_getSurahMeaning(widget.surah.transliteration)}',
            style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 13),
          ),
          const Spacer(),
          Text('Reading goal: ', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.45), fontSize: 12)),
          Text(
            '${(_readingProgress * widget.surah.totalVerses).round()}/${widget.surah.totalVerses}',
            style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.65), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
              value: _readingProgress, strokeWidth: 2,
              backgroundColor: tc.surface, color: tc.green.withValues(alpha: 0.5))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: tc.textSecondary.withValues(alpha: 0.35), size: 16),
        ],
      ),
    );
  }

  // ── Thin progress bar ──
  Widget _buildProgressBar(IslamicThemeColors tc) {
    return Container(
      height: 2.5, width: double.infinity,
      color: tc.surface.withValues(alpha: 0.5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 2.5,
          width: MediaQuery.of(context).size.width * _readingProgress,
          decoration: BoxDecoration(
            color: tc.green.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Ornamental Surah Banner — green header matching reference ──
  Widget _buildSurahBanner(IslamicThemeColors tc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 28),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: isDark ? 0.5 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tc.surface.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Surah number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tc.green.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Surah ${widget.surah.id}',
              style: TextStyle(
                color: tc.green.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Arabic name - centered and prominent
          Text(
            widget.surah.name,
            style: TextStyle(
              color: tc.text.withValues(alpha: 0.95),
              fontSize: 32,
              fontWeight: FontWeight.w500,
              fontFamily: 'Amiri',
              height: 1.3,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Transliteration and info
          Text(
            widget.surah.transliteration,
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Type and verses count
          Text(
            '${widget.surah.type == 'meccan' ? 'Meccan' : 'Medinan'}  •  ${widget.surah.totalVerses} Verses',
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Individual Verse ──
  // ── Reading mode switcher: Classic (word-by-word) · Focus · Mushaf ──
  Widget _buildModeSwitcher(IslamicThemeColors tc, String mode) {
    const modes = [
      ('classic', 'Classic'),
      ('focus', 'Focus'),
      ('mushaf', 'Mushaf'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final m in modes)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(quranReaderModeProvider.notifier).set(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: mode == m.$1
                        ? tc.green.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    m.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mode == m.$1
                          ? tc.green
                          : tc.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight:
                          mode == m.$1 ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerseItem(dynamic verse, dynamic arabicFont, bool isHighlighted,
      bool isLast, IslamicThemeColors tc, QuranSettings settings,
      WordByWordService? wbw, String mode) {
    final classic = wbw != null;
    final hasTranslation = verse.translation != null &&
        (verse.translation as String).isNotEmpty &&
        settings.showTranslation;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: isHighlighted ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
              color: tc.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.accent.withValues(alpha: 0.2)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // ── Verse header: number + actions ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: tc.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('${widget.surah.id}:${verse.id}',
                    style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              _focusIcon(Icons.bookmark_border_rounded, tc,
                  () => _saveReadingProgress(verse.id)),
              _focusIcon(
                  Icons.menu_book_rounded,
                  tc,
                  () => TafseerBottomSheet.show(context,
                      surahId: widget.surah.id,
                      ayahId: verse.id,
                      surahName: widget.surah.transliteration)),
              _focusIcon(Icons.more_horiz_rounded, tc,
                  () => _showVerseMenu(verse)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Arabic — word-by-word (Classic) or whole-ayah fallback ──
          if (classic)
            _buildWordByWord(verse, arabicFont, tc, wbw)
          else
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    verse.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: tc.arabicText,
                      fontSize: 24,
                      height: 1.9,
                      fontWeight: FontWeight.w400,
                      fontFamily: arabicFont.fontFamily,
                    ),
                  ),
                ),
                Positioned(
                    left: 0, top: 6, child: _buildVerseMarker(verse.id, tc)),
              ],
            ),

          if (hasTranslation) ...[
            const SizedBox(height: 10),
            Text(
              verse.translation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.72),
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (!isLast) _buildVerseDivider(tc),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Word-by-word: each Arabic word over its English gloss, RTL flow ──
  Widget _buildWordByWord(dynamic verse, dynamic arabicFont,
      IslamicThemeColors tc, WordByWordService wbw) {
    final pairs = wbw.pair(verse.arabic, widget.surah.id, verse.id);
    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 13,
      children: [
        for (final w in pairs)
          IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: tc.arabicText,
                      fontSize: 23,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                      fontFamily: arabicFont.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                      height: 0.8, color: tc.accent.withValues(alpha: 0.18)),
                  const SizedBox(height: 4),
                  Text(
                    w.english.isEmpty ? '·' : w.english,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Ayah-number marker as the trailing cell
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _buildVerseMarker(verse.id, tc),
        ),
      ],
    );
  }

  // ── Ornamental verse marker ──
  Widget _buildVerseMarker(int num, IslamicThemeColors tc) {
    return SizedBox(
      width: 30, height: 30,
      child: Stack(alignment: Alignment.center, children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: tc.accent.withValues(alpha: 0.35), width: 1.5))),
        Container(width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: tc.accent.withValues(alpha: 0.2), width: 1))),
        Text('$num', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.55), fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Elegant divider ──
  Widget _buildVerseDivider(IslamicThemeColors tc) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 28, height: 0.5, color: tc.accent.withValues(alpha: 0.15)),
      const SizedBox(width: 8),
      Text('·', style: TextStyle(color: tc.accent.withValues(alpha: 0.3), fontSize: 10)),
      const SizedBox(width: 6),
      Text('✦', style: TextStyle(color: tc.accent.withValues(alpha: 0.2), fontSize: 7)),
      const SizedBox(width: 6),
      Text('·', style: TextStyle(color: tc.accent.withValues(alpha: 0.3), fontSize: 10)),
      const SizedBox(width: 8),
      Container(width: 28, height: 0.5, color: tc.accent.withValues(alpha: 0.15)),
    ]);
  }

  String _getSurahMeaning(String t) {
    const m = {'Al-Faatiha':'The Opener','Al-Baqara':'The Cow','Aal-i-Imraan':'Family of Imran',
      'An-Nisaa':'The Women','Al-Maaida':'The Table','Al-An\'aam':'The Cattle',
      'Al-A\'raaf':'The Heights','Al-Anfaal':'Spoils of War','At-Tawba':'Repentance',
      'Yunus':'Jonah','Hud':'Hud','Yusuf':'Joseph','Ar-Ra\'d':'Thunder',
      'Ibrahim':'Abraham','An-Nahl':'The Bee','Al-Kahf':'The Cave','Maryam':'Mary',
      'Ya-Sin':'Ya-Sin','Ar-Rahmaan':'The Merciful','Al-Mulk':'Dominion',
      'Al-Ikhlaas':'Sincerity','Al-Falaq':'Daybreak','An-Naas':'Mankind'};
    return m[t] ?? '';
  }
}
