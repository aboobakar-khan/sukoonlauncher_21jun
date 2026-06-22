import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';
import 'reader_settings_provider.dart';

// ══════════════════════════════════════════════════════════════════════
// BOOK DATA PROVIDER
// ══════════════════════════════════════════════════════════════════════

/// Loads the book from separate JSON asset files and merges chapters.
/// Language-aware: re-loads from the Hinglish asset set when the reader
/// language changes (English ⇆ Hinglish share identical chapter/topic IDs,
/// so reading progress carries across a language switch).
final bookProvider = FutureProvider<BookModel>((ref) async {
  final lang = ref.watch(readerLanguageProvider);
  final prefix = lang.assetPrefix; // 'ar_raheeq' or 'ar_raheeq_hi'

  // Load ch1 (has book envelope)
  final ch1Raw = await rootBundle.loadString('assets/${prefix}_ch1_v2.json');
  final ch1Json = jsonDecode(ch1Raw) as Map<String, dynamic>;
  final bookJson = ch1Json['book'] as Map<String, dynamic>;

  // Parse book from ch1 (includes ch1 chapter)
  final book = BookModel.fromJson(bookJson);

  // Start with chapter 1
  final allChapters = [...book.chapters];

  // Dynamically load available chapters or yield placeholders
  for (int i = 2; i <= 48; i++) {
    try {
      final chRaw = await rootBundle.loadString('assets/${prefix}_ch$i.json');
      final chJson = jsonDecode(chRaw) as Map<String, dynamic>;
      allChapters.add(ChapterModel.fromJson(chJson));
    } catch (_) {
      // File not found; fallback to placeholder "Coming Soon" chapter
      allChapters.add(ChapterModel(
        id: 'ch-$i',
        title: _placeholderChapterTitle(i, lang),
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

/// Placeholder chapter titles for locked ("Coming Soon") chapters.
/// English titles mirror the authoritative table of contents in
/// assets/ar_raheeq_index.json (sourced from the official Seerah app).
String _placeholderChapterTitle(int number, ReaderLanguage lang) {
  const en = {
    2: 'Rulership and Princeship among the Arabs',
    3: 'Religions of the Arabs',
    4: 'Aspects of Pre-Islamic Arabian Society',
    5: 'The Lineage and Family of Muhammad [pbuh]',
    6: 'Muhammad\'s Birth and Forty years prior Prophethood',
    7: 'In the Shade of the Message and Prophethood',
    8: 'Phases and stages of the call: The First Stage: Strife in the Way of the Call',
    9: 'The Second Phase: Open Preaching',
    10: 'The Third Phase: Calling unto Islam beyond Makkah',
    11: 'Al-Isra\' and Al-Mir\'raj',
    12: 'The First \'Aqabah Pledge',
    13: 'The Second \'Aqabah Pledge',
    14: 'The Vanguard of Migration (in the Cause of Allah)',
    15: 'In An-Nadwah (Council) House The Parliament of Quraish',
    16: 'Migration of the Prophet [pbuh]',
    17: 'Life in Madinah',
    18: 'The First Phase: The Status Quo in Madinah at the Time of Emigration',
    19: 'The Military Activities between Badr and Uhud',
    20: 'The Battle of Uhud',
    21: 'Military Platoons and Missions between the Battle of Uhud and the Battle of the Confederates',
    22: 'Al-Ahzab (the Confederates) Invasion',
    23: 'Invading Banu Quraiza',
    24: 'Military Activities continued',
    25: 'Bani Al-Mustaliq (Muraisi\') Ghazwah Sha\'ban 6 Hijri',
    26: 'Delegations and Expeditions following Al-Muraisi\' Ghazwah',
    27: 'Al-Hudaibiyah Treaty (Dhul Qu\'dah 6 A.H.)',
    28: 'The Second Stage: A New Phase of Islamic Action',
    29: 'The Prophet\'s Plans to spread the Message of Islam to beyond Arabia',
    30: 'Post-Hudaibiyah Hostilities',
    31: 'The Conquest of Khaibar (in Moharram, 7 A.H.)',
    32: 'Sporadic Invasions',
    33: 'The Compensatory Umrah (Lesser Pilgrimage)',
    34: 'The Battle of Mu\'tah',
    35: 'The Conquest of Makkah',
    36: 'The Third Stage Hunain Ghazwah',
    37: 'Missions and Platoons After the Conquest',
    38: 'The Invasion of Tabuk in Rajab, in the year 9 A.H.',
    39: 'Abu Bakr [R] performs the Pilgrimage',
    40: 'A Meditation on the Ghazawat',
    41: 'People embrace the Religion of Allah in Large Crowds',
    42: 'The Delegations',
    43: 'The Success and Impact of the Call',
    44: 'The Farewell Pilgrimage',
    45: 'The Last Expeditions',
    46: 'The Journey to Allah, the Sublime',
    47: 'The Prophet Household',
    48: 'The Prophet [pbuh], Attributes and Manners',
  };
  const hi = {
    3: 'Arab ke Adyaan-o-Mazaahib',
    4: 'Muhammad ﷺ ka Khaandaan aur Nasab',
    5: 'Muhammad ﷺ — Wiladat se Nubuwwat tak',
    6: 'Nubuwwat se Hijrat tak',
    7: 'Islam ke Ibtidaai Qubool karne waale',
    8: 'Zulm-o-Sitam ka Daur',
    9: 'Habsha ki Hijrat',
    10: 'Gham ka Saal (Aam-ul-Huzn)',
    11: 'Isra aur Mi\'raj',
    12: 'Pehli Bai\'at-e-Aqabah',
    13: 'Doosri Bai\'at-e-Aqabah',
    14: 'Hijrat — Madinah ki taraf',
    15: 'Islami Riyaasat ka Qiyaam',
    16: 'Ghazwaat ka Aaghaz',
    17: 'Ghazwa-e-Badr',
    18: 'Ghazwa-e-Uhud',
    19: 'Ghazwa-e-Khandaq (Ahzaab)',
    20: 'Sulah-e-Hudaibiyah',
    21: 'Khaybar ki Fatah',
    22: 'Islam ka Phailaao',
    23: 'Fatah-e-Makkah',
    24: 'Ghazwa-e-Hunain',
    25: 'Ghazwa-e-Tabook',
    26: 'Wufood ka Saal (Aam-ul-Wufood)',
    27: 'Hujjat-ul-Wida (Alvidaai Hajj)',
    28: 'Rafeeq-e-A\'la ki taraf Safar',
    29: 'Nabi ﷺ ke Akhlaaq-o-Ausaaf',
    30: 'Khaandaan-e-Nubuwwat',
  };
  final titles = lang == ReaderLanguage.hinglish ? hi : en;
  return titles[number] ??
      (lang == ReaderLanguage.hinglish ? 'Baab $number' : 'Chapter $number');
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
