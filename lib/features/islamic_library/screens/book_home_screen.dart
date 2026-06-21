import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/chapter_card.dart';
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
    // Force rebuild of root screen when theme changes
    ref.watch(readerSettingsProvider);
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final isDark = settingsNotifier.isDarkMode(context);
    final progress = ref.watch(readingProgressProvider);

    const gold = Color(0xFFD4A017);
    final bgColor =
        isDark ? const Color(0xFF000000) : const Color(0xFFF9F6EE);
    final textColor =
        isDark ? const Color(0xFFF5F0E8) : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: bgColor,
      body: bookAsync.when(
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
                isDark: isDark,
              ),
            ),

            // ══════════════════════════════════════
            // CONTINUE READING BANNER
            // ══════════════════════════════════════
            if (progress.hasProgress)
              SliverToBoxAdapter(
                child: _ContinueReadingBanner(
                  progress: progress,
                  isDark: isDark,
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
                    color: isDark
                        ? const Color(0xFF555555)
                        : const Color(0xFFAAAAAA),
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
                        isDark: isDark,
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

class _BookHeader extends ConsumerWidget {
  final BookModel book;
  final ReadingProgress progress;
  final AnimationController progressAnim;
  final bool isDark;

  const _BookHeader({
    required this.book,
    required this.progress,
    required this.progressAnim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gold = Color(0xFFD4A017);
    final overallProgress = progress.overallProgress(book);
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    
    final textColor = isDark ? const Color(0xFFF5F0E8) : const Color(0xFF1C1C1E);
    final mutedText = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          // ── Top Bar (Back + Theme) ──
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
                IconButton(
                  icon: Icon(
                    settings.themeMode == ReaderThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: gold.withValues(alpha: 0.8),
                    size: 22,
                  ),
                  onPressed: () {
                    final newMode = settings.themeMode == ReaderThemeMode.dark
                        ? ReaderThemeMode.light
                        : ReaderThemeMode.dark;
                    notifier.setThemeMode(newMode);
                  },
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
  final bool isDark;
  final VoidCallback onTap;

  const _ContinueReadingBanner({
    required this.progress,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A017);
    final mutedText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

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
                child: const Icon(Icons.play_arrow_rounded,
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
