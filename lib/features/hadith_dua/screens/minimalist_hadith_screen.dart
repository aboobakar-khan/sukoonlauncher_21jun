import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../utils/hive_box_manager.dart';

// ═══════════════════════════════════════════════════════════════════════
//  READ TRACKING
// ═══════════════════════════════════════════════════════════════════════

final readHadithsProvider = StateNotifierProvider<ReadHadithsNotifier, Set<String>>((ref) {
  return ReadHadithsNotifier();
});

class ReadHadithsNotifier extends StateNotifier<Set<String>> {
  static const String _boxName = 'read_hadiths';
  Box<String>? _box;

  ReadHadithsNotifier() : super({}) { _init(); }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get('read_list');
    if (saved != null) {
      state = saved.split(',').where((s) => s.isNotEmpty).toSet();
    }
  }

  String _getKey(Hadith hadith) => '${hadith.collection}_${hadith.hadithNumber}';
  bool isRead(Hadith hadith) => state.contains(_getKey(hadith));

  void toggleRead(Hadith hadith) {
    final key = _getKey(hadith);
    if (state.contains(key)) {
      state = Set.from(state)..remove(key);
    } else {
      state = Set.from(state)..add(key);
    }
    _save();
  }

  void markAsRead(Hadith hadith) {
    final key = _getKey(hadith);
    if (!state.contains(key)) {
      state = Set.from(state)..add(key);
      _save();
    }
  }

  Future<void> _save() async {
    await _box?.put('read_list', state.join(','));
  }

  int get readCount => state.length;
}

// ═══════════════════════════════════════════════════════════════════════
//  NAVIGATION STATE — Progressive Disclosure
//  Depth 0 = Book Library    →  user picks a collection
//  Depth 1 = Chapter List    →  user picks a chapter / kitab
//  Depth 2 = Hadith List     →  user reads hadiths
// ═══════════════════════════════════════════════════════════════════════

final hadithNavDepthProvider = StateProvider<int>((ref) => 0);
final selectedChapterProvider = StateProvider<HadithChapter?>((ref) => null);
final hadithPageProvider = StateProvider<int>((ref) => 1);
const int _pageSize = 20;

// ── Providers ──

/// Full HadithChapter objects for the selected book
final bookChaptersProvider = FutureProvider<List<HadithChapter>>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  final collectionId = ref.watch(selectedCollectionProvider);
  final collection = HadithCollection.fromId(collectionId);
  return service.getChapters(collection);
});

/// Hadiths for the selected chapter (or all if null)
final chapterHadithsProvider = FutureProvider<List<Hadith>>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  final collectionId = ref.watch(selectedCollectionProvider);
  final chapter = ref.watch(selectedChapterProvider);
  final collection = HadithCollection.fromId(collectionId);
  final gradeFilter = ref.watch(selectedGradeFilterProvider);
  // Watch language so that changing it invalidates this provider and re-fetches
  final lang = ref.watch(hadithLanguageProvider);

  var hadiths = await service.fetchHadiths(
    collection,
    chapterId: chapter?.chapterNumber,
    maxPages: 10,
    language: lang.code,
  );

  if (hadiths.isEmpty) {
    hadiths = await _offlineHadiths(collectionId);
    if (chapter != null) {
      hadiths = hadiths.where((h) => h.book == chapter.chapterNumber).toList();
    }
  }

  if (gradeFilter != null) {
    hadiths = hadiths.where((h) => h.grade == gradeFilter).toList();
  }
  return hadiths;
});

Future<List<Hadith>> _offlineHadiths(String? collectionId) async {
  try {
    final box = await HiveBoxManager.get<String>('offline_content_v2');
    final cached = box.get('hadith_cache');
    if (cached == null) return [];
    final list = jsonDecode(cached) as List<dynamic>;
    var hadiths = list.map((json) {
      final map = json as Map<String, dynamic>;
      return Hadith(
        hadithNumber: map['hadithNumber'] as int? ?? 0,
        arabicNumber: map['arabicNumber'] as int? ?? 0,
        text: map['text'] as String? ?? '',
        arabicText: map['arabicText'] as String?,
        narrator: map['narrator'] as String?,
        collection: map['collection'] as String? ?? 'Unknown',
        book: map['book'] as int? ?? 0,
        hadithInBook: map['hadithInBook'] as int? ?? 0,
        section: map['section'] as String?,
        chapterName: map['chapterName'] as String?,
        grade: map['grade'] != null
            ? HadithGrade.values.firstWhere((g) => g.name == map['grade'], orElse: () => HadithGrade.unknown)
            : HadithGrade.unknown,
      );
    }).toList();
    if (collectionId != null) {
      final cl = collectionId.toLowerCase();
      hadiths = hadiths.where((h) =>
          h.collection.toLowerCase().contains(cl) || cl.contains(h.collection.toLowerCase())).toList();
    }
    return hadiths;
  } catch (_) {}
  return [];
}

// ═══════════════════════════════════════════════════════════════════════
//  MAIN SCREEN — orchestrates the 3 navigation depths
// ═══════════════════════════════════════════════════════════════════════

class MinimalistHadithScreen extends ConsumerWidget {
  const MinimalistHadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(hadithNavDepthProvider);
    final tc = ref.watch(islamicThemeColorsProvider);

    return PopScope(
      // canPop = true only when already at depth 0 (let the route pop back to Islamic Hub)
      canPop: depth == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // depth == 0, route already popped
        // Step back one depth
        if (depth == 2) {
          ref.read(hadithNavDepthProvider.notifier).state = 1;
        } else if (depth == 1) {
          ref.read(hadithNavDepthProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(depth),
            child: switch (depth) {
              0 => _BookLibrary(tc: tc),
              1 => _ChapterList(tc: tc),
              2 => _HadithListView(tc: tc),
              _ => _BookLibrary(tc: tc),
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DEPTH 0 — BOOK LIBRARY  (the home view — collection cards)
// ═══════════════════════════════════════════════════════════════════════

class _BookLibrary extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _BookLibrary({required this.tc});

  static const _bookEmojis = {
    'bukhari': '📕', 'muslim': '📗', 'abudawud': '📘',
    'tirmidhi': '📙', 'nasai': '📓', 'ibnmajah': '📔',
  };
  static const _bookDescs = {
    'bukhari': 'Most authentic collection of Hadith',
    'muslim': 'Second most authentic collection',
    'abudawud': 'Focused on Islamic jurisprudence',
    'tirmidhi': 'Includes jurisprudence & commentary',
    'nasai': 'Strict criteria for authentication',
    'ibnmajah': 'Comprehensive legal traditions',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readCount = ref.watch(readHadithsProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_stories_rounded, color: tc.green.withValues(alpha: 0.6), size: 20),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hadith Library',
                  style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 20,
                      fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              Text('Six Authentic Collections',
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11,
                      fontWeight: FontWeight.w400, letterSpacing: 0.3)),
            ]),
            const Spacer(),
            if (readCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: tc.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline_rounded, color: tc.green.withValues(alpha: 0.5), size: 13),
                  const SizedBox(width: 4),
                  Text('$readCount',
                      style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),

        const SizedBox(height: 8),

        // ── Daily Hadith ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DailyHadithCard(tc: tc),
        ),

        const SizedBox(height: 14),

        // ── Section label ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text('COLLECTIONS',
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ),

        // ── Book list ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            itemCount: HadithCollection.collections.length,
            itemBuilder: (context, i) {
              final c = HadithCollection.collections[i];
              return _BookCard(
                collection: c,
                emoji: _bookEmojis[c.id] ?? '📖',
                description: _bookDescs[c.id] ?? '',
                tc: tc,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedCollectionProvider.notifier).state = c.id;
                  ref.read(selectedChapterProvider.notifier).state = null;
                  ref.read(hadithPageProvider.notifier).state = 1;
                  ref.read(hadithNavDepthProvider.notifier).state = 1;
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Daily Hadith highlight card ──

class _DailyHadithCard extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _DailyHadithCard({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyHadithProvider);

    return dailyAsync.when(
      data: (hadith) {
        if (hadith == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () {
            ref.read(readHadithsProvider.notifier).markAsRead(hadith);
            Navigator.of(context, rootNavigator: true).push(
              PageRouteBuilder(
                fullscreenDialog: true,
                transitionDuration: const Duration(milliseconds: 350),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                pageBuilder: (context, animation, _) => HadithReaderScreen(hadith: hadith),
                transitionsBuilder: (context, animation, _, child) =>
                    FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [tc.green.withValues(alpha: 0.06), tc.accent.withValues(alpha: 0.04)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.green.withValues(alpha: 0.10)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.wb_sunny_rounded, color: tc.accent.withValues(alpha: 0.5), size: 14),
                const SizedBox(width: 6),
                Text("Today's Hadith",
                    style: TextStyle(color: tc.accent.withValues(alpha: 0.7), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const Spacer(),
                Text(hadith.collection,
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 10)),
              ]),
              const SizedBox(height: 10),
              Text(
                hadith.text.length > 160 ? '${hadith.text.substring(0, 160)}…' : hadith.text,
                style: TextStyle(color: tc.text.withValues(alpha: 0.7), fontSize: 13.5, height: 1.55),
                maxLines: 3, overflow: TextOverflow.ellipsis,
              ),
              if (hadith.extractedNarrator != null) ...[
                const SizedBox(height: 6),
                Text('— ${hadith.extractedNarrator}',
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        );
      },
      loading: () => Container(
        height: 76,
        decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
        child: Center(child: SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.green.withValues(alpha: 0.3)))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Book Card ──

class _BookCard extends StatelessWidget {
  final HadithCollection collection;
  final String emoji;
  final String description;
  final IslamicThemeColors tc;
  final VoidCallback onTap;

  const _BookCard({required this.collection, required this.emoji,
    required this.description, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(collection.name,
                  style: TextStyle(color: tc.text.withValues(alpha: 0.8), fontSize: 14,
                      fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text(collection.arabicName,
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 12, fontFamily: 'Amiri')),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (collection.defaultGrade == HadithGrade.sahih)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: tc.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                child: Text('Sahih', style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 6),
            Text('${(collection.totalHadiths / 1000).toStringAsFixed(1)}k',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.25), fontSize: 11)),
            const SizedBox(height: 4),
            Icon(Icons.chevron_right_rounded, color: tc.textSecondary.withValues(alpha: 0.2), size: 20),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DEPTH 1 — CHAPTER LIST  (kitabs within a collection)
// ═══════════════════════════════════════════════════════════════════════

class _ChapterList extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _ChapterList({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionId = ref.watch(selectedCollectionProvider);
    final collection = HadithCollection.fromId(collectionId);
    final chaptersAsync = ref.watch(bookChaptersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(hadithNavDepthProvider.notifier).state = 0;
              },
              icon: Icon(Icons.arrow_back_rounded, color: tc.text.withValues(alpha: 0.6), size: 22),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(collection.name,
                  style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 18,
                      fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              Text(collection.arabicName,
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.35), fontSize: 12, fontFamily: 'Amiri')),
            ])),
            // "All Hadiths" shortcut
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(selectedChapterProvider.notifier).state = null;
                ref.read(hadithPageProvider.notifier).state = 1;
                ref.read(hadithNavDepthProvider.notifier).state = 2;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: tc.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.list_rounded, color: tc.green.withValues(alpha: 0.5), size: 14),
                  const SizedBox(width: 4),
                  Text('All', style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 6),

        // ── Info bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.menu_book_rounded, color: tc.accent.withValues(alpha: 0.4), size: 15),
              const SizedBox(width: 8),
              Text('Chapters / Kitabs',
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.45), fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              chaptersAsync.when(
                data: (ch) => Text('${ch.length} chapters',
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 11)),
                loading: () => SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1, color: tc.green.withValues(alpha: 0.3))),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 6),

        // ── Chapter list ──
        Expanded(
          child: chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) {
                return _CenteredMessage(
                  icon: Icons.cloud_off_rounded,
                  message: 'Could not load chapters',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(bookChaptersProvider),
                  tc: tc,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final ch = chapters[i];
                  return _ChapterCard(
                    chapter: ch, index: i, tc: tc,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedChapterProvider.notifier).state = ch;
                      ref.read(hadithPageProvider.notifier).state = 1;
                      ref.read(hadithNavDepthProvider.notifier).state = 2;
                    },
                  );
                },
              );
            },
            loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.green.withValues(alpha: 0.4))),
              const SizedBox(height: 12),
              Text('Loading chapters…', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 12)),
            ])),
            error: (_, __) => _CenteredMessage(
              icon: Icons.error_outline, message: 'Failed to load chapters',
              actionLabel: 'Retry', onAction: () => ref.invalidate(bookChaptersProvider), tc: tc,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chapter Card ──

class _ChapterCard extends StatelessWidget {
  final HadithChapter chapter;
  final int index;
  final IslamicThemeColors tc;
  final VoidCallback onTap;
  const _ChapterCard({required this.chapter, required this.index, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.surface.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          // Number badge
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('${chapter.chapterNumber}',
                style: TextStyle(color: tc.accent.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chapter.chapterEnglish,
                style: TextStyle(color: tc.text.withValues(alpha: 0.75), fontSize: 13,
                    fontWeight: FontWeight.w500, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (chapter.chapterArabic.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(chapter.chapterArabic,
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 12, fontFamily: 'Amiri'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
            ],
          ])),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: tc.textSecondary.withValues(alpha: 0.18), size: 20),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DEPTH 2 — HADITH LIST (within a chapter or entire book)
// ═══════════════════════════════════════════════════════════════════════

class _HadithListView extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _HadithListView({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(selectedChapterProvider);
    final collectionId = ref.watch(selectedCollectionProvider);
    final collection = HadithCollection.fromId(collectionId);
    final hadithsAsync = ref.watch(chapterHadithsProvider);
    final currentPage = ref.watch(hadithPageProvider);
    final gradeFilter = ref.watch(selectedGradeFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(hadithNavDepthProvider.notifier).state = 1;
              },
              icon: Icon(Icons.arrow_back_rounded, color: tc.text.withValues(alpha: 0.6), size: 22),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                chapter != null ? chapter.chapterEnglish : collection.shortName,
                style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 16,
                    fontWeight: FontWeight.w600, letterSpacing: -0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                chapter != null
                    ? '${collection.shortName} · Chapter ${chapter.chapterNumber}'
                    : 'All Hadiths',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11),
              ),
            ])),
          ]),
        ),

        // ── Grade filter pills ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Pill(label: 'All Grades', isSelected: gradeFilter == null, tc: tc,
                    onTap: () { HapticFeedback.selectionClick(); ref.read(selectedGradeFilterProvider.notifier).state = null; }),
                ...HadithGrade.values.where((g) => g != HadithGrade.unknown).map((g) => _Pill(
                  label: g.displayName, isSelected: gradeFilter == g,
                  tc: tc, color: Color(g.colorValue),
                  onTap: () { HapticFeedback.selectionClick();
                    ref.read(selectedGradeFilterProvider.notifier).state = gradeFilter == g ? null : g; },
                )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),

        // ── Hadith list ──
        Expanded(
          child: hadithsAsync.when(
            data: (hadiths) {
              if (hadiths.isEmpty) {
                return _CenteredMessage(icon: Icons.auto_stories_rounded,
                    message: 'No hadiths found', sub: 'Try a different filter or check connection',
                    actionLabel: 'Retry', onAction: () => ref.invalidate(chapterHadithsProvider), tc: tc);
              }
              final displayCount = currentPage * _pageSize;
              final displayed = hadiths.take(displayCount).toList();
              final hasMore = displayCount < hadiths.length;
              final remaining = hadiths.length - displayCount;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: displayed.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == displayed.length) {
                    return _LoadMoreButton(remaining: remaining, tc: tc,
                        onTap: () { HapticFeedback.lightImpact(); ref.read(hadithPageProvider.notifier).state++; });
                  }
                  return _HadithCard(hadith: displayed[index], allHadiths: hadiths, tc: tc);
                },
              );
            },
            loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.green.withValues(alpha: 0.4))),
              const SizedBox(height: 12),
              Text('Loading hadiths…', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 12)),
            ])),
            error: (_, __) => _CenteredMessage(icon: Icons.error_outline,
                message: 'Failed to load hadiths', actionLabel: 'Try Again',
                onAction: () => ref.invalidate(chapterHadithsProvider), tc: tc),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SHARED UI ATOMS
// ═══════════════════════════════════════════════════════════════════════

class _Pill extends StatelessWidget {
  final String label; final bool isSelected; final IslamicThemeColors tc;
  final Color? color; final VoidCallback onTap;
  const _Pill({required this.label, required this.isSelected, required this.tc, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? tc.green;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.10) : tc.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? c.withValues(alpha: 0.25) : tc.surface.withValues(alpha: 0.5),
              width: isSelected ? 1.0 : 0.6),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? c.withValues(alpha: 0.8) : tc.textSecondary.withValues(alpha: 0.4),
                fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final int remaining; final IslamicThemeColors tc; final VoidCallback onTap;
  const _LoadMoreButton({required this.remaining, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.green.withValues(alpha: 0.10))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.expand_more_rounded, color: tc.green.withValues(alpha: 0.4), size: 18),
            const SizedBox(width: 6),
            Text('Load More ($remaining remaining)',
                style: TextStyle(color: tc.green.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon; final String message; final String? sub;
  final String? actionLabel; final VoidCallback? onAction; final IslamicThemeColors tc;
  const _CenteredMessage({required this.icon, required this.message, this.sub,
    this.actionLabel, this.onAction, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: tc.textSecondary.withValues(alpha: 0.12), size: 48),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 13)),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!, style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.22), fontSize: 11)),
      ],
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: Text(actionLabel!, style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 12)),
          ),
        ),
      ],
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HADITH CARD — compact preview
// ═══════════════════════════════════════════════════════════════════════

class _HadithCard extends ConsumerWidget {
  final Hadith hadith;
  final List<Hadith> allHadiths;
  final IslamicThemeColors tc;
  const _HadithCard({required this.hadith, required this.allHadiths, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select(
        (s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    return GestureDetector(
      onTap: () => _openReader(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? tc.surface.withValues(alpha: 0.45) : tc.surface.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRead ? tc.green.withValues(alpha: 0.10) : tc.surface.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: number + grade + read
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: tc.accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(5)),
              child: Text('#${hadith.hadithNumber}',
                  style: TextStyle(color: tc.accent.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            if (hadith.grade != HadithGrade.unknown) ...[
              const SizedBox(width: 6),
              _GradeBadge(grade: hadith.grade, tc: tc),
            ],
            const Spacer(),
            if (isRead) Icon(Icons.check_circle_rounded, color: tc.green.withValues(alpha: 0.3), size: 14),
          ]),
          if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(hadith.chapterName!,
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.28), fontSize: 10.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(
            hadith.text.length > 150 ? '${hadith.text.substring(0, 150)}…' : hadith.text,
            style: TextStyle(color: tc.text.withValues(alpha: 0.65), fontSize: 13.5, height: 1.55),
            maxLines: 3, overflow: TextOverflow.ellipsis,
          ),
          if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
            const SizedBox(height: 6),
            Text('— ${hadith.narrator ?? hadith.extractedNarrator ?? ''}',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.28), fontSize: 10.5,
                    fontStyle: FontStyle.italic),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  void _openReader(BuildContext context, WidgetRef ref) {
    ref.read(readHadithsProvider.notifier).markAsRead(hadith);
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, _) =>
            HadithReaderScreen(hadith: hadith, allHadiths: allHadiths),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final HadithGrade grade; final IslamicThemeColors tc;
  const _GradeBadge({required this.grade, required this.tc});

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      HadithGrade.sahih => tc.green,
      HadithGrade.hasan => const Color(0xFF00796B),
      HadithGrade.daif => const Color(0xFFE65100),
      _ => tc.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
      child: Text(grade.displayName,
          style: TextStyle(color: color.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  READER PREFERENCES  (persisted in memory — extend to Hive if needed)
// ═══════════════════════════════════════════════════════════════════════

class _ReaderPrefs {
  final bool showArabic;
  final bool showMetadata;
  final double fontSize;       // translation font size multiplier
  final double arabicFontSize; // arabic font size
  const _ReaderPrefs({
    this.showArabic = false,
    this.showMetadata = true,
    this.fontSize = 17,
    this.arabicFontSize = 24,
  });
  _ReaderPrefs copyWith({bool? showArabic, bool? showMetadata,
      double? fontSize, double? arabicFontSize}) => _ReaderPrefs(
    showArabic: showArabic ?? this.showArabic,
    showMetadata: showMetadata ?? this.showMetadata,
    fontSize: fontSize ?? this.fontSize,
    arabicFontSize: arabicFontSize ?? this.arabicFontSize,
  );
}

final _readerPrefsProvider = StateProvider<_ReaderPrefs>((ref) => const _ReaderPrefs());

// ═══════════════════════════════════════════════════════════════════════
//  HADITH READER — immersive swipeable reading experience
// ═══════════════════════════════════════════════════════════════════════

class HadithReaderScreen extends ConsumerStatefulWidget {
  final Hadith hadith;
  final List<Hadith>? allHadiths;
  const HadithReaderScreen({super.key, required this.hadith, this.allHadiths});

  @override
  ConsumerState<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends ConsumerState<HadithReaderScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allHadiths?.indexWhere((h) =>
        h.hadithNumber == widget.hadith.hadithNumber &&
        h.collection == widget.hadith.collection) ?? 0;
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  void _openSettings(BuildContext context, IslamicThemeColors tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReaderSettingsSheet(tc: tc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hadiths = widget.allHadiths ?? [widget.hadith];
    final tc = ref.watch(islamicThemeColorsProvider);
    final currentHadith = hadiths[_currentIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: tc.background,
        statusBarIconBrightness: tc.statusBarBrightness,
        systemNavigationBarColor: tc.background,
        systemNavigationBarIconBrightness: tc.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(children: [
            // ── Top bar ──
            _ReaderTopBar(
              hadith: currentHadith,
              onClose: () => Navigator.pop(context),
              onSettings: () => _openSettings(context, tc),
            ),
            // ── Progress bar ──
            if (hadiths.length > 1)
              _ProgressBar(current: _currentIndex, total: hadiths.length, tc: tc),
            // ── Page content ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: hadiths.length,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  HapticFeedback.selectionClick();
                  ref.read(readHadithsProvider.notifier).markAsRead(hadiths[i]);
                },
                itemBuilder: (_, i) => _HadithPage(hadith: hadiths[i], totalInChapter: hadiths.length),
              ),
            ),
            // ── Bottom action bar ──
            _ReaderActionBar(
              hadith: currentHadith,
              currentIndex: _currentIndex,
              total: hadiths.length,
              onPrevious: _currentIndex > 0
                  ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic)
                  : null,
              onNext: _currentIndex < hadiths.length - 1
                  ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  TOP BAR
// ═══════════════════════════════════════════════════════════════════════

class _ReaderTopBar extends ConsumerWidget {
  final Hadith hadith;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  const _ReaderTopBar({required this.hadith, required this.onClose, required this.onSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final isRead = ref.watch(readHadithsProvider
        .select((s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(bottom: BorderSide(color: tc.surface.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        // Back
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.arrow_back_rounded, color: tc.text.withValues(alpha: 0.65), size: 22),
          splashRadius: 20,
        ),
        // Title
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hadith.collection.toUpperCase(),
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          const SizedBox(height: 1),
          Row(children: [
            Text('Hadith ${hadith.hadithNumber}',
                style: TextStyle(color: tc.text.withValues(alpha: 0.82), fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (hadith.grade != HadithGrade.unknown) ...[
              const SizedBox(width: 8),
              _ReaderGradeBadge(grade: hadith.grade),
            ],
          ]),
        ])),
        // Bookmark
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact();
            ref.read(readHadithsProvider.notifier).toggleRead(hadith); },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              isRead ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: isRead ? tc.accent : tc.textSecondary.withValues(alpha: 0.3),
              size: 21,
            ),
          ),
        ),
        // Settings
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); onSettings(); },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.tune_rounded,
                color: tc.textSecondary.withValues(alpha: 0.4), size: 21),
          ),
        ),
      ]),
    );
  }
}

// ── Thin reading-progress bar ──
class _ProgressBar extends StatelessWidget {
  final int current; final int total; final IslamicThemeColors tc;
  const _ProgressBar({required this.current, required this.total, required this.tc});

  @override
  Widget build(BuildContext context) {
    final pct = total > 1 ? (current + 1) / total : 1.0;
    return Container(
      height: 2,
      color: tc.surface.withValues(alpha: 0.3),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: pct,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              tc.green.withValues(alpha: 0.5),
              tc.accent.withValues(alpha: 0.5),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  GRADE BADGE (shared)
// ═══════════════════════════════════════════════════════════════════════

class _ReaderGradeBadge extends ConsumerWidget {
  final HadithGrade grade;
  const _ReaderGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final color = switch (grade) {
      HadithGrade.sahih  => tc.green,
      HadithGrade.hasan  => const Color(0xFF00796B),
      HadithGrade.daif   => const Color(0xFFE65100),
      _                  => tc.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Text(grade.displayName,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HADITH PAGE  — clean, readable, respects prefs
// ═══════════════════════════════════════════════════════════════════════

class _HadithPage extends ConsumerWidget {
  final Hadith hadith;
  final int totalInChapter;
  const _HadithPage({required this.hadith, this.totalInChapter = 1});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc    = ref.watch(islamicThemeColorsProvider);
    final prefs = ref.watch(_readerPrefsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      physics: const ClampingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ══ Arabic block ══
        if (prefs.showArabic && hadith.arabicText != null && hadith.arabicText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tc.accent.withValues(alpha: 0.07)),
            ),
            child: Text(
              hadith.arabicText!,
              style: TextStyle(
                color: tc.arabicText,
                fontSize: prefs.arabicFontSize,
                height: 2.1,
                fontFamily: 'Amiri',
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // divider ornament
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 28, height: 0.5, color: tc.accent.withValues(alpha: 0.18)),
            const SizedBox(width: 10),
            Text('✦', style: TextStyle(fontSize: 8, color: tc.accent.withValues(alpha: 0.28))),
            const SizedBox(width: 10),
            Container(width: 28, height: 0.5, color: tc.accent.withValues(alpha: 0.18)),
          ]),
          const SizedBox(height: 20),
        ],

        // ══ Narrator ══
        if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: tc.green.withValues(alpha: 0.25), width: 2.5)),
            ),
            child: Text(
              hadith.narrator ?? hadith.extractedNarrator ?? '',
              style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ══ Translation text ══
        SelectableText(
          hadith.text,
          style: TextStyle(
            color: tc.text.withValues(alpha: 0.88),
            fontSize: prefs.fontSize,
            height: 1.9,
            letterSpacing: 0.05,
          ),
        ),

        const SizedBox(height: 24),

        // ══ Metadata card ══
        if (prefs.showMetadata) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.surface.withValues(alpha: 0.45)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _MetaRow(label: 'Reference',
                  value: '${hadith.collection.toUpperCase()} · #${hadith.hadithNumber}', tc: tc),
              if (hadith.book > 0) ...[
                _MetaDivider(tc: tc),
                _MetaRow(label: 'Book', value: '${hadith.book}', tc: tc),
              ],
              if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
                _MetaDivider(tc: tc),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chapter',
                      style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.38), fontSize: 11)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(hadith.chapterName!,
                      style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.58), fontSize: 11.5),
                      textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (hadith.grade != HadithGrade.unknown) ...[
                _MetaDivider(tc: tc),
                Row(children: [
                  Text('Authenticity',
                      style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.38), fontSize: 11)),
                  const Spacer(),
                  _ReaderGradeBadge(grade: hadith.grade),
                ]),
              ],
              if (hadith.scholarGrades.isNotEmpty) ...[
                _MetaDivider(tc: tc),
                ...hadith.scholarGrades.map((sg) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(sg.displayText,
                      style: TextStyle(
                          color: tc.textSecondary.withValues(alpha: 0.38), fontSize: 10.5)),
                )),
              ],
            ]),
          ),
        ],

        const SizedBox(height: 16),
        // Swipe hint
        if (totalInChapter > 1)
          Center(child: Text('swipe to navigate',
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.14),
                  fontSize: 10.5, letterSpacing: 0.8))),
        const SizedBox(height: 32),
      ]),
    );
  }
}

class _MetaDivider extends StatelessWidget {
  final IslamicThemeColors tc;
  const _MetaDivider({required this.tc});
  @override
  Widget build(BuildContext context) => Divider(
      color: tc.textSecondary.withValues(alpha: 0.06), height: 18);
}

class _MetaRow extends StatelessWidget {
  final String label; final String value; final IslamicThemeColors tc;
  const _MetaRow({required this.label, required this.value, required this.tc});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
        style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.38), fontSize: 11)),
    const Spacer(),
    Text(value,
        style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.62), fontSize: 11.5,
            fontWeight: FontWeight.w500)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════
//  BOTTOM ACTION BAR
// ═══════════════════════════════════════════════════════════════════════

class _ReaderActionBar extends ConsumerWidget {
  final Hadith hadith;
  final int currentIndex;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  const _ReaderActionBar({required this.hadith, required this.currentIndex,
      required this.total, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(top: BorderSide(color: tc.surface.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        // Prev
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrevious,
            enabled: onPrevious != null, tc: tc),
        const Spacer(),
        // Copy
        _ActBtn(icon: Icons.copy_outlined, tc: tc, tooltip: 'Copy', onTap: () {
          Clipboard.setData(ClipboardData(text: hadith.shareableText));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Copied to clipboard',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              backgroundColor: tc.accent.withValues(alpha: 0.9),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        }),
        const SizedBox(width: 6),
        // Counter pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${currentIndex + 1} / $total',
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5),
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 6),
        // Share
        _ActBtn(icon: Icons.share_outlined, tc: tc, tooltip: 'Share',
            onTap: () => Share.share(hadith.shareableText)),
        const Spacer(),
        // Next
        _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext,
            enabled: onNext != null, tc: tc),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  final bool enabled; final IslamicThemeColors tc;
  const _NavBtn({required this.icon, this.onTap,
      this.enabled = true, required this.tc});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? () { HapticFeedback.lightImpact(); onTap?.call(); } : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: enabled
            ? tc.surface.withValues(alpha: 0.5)
            : tc.surface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon,
          color: enabled
              ? tc.textSecondary.withValues(alpha: 0.65)
              : tc.textSecondary.withValues(alpha: 0.18),
          size: 20),
    ),
  );
}

class _ActBtn extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  final IslamicThemeColors tc; final String tooltip;
  const _ActBtn({required this.icon, this.onTap,
      required this.tc, this.tooltip = ''});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap?.call(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(icon, color: tc.textSecondary.withValues(alpha: 0.45), size: 21),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  READER SETTINGS  — bottom sheet
// ═══════════════════════════════════════════════════════════════════════

class _ReaderSettingsSheet extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _ReaderSettingsSheet({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_readerPrefsProvider);

    return Container(
      decoration: BoxDecoration(
        color: tc.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: tc.surface.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 36, height: 3,
            decoration: BoxDecoration(color: tc.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 16),

        // Title
        Text('Reading Settings',
            style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),

        // ── Display section ──
        _SheetSection(label: 'DISPLAY', tc: tc),
        const SizedBox(height: 10),

        _ToggleRow(
          icon: Icons.translate_rounded,
          label: 'Show Arabic Text',
          sub: 'Original Arabic of the hadith',
          value: prefs.showArabic,
          tc: tc,
          onChanged: (v) => ref.read(_readerPrefsProvider.notifier)
              .state = prefs.copyWith(showArabic: v),
        ),
        _ToggleRow(
          icon: Icons.info_outline_rounded,
          label: 'Show Metadata',
          sub: 'Reference, grade, scholar notes',
          value: prefs.showMetadata,
          tc: tc,
          onChanged: (v) => ref.read(_readerPrefsProvider.notifier)
              .state = prefs.copyWith(showMetadata: v),
        ),

        const SizedBox(height: 18),

        // ── Font size section ──
        _SheetSection(label: 'FONT SIZE', tc: tc),
        const SizedBox(height: 12),

        // Translation size
        _SliderRow(
          label: 'Translation',
          value: prefs.fontSize,
          min: 13, max: 22,
          displayValue: '${prefs.fontSize.round()}pt',
          tc: tc,
          onChanged: (v) => ref.read(_readerPrefsProvider.notifier)
              .state = prefs.copyWith(fontSize: v),
        ),

        const SizedBox(height: 8),

        // Arabic size
        if (prefs.showArabic)
          _SliderRow(
            label: 'Arabic',
            value: prefs.arabicFontSize,
            min: 18, max: 34,
            displayValue: '${prefs.arabicFontSize.round()}pt',
            tc: tc,
            onChanged: (v) => ref.read(_readerPrefsProvider.notifier)
                .state = prefs.copyWith(arabicFontSize: v),
          ),

        const SizedBox(height: 20),

        // Reset button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(_readerPrefsProvider.notifier).state = const _ReaderPrefs();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Reset to Defaults',
                textAlign: TextAlign.center,
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5),
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ]),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String label; final IslamicThemeColors tc;
  const _SheetSection({required this.label, required this.tc});
  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.4));
}

class _ToggleRow extends StatelessWidget {
  final IconData icon; final String label; final String sub;
  final bool value; final IslamicThemeColors tc;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.sub,
      required this.value, required this.tc, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: tc.textSecondary.withValues(alpha: 0.45), size: 17),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: tc.text.withValues(alpha: 0.78),
            fontSize: 13.5, fontWeight: FontWeight.w500)),
        Text(sub, style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.32), fontSize: 11)),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: tc.green,
        activeTrackColor: tc.green.withValues(alpha: 0.25),
        inactiveThumbColor: tc.textSecondary.withValues(alpha: 0.3),
        inactiveTrackColor: tc.surface.withValues(alpha: 0.6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );
}

class _SliderRow extends StatelessWidget {
  final String label; final double value; final double min; final double max;
  final String displayValue; final IslamicThemeColors tc;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min,
      required this.max, required this.displayValue, required this.tc,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80,
        child: Text(label, style: TextStyle(color: tc.text.withValues(alpha: 0.65),
            fontSize: 13, fontWeight: FontWeight.w500))),
    Expanded(child: SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: tc.green.withValues(alpha: 0.5),
        inactiveTrackColor: tc.surface.withValues(alpha: 0.5),
        thumbColor: tc.green.withValues(alpha: 0.75),
        overlayColor: tc.green.withValues(alpha: 0.12),
      ),
      child: Slider(value: value, min: min, max: max,
          onChanged: (v) => onChanged(v.roundToDouble())),
    )),
    SizedBox(width: 38,
        child: Text(displayValue, textAlign: TextAlign.right,
            style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.45),
                fontSize: 11, fontWeight: FontWeight.w500))),
  ]);
}

