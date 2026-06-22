import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/topic_content.dart';
import '../widgets/reader_settings_sheet.dart';

/// Immersive chapter reader:
///   • One topic per vertical page; tap toggles the top bar.
///   • A slim, always-visible bottom bar keeps Contents one tap away.
///   • Contents opens a full chapter→topic index (current unit highlighted).
class ChapterScreen extends ConsumerStatefulWidget {
  final BookModel book;
  final String initialChapterId;
  const ChapterScreen(
      {super.key, required this.book, required this.initialChapterId});

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _TopicWithChapter {
  final ChapterModel chapter;
  final TopicModel topic;
  _TopicWithChapter(this.chapter, this.topic);
}

class _ChapterScreenState extends ConsumerState<ChapterScreen>
    with SingleTickerProviderStateMixin {
  int _currentTopicIndex = 0;
  late final PageController _pageController;
  late List<_TopicWithChapter> _allTopics;
  late BookModel _book;

  bool _overlayVisible = false;
  late AnimationController _overlayAnim;
  late Animation<double> _fadeCurve;

  /// Flattens a book's chapters into the linear topic list the reader pages
  /// through. Used at startup and whenever the language (and thus the book)
  /// changes underneath an open reader.
  List<_TopicWithChapter> _buildTopics(BookModel book) {
    final list = <_TopicWithChapter>[];
    for (var c in book.chapters) {
      if (c.hasContent) {
        for (var t in c.topics) {
          list.add(_TopicWithChapter(c, t));
        }
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();

    _book = widget.book;
    _allTopics = _buildTopics(_book);

    _currentTopicIndex =
        _allTopics.indexWhere((t) => t.chapter.id == widget.initialChapterId);
    if (_currentTopicIndex == -1) _currentTopicIndex = 0;
    _pageController = PageController(initialPage: _currentTopicIndex);

    _overlayAnim = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fadeCurve = CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);

    // Reveal the top bar briefly when the reader opens, then let the reader breathe.
    _overlayVisible = true;
    _overlayAnim.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgress());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayAnim.dispose();
    super.dispose();
  }

  void _saveProgress() {
    if (_allTopics.isEmpty) return;
    final tc = _allTopics[_currentTopicIndex];
    ref.read(readingProgressProvider.notifier).savePosition(
          chapterId: tc.chapter.id,
          topicId: tc.topic.id,
          chapterTitle: tc.chapter.title,
          topicTitle: tc.topic.title,
          chapterNumber: tc.chapter.number,
        );
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) {
      _overlayAnim.forward();
    } else {
      _overlayAnim.reverse();
    }
  }

  void _hideOverlay() {
    if (_overlayVisible) {
      setState(() => _overlayVisible = false);
      _overlayAnim.reverse();
    }
  }

  void _jumpToTopic(int index) {
    _hideOverlay();
    if (index == _currentTopicIndex) return;
    if (index > _currentTopicIndex) {
      ref
          .read(readingProgressProvider.notifier)
          .markTopicCompleted(_allTopics[_currentTopicIndex].topic.id);
    }
    setState(() => _currentTopicIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
    );
    _saveProgress();
  }

  // ── Contents index — a full, always-reachable chapter/topic browser ──
  void _showContents() {
    final p = ref.read(readerSettingsProvider).palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContentsSheet(
        chapters: _book.chapters.where((c) => c.hasContent).toList(),
        allTopics: _allTopics,
        currentIndex: _currentTopicIndex,
        palette: p,
        bookTitle: _book.title,
        onJump: (globalIndex) {
          Navigator.pop(context);
          _jumpToTopic(globalIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live-swap the book when the reader language changes mid-read. English and
    // Hinglish share identical chapter/topic IDs and ordering, so the current
    // page index stays valid — the open unit simply re-renders in the new
    // language without losing the reader's place.
    ref.listen<AsyncValue<BookModel>>(bookProvider, (prev, next) {
      final book = next.asData?.value;
      if (book != null && !identical(book, _book)) {
        setState(() {
          _book = book;
          _allTopics = _buildTopics(_book);
          if (_currentTopicIndex >= _allTopics.length) {
            _currentTopicIndex = _allTopics.isEmpty ? 0 : _allTopics.length - 1;
          }
        });
      }
    });

    if (_allTopics.isEmpty) {
      return const Scaffold(body: Center(child: Text('No content available.')));
    }
    final tc = _allTopics[_currentTopicIndex];
    final settings = ref.watch(readerSettingsProvider);
    final p = settings.palette;
    final totalTopics = _allTopics.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.surface,
        systemNavigationBarIconBrightness:
            p.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        body: GestureDetector(
          onTap: _toggleOverlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // ── Reading content ──
              NotificationListener<ScrollUpdateNotification>(
                onNotification: (notif) {
                  if (notif.scrollDelta != null &&
                      notif.scrollDelta!.abs() > 2) {
                    _hideOverlay();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalTopics,
                  onPageChanged: (index) {
                    if (index > _currentTopicIndex) {
                      ref
                          .read(readingProgressProvider.notifier)
                          .markTopicCompleted(
                              _allTopics[_currentTopicIndex].topic.id);
                    }
                    setState(() => _currentTopicIndex = index);
                    _saveProgress();
                  },
                  itemBuilder: (context, index) {
                    final item = _allTopics[index];
                    final page = KindleTopicPage(
                      key: ValueKey('topic_${item.topic.id}'),
                      topic: item.topic,
                      palette: p,
                      fontSize: settings.fontSize,
                      lineHeight: settings.lineHeight,
                      chapterTitle: item.chapter.title,
                      topicIndex: index,
                      totalTopics: totalTopics,
                      onSwipeNext: index < totalTopics - 1
                          ? () => _jumpToTopic(index + 1)
                          : null,
                      onSwipePrev:
                          index > 0 ? () => _jumpToTopic(index - 1) : null,
                    );
                    // Premium unit transition: fade + scale + gentle parallax,
                    // driven by the live page-scroll position.
                    return AnimatedBuilder(
                      animation: _pageController,
                      child: page,
                      builder: (context, child) {
                        double delta = 0.0;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          delta = (_pageController.page ??
                                  _currentTopicIndex.toDouble()) -
                              index;
                        }
                        final t = delta.abs().clamp(0.0, 1.0);
                        return Opacity(
                          opacity: (1.0 - t * 0.85).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, -delta * 28.0),
                            child: Transform.scale(
                              scale: 1.0 - t * 0.05,
                              child: child,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Always-visible bottom bar (Contents + progress + nav) ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomBar(p),
              ),

              // ── Tap overlay: top bar ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeCurve,
                  child: IgnorePointer(
                    ignoring: !_overlayVisible,
                    child: _ReaderOverlay(
                      title: tc.chapter.title,
                      palette: p,
                      onBack: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderPalette p) {
    final total = _allTopics.length;
    final percent =
        total > 1 ? ((_currentTopicIndex / (total - 1)) * 100).round() : 100;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 6,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Row(
        children: [
          // Contents — the always-reachable index
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showContents,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_rounded, size: 17, color: p.accent),
                const SizedBox(width: 7),
                Text('Contents',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.accent)),
              ]),
            ),
          ),
          const Spacer(),
          Text('Unit ${_currentTopicIndex + 1} / $total',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12, color: p.textFaint, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text('· $percent%',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: p.accent.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          _navBtn(Icons.keyboard_arrow_up_rounded,
              _currentTopicIndex > 0 ? () => _jumpToTopic(_currentTopicIndex - 1) : null, p),
          _navBtn(Icons.keyboard_arrow_down_rounded,
              _currentTopicIndex < total - 1 ? () => _jumpToTopic(_currentTopicIndex + 1) : null, p),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap, ReaderPalette p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon,
            size: 24,
            color: onTap == null
                ? p.textFaint.withValues(alpha: 0.4)
                : p.text.withValues(alpha: 0.75)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// READER OVERLAY — slim top bar (back · chapter · settings)
// ═══════════════════════════════════════════════════════════════════════════

class _ReaderOverlay extends StatelessWidget {
  final String title;
  final ReaderPalette palette;
  final VoidCallback onBack;

  const _ReaderOverlay({
    required this.title,
    required this.palette,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.97),
        border: Border(bottom: BorderSide(color: p.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(top: topPad + 6, left: 4, right: 12, bottom: 10),
      child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: p.text),
              splashRadius: 20,
            ),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.literata(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ReaderSettingsButton(palette: p),
          ],
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTENTS SHEET — full chapter/topic index, current unit highlighted
// ═══════════════════════════════════════════════════════════════════════════

class _ContentsSheet extends StatelessWidget {
  final List<ChapterModel> chapters;
  final List<_TopicWithChapter> allTopics;
  final int currentIndex;
  final ReaderPalette palette;
  final String bookTitle;
  final ValueChanged<int> onJump;

  const _ContentsSheet({
    required this.chapters,
    required this.allTopics,
    required this.currentIndex,
    required this.palette,
    required this.bookTitle,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: p.textFaint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contents',
                          style: GoogleFonts.literata(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: p.text)),
                      const SizedBox(height: 2),
                      Text(bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                              fontSize: 13, color: p.textMuted)),
                    ],
                  ),
                ),
                Text('${allTopics.length} units',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12.5, color: p.textFaint)),
              ],
            ),
          ),
          Container(height: 0.5, color: p.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28, top: 4),
              physics: const BouncingScrollPhysics(),
              children: [
                for (final ch in chapters) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                    child: Text(
                      'CHAPTER ${ch.number}  ·  ${ch.title}'.toUpperCase(),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  for (final item
                      in allTopics.where((x) => x.chapter.id == ch.id))
                    _topicRow(p, item),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicRow(ReaderPalette p, _TopicWithChapter item) {
    final gi = allTopics.indexWhere((x) => x.topic.id == item.topic.id);
    final active = gi == currentIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onJump(gi),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        color: active ? p.accent.withValues(alpha: 0.10) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('${item.topic.number}',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? p.accent : p.textFaint)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  fontSize: 14.5,
                  height: 1.3,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? p.text : p.text.withValues(alpha: 0.78),
                ),
              ),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.menu_book_rounded,
                    size: 15, color: p.accent.withValues(alpha: 0.8)),
              ),
          ],
        ),
      ),
    );
  }
}
