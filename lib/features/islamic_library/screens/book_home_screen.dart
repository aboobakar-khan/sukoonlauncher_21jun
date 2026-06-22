import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../widgets/chapter_card.dart';
import '../widgets/reader_palette.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../providers/theme_provider.dart';
import 'chapter_screen.dart';

/// Book home screen — book hero + chapter list. Apple Books inspired.
class BookHomeScreen extends ConsumerWidget {
  const BookHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider);
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final accent = ref.watch(themeColorProvider).color;
    final p = ReaderPalette(isDark, accent);
    final progress = ref.watch(readingProgressProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        body: bookAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: accent, strokeWidth: 2.4),
          ),
          error: (e, _) => Center(
            child: Text('Error loading book: $e',
                style: TextStyle(color: p.text)),
          ),
          data: (book) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _BookHeader(book: book, progress: progress, p: p),
              ),
              if (progress.hasProgress)
                SliverToBoxAdapter(
                  child: _ContinueReadingBanner(
                    progress: progress,
                    p: p,
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 6),
                  child: Text(
                    'CHAPTERS',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: p.textTertiary,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 44),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ch = book.chapters[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ChapterCard(
                          chapter: ch,
                          p: p,
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
                                    style: GoogleFonts.nunitoSans(
                                        color: p.text),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: p.surfaceHigh,
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
      ),
    );
  }

  static Route _smoothRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOOK HEADER
// ═══════════════════════════════════════════════════════════════════════

class _BookHeader extends ConsumerWidget {
  final BookModel book;
  final ReadingProgress progress;
  final ReaderPalette p;

  const _BookHeader(
      {required this.book, required this.progress, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = progress.overallProgress(book);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  color: p.text,
                  onTap: () => Navigator.pop(context),
                ),
                _CircleIconButton(
                  icon: p.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: p.accent,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(islamicThemeProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),

          // ── Title block ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
            child: Column(
              children: [
                Text(
                  'الرحيق المختوم',
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    color: p.accent,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  book.subtitle.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: p.textSecondary,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  book.author,
                  style: GoogleFonts.literata(
                    fontSize: 14.5,
                    color: p.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar (only once started) ──
          if (progress.hasProgress) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: overall.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: p.accent.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation(p.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(overall * 100).round()}%',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  final ReaderPalette p;
  final VoidCallback onTap;

  const _ContinueReadingBanner({
    required this.progress,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.play_arrow_rounded, color: p.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Reading',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ch ${progress.lastChapterNumber} · ${progress.lastTopicTitle ?? ''}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12.5,
                        color: p.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: p.accent.withValues(alpha: 0.7), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular icon button used in the header top bar.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }
}
