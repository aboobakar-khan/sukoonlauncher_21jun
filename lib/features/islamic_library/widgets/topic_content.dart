import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';

/// Kindle-style single topic page with vertical scroll.
class KindleTopicPage extends StatefulWidget {
  final TopicModel topic;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final String chapterTitle;
  final int topicIndex;
  final int totalTopics;
  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrev;

  const KindleTopicPage({
    super.key,
    required this.topic,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.chapterTitle,
    required this.topicIndex,
    required this.totalTopics,
    this.onSwipeNext,
    this.onSwipePrev,
  });

  @override
  State<KindleTopicPage> createState() => _KindleTopicPageState();
}

class _KindleTopicPageState extends State<KindleTopicPage> {
  double _overscroll = 0.0;
  static const double _overscrollThreshold = 80.0;
  bool _triggered = false;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels > notification.metrics.maxScrollExtent) {
        final newOverscroll = notification.metrics.pixels - notification.metrics.maxScrollExtent;
        if (newOverscroll >= _overscrollThreshold && _overscroll < _overscrollThreshold) {
          HapticFeedback.lightImpact(); // Haptic when threshold reached
        }
        setState(() {
          _overscroll = newOverscroll;
        });
      } else if (_overscroll > 0) {
        setState(() {
          _overscroll = 0;
          _triggered = false;
        });
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        if (_overscroll >= _overscrollThreshold && widget.onSwipeNext != null && !_triggered) {
          _triggered = true;
          HapticFeedback.mediumImpact();
          widget.onSwipeNext!();
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final isDark = widget.isDark;
    final fontSize = widget.fontSize;
    final lineHeight = widget.lineHeight;
    final bg = isDark
        ? const Color(0xFF111111).withValues(alpha: 0.97)
        : const Color(0xFFFAF8F4).withValues(alpha: 0.97);
    final textColor = isDark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A);
    final muted = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    const gold = Color(0xFFD4A017);
    final double hPad = 28;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -400 && widget.onSwipeNext != null) widget.onSwipeNext!();
        if (d.primaryVelocity! > 400 && widget.onSwipePrev != null) widget.onSwipePrev!();
      },
      child: Container(
        color: bg,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 80),
          children: [
            // ── Chapter label ──────────────────────────────
            Text(
              widget.chapterTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: muted,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 36),

            // ── Topic title (big centered serif) ──────────
            Text(
              topic.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: fontSize + 8,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),

            // ── Decorative rule ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Row(
                children: [
                  Expanded(child: Divider(color: muted.withValues(alpha: 0.35), thickness: 0.8)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('✦', style: TextStyle(color: muted.withValues(alpha: 0.5), fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: muted.withValues(alpha: 0.35), thickness: 0.8)),
                ],
              ),
            ),

            // ── Paragraphs ─────────────────────────────────
            ...topic.paragraphs.asMap().entries.map((e) => _KindleParagraph(
                  paragraph: e.value,
                  isFirst: e.key == 0,
                  isDark: isDark,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  textColor: textColor,
                )),

            // ── Section rule before extras ─────────────────
            if (topic.topicSummary.isNotEmpty || topic.keyPoints.isNotEmpty || topic.quiz.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Divider(color: muted.withValues(alpha: 0.25), thickness: 0.8),
              ),

            // ── Summary ────────────────────────────────────
            if (topic.topicSummary.isNotEmpty)
              _KindleSummary(
                summary: topic.topicSummary,
                isDark: isDark,
                fontSize: fontSize,
                lineHeight: lineHeight,
                textColor: textColor,
                muted: muted,
              ),

            // ── Key Points ─────────────────────────────────
            if (topic.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 32),
              _KindleKeyPoints(
                keyPoints: topic.keyPoints,
                isDark: isDark,
                fontSize: fontSize,
                lineHeight: lineHeight,
                textColor: textColor,
                muted: muted,
              ),
            ],

            // ── Quiz ───────────────────────────────────────
            if (topic.quiz.isNotEmpty) ...[
              const SizedBox(height: 32),
              _KindleQuizSection(
                questions: topic.quiz,
                isDark: isDark,
                fontSize: fontSize,
                lineHeight: lineHeight,
                textColor: textColor,
                muted: muted,
              ),
            ],

            const SizedBox(height: 40),

            // ── Navigation hint (Pull to next) ────────────────────────────
            if (widget.onSwipeNext != null)
              GestureDetector(
                onTap: widget.onSwipeNext,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _overscroll >= _overscrollThreshold
                            ? 'Release for next unit'
                            : 'Pull up for next unit',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          fontWeight: _overscroll >= _overscrollThreshold ? FontWeight.w700 : FontWeight.w600,
                          color: _overscroll >= _overscrollThreshold ? gold : muted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedRotation(
                        turns: _overscroll >= _overscrollThreshold ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: _overscroll >= _overscrollThreshold ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Icon(Icons.arrow_upward_rounded, 
                            size: 16, 
                            color: _overscroll >= _overscrollThreshold ? gold : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// KINDLE PARAGRAPH — justified, drop-cap on first
// ════════════════════════════════════════════════════════════════════════

class _KindleParagraph extends StatelessWidget {
  final ParagraphModel paragraph;
  final bool isFirst;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final Color textColor;

  const _KindleParagraph({
    required this.paragraph,
    required this.isFirst,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.literata(
      fontSize: fontSize + 2,
      color: textColor,
      height: lineHeight * 1.1,
      letterSpacing: 0.05,
      fontWeight: FontWeight.w400,
    );

    Widget content;
    // Drop cap on first paragraph
    if (isFirst && paragraph.text.isNotEmpty) {
      final first = paragraph.text[0];
      final rest = paragraph.text.substring(1);
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Text(
              first,
              style: GoogleFonts.literata(
                fontSize: (fontSize + 2) * 3.4,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 0.82,
              ),
            ),
          ),
          Expanded(
            child: Text(rest, textAlign: TextAlign.justify, style: body),
          ),
        ],
      );
    } else {
      content = Text(paragraph.text, textAlign: TextAlign.justify, style: body);
    }

    return GestureDetector(
      onLongPress: () => _onLongPress(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: content,
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    HapticFeedback.mediumImpact();
    final bgSheet = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final tc = isDark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A);
    showModalBottomSheet(
      context: context,
      backgroundColor: bgSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: tc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Text('📋', style: TextStyle(fontSize: 20)),
              title: Text('Copy', style: GoogleFonts.nunitoSans(fontSize: 15, fontWeight: FontWeight.w600, color: tc)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: paragraph.text));
                Navigator.pop(context);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              dense: true,
            ),
            ListTile(
              leading: const Text('🔖', style: TextStyle(fontSize: 20)),
              title: Text('Bookmark', style: GoogleFonts.nunitoSans(fontSize: 15, fontWeight: FontWeight.w600, color: tc)),
              onTap: () => Navigator.pop(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// KINDLE SUMMARY
// ════════════════════════════════════════════════════════════════════════

class _KindleSummary extends StatelessWidget {
  final String summary;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color muted;

  const _KindleSummary({
    required this.summary,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    const sage = Color(0xFF7D9686);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'SUMMARY',
          style: GoogleFonts.nunitoSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: sage,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 20),
        // Blockquote style
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: sage.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  summary,
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.literata(
                    fontSize: fontSize + 1,
                    fontStyle: FontStyle.italic,
                    color: textColor.withValues(alpha: 0.85),
                    height: lineHeight * 1.05,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// KINDLE KEY POINTS
// ════════════════════════════════════════════════════════════════════════

class _KindleKeyPoints extends StatelessWidget {
  final List<String> keyPoints;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color muted;

  const _KindleKeyPoints({
    required this.keyPoints,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEY LEARNINGS',
          style: GoogleFonts.nunitoSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 20),
        ...keyPoints.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Roman-numeral style index
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${e.key + 1}.',
                      style: GoogleFonts.literata(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: lineHeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.literata(
                        fontSize: fontSize,
                        color: textColor.withValues(alpha: 0.9),
                        height: lineHeight,
                        letterSpacing: 0.05,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// KINDLE QUIZ SECTION — book-like styling
// ════════════════════════════════════════════════════════════════════════

class _KindleQuizSection extends StatelessWidget {
  final List<QuizQuestion> questions;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color muted;

  const _KindleQuizSection({
    required this.questions,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPREHENSION',
          style: GoogleFonts.nunitoSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 20),
        KindleQuizWidget(
          key: ValueKey('quiz_${questions.hashCode}'),
          questions: questions,
          isDark: isDark,
          fontSize: fontSize,
          lineHeight: lineHeight,
          textColor: textColor,
          muted: muted,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// KINDLE QUIZ WIDGET — stateful, book-style options
// ════════════════════════════════════════════════════════════════════════

class KindleQuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color muted;

  const KindleQuizWidget({
    super.key,
    required this.questions,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.muted,
  });

  @override
  State<KindleQuizWidget> createState() => _KindleQuizWidgetState();
}

class _KindleQuizWidgetState extends State<KindleQuizWidget> {
  int _idx = 0;
  String? _selected;
  bool _answered = false;
  bool _done = false;
  int _correct = 0;

  static const _correctColor = Color(0xFF5A8A6A);
  static const _wrongColor = Color(0xFF9B4A4A);

  void _pick(String option) {
    if (_answered) return;
    setState(() {
      _selected = option;
      _answered = true;
      if (option == widget.questions[_idx].answer) _correct++;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_idx < widget.questions.length - 1) {
        setState(() { _idx++; _selected = null; _answered = false; });
      } else {
        setState(() => _done = true);
      }
    });
  }

  void _reset() => setState(() { _idx = 0; _selected = null; _answered = false; _done = false; _correct = 0; });

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult();
    final q = widget.questions[_idx];
    final letters = ['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Text(
          'Question ${_idx + 1} of ${widget.questions.length}',
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
            color: widget.muted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        // Question
        Text(
          q.question,
          textAlign: TextAlign.justify,
          style: GoogleFonts.literata(
            fontSize: widget.fontSize + 1,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
            height: widget.lineHeight,
          ),
        ),
        const SizedBox(height: 18),
        // Options
        ...q.options.asMap().entries.map((e) {
          final letter = e.key < letters.length ? letters[e.key] : '${e.key + 1}';
          final opt = e.value;
          final isSelected = _selected == opt;
          final isCorrect = opt == q.answer;

          Color borderColor;
          Color bgColor;
          Color labelColor;

          final bg = widget.isDark ? const Color(0xFF1A1A1A) : Colors.white;
          final subtle = widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07);

          if (!_answered) {
            bgColor = bg;
            borderColor = subtle;
            labelColor = widget.textColor;
          } else if (isCorrect) {
            bgColor = _correctColor.withValues(alpha: 0.10);
            borderColor = _correctColor.withValues(alpha: 0.45);
            labelColor = _correctColor;
          } else if (isSelected) {
            bgColor = _wrongColor.withValues(alpha: 0.10);
            borderColor = _wrongColor.withValues(alpha: 0.45);
            labelColor = _wrongColor;
          } else {
            bgColor = bg.withValues(alpha: 0.4);
            borderColor = subtle.withValues(alpha: 0.4);
            labelColor = widget.textColor.withValues(alpha: 0.35);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _pick(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    // Letter badge
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1.2),
                        color: isCorrect && _answered
                            ? _correctColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.literata(
                          fontSize: widget.fontSize - 1,
                          color: labelColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_answered && isCorrect)
                      Icon(Icons.check_rounded, size: 18, color: _correctColor),
                    if (_answered && isSelected && !isCorrect)
                      Icon(Icons.close_rounded, size: 18, color: _wrongColor),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResult() {
    final total = widget.questions.length;
    final pct = ((_correct / total) * 100).round();
    final emoji = pct >= 80 ? '🎉' : pct >= 50 ? '👏' : '💪';
    final msg = pct >= 80 ? 'Excellent mastery!' : pct >= 50 ? 'Good understanding.' : 'Keep studying — you will get there.';

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 12),
        Text(
          '$_correct / $total',
          style: GoogleFonts.literata(
            fontSize: widget.fontSize + 8,
            fontWeight: FontWeight.w700,
            color: widget.textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          msg,
          style: GoogleFonts.literata(
            fontSize: widget.fontSize - 1,
            fontStyle: FontStyle.italic,
            color: widget.muted,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _reset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: widget.muted.withValues(alpha: 0.4), width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.muted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Keep old class name alias so existing code doesn't break
class TopicContent extends StatelessWidget {
  final TopicModel topic;
  final bool isDark;
  final double fontSize;
  final double lineHeight;
  final ScrollController? scrollController;

  const TopicContent({
    super.key,
    required this.topic,
    required this.isDark,
    required this.fontSize,
    required this.lineHeight,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return KindleTopicPage(
      topic: topic,
      isDark: isDark,
      fontSize: fontSize,
      lineHeight: lineHeight,
      chapterTitle: '',
      topicIndex: 0,
      totalTopics: 1,
    );
  }
}
