import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import 'reader_palette.dart';

/// Apple-Books-style single topic page with vertical scroll.
class KindleTopicPage extends StatefulWidget {
  final TopicModel topic;
  final ReaderPalette p;
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
    required this.p,
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
        final newOverscroll =
            notification.metrics.pixels - notification.metrics.maxScrollExtent;
        if (newOverscroll >= _overscrollThreshold &&
            _overscroll < _overscrollThreshold) {
          HapticFeedback.lightImpact();
        }
        setState(() => _overscroll = newOverscroll);
      } else if (_overscroll > 0) {
        setState(() {
          _overscroll = 0;
          _triggered = false;
        });
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        if (_overscroll >= _overscrollThreshold &&
            widget.onSwipeNext != null &&
            !_triggered) {
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
    final p = widget.p;
    final fontSize = widget.fontSize;
    final lineHeight = widget.lineHeight;
    const double hPad = 26;
    final triggered = _overscroll >= _overscrollThreshold;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -400 && widget.onSwipeNext != null) {
          widget.onSwipeNext!();
        }
        if (d.primaryVelocity! > 400 && widget.onSwipePrev != null) {
          widget.onSwipePrev!();
        }
      },
      child: Container(
        color: p.bg,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
                hPad, MediaQuery.paddingOf(context).top + 64, hPad, 96),
            children: [
              // ── Chapter eyebrow ──
              Text(
                widget.chapterTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: p.textTertiary,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 28),

              // ── Topic title ──
              Text(
                topic.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: fontSize + 9,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  height: 1.24,
                  letterSpacing: -0.3,
                ),
              ),

              // ── Ornamental divider ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 30,
                        height: 1,
                        color: p.accent.withValues(alpha: 0.4)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('✦',
                          style: TextStyle(
                              color: p.accent.withValues(alpha: 0.7),
                              fontSize: 11)),
                    ),
                    Container(
                        width: 30,
                        height: 1,
                        color: p.accent.withValues(alpha: 0.4)),
                  ],
                ),
              ),

              // ── Paragraphs ──
              ...topic.paragraphs.asMap().entries.map((e) => _KindleParagraph(
                    paragraph: e.value,
                    isFirst: e.key == 0,
                    p: p,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                  )),

              // ── Section rule ──
              if (topic.topicSummary.isNotEmpty ||
                  topic.keyPoints.isNotEmpty ||
                  topic.quiz.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: Divider(
                      color: p.textTertiary.withValues(alpha: 0.25),
                      thickness: 0.8),
                ),

              if (topic.topicSummary.isNotEmpty)
                _KindleSummary(
                  summary: topic.topicSummary,
                  p: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),

              if (topic.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 34),
                _KindleKeyPoints(
                  keyPoints: topic.keyPoints,
                  p: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              ],

              if (topic.quiz.isNotEmpty) ...[
                const SizedBox(height: 34),
                _KindleQuizSection(
                  questions: topic.quiz,
                  p: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              ],

              const SizedBox(height: 40),

              // ── Pull-up to next unit ──
              if (widget.onSwipeNext != null)
                GestureDetector(
                  onTap: widget.onSwipeNext,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: triggered ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: triggered
                                  ? p.accent.withValues(alpha: 0.18)
                                  : p.textTertiary.withValues(alpha: 0.10),
                            ),
                            child: AnimatedRotation(
                              turns: triggered ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Icon(Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: triggered ? p.accent : p.textTertiary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          triggered ? 'Release for next unit' : 'Next unit',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: triggered ? p.accent : p.textTertiary,
                            letterSpacing: 0.3,
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
// PARAGRAPH — justified, drop-cap on first
// ════════════════════════════════════════════════════════════════════════

class _KindleParagraph extends StatelessWidget {
  final ParagraphModel paragraph;
  final bool isFirst;
  final ReaderPalette p;
  final double fontSize;
  final double lineHeight;

  const _KindleParagraph({
    required this.paragraph,
    required this.isFirst,
    required this.p,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.literata(
      fontSize: fontSize + 2,
      color: p.text,
      height: lineHeight * 1.1,
      letterSpacing: 0.05,
      fontWeight: FontWeight.w400,
    );

    Widget content;
    if (isFirst && paragraph.text.isNotEmpty) {
      final first = paragraph.text[0];
      final rest = paragraph.text.substring(1);
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 4),
            child: Text(
              first,
              style: GoogleFonts.literata(
                fontSize: (fontSize + 2) * 3.2,
                fontWeight: FontWeight.w700,
                color: p.accent,
                height: 0.8,
              ),
            ),
          ),
          Expanded(child: Text(rest, textAlign: TextAlign.justify, style: body)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: p.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _SheetAction(
              icon: Icons.copy_rounded,
              label: 'Copy',
              p: p,
              onTap: () {
                Clipboard.setData(ClipboardData(text: paragraph.text));
                Navigator.pop(context);
              },
            ),
            _SheetAction(
              icon: Icons.bookmark_outline_rounded,
              label: 'Bookmark',
              p: p,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final ReaderPalette p;
  final VoidCallback onTap;
  const _SheetAction(
      {required this.icon,
      required this.label,
      required this.p,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.accent),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SUMMARY
// ════════════════════════════════════════════════════════════════════════

class _KindleSummary extends StatelessWidget {
  final String summary;
  final ReaderPalette p;
  final double fontSize;
  final double lineHeight;

  const _KindleSummary({
    required this.summary,
    required this.p,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUMMARY',
          style: GoogleFonts.nunitoSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: p.accent,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 18),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.6),
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
                    color: p.textSecondary,
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
// KEY POINTS
// ════════════════════════════════════════════════════════════════════════

class _KindleKeyPoints extends StatelessWidget {
  final List<String> keyPoints;
  final ReaderPalette p;
  final double fontSize;
  final double lineHeight;

  const _KindleKeyPoints({
    required this.keyPoints,
    required this.p,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEY LEARNINGS',
          style: GoogleFonts.nunitoSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: p.textTertiary,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 18),
        ...keyPoints.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      '${e.key + 1}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        e.value,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.literata(
                          fontSize: fontSize,
                          color: p.text,
                          height: lineHeight,
                          letterSpacing: 0.05,
                        ),
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
// QUIZ SECTION
// ════════════════════════════════════════════════════════════════════════

class _KindleQuizSection extends StatelessWidget {
  final List<QuizQuestion> questions;
  final ReaderPalette p;
  final double fontSize;
  final double lineHeight;

  const _KindleQuizSection({
    required this.questions,
    required this.p,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPREHENSION',
          style: GoogleFonts.nunitoSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: p.textTertiary,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 18),
        KindleQuizWidget(
          key: ValueKey('quiz_${questions.hashCode}'),
          questions: questions,
          p: p,
          fontSize: fontSize,
          lineHeight: lineHeight,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// QUIZ WIDGET — stateful
// ════════════════════════════════════════════════════════════════════════

class KindleQuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final ReaderPalette p;
  final double fontSize;
  final double lineHeight;

  const KindleQuizWidget({
    super.key,
    required this.questions,
    required this.p,
    required this.fontSize,
    required this.lineHeight,
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

  static const _correctColor = Color(0xFF4E9A6B);
  static const _wrongColor = Color(0xFFC25B5B);

  void _pick(String option) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = option;
      _answered = true;
      if (option == widget.questions[_idx].answer) _correct++;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_idx < widget.questions.length - 1) {
        setState(() {
          _idx++;
          _selected = null;
          _answered = false;
        });
      } else {
        setState(() => _done = true);
      }
    });
  }

  void _reset() => setState(() {
        _idx = 0;
        _selected = null;
        _answered = false;
        _done = false;
        _correct = 0;
      });

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    if (_done) return _buildResult(p);
    final q = widget.questions[_idx];
    final letters = ['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${_idx + 1} of ${widget.questions.length}',
          style: GoogleFonts.nunitoSans(
              fontSize: 11, color: p.textTertiary, letterSpacing: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          q.question,
          textAlign: TextAlign.justify,
          style: GoogleFonts.literata(
            fontSize: widget.fontSize + 1,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: widget.lineHeight,
          ),
        ),
        const SizedBox(height: 18),
        ...q.options.asMap().entries.map((e) {
          final letter = e.key < letters.length ? letters[e.key] : '${e.key + 1}';
          final opt = e.value;
          final isSelected = _selected == opt;
          final isCorrect = opt == q.answer;

          Color borderColor;
          Color bgColor;
          Color labelColor;

          if (!_answered) {
            bgColor = p.surface;
            borderColor = p.border;
            labelColor = p.text;
          } else if (isCorrect) {
            bgColor = _correctColor.withValues(alpha: 0.12);
            borderColor = _correctColor.withValues(alpha: 0.5);
            labelColor = _correctColor;
          } else if (isSelected) {
            bgColor = _wrongColor.withValues(alpha: 0.12);
            borderColor = _wrongColor.withValues(alpha: 0.5);
            labelColor = _wrongColor;
          } else {
            bgColor = p.surface.withValues(alpha: 0.4);
            borderColor = p.border.withValues(alpha: 0.5);
            labelColor = p.textTertiary;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _pick(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
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
                            fontWeight: FontWeight.w800,
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

  Widget _buildResult(ReaderPalette p) {
    final total = widget.questions.length;
    final pct = ((_correct / total) * 100).round();
    final emoji = pct >= 80 ? '🎉' : pct >= 50 ? '👏' : '💪';
    final msg = pct >= 80
        ? 'Excellent mastery!'
        : pct >= 50
            ? 'Good understanding.'
            : 'Keep studying — you will get there.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 0.8),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            '$_correct / $total',
            style: GoogleFonts.literata(
              fontSize: widget.fontSize + 8,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            style: GoogleFonts.literata(
              fontSize: widget.fontSize - 1,
              fontStyle: FontStyle.italic,
              color: p.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.accent,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
