import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/topic_content.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_palette.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../providers/theme_provider.dart';

/// Apple-Books-style chapter reader:
///   • Full-screen vertical scroll (one unit per page)
///   • Tap anywhere → minimal overlay (back / contents / Aa)
///   • Slim progress bar + location label at the bottom
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTopicIndex = 0;
  late final PageController _pageController;
  late final List<_TopicWithChapter> _allTopics;

  bool _overlayVisible = false;
  late AnimationController _overlayAnim;
  late Animation<double> _fadeCurve;

  @override
  void initState() {
    super.initState();

    _allTopics = [];
    for (var c in widget.book.chapters) {
      if (c.hasContent) {
        for (var t in c.topics) {
          _allTopics.add(_TopicWithChapter(c, t));
        }
      }
    }

    _currentTopicIndex =
        _allTopics.indexWhere((t) => t.chapter.id == widget.initialChapterId);
    if (_currentTopicIndex == -1) _currentTopicIndex = 0;
    _pageController = PageController(initialPage: _currentTopicIndex);

    _overlayAnim = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fadeCurve = CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);

    // Show the chrome briefly when the reader opens, then let it rest.
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
    HapticFeedback.lightImpact();
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
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (_allTopics.isEmpty) {
      return const Scaffold(body: Center(child: Text('No content available.')));
    }
    final tc = _allTopics[_currentTopicIndex];
    final currentChapter = tc.chapter;

    final settings = ref.watch(readerSettingsProvider);
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final accent = ref.watch(themeColorProvider).color;
    final p = ReaderPalette(isDark, accent);

    final totalTopics = _allTopics.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: p.bg,
        endDrawer: _buildContentsDrawer(p),
        body: GestureDetector(
          onTap: _toggleOverlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // ── Page content ──
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
                    return KindleTopicPage(
                      key: ValueKey('topic_${item.topic.id}'),
                      topic: item.topic,
                      p: p,
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
                  },
                ),
              ),

              // ── Bottom location bar ──
              if (totalTopics > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _LocationBar(
                    currentIndex: _currentTopicIndex,
                    total: totalTopics,
                    p: p,
                  ),
                ),

              // ── Tap overlay (top chrome) ──
              FadeTransition(
                opacity: _fadeCurve,
                child: IgnorePointer(
                  ignoring: !_overlayVisible,
                  child: _ReaderOverlay(
                    chapter: currentChapter,
                    p: p,
                    onBack: () => Navigator.pop(context),
                    onOpenSidebar: () {
                      _hideOverlay();
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // CONTENTS DRAWER
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildContentsDrawer(ReaderPalette p) {
    final chapters = widget.book.chapters.where((c) => c.hasContent).toList();

    return Drawer(
      backgroundColor: p.bg,
      width: MediaQuery.sizeOf(context).width * 0.86,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Contents',
                    style: GoogleFonts.literata(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        size: 22, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: p.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
                itemBuilder: (context, chapterIndex) {
                  final ch = chapters[chapterIndex];
                  final isCurrentChapter =
                      ch.id == _allTopics[_currentTopicIndex].chapter.id;

                  return Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: isCurrentChapter,
                      iconColor: p.accent,
                      collapsedIconColor: p.textTertiary,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(
                        'Ch ${ch.number} · ${ch.title}',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13.5,
                          fontWeight: isCurrentChapter
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isCurrentChapter ? p.accent : p.text,
                          height: 1.3,
                        ),
                      ),
                      children: _allTopics
                          .where((item) => item.chapter.id == ch.id)
                          .map((item) {
                        final t = item.topic;
                        final globalIndex =
                            _allTopics.indexWhere((x) => x.topic.id == t.id);
                        final isActive = globalIndex == _currentTopicIndex;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _jumpToTopic(globalIndex);
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(24, 12, 24, 12),
                            color: isActive
                                ? p.accent.withValues(alpha: 0.10)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? p.accent.withValues(alpha: 0.18)
                                        : p.textTertiary
                                            .withValues(alpha: 0.10),
                                  ),
                                  child: Text(
                                    '${t.number}',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 11.5,
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isActive
                                          ? p.accent
                                          : p.textTertiary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: GoogleFonts.literata(
                                      fontSize: 13.5,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color:
                                          isActive ? p.text : p.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCATION BAR — slim progress + unit label
// ═══════════════════════════════════════════════════════════════════════════

class _LocationBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final ReaderPalette p;

  const _LocationBar({
    required this.currentIndex,
    required this.total,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 1 ? (currentIndex + 1) / total : 1.0;
    final percent = (fraction * 100).round();

    return Container(
      color: p.bg,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 10,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 2.5,
              backgroundColor: p.textTertiary.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(p.accent.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Unit ${currentIndex + 1} of $total',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: p.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: p.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// READER OVERLAY — minimal top chrome
// ═══════════════════════════════════════════════════════════════════════════

class _ReaderOverlay extends StatelessWidget {
  final ChapterModel chapter;
  final ReaderPalette p;
  final VoidCallback onBack;
  final VoidCallback onOpenSidebar;

  const _ReaderOverlay({
    required this.chapter,
    required this.p,
    required this.onBack,
    required this.onOpenSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: p.bg.withValues(alpha: 0.96),
          border: Border(
            bottom: BorderSide(color: p.border, width: 0.5),
          ),
        ),
        padding: EdgeInsets.only(
          top: topPad + 6,
          left: 6,
          right: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            _OverlayIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              color: p.text,
              onTap: onBack,
            ),
            Expanded(
              child: Text(
                chapter.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _OverlayIconButton(
              icon: Icons.format_list_bulleted_rounded,
              color: p.textSecondary,
              onTap: onOpenSidebar,
            ),
            ReaderSettingsButton(p: p),
          ],
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OverlayIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 21, color: color),
      ),
    );
  }
}
