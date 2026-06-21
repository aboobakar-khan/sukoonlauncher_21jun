import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../models/book_models.dart';

/// Full-card chapter tile — premium ebook style.
/// Every chapter (including locked/coming-soon) is tappable.
/// No read/unread status display.
class ChapterCard extends StatefulWidget {
  final ChapterModel chapter;
  final bool isDark;
  final VoidCallback onTap;
  final int index; // 0-based position for display number

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.isDark,
    required this.onTap,
    required this.index,
  });

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;
    final isDark = widget.isDark;
    final locked = !ch.hasContent;

    const gold = Color(0xFFD4A017);
    final textColor =
        isDark ? const Color(0xFFF0EBE1) : const Color(0xFF1C1C1E);
    final mutedText =
        isDark ? const Color(0xFF888580) : const Color(0xFF9B9896);
    final cardBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF5F2EC);
    final cardBorder = isDark
        ? const Color(0xFF222222)
        : const Color(0xFFE4DFD6);

    final int minutes = _estimateMinutes(ch);
    final String chapterNum =
        (widget.index + 1).toString().padLeft(2, '0');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap(); // Always fire — locked chapters handled by caller
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: locked ? 0.50 : (_pressed ? 0.85 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Chapter number badge ──────────────────────────────
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: locked
                        ? mutedText.withValues(alpha: 0.08)
                        : gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapterNum,
                    style: GoogleFonts.literata(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: locked
                          ? mutedText.withValues(alpha: 0.5)
                          : gold.withValues(alpha: 0.85),
                      height: 1,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Title + meta ──────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch.title,
                        style: GoogleFonts.literata(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (ch.hasContent)
                        Text(
                          '${ch.totalTopics} unit${ch.totalTopics != 1 ? 's' : ''}  ·  $minutes min read',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: mutedText,
                            letterSpacing: 0.1,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 11,
                              color: mutedText.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Coming soon',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: mutedText.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // ── Chevron ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: locked
                        ? mutedText.withValues(alpha: 0.2)
                        : mutedText.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _estimateMinutes(ChapterModel ch) {
    try {
      final words = ch.topics
          .expand((t) => t.paragraphs)
          .map((p) => p.text.split(RegExp(r'\s+')))
          .fold<int>(0, (acc, list) => acc + list.length);
      return max(1, (words / 200).ceil());
    } catch (_) {
      return 1;
    }
  }
}
