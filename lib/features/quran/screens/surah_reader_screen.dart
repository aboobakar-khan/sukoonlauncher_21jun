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
  
  // For tracking visible verse
  int _currentVisibleAyah = 1;
  bool _hasScrolledToInitial = false;
  
  // Reading progress (0.0 to 1.0)
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
                  _buildTopBar(tc),
                  // ── Audio Player Bar ──
                  _buildAudioBar(tc, settings, audioState),
                  // ── Sub-header ──
                  _buildSubHeader(tc),
                  // ── Reading mode switcher ──
                  _buildModeSwitcher(tc, mode),
                  // ── Progress bar ──
                  _buildProgressBar(tc),
                  // ── Verses ──
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.maxScrollExtent > 0) {
                          final progress = notification.metrics.pixels /
                              notification.metrics.maxScrollExtent;
                          setState(() => _readingProgress = progress.clamp(0.0, 1.0));
                          final visibleAyah = (progress * verses.length).ceil();
                          final clampedAyah = visibleAyah.clamp(1, verses.length);
                          if (progress >= 0.95) {
                            _saveReadingProgress(verses.length);
                          } else {
                            _saveReadingProgress(clampedAyah);
                          }
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
                          final isHighlighted = widget.initialAyah != null &&
                              verse.id == widget.initialAyah;
                          final isLast = index == verses.length;
                          return _buildVerseItem(verse, arabicFont, isHighlighted, isLast, tc, settings, wbw, mode);
                        },
                      ),
                    ),
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

  // ── Top Bar — warm cream, matching reference ──
  Widget _buildTopBar(IslamicThemeColors tc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      color: tc.background,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: tc.text, size: 22),
          ),
          Expanded(
            child: Text(
              widget.surah.transliteration,
              style: TextStyle(color: tc.text, fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuranSettingsScreen()),
              );
            },
            icon: Icon(Icons.tune_rounded, color: tc.textSecondary.withValues(alpha: 0.7), size: 22),
          ),
        ],
      ),
    );
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
    final mushaf = mode == 'mushaf';
    final classic = mode == 'classic' && wbw != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: isHighlighted ? const EdgeInsets.all(12) : EdgeInsets.zero,
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
          const SizedBox(height: 8),
          // ── Aya label chip (hidden in Mushaf) ──
          if (!mushaf)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    TafseerBottomSheet.show(context,
                        surahId: widget.surah.id,
                        ayahId: verse.id,
                        surahName: widget.surah.transliteration);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: tc.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Aya ${widget.surah.id}:${verse.id}',
                          style: TextStyle(
                              color: tc.textSecondary.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 3),
                      Icon(Icons.expand_more,
                          color: tc.green.withValues(alpha: 0.5), size: 15),
                    ]),
                  ),
                ),
                const Spacer(),
              ],
            ),
          SizedBox(height: mushaf ? 6 : 20),

          // ── Arabic — word-by-word (Classic) or whole-ayah ──
          if (classic)
            _buildWordByWord(verse, arabicFont, tc, wbw)
          else
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Text(
                    verse.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: tc.arabicText,
                      fontSize: mushaf ? 30 : 28,
                      height: 2.0,
                      fontWeight: FontWeight.w400,
                      fontFamily: arabicFont.fontFamily,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 8,
                  child: _buildVerseMarker(verse.id, tc),
                ),
              ],
            ),

          // ── Translation (Classic & Focus only) ──
          if (!mushaf &&
              verse.translation != null &&
              verse.translation!.isNotEmpty &&
              settings.showTranslation) ...[
            const SizedBox(height: 16),
            Text(
              verse.translation!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          SizedBox(height: mushaf ? 18 : 28),
          if (!isLast) _buildVerseDivider(tc),
          const SizedBox(height: 12),
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
      spacing: 6,
      runSpacing: 16,
      children: [
        for (final w in pairs)
          IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      fontSize: 26,
                      height: 1.7,
                      fontWeight: FontWeight.w400,
                      fontFamily: arabicFont.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                      height: 0.8, color: tc.accent.withValues(alpha: 0.18)),
                  const SizedBox(height: 6),
                  Text(
                    w.english.isEmpty ? '·' : w.english,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      height: 1.25,
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
