/// Hadith authenticity grades
enum HadithGrade {
  sahih,      // Authentic
  hasan,      // Good
  daif,       // Weak
  unknown;    // Not graded

  String get displayName {
    switch (this) {
      case HadithGrade.sahih:
        return 'Sahih';
      case HadithGrade.hasan:
        return 'Hasan';
      case HadithGrade.daif:
        return "Da'if";
      case HadithGrade.unknown:
        return 'Ungraded';
    }
  }

  int get colorValue {
    switch (this) {
      case HadithGrade.sahih:
        return 0xFFC2A366; // Green
      case HadithGrade.hasan:
        return 0xFFE3B341; // Yellow/Amber
      case HadithGrade.daif:
        return 0xFFE34141; // Red
      case HadithGrade.unknown:
        return 0xFF6E7681; // Grey
    }
  }

  static HadithGrade fromString(String? grade) {
    if (grade == null || grade.isEmpty) return HadithGrade.unknown;
    final lower = grade.toLowerCase();
    if (lower.contains('sahih') || lower.contains('authentic') || lower.contains('sound')) {
      return HadithGrade.sahih;
    } else if (lower.contains('hasan') || lower.contains('good') || lower.contains('fair')) {
      return HadithGrade.hasan;
    } else if (lower.contains('daif') || lower.contains("da'if") || lower.contains('weak')) {
      return HadithGrade.daif;
    }
    return HadithGrade.unknown;
  }
}

/// Hadith category tags
enum HadithCategory {
  prayer('Prayer', '🕌'),
  fasting('Fasting', '🌙'),
  charity('Charity', '💰'),
  hajj('Hajj', '🕋'),
  character('Character', '✨'),
  knowledge('Knowledge', '📚'),
  family('Family', '👨‍👩‍👧'),
  faith('Faith', '❤️'),
  jihad('Jihad', '⚔️'),
  business('Business', '💼'),
  food('Food & Drink', '🍽️'),
  health('Health', '🏥'),
  marriage('Marriage', '💍'),
  supplication('Supplication', '🤲'),
  manners('Manners', '🤝'),
  prophethood('Prophethood', '🌟'),
  afterlife('Afterlife', '☁️'),
  general('General', '📖');

  final String displayName;
  final String emoji;

  const HadithCategory(this.displayName, this.emoji);

  static List<HadithCategory> detectCategories(String text) {
    final categories = <HadithCategory>[];
    final lower = text.toLowerCase();

    if (lower.contains('prayer') || lower.contains('salat') || lower.contains('pray')) {
      categories.add(HadithCategory.prayer);
    }
    if (lower.contains('fast') || lower.contains('ramadan') || lower.contains('siyam')) {
      categories.add(HadithCategory.fasting);
    }
    if (lower.contains('charity') || lower.contains('zakat') || lower.contains('sadaqa')) {
      categories.add(HadithCategory.charity);
    }
    if (lower.contains('hajj') || lower.contains('pilgrimage') || lower.contains('mecca')) {
      categories.add(HadithCategory.hajj);
    }
    if (lower.contains('character') || lower.contains('akhlaq') || lower.contains('manner')) {
      categories.add(HadithCategory.character);
    }
    if (lower.contains('knowledge') || lower.contains('learn') || lower.contains('teach')) {
      categories.add(HadithCategory.knowledge);
    }
    if (lower.contains('family') || lower.contains('parent') || lower.contains('child')) {
      categories.add(HadithCategory.family);
    }
    if (lower.contains('faith') || lower.contains('believe') || lower.contains('iman')) {
      categories.add(HadithCategory.faith);
    }
    if (lower.contains('food') || lower.contains('eat') || lower.contains('drink')) {
      categories.add(HadithCategory.food);
    }
    if (lower.contains('marriage') || lower.contains('wife') || lower.contains('husband')) {
      categories.add(HadithCategory.marriage);
    }
    if (lower.contains('dua') || lower.contains('supplicat') || lower.contains('invok')) {
      categories.add(HadithCategory.supplication);
    }
    if (lower.contains('prophet') || lower.contains('messenger')) {
      categories.add(HadithCategory.prophethood);
    }
    if (lower.contains('paradise') || lower.contains('hell') || lower.contains('judgement') || lower.contains('hereafter')) {
      categories.add(HadithCategory.afterlife);
    }

    return categories.isEmpty ? [HadithCategory.general] : categories;
  }
}

/// Scholar grading info
class ScholarGrade {
  final String scholarName;
  final HadithGrade grade;
  final String? note;

  const ScholarGrade({
    required this.scholarName,
    required this.grade,
    this.note,
  });

  String get displayText => 'Graded ${grade.displayName} by $scholarName';
}

/// Hadith model for storing hadith data
class Hadith {
  final int hadithNumber;
  final int arabicNumber;
  final String text;
  final String? arabicText;
  final String? transliteration;
  final int book;
  final int hadithInBook;
  final String collection;
  final String? section;
  final String? chapterName;
  final String? narrator;           // Primary narrator
  final String? narratorChain;      // Full isnad/chain
  final HadithGrade grade;
  final List<ScholarGrade> scholarGrades;
  final List<HadithCategory> categories;
  final bool isBookmarked;
  final String? bookmarkCollection;  // For organizing bookmarks

  Hadith({
    required this.hadithNumber,
    required this.arabicNumber,
    required this.text,
    this.arabicText,
    this.transliteration,
    required this.book,
    required this.hadithInBook,
    required this.collection,
    this.section,
    this.chapterName,
    this.narrator,
    this.narratorChain,
    this.grade = HadithGrade.unknown,
    this.scholarGrades = const [],
    this.categories = const [],
    this.isBookmarked = false,
    this.bookmarkCollection,
  });

  /// Get formatted reference
  String get formattedReference {
    final parts = <String>[];
    parts.add(collection);
    if (section != null && section!.isNotEmpty) {
      parts.add('Book $book');
    }
    parts.add('Hadith #$hadithNumber');
    return parts.join(' • ');
  }

  /// Get short reference
  String get shortReference => '$collection #$hadithNumber';

  /// Extract narrator from text
  String? get extractedNarrator {
    if (narrator != null) return narrator;
    
    // Try to extract narrator from text
    final text = this.text;
    final narratorPatterns = [
      RegExp(r'^Narrated by ([^:]+):'),
      RegExp(r'^Narrated ([^:]+):'),
      RegExp(r'^([^:]+) narrated:'),
      RegExp(r"^([^:]+) reported:"),
      RegExp(r'^It was narrated from ([^:]+):'),
      RegExp(r'^It was narrated that ([^:]+)'),
    ];

    for (final pattern in narratorPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  factory Hadith.fromJson(Map<String, dynamic> json, {
    required String collection,
    String? section,
    Map<String, String>? sectionDetails,
  }) {
    // ── Detect API source: hadithapi.com vs legacy fawazahmed0 / offline ──
    final bool isNewApi = json.containsKey('hadithEnglish') ||
        json.containsKey('hadithArabic') ||
        json.containsKey('bookSlug');

    if (isNewApi) {
      return _fromHadithApiJson(json, collection: collection);
    }
    return _fromLegacyJson(json, collection: collection, section: section, sectionDetails: sectionDetails);
  }

  /// Parse hadithapi.com response format
  static Hadith _fromHadithApiJson(Map<String, dynamic> json, {required String collection}) {
    final text = json['hadithEnglish'] as String? ??
        json['hadithUrdu'] as String? ?? '';
    final arabicText = json['hadithArabic'] as String?;
    final status = json['status'] as String?;
    final grade = HadithGrade.fromString(status);
    final categories = HadithCategory.detectCategories(text);
    final chapterIdRaw = json['chapterId'];
    final chapterId = chapterIdRaw is int
        ? chapterIdRaw
        : int.tryParse(chapterIdRaw?.toString() ?? '') ?? 0;
    final hadithNumRaw = json['hadithNumber'];
    final hadithNum = hadithNumRaw is int
        ? hadithNumRaw
        : int.tryParse(hadithNumRaw?.toString() ?? '') ?? 0;
    // Extract narrator from english text (pattern: "Narrated X: ...")
    String? narrator;
    final narratorMatch = RegExp(r'^Narrated\s+(.+?)\s*:\s*').firstMatch(text);
    if (narratorMatch != null) {
      narrator = narratorMatch.group(1)?.trim();
    }
    final slug = json['bookSlug'] as String? ?? '';
    final bookName = json['book']?['bookName'] as String? ??
        json['chapter']?['chapterEnglish'] as String? ?? '';
    return Hadith(
      hadithNumber: hadithNum,
      arabicNumber: hadithNum,
      text: text,
      arabicText: arabicText,
      book: chapterId,
      hadithInBook: hadithNum,
      collection: slug.isNotEmpty ? _slugToCollectionName(slug) : collection,
      chapterName: bookName,
      narrator: narrator,
      grade: grade,
      categories: categories,
    );
  }

  /// Parse legacy fawazahmed0 / offline cached format
  static Hadith _fromLegacyJson(Map<String, dynamic> json, {
    required String collection,
    String? section,
    Map<String, String>? sectionDetails,
  }) {
    final reference = json['reference'] as Map<String, dynamic>? ?? {};
    final text = json['text'] as String? ?? '';
    
    // Parse grades if available
    final gradesData = json['grades'] as List<dynamic>? ?? [];
    final scholarGrades = <ScholarGrade>[];
    HadithGrade mainGrade = HadithGrade.unknown;
    
    for (final gradeData in gradesData) {
      if (gradeData is Map<String, dynamic>) {
        final gradeName = gradeData['name'] as String? ?? gradeData['grade'] as String?;
        final scholarName = gradeData['scholar'] as String? ?? 'Unknown Scholar';
        final grade = HadithGrade.fromString(gradeName);
        
        if (grade != HadithGrade.unknown) {
          mainGrade = grade;
          scholarGrades.add(ScholarGrade(
            scholarName: scholarName,
            grade: grade,
          ));
        }
      }
    }

    // Also check top-level 'grade' field (from offline cache toJson)
    if (mainGrade == HadithGrade.unknown && json['grade'] is String) {
      mainGrade = HadithGrade.fromString(json['grade'] as String);
    }

    // Detect categories from text
    final categories = HadithCategory.detectCategories(text);

    // Get chapter/section name
    final bookNum = reference['book'] as int? ?? json['book'] as int? ?? 0;
    final chapterName = json['chapterName'] as String? ?? sectionDetails?[bookNum.toString()];

    return Hadith(
      hadithNumber: json['hadithnumber'] as int? ?? json['hadithNumber'] as int? ?? 0,
      arabicNumber: json['arabicnumber'] as int? ?? json['arabicNumber'] as int? ?? 0,
      text: text,
      arabicText: json['arabic'] as String? ?? json['arabicText'] as String?,
      transliteration: json['transliteration'] as String?,
      book: bookNum,
      hadithInBook: reference['hadith'] as int? ?? json['hadithInBook'] as int? ?? 0,
      collection: json['collection'] as String? ?? collection,
      section: json['section'] as String? ?? section,
      chapterName: chapterName,
      narrator: json['narrator'] as String?,
      narratorChain: json['chain'] as String? ?? json['isnad'] as String?,
      grade: mainGrade,
      scholarGrades: scholarGrades,
      categories: categories,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      bookmarkCollection: json['bookmarkCollection'] as String?,
    );
  }

  /// Map bookSlug to display name
  static String _slugToCollectionName(String slug) {
    const map = {
      'sahih-bukhari': 'Bukhari',
      'sahih-muslim': 'Muslim',
      'abu-dawood': 'Abu Dawud',
      'sunan-abu-dawood': 'Abu Dawud', // legacy / alternate slug
      'al-tirmidhi': 'Tirmidhi',
      'sunan-nasai': "Nasa'i",
      'ibn-e-majah': 'Ibn Majah',
    };
    return map[slug] ?? slug;
  }

  Hadith copyWith({
    int? hadithNumber,
    int? arabicNumber,
    String? text,
    String? arabicText,
    String? transliteration,
    int? book,
    int? hadithInBook,
    String? collection,
    String? section,
    String? chapterName,
    String? narrator,
    String? narratorChain,
    HadithGrade? grade,
    List<ScholarGrade>? scholarGrades,
    List<HadithCategory>? categories,
    bool? isBookmarked,
    String? bookmarkCollection,
  }) {
    return Hadith(
      hadithNumber: hadithNumber ?? this.hadithNumber,
      arabicNumber: arabicNumber ?? this.arabicNumber,
      text: text ?? this.text,
      arabicText: arabicText ?? this.arabicText,
      transliteration: transliteration ?? this.transliteration,
      book: book ?? this.book,
      hadithInBook: hadithInBook ?? this.hadithInBook,
      collection: collection ?? this.collection,
      section: section ?? this.section,
      chapterName: chapterName ?? this.chapterName,
      narrator: narrator ?? this.narrator,
      narratorChain: narratorChain ?? this.narratorChain,
      grade: grade ?? this.grade,
      scholarGrades: scholarGrades ?? this.scholarGrades,
      categories: categories ?? this.categories,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarkCollection: bookmarkCollection ?? this.bookmarkCollection,
    );
  }

  Map<String, dynamic> toJson() => {
    'hadithnumber': hadithNumber,
    'arabicnumber': arabicNumber,
    'text': text,
    'arabic': arabicText,
    'transliteration': transliteration,
    'collection': collection,
    'section': section,
    'chapterName': chapterName,
    'narrator': narrator,
    'chain': narratorChain,
    'grade': grade.displayName,
    'categories': categories.map((c) => c.name).toList(),
    'reference': {
      'book': book,
      'hadith': hadithInBook,
    },
    'isBookmarked': isBookmarked,
    'bookmarkCollection': bookmarkCollection,
  };

  /// Generate shareable formatted text
  String get shareableText {
    final buffer = StringBuffer();
    
    buffer.writeln('══════════════════════');
    buffer.writeln('📖 $formattedReference');
    buffer.writeln('══════════════════════');
    buffer.writeln();
    
    if (extractedNarrator != null) {
      buffer.writeln('🔗 Narrator: $extractedNarrator');
      buffer.writeln();
    }
    
    if (arabicText != null && arabicText!.isNotEmpty) {
      buffer.writeln(arabicText!);
      buffer.writeln();
    }
    
    buffer.writeln(text);
    buffer.writeln();
    
    if (grade != HadithGrade.unknown) {
      buffer.writeln('⭐ Grade: ${grade.displayName}');
    }
    
    if (scholarGrades.isNotEmpty) {
      buffer.writeln('📌 ${scholarGrades.first.displayText}');
    }
    
    buffer.writeln();
    buffer.writeln('──────────────────────');
    buffer.writeln('Shared via Sukoon Launcher ☪️');
    buffer.writeln('📲 https://play.google.com/store/apps/details?id=com.sukoon.launcher');
    
    return buffer.toString();
  }
}

/// Dua model for storing supplication data
class Dua {
  final String id;
  final String title;
  final String arabicText;
  final String transliteration;
  final String translation;
  final String? category;
  final String? source;
  final bool isBookmarked;
  final String? bookmarkCollection;
  final int? repeatCount; // For duas with recommended repetition count
  final String? benefit; // Description of the benefits/rewards

  Dua({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.transliteration,
    required this.translation,
    this.category,
    this.source,
    this.isBookmarked = false,
    this.bookmarkCollection,
    this.repeatCount,
    this.benefit,
  });

  Dua copyWith({
    String? id,
    String? title,
    String? arabicText,
    String? transliteration,
    String? translation,
    String? category,
    String? source,
    bool? isBookmarked,
    String? bookmarkCollection,
    int? repeatCount,
    String? benefit,
  }) {
    return Dua(
      id: id ?? this.id,
      title: title ?? this.title,
      arabicText: arabicText ?? this.arabicText,
      transliteration: transliteration ?? this.transliteration,
      translation: translation ?? this.translation,
      category: category ?? this.category,
      source: source ?? this.source,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarkCollection: bookmarkCollection ?? this.bookmarkCollection,
      repeatCount: repeatCount ?? this.repeatCount,
      benefit: benefit ?? this.benefit,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'arabicText': arabicText,
    'transliteration': transliteration,
    'translation': translation,
    'category': category,
    'source': source,
    'isBookmarked': isBookmarked,
    'bookmarkCollection': bookmarkCollection,
    'repeatCount': repeatCount,
    'benefit': benefit,
  };

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      arabicText: json['arabicText'] as String? ?? json['arabic'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? json['english'] as String? ?? '',
      category: json['category'] as String?,
      source: json['source'] as String?,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      bookmarkCollection: json['bookmarkCollection'] as String?,
      repeatCount: json['repeatCount'] as int?,
      benefit: json['benefit'] as String?,
    );
  }

  /// Generate shareable formatted text
  String get shareableText {
    final buffer = StringBuffer();
    
    buffer.writeln('══════════════════════');
    buffer.writeln('🤲 $title');
    buffer.writeln('══════════════════════');
    buffer.writeln();
    buffer.writeln(arabicText);
    buffer.writeln();
    buffer.writeln('📝 $transliteration');
    buffer.writeln();
    buffer.writeln('💬 $translation');
    buffer.writeln();
    
    if (source != null) {
      buffer.writeln('📖 Source: $source');
    }
    
    buffer.writeln();
    buffer.writeln('──────────────────────');
    buffer.writeln('Shared via Sukoon Launcher ☪️');
    buffer.writeln('📲 https://play.google.com/store/apps/details?id=com.sukoon.launcher');
    
    return buffer.toString();
  }
}

/// Hadith collection info
class HadithCollection {
  final String id;
  final String name;
  final String shortName;
  final String apiKey;      // Legacy key for offline cache compat
  final String bookSlug;    // hadithapi.com slug
  final int totalHadiths;
  final String arabicName;
  final HadithGrade defaultGrade;

  const HadithCollection({
    required this.id,
    required this.name,
    required this.shortName,
    required this.apiKey,
    required this.bookSlug,
    required this.totalHadiths,
    this.arabicName = '',
    this.defaultGrade = HadithGrade.unknown,
  });

  static const List<HadithCollection> collections = [
    HadithCollection(
      id: 'bukhari',
      name: 'Sahih al-Bukhari',
      shortName: 'Bukhari',
      apiKey: 'eng-bukhari',
      bookSlug: 'sahih-bukhari',
      totalHadiths: 7563,
      arabicName: 'صحيح البخاري',
      defaultGrade: HadithGrade.sahih,
    ),
    HadithCollection(
      id: 'muslim',
      name: 'Sahih Muslim',
      shortName: 'Muslim',
      apiKey: 'eng-muslim',
      bookSlug: 'sahih-muslim',
      totalHadiths: 7563,
      arabicName: 'صحيح مسلم',
      defaultGrade: HadithGrade.sahih,
    ),
    HadithCollection(
      id: 'abudawud',
      name: 'Sunan Abu Dawud',
      shortName: 'Abu Dawud',
      apiKey: 'eng-abudawud',
      bookSlug: 'abu-dawood',
      totalHadiths: 5274,
      arabicName: 'سنن أبي داود',
    ),
    HadithCollection(
      id: 'tirmidhi',
      name: 'Jami at-Tirmidhi',
      shortName: 'Tirmidhi',
      apiKey: 'eng-tirmidhi',
      bookSlug: 'al-tirmidhi',
      totalHadiths: 3956,
      arabicName: 'جامع الترمذي',
    ),
    HadithCollection(
      id: 'nasai',
      name: "Sunan an-Nasa'i",
      shortName: "Nasa'i",
      apiKey: 'eng-nasai',
      bookSlug: 'sunan-nasai',
      totalHadiths: 5761,
      arabicName: 'سنن النسائي',
    ),
    HadithCollection(
      id: 'ibnmajah',
      name: 'Sunan Ibn Majah',
      shortName: 'Ibn Majah',
      apiKey: 'eng-ibnmajah',
      bookSlug: 'ibn-e-majah',
      totalHadiths: 4341,
      arabicName: 'سنن ابن ماجه',
    ),
  ];

  static HadithCollection fromId(String id) {
    return collections.firstWhere(
      (c) => c.id == id,
      orElse: () => collections.first,
    );
  }

  static HadithCollection fromSlug(String slug) {
    return collections.firstWhere(
      (c) => c.bookSlug == slug,
      orElse: () => collections.first,
    );
  }
}

/// Chapter / Kitab from hadithapi.com
class HadithChapter {
  final int id;
  final int chapterNumber;
  final String chapterEnglish;
  final String chapterArabic;
  final String chapterUrdu;
  final String bookSlug;

  const HadithChapter({
    required this.id,
    required this.chapterNumber,
    required this.chapterEnglish,
    required this.chapterArabic,
    required this.chapterUrdu,
    required this.bookSlug,
  });

  factory HadithChapter.fromJson(Map<String, dynamic> json) {
    return HadithChapter(
      id: json['id'] as int? ?? 0,
      chapterNumber: int.tryParse(json['chapterNumber']?.toString() ?? '') ?? 0,
      chapterEnglish: json['chapterEnglish'] as String? ?? json['chapter_english'] as String? ?? '',
      chapterArabic: json['chapterArabic'] as String? ?? json['chapter_arabic'] as String? ?? '',
      chapterUrdu: json['chapterUrdu'] as String? ?? json['chapter_urdu'] as String? ?? '',
      bookSlug: json['bookSlug'] as String? ?? json['book_slug'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterNumber': chapterNumber,
    'chapterEnglish': chapterEnglish,
    'chapterArabic': chapterArabic,
    'chapterUrdu': chapterUrdu,
    'bookSlug': bookSlug,
  };
}

/// Bookmark collection for organizing
class BookmarkCollection {
  final String id;
  final String name;
  final String? emoji;
  final DateTime createdAt;

  const BookmarkCollection({
    required this.id,
    required this.name,
    this.emoji,
    required this.createdAt,
  });

  static const List<String> defaultCollections = [
    'Favorites',
    'To Read',
    'Memorize',
    'Share',
  ];
}
