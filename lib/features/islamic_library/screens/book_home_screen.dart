import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/chapter_card.dart';
import '../widgets/reader_settings_sheet.dart';
import 'chapter_screen.dart';

/// Book home screen — shows book header + chapter list.
class BookHomeScreen extends ConsumerStatefulWidget {
  const BookHomeScreen({super.key});

  @override
  ConsumerState<BookHomeScreen> createState() => _BookHomeScreenState();
}

class _BookHomeScreenState extends ConsumerState<BookHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim.forward();
  }

  @override
  void dispose() {
    _progressAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider);
    final settings = ref.watch(readerSettingsProvider);
    final p = settings.palette;
    final progress = ref.watch(readingProgressProvider);

    final gold = p.accent;
    final bgColor = p.bg;
    final textColor = p.text;

    return Scaffold(
      backgroundColor: bgColor,
      body: bookAsync.when(
        // Keep the current chapter list on screen while switching language,
        // instead of flashing a full-screen spinner over a quick local reload.
        skipLoadingOnReload: true,
        loading: () => Center(
          child: CircularProgressIndicator(color: gold),
        ),
        error: (e, _) => Center(
          child: Text('Error loading book: $e',
              style: TextStyle(color: textColor)),
        ),
        data: (book) => CustomScrollView(
          slivers: [
            // ══════════════════════════════════════
            // HEADER
            // ══════════════════════════════════════
            SliverToBoxAdapter(
              child: _BookHeader(
                book: book,
                progress: progress,
                progressAnim: _progressAnim,
                palette: p,
              ),
            ),

            // ══════════════════════════════════════
            // CONTINUE READING BANNER
            // ══════════════════════════════════════
            if (progress.hasProgress)
              SliverToBoxAdapter(
                child: _ContinueReadingBanner(
                  progress: progress,
                  palette: p,
                  onTap: () {
                    final chapter = book.chapters.firstWhere(
                      (c) => c.id == progress.lastChapterId,
                      orElse: () => book.chapters.first,
                    );
                    if (chapter.hasContent) {
                      Navigator.push(
                        context,
                        _smoothRoute(ChapterScreen(
                          book: book,
                          initialChapterId: chapter.id,
                        )),
                      );
                    }
                  },
                ),
              ),

            // ══════════════════════════════════════
            // SECTION TITLE
            // ══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Text(
                  'Chapters',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.textFaint,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            // ══════════════════════════════════════
            // CHAPTER LIST
            // ══════════════════════════════════════
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ch = book.chapters[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ChapterCard(
                        chapter: ch,
                        palette: p,
                        index: index,
                        onTap: () {
                          if (ch.hasContent) {
                            Navigator.push(
                              context,
                              _smoothRoute(ChapterScreen(
                                book: book,
                                initialChapterId: ch.id,
                              )),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Content coming soon, stay tuned!',
                                  style: GoogleFonts.nunitoSans(),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF1A2B22),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  childCount: book.chapters.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Route _smoothRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOOK HEADER - Premium typography design
// ═══════════════════════════════════════════════════════════════════════

class _BookHeader extends StatelessWidget {
  final BookModel book;
  final ReadingProgress progress;
  final AnimationController progressAnim;
  final ReaderPalette palette;

  const _BookHeader({
    required this.book,
    required this.progress,
    required this.progressAnim,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final gold = p.accent;
    final textColor = p.text;
    final mutedText = p.textMuted;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          // ── Top Bar (Back + Language + Theme) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: textColor.withValues(alpha: 0.8), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Language picker (English ⇆ Hinglish)
                      _LanguageHeaderPill(palette: p),
                      const SizedBox(width: 8),
                      // Reading-theme picker (Paper · Sepia · Night · Black · Nord · Forest)
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const ReaderThemeQuickSheet(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.palette_outlined, color: gold, size: 17),
                            const SizedBox(width: 6),
                            Text('Theme',
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: gold)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Premium Typography Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            child: Column(
              children: [
                Text(
                  'الرحيق المختوم',
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    color: gold.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.subtitle.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: mutedText,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  book.author,
                  style: GoogleFonts.literata(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CONTINUE READING BANNER
// ═══════════════════════════════════════════════════════════════════════

class _ContinueReadingBanner extends StatelessWidget {
  final ReadingProgress progress;
  final ReaderPalette palette;
  final VoidCallback onTap;

  const _ContinueReadingBanner({
    required this.progress,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gold = palette.accent;
    final mutedText = palette.textMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Reading',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ch ${progress.lastChapterNumber} · ${progress.lastTopicTitle ?? ''}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: gold.withValues(alpha: 0.6), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// LANGUAGE HEADER PILL — shows the active language, opens the quick picker
// ═══════════════════════════════════════════════════════════════════════

class _LanguageHeaderPill extends ConsumerWidget {
  final ReaderPalette palette;
  const _LanguageHeaderPill({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(readerLanguageProvider);
    final gold = palette.accent;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ReaderLanguageQuickSheet(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.translate_rounded, color: gold, size: 17),
          const SizedBox(width: 6),
          Text(lang.label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: gold)),
        ]),
      ),
    );
  }
}
