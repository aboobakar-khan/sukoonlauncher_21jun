import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_models.dart';

/// Self-contained quiz widget: one question at a time, feedback, score.
class QuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final bool isDark;

  const QuizWidget({
    super.key,
    required this.questions,
    required this.isDark,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentIndex = 0;
  int _correctCount = 0;
  String? _selectedAnswer;
  bool _answered = false;
  bool _finished = false;

  @override
  void didUpdateWidget(covariant QuizWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset quiz when questions change (topic switch)
    if (oldWidget.questions != widget.questions) {
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _currentIndex = 0;
      _correctCount = 0;
      _selectedAnswer = null;
      _answered = false;
      _finished = false;
    });
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (answer == widget.questions[_currentIndex].answer) {
        _correctCount++;
      }
    });

    // Auto-advance after 1.2 seconds
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIndex < widget.questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
          _answered = false;
        });
      } else {
        setState(() => _finished = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isDark;
    const gold = Color(0xFFD4A017);
    final textColor =
        isDark ? const Color(0xFFF5F0E8) : const Color(0xFF1C1C1E);
    final mutedText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final surfaceColor = isDark ? const Color(0xFF1A2B22) : Colors.white;
    final cardBg = isDark
        ? const Color(0xFF152019)
        : const Color(0xFFF5F3EF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, size: 18, color: gold),
              const SizedBox(width: 8),
              Text(
                'TEST YOURSELF',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: gold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!_finished)
                Text(
                  '${_currentIndex + 1}/${widget.questions.length}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gold.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_finished)
            _buildScoreCard(textColor, gold, mutedText, surfaceColor)
          else
            _buildQuestion(textColor, gold, mutedText, surfaceColor),
        ],
      ),
    );
  }

  Widget _buildQuestion(
      Color textColor, Color gold, Color mutedText, Color surfaceColor) {
    final q = widget.questions[_currentIndex];
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Text(
          q.question,
          style: GoogleFonts.literata(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),

        // Options
        ...q.options.map((option) {
          final isSelected = _selectedAnswer == option;
          final isCorrect = option == q.answer;
          Color optionBg;
          Color optionBorder;
          Color optionText;

          if (!_answered) {
            optionBg = surfaceColor;
            optionBorder = isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08);
            optionText = textColor;
          } else if (isCorrect) {
            optionBg = const Color(0xFF4CAF50).withValues(alpha: 0.15);
            optionBorder = const Color(0xFF4CAF50).withValues(alpha: 0.5);
            optionText = const Color(0xFF4CAF50);
          } else if (isSelected && !isCorrect) {
            optionBg = const Color(0xFFE53935).withValues(alpha: 0.15);
            optionBorder = const Color(0xFFE53935).withValues(alpha: 0.5);
            optionText = const Color(0xFFE53935);
          } else {
            optionBg = surfaceColor.withValues(alpha: 0.5);
            optionBorder = isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04);
            optionText = textColor.withValues(alpha: 0.4);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _selectAnswer(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: optionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: optionBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: optionText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_answered && isCorrect)
                      const Icon(Icons.check_circle_rounded,
                          size: 20, color: Color(0xFF4CAF50)),
                    if (_answered && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded,
                          size: 20, color: Color(0xFFE53935)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScoreCard(
      Color textColor, Color gold, Color mutedText, Color surfaceColor) {
    final total = widget.questions.length;
    final score = _correctCount;
    final percent = (score / total * 100).round();
    final emoji = percent >= 80
        ? '🎉'
        : percent >= 50
            ? '👏'
            : '💪';

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          emoji,
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(height: 12),
        Text(
          '$score/$total Correct',
          style: GoogleFonts.nunitoSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          percent >= 80
              ? 'Excellent mastery!'
              : percent >= 50
                  ? 'Good understanding!'
                  : 'Keep studying, you\'ll get there!',
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            color: mutedText,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: gold.withValues(alpha: 0.4)),
              ),
            ),
            child: Text(
              'Retry Quiz',
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: gold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
