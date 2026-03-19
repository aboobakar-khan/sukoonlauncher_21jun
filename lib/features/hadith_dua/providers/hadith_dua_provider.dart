import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hadith_dua_models.dart';
import '../services/hadith_dua_service.dart';
import '../../../utils/hive_box_manager.dart';

/// Service provider
final hadithDuaServiceProvider = Provider((ref) => HadithDuaService());

/// Available hadith languages from the API
class HadithLanguage {
  final String code;       // API prefix: eng, urd, ben, etc.
  final String name;       // Display name: English, Urdu, etc.
  final String direction;  // 'ltr' or 'rtl'

  const HadithLanguage({
    required this.code,
    required this.name,
    this.direction = 'ltr',
  });

  static const List<HadithLanguage> available = [
    HadithLanguage(code: 'eng', name: 'English'),
    HadithLanguage(code: 'ara', name: 'Arabic', direction: 'rtl'),
    HadithLanguage(code: 'urd', name: 'Urdu', direction: 'rtl'),
    HadithLanguage(code: 'ben', name: 'Bengali'),
    HadithLanguage(code: 'tur', name: 'Turkish'),
    HadithLanguage(code: 'ind', name: 'Indonesian'),
    HadithLanguage(code: 'fra', name: 'French'),
    HadithLanguage(code: 'rus', name: 'Russian'),
    HadithLanguage(code: 'tam', name: 'Tamil'),
  ];

  static HadithLanguage fromCode(String code) {
    return available.firstWhere(
      (l) => l.code == code,
      orElse: () => available.first,
    );
  }
}

/// Provider for hadith language selection — persisted in Hive
final hadithLanguageProvider = StateNotifierProvider<HadithLanguageNotifier, HadithLanguage>((ref) {
  return HadithLanguageNotifier();
});

class HadithLanguageNotifier extends StateNotifier<HadithLanguage> {
  static const String _boxName = 'hadith_settings';
  Box<String>? _box;

  HadithLanguageNotifier() : super(HadithLanguage.available.first) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get('hadith_language');
    if (saved != null) {
      state = HadithLanguage.fromCode(saved);
    }
  }

  Future<void> setLanguage(HadithLanguage lang) async {
    state = lang;
    _box ??= await HiveBoxManager.get<String>(_boxName);
    await _box!.put('hadith_language', lang.code);
  }
}

/// Provider for daily random hadith - with offline support
final dailyHadithProvider = FutureProvider<Hadith?>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  
  // Check if we have a cached daily hadith
  final box = await HiveBoxManager.get<String>('hadith_dua_cache');
  final today = DateTime.now().toIso8601String().split('T')[0];
  final cachedKey = 'daily_hadith_$today';
  
  final cached = box.get(cachedKey);
  if (cached != null) {
    try {
      final json = jsonDecode(cached) as Map<String, dynamic>;
      return Hadith.fromJson(json, collection: json['collection'] as String? ?? '');
    } catch (e) {
      // Continue to fetch new one
    }
  }

  // Fetch random hadith from Bukhari (default)
  final hadith = await service.getRandomHadith(collectionId: 'bukhari');
  
  if (hadith != null) {
    await box.put(cachedKey, jsonEncode(hadith.toJson()));
    return hadith;
  }
  
  // Fallback to offline cache
  final offlineHadiths = await _getOfflineHadiths('bukhari');
  if (offlineHadiths.isNotEmpty) {
    // Get a random one based on the day
    final index = DateTime.now().day % offlineHadiths.length;
    return offlineHadiths[index];
  }
  
  return null;
});

/// Provider for daily random dua
final dailyDuaProvider = Provider<Dua>((ref) {
  final service = ref.read(hadithDuaServiceProvider);
  
  // Get a random dua each day based on day of year
  final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  final duas = service.getCuratedDuas();
  return duas[dayOfYear % duas.length];
});

/// Provider for all duas
final allDuasProvider = Provider<List<Dua>>((ref) {
  final service = ref.read(hadithDuaServiceProvider);
  return service.getCuratedDuas();
});

/// Provider for dua categories
final duaCategoriesProvider = Provider<List<String>>((ref) {
  final duas = ref.watch(allDuasProvider);
  final categories = duas.map((d) => d.category ?? 'Other').toSet().toList();
  categories.sort();
  return categories;
});

/// Provider for duas by category
final duasByCategoryProvider = Provider.family<List<Dua>, String>((ref, category) {
  final duas = ref.watch(allDuasProvider);
  return duas.where((d) => d.category == category).toList();
});

/// Search state
class SearchState {
  final String query;
  final bool isSearching;
  final List<Hadith> hadithResults;
  final List<Dua> duaResults;
  final bool isLoading;

  SearchState({
    this.query = '',
    this.isSearching = false,
    this.hadithResults = const [],
    this.duaResults = const [],
    this.isLoading = false,
  });

  SearchState copyWith({
    String? query,
    bool? isSearching,
    List<Hadith>? hadithResults,
    List<Dua>? duaResults,
    bool? isLoading,
  }) {
    return SearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      hadithResults: hadithResults ?? this.hadithResults,
      duaResults: duaResults ?? this.duaResults,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Search provider
final searchStateProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  
  SearchNotifier(this.ref) : super(SearchState());

  void startSearch() {
    state = state.copyWith(isSearching: true);
  }

  void endSearch() {
    state = SearchState();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        query: '',
        hadithResults: [],
        duaResults: [],
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(query: query, isLoading: true);

    final service = ref.read(hadithDuaServiceProvider);
    
    // Search duas immediately (local)
    final duaResults = service.searchDuas(query);
    state = state.copyWith(duaResults: duaResults);
    
    // Search hadiths (network)
    try {
      final hadithResults = await service.searchHadiths(query);
      state = state.copyWith(hadithResults: hadithResults, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

/// Bookmarks state with collections support
class BookmarksState {
  final List<Hadith> bookmarkedHadiths;
  final List<Dua> bookmarkedDuas;
  final List<String> collections; // User-created collections

  BookmarksState({
    this.bookmarkedHadiths = const [],
    this.bookmarkedDuas = const [],
    this.collections = const ['Favorites', 'To Read', 'Memorize', 'Share'],
  });

  /// Get hadiths in a specific collection
  List<Hadith> getHadithsInCollection(String collectionName) {
    return bookmarkedHadiths
        .where((h) => h.bookmarkCollection == collectionName)
        .toList();
  }

  /// Get duas in a specific collection
  List<Dua> getDuasInCollection(String collectionName) {
    return bookmarkedDuas
        .where((d) => d.bookmarkCollection == collectionName)
        .toList();
  }
}

/// Bookmarks provider with collections
final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, BookmarksState>((ref) {
  return BookmarksNotifier();
});

class BookmarksNotifier extends StateNotifier<BookmarksState> {
  static const String _boxName = 'hadith_dua_bookmarks';
  Box<String>? _box;

  BookmarksNotifier() : super(BookmarksState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final hadithsJson = _box?.get('hadiths');
    final duasJson = _box?.get('duas');
    final collectionsJson = _box?.get('collections');

    final hadiths = <Hadith>[];
    final duas = <Dua>[];
    var collections = BookmarksState().collections;

    if (hadithsJson != null) {
      try {
        final list = jsonDecode(hadithsJson) as List<dynamic>;
        for (final item in list) {
          final json = item as Map<String, dynamic>;
          hadiths.add(Hadith.fromJson(json, collection: json['collection'] as String? ?? ''));
        }
      } catch (e) {
        // Ignore
      }
    }

    if (duasJson != null) {
      try {
        final list = jsonDecode(duasJson) as List<dynamic>;
        for (final item in list) {
          duas.add(Dua.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        // Ignore
      }
    }

    if (collectionsJson != null) {
      try {
        collections = (jsonDecode(collectionsJson) as List<dynamic>).cast<String>();
      } catch (e) {
        // Ignore
      }
    }

    state = BookmarksState(
      bookmarkedHadiths: hadiths,
      bookmarkedDuas: duas,
      collections: collections,
    );
  }

  Future<void> _saveBookmarks() async {
    _box ??= await HiveBoxManager.get<String>(_boxName);
    await _box!.put('hadiths', jsonEncode(state.bookmarkedHadiths.map((h) => h.toJson()).toList()));
    await _box!.put('duas', jsonEncode(state.bookmarkedDuas.map((d) => d.toJson()).toList()));
    await _box!.put('collections', jsonEncode(state.collections));
  }

  void toggleHadithBookmark(Hadith hadith, {String? collectionName}) {
    final existing = state.bookmarkedHadiths.any((h) => h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection);
    
    if (existing && collectionName == null) {
      // Remove from bookmarks
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths.where((h) => 
          !(h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection)
        ).toList(),
        bookmarkedDuas: state.bookmarkedDuas,
        collections: state.collections,
      );
    } else if (existing && collectionName != null) {
      // Update collection
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths.map((h) {
          if (h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection) {
            return h.copyWith(bookmarkCollection: collectionName);
          }
          return h;
        }).toList(),
        bookmarkedDuas: state.bookmarkedDuas,
        collections: state.collections,
      );
    } else {
      // Add to bookmarks
      state = BookmarksState(
        bookmarkedHadiths: [...state.bookmarkedHadiths, hadith.copyWith(
          isBookmarked: true,
          bookmarkCollection: collectionName ?? 'Favorites',
        )],
        bookmarkedDuas: state.bookmarkedDuas,
        collections: state.collections,
      );
    }
    _saveBookmarks();
  }

  void toggleDuaBookmark(Dua dua, {String? collectionName}) {
    final existing = state.bookmarkedDuas.any((d) => d.id == dua.id);
    
    if (existing && collectionName == null) {
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths,
        bookmarkedDuas: state.bookmarkedDuas.where((d) => d.id != dua.id).toList(),
        collections: state.collections,
      );
    } else if (existing && collectionName != null) {
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths,
        bookmarkedDuas: state.bookmarkedDuas.map((d) {
          if (d.id == dua.id) {
            return d.copyWith(bookmarkCollection: collectionName);
          }
          return d;
        }).toList(),
        collections: state.collections,
      );
    } else {
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths,
        bookmarkedDuas: [...state.bookmarkedDuas, dua.copyWith(
          isBookmarked: true,
          bookmarkCollection: collectionName ?? 'Favorites',
        )],
        collections: state.collections,
      );
    }
    _saveBookmarks();
  }

  void addCollection(String name) {
    if (!state.collections.contains(name)) {
      state = BookmarksState(
        bookmarkedHadiths: state.bookmarkedHadiths,
        bookmarkedDuas: state.bookmarkedDuas,
        collections: [...state.collections, name],
      );
      _saveBookmarks();
    }
  }

  void removeCollection(String name) {
    // Don't remove default collections
    if (['Favorites', 'To Read', 'Memorize', 'Share'].contains(name)) return;
    
    state = BookmarksState(
      bookmarkedHadiths: state.bookmarkedHadiths,
      bookmarkedDuas: state.bookmarkedDuas,
      collections: state.collections.where((c) => c != name).toList(),
    );
    _saveBookmarks();
  }

  bool isHadithBookmarked(Hadith hadith) {
    return state.bookmarkedHadiths.any((h) => 
      h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection
    );
  }

  bool isDuaBookmarked(Dua dua) {
    return state.bookmarkedDuas.any((d) => d.id == dua.id);
  }

  String? getHadithCollection(Hadith hadith) {
    final bookmarked = state.bookmarkedHadiths.firstWhere(
      (h) => h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection,
      orElse: () => hadith,
    );
    return bookmarked.bookmarkCollection;
  }
}

/// Selected tab provider
final hadithDuaTabProvider = StateProvider<int>((ref) => 0); // 0 = Hadith, 1 = Dua

/// Selected collection provider
final selectedCollectionProvider = StateProvider<String>((ref) => 'bukhari');

/// Selected book/chapter filter (null = show all)
final selectedBookFilterProvider = StateProvider<int?>((ref) => null);

/// Provider for available chapters/books in the selected collection.
/// Returns a map of chapter number → chapter name from hadithapi.com.
final collectionChaptersProvider = FutureProvider<Map<int, String>>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  final collectionId = ref.watch(selectedCollectionProvider);
  final collection = HadithCollection.fromId(collectionId);

  // Fetch chapters from hadithapi.com (cached internally)
  final chapters = await service.getChapters(collection);
  if (chapters.isEmpty) return {};

  final result = <int, String>{};
  for (final ch in chapters) {
    result[ch.chapterNumber] = ch.chapterEnglish;
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
});

/// Selected grade filter
final selectedGradeFilterProvider = StateProvider<HadithGrade?>((ref) => null);

/// Selected category filter
final selectedCategoryFilterProvider = StateProvider<HadithCategory?>((ref) => null);

/// Hadiths from selected collection - with offline fallback
final collectionHadithsProvider = FutureProvider<List<Hadith>>((ref) async {
  final service = ref.read(hadithDuaServiceProvider);
  final collectionId = ref.watch(selectedCollectionProvider);
  final gradeFilter = ref.watch(selectedGradeFilterProvider);
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);
  final bookFilter = ref.watch(selectedBookFilterProvider);
  
  final collection = HadithCollection.fromId(collectionId);
  
  // Fetch from hadithapi.com — returns all languages in one response
  var hadiths = await service.fetchHadiths(
    collection,
    chapterId: bookFilter,
  );
  
  // If empty, try offline cache
  if (hadiths.isEmpty) {
    hadiths = await _getOfflineHadiths(collectionId);
    // Apply book/chapter filter on offline data (not passed to API)
    if (bookFilter != null) {
      hadiths = hadiths.where((h) => h.book == bookFilter).toList();
    }
  }
  
  // Apply filters
  if (gradeFilter != null) {
    hadiths = hadiths.where((h) => h.grade == gradeFilter).toList();
  }
  if (categoryFilter != null) {
    hadiths = hadiths.where((h) => h.categories.contains(categoryFilter)).toList();
  }
  
  return hadiths;
});

/// Get hadiths from offline cache
Future<List<Hadith>> _getOfflineHadiths(String? collectionId) async {
  try {
    final box = await HiveBoxManager.get<String>('offline_content_v2');
    final cached = box.get('hadith_cache');
    if (cached != null) {
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
              ? HadithGrade.values.firstWhere(
                  (g) => g.name == map['grade'],
                  orElse: () => HadithGrade.unknown,
                )
              : HadithGrade.unknown,
        );
      }).toList();
      
      // Filter by collection if specified
      if (collectionId != null) {
        final collectionLower = collectionId.toLowerCase();
        hadiths = hadiths.where((h) => 
          h.collection.toLowerCase().contains(collectionLower) ||
          collectionLower.contains(h.collection.toLowerCase())
        ).toList();
      }
      
      return hadiths;
    }
  } catch (e) {
    // Return empty on error
  }
  return [];
}

/// Refresh trigger for daily content
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Refreshable daily hadith
final refreshableDailyHadithProvider = FutureProvider<Hadith?>((ref) async {
  ref.watch(refreshTriggerProvider); // Watch for refresh
  final service = ref.read(hadithDuaServiceProvider);
  return await service.getRandomHadith();
});

/// Refreshable daily dua
final refreshableDailyDuaProvider = Provider<Dua>((ref) {
  ref.watch(refreshTriggerProvider); // Watch for refresh
  final service = ref.read(hadithDuaServiceProvider);
  return service.getRandomDua();
});

/// Load more hadiths state
class LoadMoreHadithsState {
  final List<Hadith> hadiths;
  final bool isLoading;
  final String? collectionId;

  LoadMoreHadithsState({
    this.hadiths = const [],
    this.isLoading = false,
    this.collectionId,
  });
}

/// Load more hadiths provider
final loadMoreHadithsProvider = StateNotifierProvider<LoadMoreHadithsNotifier, LoadMoreHadithsState>((ref) {
  return LoadMoreHadithsNotifier(ref);
});

class LoadMoreHadithsNotifier extends StateNotifier<LoadMoreHadithsState> {
  final Ref ref;

  LoadMoreHadithsNotifier(this.ref) : super(LoadMoreHadithsState());

  Future<void> loadMore({String? collectionId, int count = 5}) async {
    if (state.isLoading) return;
    
    state = LoadMoreHadithsState(
      hadiths: state.hadiths,
      isLoading: true,
      collectionId: collectionId,
    );

    final service = ref.read(hadithDuaServiceProvider);
    final excludeNumbers = state.hadiths.map((h) => h.hadithNumber).toList();
    
    try {
      final newHadiths = await service.getMultipleRandomHadiths(
        collectionId: collectionId,
        count: count,
        excludeNumbers: excludeNumbers,
      );
      
      state = LoadMoreHadithsState(
        hadiths: [...state.hadiths, ...newHadiths],
        isLoading: false,
        collectionId: collectionId,
      );
    } catch (e) {
      state = LoadMoreHadithsState(
        hadiths: state.hadiths,
        isLoading: false,
        collectionId: collectionId,
      );
    }
  }

  void clear() {
    state = LoadMoreHadithsState();
  }
}

/// Expanded sections state for hadith cards
final expandedSectionsProvider = StateProvider<Map<String, Set<String>>>((ref) => {});

/// Helper to check if a section is expanded
bool isSectionExpanded(WidgetRef ref, String hadithKey, String section) {
  final expanded = ref.watch(expandedSectionsProvider);
  return expanded[hadithKey]?.contains(section) ?? false;
}

/// Toggle section expansion
void toggleSectionExpanded(WidgetRef ref, String hadithKey, String section) {
  final notifier = ref.read(expandedSectionsProvider.notifier);
  final current = Map<String, Set<String>>.from(ref.read(expandedSectionsProvider));
  
  if (!current.containsKey(hadithKey)) {
    current[hadithKey] = {section};
  } else if (current[hadithKey]!.contains(section)) {
    current[hadithKey] = Set.from(current[hadithKey]!)..remove(section);
  } else {
    current[hadithKey] = Set.from(current[hadithKey]!)..add(section);
  }
  
  notifier.state = current;
}
