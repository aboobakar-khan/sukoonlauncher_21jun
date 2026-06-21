import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/topic_content.dart';
import '../widgets/reader_settings_sheet.dart';

/// Kindle-style chapter reader:
///   • Full-screen vertical scroll (no tabs)
///   • Tap anywhere → overlay with unit picker dropdown
///   • Location bar at the bottom (like real Kindle)
class ChapterScreen extends ConsumerStatefulWidget {
  final BookModel book;
  final String initialChapterId;
  const ChapterScreen({super.key, required this.book, required this.initialChapterId});

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

  // Overlay visibility
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
    
    _currentTopicIndex = _allTopics.indexWhere((t) => t.chapter.id == widget.initialChapterId);
    if (_currentTopicIndex == -1) _currentTopicIndex = 0;
    _pageController = PageController(initialPage: _currentTopicIndex);

    _overlayAnim = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fadeCurve = CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);

    // Show unit panel immediately when reader opens
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

    // Mark old topic completed if moving forward
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
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final isDark = settingsNotifier.isDarkMode(context);

    final bgColor = isDark ? const Color(0xFF111111) : const Color(0xFFFAF8F4);
    final textColor = isDark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9B9B9B);
    const gold = Color(0xFFD4A017);

    final totalTopics = _allTopics.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: const Color(0xFF111111),
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: const Color(0xFFFAF8F4),
            ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgColor,
        endDrawer: _buildUnitSidebar(isDark, textColor, mutedColor, gold),
        body: GestureDetector(
          // Single tap anywhere toggles the overlay
          onTap: _toggleOverlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // ── Main page content ──────────────────────────────────────────
              NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notif) {
                        if (notif.scrollDelta != null && notif.scrollDelta!.abs() > 2) {
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
                            isDark: isDark,
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

              // ── Kinlde location bar (bottom) ───────────────────────────────
              if (totalTopics > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _LocationBar(
                    currentIndex: _currentTopicIndex,
                    total: totalTopics,
                    isDark: isDark,
                  ),
                ),

              // ── Tap overlay: top bar ─────────────────────────
              FadeTransition(
                opacity: _fadeCurve,
                child: IgnorePointer(
                  ignoring: !_overlayVisible,
                  child: _ReaderOverlay(
                    chapter: currentChapter,
                    currentTopicIndex: _allTopics[_currentTopicIndex].topic.number - 1,
                    totalTopics: currentChapter.topics.length,
                    isDark: isDark,
                    onBack: () => Navigator.pop(context),
                    onOpenSidebar: () {
                      _hideOverlay();
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    onDismiss: _hideOverlay,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitSidebar(bool isDark, Color textColor, Color muted, Color gold) {
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFFAF8F4);
    final divider = isDark ? const Color(0xFF222222) : const Color(0xFFE8E4DC);
    final chapters = widget.book.chapters.where((c) => c.hasContent).toList();

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'ALL UNITS',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            Container(height: 0.5, color: divider),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: chapters.length,
                itemBuilder: (context, chapterIndex) {
                  final ch = chapters[chapterIndex];
                  final isCurrentChapter = ch.id == _allTopics[_currentTopicIndex].chapter.id;
                  
                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: isCurrentChapter,
                      iconColor: gold,
                      collapsedIconColor: muted,
                      title: Text(
                        'Ch ${ch.number} · ${ch.title}',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          fontWeight: isCurrentChapter ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrentChapter ? gold : textColor,
                        ),
                      ),
                      children: _allTopics.where((item) => item.chapter.id == ch.id).map((item) {
                        final t = item.topic;
                        final globalIndex = _allTopics.indexWhere((x) => x.topic.id == t.id);
                        final isActive = globalIndex == _currentTopicIndex;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context); // close drawer
                            _jumpToTopic(globalIndex);
                          },
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(40, 12, 24, 12),
                            decoration: BoxDecoration(
                              color: isActive ? gold.withValues(alpha: 0.08) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${t.number}',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 12,
                                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                                      color: isActive ? gold : muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: GoogleFonts.literata(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                      color: isActive ? textColor : muted,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(Icons.circle, size: 6, color: gold.withValues(alpha: 0.7)),
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
// KINDLE LOCATION BAR
// ═══════════════════════════════════════════════════════════════════════════

class _LocationBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final bool isDark;

  const _LocationBar({
    required this.currentIndex,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFFAF8F4);
    final muted = isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);
    final percent = total > 1
        ? ((currentIndex / (total - 1)) * 100).round()
        : 100;

    return Container(
      color: bg,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 10,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Row(
        children: [
          Text(
            'Unit ${currentIndex + 1} of $total',
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            '$percent%',
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// READER OVERLAY — top navigation + unit picker dropdown
// ═══════════════════════════════════════════════════════════════════════════

class _ReaderOverlay extends StatelessWidget {
  final ChapterModel chapter;
  final int currentTopicIndex;
  final int totalTopics;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onOpenSidebar;
  final VoidCallback onDismiss;

  const _ReaderOverlay({
    required this.chapter,
    required this.currentTopicIndex,
    required this.totalTopics,
    required this.isDark,
    required this.onBack,
    required this.onOpenSidebar,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF111111).withValues(alpha: 0.97)
        : const Color(0xFFFAF8F4).withValues(alpha: 0.97);
    final textColor = isDark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A);
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: bg,
            padding: EdgeInsets.only(
              top: topPad + 8,
              left: 8,
              right: 16,
              bottom: 12,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: textColor),
                  splashRadius: 20,
                ),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: GoogleFonts.literata(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onOpenSidebar,
                  icon: Icon(Icons.format_list_bulleted_rounded,
                      size: 22, color: textColor.withValues(alpha: 0.8)),
                  splashRadius: 20,
                ),
                ReaderSettingsButton(isDark: isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

