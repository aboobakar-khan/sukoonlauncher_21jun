import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/saved_verses_provider.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/theme_provider.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Saved Verses Screen — displays bookmarked verses from "Verse of the Moment"
class SavedVersesScreen extends ConsumerWidget {
  const SavedVersesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verses = ref.watch(savedVersesProvider);
    final arabicFont = ref.watch(arabicFontProvider);
    final accent = ref.watch(themeColorProvider).color;

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, accent, verses.length),
              Expanded(
                child: verses.isEmpty
                    ? _buildEmptyState(accent)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: verses.length,
                        itemBuilder: (context, index) => _buildVerseCard(
                          context, ref, verses[index], arabicFont, accent,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accent, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Verses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count verse${count == 1 ? '' : 's'} saved',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.bookmark_rounded, color: accent.withValues(alpha: 0.5), size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded,
              color: accent.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: 14),
          Text(
            'No saved verses yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the bookmark icon on\n"Verse of the Moment" to save',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard(
    BuildContext context,
    WidgetRef ref,
    SavedVerse verse,
    dynamic arabicFont,
    Color accent,
  ) {
    return Dismissible(
      key: ValueKey(verse.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(savedVersesProvider.notifier).removeVerse(verse.key);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: Colors.red.withValues(alpha: 0.6), size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arabic text
            Text(
              verse.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 20,
                height: 1.85,
                fontFamily: arabicFont.fontFamily,
              ),
            ),
            if (verse.translation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                verse.translation,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Footer
            Row(
              children: [
                Text(
                  '${verse.surahName} ${verse.verseNumber}',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    TafseerBottomSheet.show(
                      context,
                      surahId: verse.surahId,
                      ayahId: verse.verseNumber,
                      surahName: verse.surahName,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 12, color: accent.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'Tafseer',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
