import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../models/book_models.dart';
import 'reader_palette.dart';

/// Full-card chapter tile — premium ebook style.
/// Every chapter (including locked/coming-soon) is tappable.
class ChapterCard extends StatefulWidget {
  final ChapterModel chapter;
  final ReaderPalette p;
  final VoidCallback onTap;
  final int index; // 0-based position for display number

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.p,
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
    final p = widget.p;
    final locked = !ch.hasContent;

    final int minutes = _estimateMinutes(ch);
    final String chapterNum = (widget.index + 1).toString().padLeft(2, '0');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: locked ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Chapter number badge ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: locked
                        ? p.textTertiary.withValues(alpha: 0.10)
                        : p.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapterNum,
                    style: GoogleFonts.literata(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: locked ? p.textTertiary : p.accent,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Title + meta ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch.title,
                        style: GoogleFonts.literata(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                          height: 1.32,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (ch.hasContent)
                        Text(
                          '${ch.totalTopics} unit${ch.totalTopics != 1 ? 's' : ''}  ·  $minutes min read',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.textTertiary,
                            letterSpacing: 0.1,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 12, color: p.textTertiary),
                            const SizedBox(width: 5),
                            Text(
                              'Coming soon',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.textTertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: locked
                      ? p.textTertiary.withValues(alpha: 0.4)
                      : p.textTertiary,
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
