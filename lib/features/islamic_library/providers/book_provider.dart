import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';

// ══════════════════════════════════════════════════════════════════════
// BOOK DATA PROVIDER
// ══════════════════════════════════════════════════════════════════════

/// Loads the book from both separate JSON asset files and merges chapters.
final bookProvider = FutureProvider<BookModel>((ref) async {
  // Load ch1 (has book envelope)
  final ch1Raw = await rootBundle.loadString('assets/ar_raheeq_ch1_v2.json');
  final ch1Json = jsonDecode(ch1Raw) as Map<String, dynamic>;
  final bookJson = ch1Json['book'] as Map<String, dynamic>;

  // Parse book from ch1 (includes ch1 chapter)
  final book = BookModel.fromJson(bookJson);

  // Start with chapter 1
  final allChapters = [...book.chapters];

  // Dynamically load available chapters or yield placeholders
  for (int i = 2; i <= 30; i++) {
    try {
      final chRaw = await rootBundle.loadString('assets/ar_raheeq_ch$i.json');
      final chJson = jsonDecode(chRaw) as Map<String, dynamic>;
      allChapters.add(ChapterModel.fromJson(chJson));
    } catch (_) {
      // File not found; fallback to placeholder "Coming Soon" chapter
      allChapters.add(ChapterModel(
        id: 'ch-$i',
        title: _placeholderChapterTitle(i),
        arabicTitle: '',
        number: i,
        totalTopics: 0,
        topics: const [],
      ));
    }
  }

  // Renumber all topics sequentially from 1 to N
  int globalTopicNumber = 1;
  final renumberedChapters = allChapters.map((ch) {
    if (ch.topics.isEmpty) return ch;
    
    final renumberedTopics = ch.topics.map((t) {
      return TopicModel(
        id: t.id,
        title: t.title,
        number: globalTopicNumber++,
        topicSummary: t.topicSummary,
        paragraphs: t.paragraphs,
        keyPoints: t.keyPoints,
        quiz: t.quiz,
      );
    }).toList();
    
    return ChapterModel(
      id: ch.id,
      title: ch.title,
      arabicTitle: ch.arabicTitle,
      number: ch.number,
      totalTopics: ch.totalTopics,
      topics: renumberedTopics,
    );
  }).toList();

  return BookModel(
    id: book.id,
    title: book.title,
    subtitle: book.subtitle,
    author: book.author,
    chapters: renumberedChapters,
  );
});

/// Placeholder chapter titles for locked chapters
String _placeholderChapterTitle(int number) {
  const titles = {
    3: 'Religions of the Arabs',
    4: 'The Lineage and Family of Muhammad ﷺ',
    5: 'Muhammad ﷺ from Birth to Prophethood',
    6: 'From Prophethood to the Migration',
    7: 'The Early Converts to Islam',
    8: 'The Persecution and Torture',
    9: 'The Migration to Abyssinia',
    10: 'The Year of Grief',
    11: 'Al-Isra and Al-Mi\'raj',
    12: 'The First Pledge of Al-Aqabah',
    13: 'The Second Pledge of Al-Aqabah',
    14: 'The Hijrah — Migration to Madinah',
    15: 'The Establishment of the Islamic State',
    16: 'The Battles Begin',
    17: 'The Battle of Badr',
    18: 'The Battle of Uhud',
    19: 'The Battle of the Trench',
    20: 'The Treaty of Al-Hudaybiyah',
    21: 'The Conquest of Khaybar',
    22: 'The Spread of Islam',
    23: 'The Conquest of Makkah',
    24: 'The Battle of Hunayn',
    25: 'The Expedition of Tabuk',
    26: 'The Year of Delegations',
    27: 'The Farewell Pilgrimage',
    28: 'The Journey to the Highest Companion',
    29: 'The Prophet\'s ﷺ Attributes and Manners',
    30: 'The Prophetic Household',
  };
  return titles[number] ?? 'Chapter $number';
}

/// Provides a single chapter by ID.
final chapterProvider =
    Provider.family<ChapterModel?, String>((ref, chapterId) {
  final bookAsync = ref.watch(bookProvider);
  return bookAsync.whenData((book) {
    try {
      return book.chapters.firstWhere((c) => c.id == chapterId);
    } catch (_) {
      return null;
    }
  }).value;
});

// ══════════════════════════════════════════════════════════════════════
// READING PROGRESS PROVIDER
// ══════════════════════════════════════════════════════════════════════

class ReadingProgress {
  final String? lastChapterId;
  final String? lastTopicId;
  final String? lastChapterTitle;
  final String? lastTopicTitle;
  final int? lastChapterNumber;
  final Set<String> completedTopicIds;

  const ReadingProgress({
    this.lastChapterId,
    this.lastTopicId,
    this.lastChapterTitle,
    this.lastTopicTitle,
    this.lastChapterNumber,
    this.completedTopicIds = const {},
  });

  bool get hasProgress => lastChapterId != null && lastTopicId != null;

  /// Calculate overall reading progress (% of total topics completed).
  double overallProgress(BookModel book) {
    int totalTopics = 0;
    for (final ch in book.chapters) {
      if (ch.hasContent) totalTopics += ch.topics.length;
    }
    if (totalTopics == 0) return 0;
    return completedTopicIds.length / totalTopics;
  }

  ReadingProgress copyWith({
    String? lastChapterId,
    String? lastTopicId,
    String? lastChapterTitle,
    String? lastTopicTitle,
    int? lastChapterNumber,
    Set<String>? completedTopicIds,
  }) {
    return ReadingProgress(
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastTopicId: lastTopicId ?? this.lastTopicId,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      lastTopicTitle: lastTopicTitle ?? this.lastTopicTitle,
      lastChapterNumber: lastChapterNumber ?? this.lastChapterNumber,
      completedTopicIds: completedTopicIds ?? this.completedTopicIds,
    );
  }
}

class ReadingProgressNotifier extends StateNotifier<ReadingProgress> {
  static const _prefix = 'seerah_reader_';

  ReadingProgressNotifier() : super(const ReadingProgress()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final completedRaw = prefs.getStringList('${_prefix}completed_topics') ?? [];
    state = ReadingProgress(
      lastChapterId: prefs.getString('${_prefix}last_chapter_id'),
      lastTopicId: prefs.getString('${_prefix}last_topic_id'),
      lastChapterTitle: prefs.getString('${_prefix}last_chapter_title'),
      lastTopicTitle: prefs.getString('${_prefix}last_topic_title'),
      lastChapterNumber: prefs.getInt('${_prefix}last_chapter_number'),
      completedTopicIds: completedRaw.toSet(),
    );
  }

  Future<void> savePosition({
    required String chapterId,
    required String topicId,
    required String chapterTitle,
    required String topicTitle,
    required int chapterNumber,
  }) async {
    state = state.copyWith(
      lastChapterId: chapterId,
      lastTopicId: topicId,
      lastChapterTitle: chapterTitle,
      lastTopicTitle: topicTitle,
      lastChapterNumber: chapterNumber,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}last_chapter_id', chapterId);
    await prefs.setString('${_prefix}last_topic_id', topicId);
    await prefs.setString('${_prefix}last_chapter_title', chapterTitle);
    await prefs.setString('${_prefix}last_topic_title', topicTitle);
    await prefs.setInt('${_prefix}last_chapter_number', chapterNumber);
  }

  Future<void> markTopicCompleted(String topicId) async {
    final updated = {...state.completedTopicIds, topicId};
    state = state.copyWith(completedTopicIds: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        '${_prefix}completed_topics', updated.toList());
  }

  bool isTopicCompleted(String topicId) =>
      state.completedTopicIds.contains(topicId);
}

final readingProgressProvider =
    StateNotifierProvider<ReadingProgressNotifier, ReadingProgress>(
  (ref) => ReadingProgressNotifier(),
);
