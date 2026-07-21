import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';
import '../providers/reader_settings_provider.dart';

/// Single topic page with vertical scroll, themed by the active [ReaderPalette].
class KindleTopicPage extends StatefulWidget {
  final TopicModel topic;
  final ReaderPalette palette;
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
    required this.palette,
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
  // Looser, lower-effort pull: a short tug past the end is enough.
  static const double _overscrollThreshold = 52.0;
  bool _triggered = false;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels > notification.metrics.maxScrollExtent) {
        final newOverscroll =
            notification.metrics.pixels - notification.metrics.maxScrollExtent;
        if (newOverscroll >= _overscrollThreshold &&
            _overscroll < _overscrollThreshold) {
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
          widget.onSwipeNext!();
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final p = widget.palette;
    final fontSize = widget.fontSize;
    final lineHeight = widget.lineHeight;
    const double hPad = 28;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -280 && widget.onSwipeNext != null) {
          widget.onSwipeNext!();
        }
        if (d.primaryVelocity! > 280 && widget.onSwipePrev != null) {
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
            padding: EdgeInsets.fromLTRB(hPad,
                MediaQuery.paddingOf(context).top + 64,
                hPad,
                MediaQuery.paddingOf(context).bottom + 104),
            children: [
              // ── Chapter label ──
              Text(
                widget.chapterTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: p.accent.withValues(alpha: 0.8),
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 34),

              // ── Topic title (big centred serif) ──
              Text(
                topic.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: fontSize + 8,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),

              // ── Decorative rule ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: p.divider, thickness: 0.8)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('✦',
                          style: TextStyle(
                              color: p.accent.withValues(alpha: 0.6),
                              fontSize: 11)),
                    ),
                    Expanded(
                        child: Divider(
                            color: p.divider, thickness: 0.8)),
                  ],
                ),
              ),

              // ── Paragraphs ──
              ...topic.paragraphs.asMap().entries.map((e) => _KindleParagraph(
                    paragraph: e.value,
                    isFirst: e.key == 0,
                    palette: p,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                  )),

              if (topic.topicSummary.isNotEmpty ||
                  topic.keyPoints.isNotEmpty ||
                  topic.quiz.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Divider(color: p.divider, thickness: 0.8),
                ),

              // ── AI-generated study aids disclaimer ──
              // The paragraphs above are transcribed from the book; the
              // summary, key learnings and quiz below are AI-generated.
              if (topic.topicSummary.isNotEmpty ||
                  topic.keyPoints.isNotEmpty ||
                  topic.quiz.isNotEmpty)
                _AiDisclaimer(p: p),

              if (topic.topicSummary.isNotEmpty)
                _KindleSummary(
                  summary: topic.topicSummary,
                  palette: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),

              if (topic.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 32),
                _KindleKeyPoints(
                  keyPoints: topic.keyPoints,
                  palette: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              ],

              if (topic.quiz.isNotEmpty) ...[
                const SizedBox(height: 32),
                _KindleQuizSection(
                  questions: topic.quiz,
                  palette: p,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              ],

              const SizedBox(height: 40),

              // ── Pull-to-next affordance: a ring that fills as you tug ──
              if (widget.onSwipeNext != null)
                _pullAffordance(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pullAffordance(ReaderPalette p) {
    final progress = (_overscroll / _overscrollThreshold).clamp(0.0, 1.0);
    final ready = progress >= 1.0;
    // Subtle at rest, prominent as the pull deepens.
    final appear = (0.45 + progress * 0.55).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSwipeNext,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 40),
        child: Opacity(
          opacity: appear,
          child: Column(
            children: [
              Transform.scale(
                scale: 0.9 + progress * 0.22,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.2,
                          backgroundColor: p.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              ready ? p.accent : p.accent.withValues(alpha: 0.85)),
                        ),
                      ),
                      AnimatedRotation(
                        turns: ready ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        child: Icon(Icons.arrow_upward_rounded,
                            size: 17, color: ready ? p.accent : p.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: ready ? FontWeight.w700 : FontWeight.w600,
                  color: ready ? p.accent : p.textFaint,
                  letterSpacing: 0.4,
                ),
                child: Text(ready ? 'Release' : 'Pull up for next unit'),
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
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;

  const _KindleParagraph({
    required this.paragraph,
    required this.isFirst,
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
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
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Text(
              first,
              style: GoogleFonts.literata(
                fontSize: (fontSize + 2) * 3.4,
                fontWeight: FontWeight.w700,
                color: p.accent,
                height: 0.82,
              ),
            ),
          ),
          Expanded(
              child: Text(rest, textAlign: TextAlign.justify, style: body)),
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
    final p = palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: p.textFaint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, size: 20, color: p.accent),
              title: Text('Copy',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: paragraph.text));
                Navigator.pop(context);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              dense: true,
            ),
            ListTile(
              leading:
                  Icon(Icons.bookmark_border_rounded, size: 20, color: p.accent),
              title: Text('Bookmark',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
              onTap: () => Navigator.pop(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AI-GENERATED CONTENT DISCLAIMER
// Shown above the summary / key learnings / quiz, which — unlike the book
// paragraphs above — are generated by AI and may contain mistakes.
// ════════════════════════════════════════════════════════════════════════

class _AiDisclaimer extends StatelessWidget {
  final ReaderPalette p;
  const _AiDisclaimer({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 34),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.textFaint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.textFaint.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 15, color: p.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The summary, key learnings and quiz below are AI-generated '
              'study aids — not from the book — and may contain mistakes. '
              'Please verify against the text above and authentic sources.',
              style: GoogleFonts.nunitoSans(
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: p.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SUMMARY — accent blockquote
// ════════════════════════════════════════════════════════════════════════

class _KindleSummary extends StatelessWidget {
  final String summary;
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;

  const _KindleSummary({
    required this.summary,
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SUMMARY',
            style: GoogleFonts.nunitoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: p.accent,
                letterSpacing: 2.2)),
        const SizedBox(height: 20),
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
                    color: p.text.withValues(alpha: 0.88),
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
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;

  const _KindleKeyPoints({
    required this.keyPoints,
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KEY LEARNINGS',
            style: GoogleFonts.nunitoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: p.accent,
                letterSpacing: 2.2)),
        const SizedBox(height: 20),
        ...keyPoints.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${e.key + 1}.',
                        style: GoogleFonts.literata(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: p.accent,
                            height: lineHeight)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.literata(
                        fontSize: fontSize,
                        color: p.text.withValues(alpha: 0.9),
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
// QUIZ SECTION
// ════════════════════════════════════════════════════════════════════════

class _KindleQuizSection extends StatelessWidget {
  final List<QuizQuestion> questions;
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;

  const _KindleQuizSection({
    required this.questions,
    required this.palette,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMPREHENSION',
            style: GoogleFonts.nunitoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: p.accent,
                letterSpacing: 2.2)),
        const SizedBox(height: 20),
        KindleQuizWidget(
          key: ValueKey('quiz_${questions.hashCode}'),
          questions: questions,
          palette: p,
          fontSize: fontSize,
          lineHeight: lineHeight,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// QUIZ WIDGET — book-style options (correct/wrong stay green/red)
// ════════════════════════════════════════════════════════════════════════

class KindleQuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final ReaderPalette palette;
  final double fontSize;
  final double lineHeight;

  const KindleQuizWidget({
    super.key,
    required this.questions,
    required this.palette,
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
    final p = widget.palette;
    if (_done) return _buildResult(p);
    final q = widget.questions[_idx];
    final letters = ['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Question ${_idx + 1} of ${widget.questions.length}',
            style: GoogleFonts.nunitoSans(
                fontSize: 11, color: p.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 14),
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
          final letter =
              e.key < letters.length ? letters[e.key] : '${e.key + 1}';
          final opt = e.value;
          final isSelected = _selected == opt;
          final isCorrect = opt == q.answer;

          Color borderColor;
          Color bgColor;
          Color labelColor;

          if (!_answered) {
            bgColor = p.surface;
            borderColor = p.divider;
            labelColor = p.text;
          } else if (isCorrect) {
            bgColor = _correctColor.withValues(alpha: 0.12);
            borderColor = _correctColor.withValues(alpha: 0.45);
            labelColor = _correctColor;
          } else if (isSelected) {
            bgColor = _wrongColor.withValues(alpha: 0.12);
            borderColor = _wrongColor.withValues(alpha: 0.45);
            labelColor = _wrongColor;
          } else {
            bgColor = p.surface.withValues(alpha: 0.4);
            borderColor = p.divider.withValues(alpha: 0.5);
            labelColor = p.text.withValues(alpha: 0.4);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _pick(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  children: [
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
                        child: Text(letter,
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: labelColor)),
                      ),
                    ),
                    Expanded(
                      child: Text(opt,
                          style: GoogleFonts.literata(
                              fontSize: widget.fontSize - 1,
                              color: labelColor,
                              height: 1.4)),
                    ),
                    if (_answered && isCorrect)
                      const Icon(Icons.check_rounded,
                          size: 18, color: _correctColor),
                    if (_answered && isSelected && !isCorrect)
                      const Icon(Icons.close_rounded,
                          size: 18, color: _wrongColor),
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
    final emoji = pct >= 80
        ? '🎉'
        : pct >= 50
            ? '👏'
            : '💪';
    final msg = pct >= 80
        ? 'Excellent mastery!'
        : pct >= 50
            ? 'Good understanding.'
            : 'Keep studying — you will get there.';

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 12),
        Text('$_correct / $total',
            style: GoogleFonts.literata(
                fontSize: widget.fontSize + 8,
                fontWeight: FontWeight.w700,
                color: p.text)),
        const SizedBox(height: 6),
        Text(
          msg,
          style: GoogleFonts.literata(
              fontSize: widget.fontSize - 1,
              fontStyle: FontStyle.italic,
              color: p.textMuted,
              height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _reset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: p.accent.withValues(alpha: 0.5), width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Try Again',
                style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                    letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }
}
