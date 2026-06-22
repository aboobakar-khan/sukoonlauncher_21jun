import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../utils/hive_box_manager.dart';
import '../../../services/offline_content_manager.dart';

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
  final offlineManager = ref.read(offlineContentProvider.notifier);
  
  try {
    final chapters = await service.getChapters(collection);
    if (chapters.isNotEmpty) {
      offlineManager.saveChapters(collection.bookSlug, chapters);
      return chapters;
    }
  } catch (_) {}

  // Fallback to offline
  return offlineManager.getCachedChapters(collection.bookSlug);
});

/// Hadiths for the selected chapter (or all if null)
final chapterHadithsProvider = FutureProvider<List<Hadith>>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  final offlineManager = ref.read(offlineContentProvider.notifier);
  final collectionId = ref.watch(selectedCollectionProvider);
  final chapter = ref.watch(selectedChapterProvider);
  final collection = HadithCollection.fromId(collectionId);
  final gradeFilter = ref.watch(selectedGradeFilterProvider);
  final lang = ref.watch(hadithLanguageProvider);

  List<Hadith> hadiths = [];

  // 1. Check if the collection is fully downloaded for offline
  if (offlineManager.isCollectionDownloaded(collectionId)) {
    if (chapter != null) {
      hadiths = await offlineManager.getCachedHadithsByChapter(
        collectionId: collectionId,
        chapterNumber: chapter.chapterNumber,
      );
    } else {
      hadiths = await offlineManager.getCachedHadiths(collectionId: collectionId);
    }
    
    if (hadiths.isNotEmpty) {
      if (gradeFilter != null) {
        hadiths = hadiths.where((h) => h.grade == gradeFilter).toList();
      }
      return hadiths;
    }
  }

  // 2. Otherwise, fetch from API (with 1st page of 50 for speed)
  try {
    hadiths = await service.fetchHadiths(
      collection,
      chapterId: chapter?.chapterNumber,
      maxPages: 1, 
      language: lang.code,
    );
  } catch (_) {
    // API failed, try general cache fallback
    hadiths = await _offlineHadiths(ref, collectionId);
    if (chapter != null) {
      hadiths = hadiths.where((h) => h.book == chapter.chapterNumber).toList();
    }
  }

  if (gradeFilter != null) {
    hadiths = hadiths.where((h) => h.grade == gradeFilter).toList();
  }
  return hadiths;
});

Future<List<Hadith>> _offlineHadiths(Ref ref, String? collectionId) async {
  return ref.read(offlineContentProvider.notifier).getCachedHadiths(collectionId: collectionId);
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

  static const _bookDescs = {
    'bukhari': 'The most authentic collection',
    'muslim': 'Second most authentic collection',
    'abudawud': 'Focused on jurisprudence',
    'tirmidhi': 'Jurisprudence & commentary',
    'nasai': 'Strict authentication criteria',
    'ibnmajah': 'Comprehensive legal traditions',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readCount = ref.watch(readHadithsProvider).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      children: [
        // ── Daily Hadith (hero) ──
        _DailyHadithCard(tc: tc),

        const SizedBox(height: 22),

        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(children: [
            Text('Collections',
                style: TextStyle(color: tc.text, fontSize: 15, fontWeight: FontWeight.w600,
                    letterSpacing: -0.2)),
            const Spacer(),
            if (readCount > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: tc.green.withValues(alpha: 0.7), size: 13),
                const SizedBox(width: 5),
                Text('$readCount read',
                    style: TextStyle(color: tc.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
          ]),
        ),

        // ── Book list ──
        ...HadithCollection.collections.map((c) => _BookCard(
              collection: c,
              description: _bookDescs[c.id] ?? '',
              tc: tc,
              onTap: () {
                ref.read(selectedCollectionProvider.notifier).state = c.id;
                ref.read(selectedChapterProvider.notifier).state = null;
                ref.read(hadithPageProvider.notifier).state = 1;
                ref.read(hadithNavDepthProvider.notifier).state = 1;
              },
            )),
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
        return _Pressable(
          onTap: () {
            ref.read(readHadithsProvider.notifier).markAsRead(hadith);
            ref.read(offlineContentProvider.notifier).cacheSingleHadith(hadith);
            showHadithGlassModal(context, hadith, [hadith]);
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tc.border.withValues(alpha: 0.6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: tc.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('TODAY',
                      style: TextStyle(color: tc.accent, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                const Spacer(),
                Text(hadith.collection,
                    style: TextStyle(color: tc.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 12),
              Text(
                hadith.text.length > 180 ? '${hadith.text.substring(0, 180)}…' : hadith.text,
                style: TextStyle(color: tc.text, fontSize: 14.5, height: 1.6, fontWeight: FontWeight.w400),
                maxLines: 4, overflow: TextOverflow.ellipsis,
              ),
              if (hadith.extractedNarrator != null) ...[
                const SizedBox(height: 10),
                Text('— ${hadith.extractedNarrator}',
                    style: TextStyle(color: tc.textSecondary, fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        );
      },
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(18)),
        child: Center(child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.accent.withValues(alpha: 0.5)))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Book Card ──

class _BookCard extends ConsumerWidget {
  final HadithCollection collection;
  final String description;
  final IslamicThemeColors tc;
  final VoidCallback onTap;

  const _BookCard({required this.collection,
    required this.description, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloaded = ref.watch(offlineContentProvider).downloadedCollections[collection.id] ?? false;
    return _Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          // Monogram tile
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              collection.name.isNotEmpty ? collection.name.substring(0, 1).toUpperCase() : '?',
              style: TextStyle(color: tc.accent, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(collection.name,
                      style: TextStyle(color: tc.text, fontSize: 15,
                          fontWeight: FontWeight.w600, letterSpacing: -0.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (isDownloaded) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.offline_pin_rounded, color: tc.green.withValues(alpha: 0.8), size: 14),
                ],
              ]),
              const SizedBox(height: 3),
              Text(description,
                  style: TextStyle(color: tc.textSecondary, fontSize: 12, height: 1.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                if (collection.defaultGrade == HadithGrade.sahih) ...[
                  Text('Sahih',
                      style: TextStyle(color: tc.green.withValues(alpha: 0.85), fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text('  ·  ',
                      style: TextStyle(color: tc.textTertiary, fontSize: 11)),
                ],
                Text('${(collection.totalHadiths / 1000).toStringAsFixed(1)}k hadiths',
                    style: TextStyle(color: tc.textTertiary, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: tc.textTertiary, size: 20),
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
        // ── Header (single back lives in the page chrome) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(collection.name,
                  style: TextStyle(color: tc.text, fontSize: 18,
                      fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              chaptersAsync.when(
                data: (ch) => Text('${ch.length} chapters',
                    style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                loading: () => Text('Loading…',
                    style: TextStyle(color: tc.textTertiary, fontSize: 12)),
                error: (_, __) => Text(collection.arabicName,
                    style: TextStyle(color: tc.textSecondary, fontSize: 12, fontFamily: 'Amiri')),
              ),
            ])),
            // "All Hadiths" shortcut
            _Pressable(
              onTap: () {
                ref.read(selectedChapterProvider.notifier).state = null;
                ref.read(hadithPageProvider.notifier).state = 1;
                ref.read(hadithNavDepthProvider.notifier).state = 2;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: tc.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.list_rounded, color: tc.accent, size: 15),
                  const SizedBox(width: 5),
                  Text('All', style: TextStyle(color: tc.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),

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
              Text('Loading chapters…', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
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
    return _Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: tc.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          // Number badge
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Center(child: Text('${chapter.chapterNumber}',
                style: TextStyle(color: tc.accent, fontSize: 13, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chapter.chapterEnglish,
                style: TextStyle(color: tc.text, fontSize: 13.5,
                    fontWeight: FontWeight.w500, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (chapter.chapterArabic.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(chapter.chapterArabic,
                  style: TextStyle(color: tc.textSecondary, fontSize: 12, fontFamily: 'Amiri'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
            ],
          ])),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: tc.textTertiary, size: 20),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header (single back lives in the page chrome) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                chapter != null ? chapter.chapterEnglish : collection.shortName,
                style: TextStyle(color: tc.text, fontSize: 16,
                    fontWeight: FontWeight.w600, letterSpacing: -0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                () {
                  final base = chapter != null
                      ? '${collection.shortName} · Chapter ${chapter.chapterNumber}'
                      : 'All Hadiths';
                  final count = hadithsAsync.maybeWhen(
                      data: (h) => h.length, orElse: () => null);
                  if (count == null) return base;
                  return '$base · $count hadith${count == 1 ? '' : 's'}';
                }(),
                style: TextStyle(color: tc.textSecondary, fontSize: 11.5),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ])),
          ]),
        ),

        const SizedBox(height: 12),

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
                    return _LoadMoreButton(
                      remaining: remaining, tc: tc,
                      onTap: () => ref.read(hadithPageProvider.notifier).state = currentPage + 1,
                    );
                  }
                  return _HadithCard(hadith: displayed[index], allHadiths: hadiths, tc: tc);
                },
              );
            },
            loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.green.withValues(alpha: 0.4))),
              const SizedBox(height: 12),
              Text('Loading hadiths…', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
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

/// Tap target with a subtle scale-down press animation + haptic feedback.
/// Replaces bare GestureDetectors so taps feel responsive and tactile.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
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
      child: _Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13),
              border: Border.all(color: tc.accent.withValues(alpha: 0.22))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.expand_more_rounded, color: tc.accent, size: 18),
            const SizedBox(width: 7),
            Text('Load more  ·  $remaining remaining',
                style: TextStyle(color: tc.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
      Icon(icon, color: tc.textTertiary.withValues(alpha: 0.5), size: 46),
      const SizedBox(height: 14),
      Text(message, style: TextStyle(color: tc.text, fontSize: 14, fontWeight: FontWeight.w500)),
      if (sub != null) ...[
        const SizedBox(height: 5),
        Text(sub!, textAlign: TextAlign.center,
            style: TextStyle(color: tc.textSecondary, fontSize: 12)),
      ],
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 16),
        _Pressable(
          onTap: onAction!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Text(actionLabel!,
                style: TextStyle(color: tc.accent, fontSize: 13, fontWeight: FontWeight.w600)),
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
    final narrator = hadith.narrator ?? hadith.extractedNarrator;
    return _Pressable(
      onTap: () => _openReader(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: isRead ? 0.24 : 0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: number · subtle grade · read tick
          Row(children: [
            Text('#${hadith.hadithNumber}',
                style: TextStyle(color: tc.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (hadith.grade != HadithGrade.unknown) ...[
              const SizedBox(width: 9),
              Container(width: 5, height: 5,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _dotColor(hadith.grade, tc))),
              const SizedBox(width: 5),
              Text(hadith.grade.displayName,
                  style: TextStyle(color: tc.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
            const Spacer(),
            if (isRead)
              Icon(Icons.check_circle_rounded, color: tc.green.withValues(alpha: 0.6), size: 15),
          ]),
          const SizedBox(height: 10),
          Text(
            hadith.text,
            style: TextStyle(
                color: isRead ? tc.textSecondary : tc.text.withValues(alpha: 0.92),
                fontSize: 14, height: 1.6),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          if (narrator != null && narrator.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('— $narrator',
                style: TextStyle(color: tc.textTertiary, fontSize: 11.5,
                    fontStyle: FontStyle.italic),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  Color _dotColor(HadithGrade g, IslamicThemeColors tc) => switch (g) {
        HadithGrade.sahih => tc.green,
        HadithGrade.hasan => const Color(0xFF00796B),
        HadithGrade.daif => const Color(0xFFE65100),
        _ => tc.textSecondary,
      };

  void _openReader(BuildContext context, WidgetRef ref) {
    ref.read(readHadithsProvider.notifier).markAsRead(hadith);
    ref.read(offlineContentProvider.notifier).cacheSingleHadith(hadith);
    showHadithGlassModal(context, hadith, allHadiths);
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  GLASS HADITH MODAL — centred, blurred, animated quick-reader
// ═══════════════════════════════════════════════════════════════════════

void showHadithGlassModal(
    BuildContext context, Hadith hadith, List<Hadith> allHadiths) {
  showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Hadith',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) =>
        _HadithGlassModal(initial: hadith, allHadiths: allHadiths),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
          parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _HadithGlassModal extends ConsumerStatefulWidget {
  final Hadith initial;
  final List<Hadith> allHadiths;
  const _HadithGlassModal({required this.initial, required this.allHadiths});

  @override
  ConsumerState<_HadithGlassModal> createState() => _HadithGlassModalState();
}

class _HadithGlassModalState extends ConsumerState<_HadithGlassModal> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.allHadiths.indexWhere((h) =>
        h.collection == widget.initial.collection &&
        h.hadithNumber == widget.initial.hadithNumber);
    if (_index < 0) _index = 0;
  }

  void _go(int delta) {
    final n = _index + delta;
    if (n < 0 || n >= widget.allHadiths.length) return;
    setState(() => _index = n);
    ref.read(readHadithsProvider.notifier).markAsRead(widget.allHadiths[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final hadith =
        widget.allHadiths.isEmpty ? widget.initial : widget.allHadiths[_index];
    final hasPrev = _index > 0;
    final hasNext = _index < widget.allHadiths.length - 1;
    final narrator = hadith.narrator ?? hadith.extractedNarrator;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: tc.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: tc.border.withValues(alpha: 0.7)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(children: [
                        Text(hadith.collection.toUpperCase(),
                            style: TextStyle(
                                color: tc.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                        const SizedBox(width: 8),
                        Text('#${hadith.hadithNumber}',
                            style: TextStyle(
                                color: tc.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        if (hadith.grade != HadithGrade.unknown) ...[
                          const SizedBox(width: 8),
                          _GradeBadge(grade: hadith.grade, tc: tc),
                        ],
                        const Spacer(),
                        _Pressable(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tc.text.withValues(alpha: 0.06)),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: tc.textSecondary),
                          ),
                        ),
                      ]),
                    ),
                    Divider(height: 1, color: tc.border.withValues(alpha: 0.5)),
                    // ── Content ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                        physics: const BouncingScrollPhysics(),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Column(
                            key: ValueKey(_index),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (narrator != null && narrator.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: tc.accent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border(
                                        left: BorderSide(
                                            color: tc.accent
                                                .withValues(alpha: 0.5),
                                            width: 3)),
                                  ),
                                  child: Text(narrator,
                                      style: TextStyle(
                                          color: tc.textSecondary,
                                          fontSize: 12.5,
                                          fontStyle: FontStyle.italic,
                                          height: 1.5)),
                                ),
                                const SizedBox(height: 16),
                              ],
                              SelectableText(hadith.text,
                                  style: TextStyle(
                                      color: tc.text,
                                      fontSize: 16,
                                      height: 1.85,
                                      letterSpacing: 0.05)),
                              const SizedBox(height: 16),
                              Text(
                                '${hadith.collection.toUpperCase()} · #${hadith.hadithNumber}${hadith.book > 0 ? ' · Book ${hadith.book}' : ''}',
                                style: TextStyle(
                                    color: tc.textTertiary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: tc.border.withValues(alpha: 0.5)),
                    // ── Footer actions ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(children: [
                        _modalIcon(Icons.chevron_left_rounded, tc,
                            hasPrev ? () => _go(-1) : null),
                        const Spacer(),
                        _modalIcon(Icons.copy_rounded, tc, () {
                          Clipboard.setData(
                              ClipboardData(text: hadith.shareableText));
                        }),
                        const SizedBox(width: 4),
                        _modalIcon(Icons.ios_share_rounded, tc,
                            () => Share.share(hadith.shareableText)),
                        const Spacer(),
                        _modalIcon(Icons.chevron_right_rounded, tc,
                            hasNext ? () => _go(1) : null),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _modalIcon(IconData icon, IslamicThemeColors tc, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon,
            size: 22,
            color: onTap != null
                ? tc.textSecondary
                : tc.textTertiary.withValues(alpha: 0.4)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(grade.displayName,
          style: TextStyle(color: color.withValues(alpha: 0.95), fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}
