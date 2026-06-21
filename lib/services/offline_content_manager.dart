import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../features/quran/services/tafseer_service.dart';
import '../features/hadith_dua/services/hadith_dua_service.dart';
import '../features/hadith_dua/models/hadith_dua_models.dart';
import 'dart:convert';
import '../utils/hive_box_manager.dart';

/// Offline Content Download Manager
/// 
/// Features:
/// - Auto-download on first launch
/// - Background downloading with progress
/// - Connectivity-aware auto-resume
/// - Manual re-download option

class DownloadStatus {
  final bool isDownloading;
  final double progress;
  final String? currentItem;
  final bool tafseerComplete;
  final bool hadithComplete;
  final bool duaComplete;
  final Map<String, bool> downloadedCollections;
  final String? error;
  final int hadithsDownloaded;
  final int tafseersDownloaded;
  final DateTime? lastDownloadTime;

  const DownloadStatus({
    this.isDownloading = false,
    this.progress = 0.0,
    this.currentItem,
    this.tafseerComplete = false,
    this.hadithComplete = false,
    this.duaComplete = false,
    this.downloadedCollections = const {},
    this.error,
    this.hadithsDownloaded = 0,
    this.tafseersDownloaded = 0,
    this.lastDownloadTime,
  });

  DownloadStatus copyWith({
    bool? isDownloading,
    double? progress,
    String? currentItem,
    bool? tafseerComplete,
    bool? hadithComplete,
    bool? duaComplete,
    Map<String, bool>? downloadedCollections,
    String? error,
    int? hadithsDownloaded,
    int? tafseersDownloaded,
    DateTime? lastDownloadTime,
  }) {
    return DownloadStatus(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      currentItem: currentItem ?? this.currentItem,
      tafseerComplete: tafseerComplete ?? this.tafseerComplete,
      hadithComplete: hadithComplete ?? this.hadithComplete,
      duaComplete: duaComplete ?? this.duaComplete,
      downloadedCollections: downloadedCollections ?? this.downloadedCollections,
      error: error,
      hadithsDownloaded: hadithsDownloaded ?? this.hadithsDownloaded,
      tafseersDownloaded: tafseersDownloaded ?? this.tafseersDownloaded,
      lastDownloadTime: lastDownloadTime ?? this.lastDownloadTime,
    );
  }

  /// Core content is complete when duas and hadiths are done.
  /// Tafseer is optional and user-initiated.
  bool get isComplete => hadithComplete && duaComplete;
  
  double get overallProgress {
    int completed = 0;
    if (tafseerComplete) completed++;
    if (hadithComplete) completed++;
    if (duaComplete) completed++;
    return completed / 3.0;
  }

  String get statusText {
    if (isDownloading) {
      return currentItem ?? 'Downloading...';
    }
    if (error != null) {
      return 'Paused - will resume when online';
    }
    if (isComplete) {
      return 'All content available offline';
    }
    return 'Tap to start download';
  }

  String get detailText {
    final parts = <String>[];
    if (hadithsDownloaded > 0) parts.add('$hadithsDownloaded hadiths');
    if (tafseersDownloaded > 0) parts.add('$tafseersDownloaded surahs tafseer');
    if (duaComplete) parts.add('All duas');
    return parts.isEmpty ? 'No content downloaded yet' : parts.join(' • ');
  }
}

class OfflineContentManager extends StateNotifier<DownloadStatus> {
  static const String _boxName = 'offline_content_v2';
  static const String _hadithBoxName = 'hadith_offline_v2'; // Dedicated box for O(1) lookups
  static const String _statusKey = 'download_status';
  static const String _duaCacheKey = 'dua_cache';
  static const String _hadithCountKey = 'hadith_count';
  static const String _tafseerCountKey = 'tafseer_count';
  static const String _lastDownloadKey = 'last_download';
  static const String _chaptersKeyPrefix = 'ch_';
  static const String _downloadedCollectionsKey = 'downloaded_collections';
  
  Box<String>? _box;
  LazyBox<String>? _hadithBox; // Use LazyBox for massive hadith data
  TafseerService? _tafseerService;
  HadithDuaService? _hadithService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isInitialized = false;
  bool _isPaused = false;

  OfflineContentManager() : super(const DownloadStatus()) {
    _init();
  }

  Future<void> _init() async {
    try {
      debugPrint('OfflineContentManager: Initializing...');
      _box = await HiveBoxManager.get<String>(_boxName);
      _hadithBox = await HiveBoxManager.getLazy<String>(_hadithBoxName);
      
      _tafseerService = TafseerService();
      await _tafseerService!.init();
      
      _hadithService = HadithDuaService();
      
      // Load saved status
      final savedStatus = _box?.get(_statusKey);
      if (savedStatus != null) {
        try {
          final json = jsonDecode(savedStatus) as Map<String, dynamic>;
          final lastDownload = _box?.get(_lastDownloadKey);
          final downloadedJson = _box?.get(_downloadedCollectionsKey);
          Map<String, bool> downloaded = {};
          if (downloadedJson != null) {
            try {
              final map = jsonDecode(downloadedJson) as Map<String, dynamic>;
              downloaded = map.map((k, v) => MapEntry(k, v as bool));
            } catch (_) {}
          }

          state = DownloadStatus(
            tafseerComplete: json['tafseerComplete'] as bool? ?? false,
            hadithComplete: json['hadithComplete'] as bool? ?? false,
            duaComplete: json['duaComplete'] as bool? ?? false,
            downloadedCollections: downloaded,
            hadithsDownloaded: int.tryParse(_box?.get(_hadithCountKey) ?? '0') ?? 0,
            tafseersDownloaded: int.tryParse(_box?.get(_tafseerCountKey) ?? '0') ?? 0,
            lastDownloadTime: lastDownload != null ? DateTime.tryParse(lastDownload) : null,
          );
          debugPrint('OfflineContentManager: Loaded status - complete: ${state.isComplete}');
        } catch (e) {
          debugPrint('OfflineContentManager: Error loading status: $e');
        }
      }
      
      _isInitialized = true;
      
      // Only listen for connectivity changes if downloads are incomplete.
      // Once all content is downloaded, no need to keep a stream subscription
      // running (saves battery + radio wakeups).
      if (!state.isComplete) {
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          _onConnectivityChanged,
        );
      }
      
      // Do NOT auto-start download — user must trigger it manually
    } catch (e) {
      debugPrint('OfflineContentManager init error: $e');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasInternet = results.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet
    );
    
    debugPrint('OfflineContentManager: Connectivity changed, hasInternet: $hasInternet');
    
    // Only resume if a download was already started and paused (has error / partial progress)
    final wasStartedBefore = state.hadithsDownloaded > 0 || state.duaComplete || state.tafseersDownloaded > 0;
    if (hasInternet && !state.isComplete && !state.isDownloading && !_isPaused && wasStartedBefore) {
      _checkAndStartDownload();
    }
  }

  Future<void> _checkAndStartDownload() async {
    if (!_isInitialized || state.isDownloading || _isPaused) {
      debugPrint('OfflineContentManager: Cannot start - init:$_isInitialized, downloading:${state.isDownloading}, paused:$_isPaused');
      return;
    }
    
    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet
    );
    
    if (!hasInternet) {
      debugPrint('OfflineContentManager: No internet, skipping download');
      return;
    }
    
    debugPrint('OfflineContentManager: Starting background download');
    startBackgroundDownload();
  }

  /// Start downloading all offline content
  Future<void> startBackgroundDownload() async {
    if (state.isDownloading) {
      debugPrint('OfflineContentManager: Already downloading');
      return;
    }
    
    _isPaused = false;
    state = state.copyWith(isDownloading: true, error: null);
    debugPrint('OfflineContentManager: Download started');
    
    try {
      // 1. Download Duas first (smallest, instant value)
      if (!state.duaComplete) {
        debugPrint('OfflineContentManager: Downloading duas...');
        await _downloadDuas();
      }
      
      // 2. Download Hadiths
      if (!state.hadithComplete && !_isPaused) {
        debugPrint('OfflineContentManager: Downloading hadiths...');
        await _downloadHadiths();
      }
      
      // NOTE: Tafseer is NOT auto-downloaded.
      // Users can trigger it manually via downloadTafseerManually().
      
      // Save completion time
      if (state.isComplete) {
        await _box?.put(_lastDownloadKey, DateTime.now().toIso8601String());
        state = state.copyWith(
          isDownloading: false,
          lastDownloadTime: DateTime.now(),
        );
        // Cancel connectivity listener — no longer needed (battery saver)
        _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
        debugPrint('OfflineContentManager: All downloads complete! Connectivity listener stopped.');
      } else {
        state = state.copyWith(isDownloading: false);
      }
    } catch (e) {
      debugPrint('OfflineContentManager: Download error: $e');
      state = state.copyWith(
        isDownloading: false,
        error: 'Download paused. Will retry when connected.',
      );
    }
  }

  Future<void> _downloadDuas() async {
    state = state.copyWith(currentItem: 'Downloading Duas...');
    
    try {
      final duas = _hadithService!.getCuratedDuas();
      
      // Cache duas locally
      final duaJson = jsonEncode(duas.map((d) => d.toJson()).toList());
      await _box?.put(_duaCacheKey, duaJson);
      
      state = state.copyWith(duaComplete: true, progress: 0.1);
      await _saveStatus();
      debugPrint('OfflineContentManager: Duas downloaded: ${duas.length}');
    } catch (e) {
      debugPrint('OfflineContentManager: Dua download error: $e');
    }
  }

  Future<void> _downloadHadiths() async {
    state = state.copyWith(currentItem: 'Downloading Hadiths...');
    
    try {
      final collections = HadithCollection.collections;
      int totalSaved = state.hadithsDownloaded;

      for (int i = 0; i < collections.length; i++) {
        if (_isPaused) break;
        
        final collection = collections[i];
        
        // Skip if already downloaded (approximated by count)
        // But better to check per collection status if we had it
        
        state = state.copyWith(
          currentItem: 'Downloading ${collection.shortName}...',
          progress: 0.1 + (i / collections.length) * 0.3,
        );
        
        debugPrint('OfflineContentManager: Starting download for ${collection.name}...');
        
        try {
          // Download chapters first
          state = state.copyWith(currentItem: 'Loading ${collection.shortName} chapters...');
          final chapters = await _hadithService!.getChapters(collection);
          if (chapters.isNotEmpty) {
            await saveChapters(collection.bookSlug, chapters);
          }

          final hadiths = await _hadithService!.downloadHadithsForOffline(
            collection,
            onProgress: (current, total) {
              state = state.copyWith(
                currentItem: '${collection.shortName}: $current/$total hadiths',
              );
            },
          );
          
          if (hadiths.isNotEmpty) {
            debugPrint('OfflineContentManager: Saving ${hadiths.length} hadiths from ${collection.shortName} to LazyBox...');
            
            // Save individually for performance (LazyBox.put)
            for (final h in hadiths) {
              final key = _getHadithKey(h.collection, h.hadithNumber);
              await _hadithBox?.put(key, jsonEncode(h.toJson()));
            }
            
            totalSaved += hadiths.length;
            await _box?.put(_hadithCountKey, totalSaved.toString());
            
            // Mark collection as downloaded
            final newDownloaded = Map<String, bool>.from(state.downloadedCollections);
            newDownloaded[collection.id] = true;
            state = state.copyWith(downloadedCollections: newDownloaded);
            await _box?.put(_downloadedCollectionsKey, jsonEncode(newDownloaded));
          }
        } catch (e) {
          debugPrint('OfflineContentManager: Error downloading ${collection.name}: $e');
        }
        
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      state = state.copyWith(
        hadithComplete: true, 
        progress: 0.4,
        hadithsDownloaded: totalSaved,
      );
      await _saveStatus();
    } catch (e) {
      debugPrint('OfflineContentManager: Hadith download error: $e');
    }
  }

  /// Cache a single hadith (auto-offline when user views)
  Future<void> cacheSingleHadith(Hadith hadith) async {
    if (!_isInitialized || _hadithBox == null) return;
    
    try {
      final key = _getHadithKey(hadith.collection, hadith.hadithNumber);
      if (!_hadithBox!.containsKey(key)) {
        await _hadithBox!.put(key, jsonEncode(hadith.toJson()));
        
        // Update count
        int count = int.tryParse(_box?.get(_hadithCountKey) ?? '0') ?? 0;
        await _box?.put(_hadithCountKey, (count + 1).toString());
        state = state.copyWith(hadithsDownloaded: count + 1);
        
        debugPrint('OfflineContentManager: Auto-cached hadith #$key');
      }
    } catch (e) {
      debugPrint('OfflineContentManager: Error caching single hadith: $e');
    }
  }

  /// Download a specific book manually
  Future<void> downloadBook(HadithCollection collection) async {
    if (!_isInitialized || state.isDownloading) return;
    
    state = state.copyWith(isDownloading: true, error: null, currentItem: 'Preparing ${collection.shortName}...');
    
    try {
      // Chapters first
      state = state.copyWith(currentItem: 'Loading ${collection.shortName} chapters...');
      final chapters = await _hadithService!.getChapters(collection);
      if (chapters.isNotEmpty) {
        await saveChapters(collection.bookSlug, chapters);
      }

      final hadiths = await _hadithService!.downloadHadithsForOffline(
        collection,
        onProgress: (current, total) {
          state = state.copyWith(
            currentItem: '${collection.shortName}: $current/$total hadiths',
          );
        },
      );
      
      if (hadiths.isNotEmpty) {
        for (final h in hadiths) {
          final key = _getHadithKey(h.collection, h.hadithNumber);
          await _hadithBox?.put(key, jsonEncode(h.toJson()));
        }
        
        int count = int.tryParse(_box?.get(_hadithCountKey) ?? '0') ?? 0;
        int newTotal = count + hadiths.length; // Approximate, might overlap
        await _box?.put(_hadithCountKey, newTotal.toString());
        
        // Mark collection as downloaded
        final newDownloaded = Map<String, bool>.from(state.downloadedCollections);
        newDownloaded[collection.id] = true;
        state = state.copyWith(downloadedCollections: newDownloaded, hadithsDownloaded: newTotal);
        await _box?.put(_downloadedCollectionsKey, jsonEncode(newDownloaded));
      }
      
      state = state.copyWith(isDownloading: false, currentItem: null);
      debugPrint('OfflineContentManager: Book ${collection.shortName} download complete');
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: 'Failed to download ${collection.shortName}');
    }
  }

  /// Clear all cached hadiths
  Future<void> clearHadithCache() async {
    if (!_isInitialized) return;
    
    try {
      await _hadithBox?.clear();
      await _box?.delete(_hadithCountKey);
      
      final currentStatus = jsonDecode(_box?.get(_statusKey) ?? '{}') as Map<String, dynamic>;
      currentStatus['hadithComplete'] = false;
      await _box?.put(_statusKey, jsonEncode(currentStatus));
      
      state = state.copyWith(
        hadithComplete: false,
        hadithsDownloaded: 0,
        currentItem: 'Hadith cache cleared',
      );
      debugPrint('OfflineContentManager: Hadith cache cleared');
    } catch (e) {
      debugPrint('OfflineContentManager: Error clearing hadith cache: $e');
    }
  }

  String _getHadithKey(String collection, int number) {
    // Normalize collection name for key
    final c = collection.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
    return '${c}_$number';
  }

  Future<void> saveChapters(String bookSlug, List<HadithChapter> chapters) async {
    if (_box == null) return;
    final json = jsonEncode(chapters.map((c) => c.toJson()).toList());
    await _box!.put('$_chaptersKeyPrefix$bookSlug', json);
    debugPrint('OfflineContentManager: Saved ${chapters.length} chapters for $bookSlug');
  }

  Future<List<HadithChapter>> getCachedChapters(String bookSlug) async {
    if (_box == null) return [];
    final json = _box!.get('$_chaptersKeyPrefix$bookSlug');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((c) => HadithChapter.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('OfflineContentManager: Error parsing cached chapters for $bookSlug: $e');
      return [];
    }
  }

  bool isCollectionDownloaded(String collectionId) {
    return state.downloadedCollections[collectionId] ?? false;
  }

  Future<List<Hadith>> getCachedHadithsByChapter({required String collectionId, required int chapterNumber}) async {
    if (_hadithBox == null) _hadithBox = await HiveBoxManager.getLazy<String>(_hadithBoxName);
    
    // This is still slow because Hive LazyBox keys() is synchronous but we need to check values
    // However, we can use the key structure: bookslug_hadithnumber
    // Wait, the key doesn't have chapter number. 
    // Ideally we should have indexed them by chapter.
    // For now, let's fetch all (which is what getCachedHadiths does) but with a filter.
    final all = await getCachedHadiths(collectionId: collectionId);
    return all.where((h) => h.book == chapterNumber).toList();
  }

  Future<void> _downloadTafseer() async {
    state = state.copyWith(currentItem: 'Preparing Tafseer download...');
    
    try {
      // Surah verse counts
      final surahVerses = {
        1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75,
        9: 129, 10: 109, 11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128,
        17: 111, 18: 110, 19: 98, 20: 135, 21: 112, 22: 78, 23: 118, 24: 64,
        25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60, 31: 34, 32: 30,
        33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
        41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29,
        49: 18, 50: 45, 51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96,
        57: 29, 58: 22, 59: 24, 60: 13, 61: 14, 62: 11, 63: 11, 64: 18,
        65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44, 71: 28, 72: 28,
        73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
        81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26,
        89: 30, 90: 20, 91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19,
        97: 5, 98: 8, 99: 8, 100: 11, 101: 11, 102: 8, 103: 3, 104: 9,
        105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3, 111: 5, 112: 4,
        113: 5, 114: 6,
      };
      
      // Priority: Short surahs first (Juz Amma), then commonly read
      final priorityOrder = [
        // Short surahs first (quick progress)
        112, 113, 114, 1, 108, 103, 110, 111, 109, 107, 105, 106, 104,
        102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88,
        87, 86, 85, 84, 83, 82, 81, 80, 79, 78,
        // Commonly read
        36, 67, 55, 56, 18, 32, 48, 71, 72, 73, 74, 75, 76, 77,
        // Rest
        2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
        19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35,
        37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 49, 50, 51, 52, 53,
        54, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 68, 69, 70,
      ];
      
      int completed = state.tafseersDownloaded;
      int totalSurahs = 114;
      
      for (int i = 0; i < priorityOrder.length && !_isPaused; i++) {
        final surahId = priorityOrder[i];
        
        // Check if already downloaded
        final isDownloaded = await _tafseerService!.isSurahDownloaded(surahId);
        if (isDownloaded) {
          completed++;
          continue;
        }
        
        state = state.copyWith(
          currentItem: 'Tafseer: Surah $surahId (${completed + 1}/$totalSurahs)',
          progress: 0.4 + (completed / totalSurahs) * 0.6,
          tafseersDownloaded: completed,
        );
        
        try {
          final verses = surahVerses[surahId] ?? 7;
          final success = await _tafseerService!.downloadSurahTafseer(surahId, verses);
          
          if (success) {
            completed++;
            await _box?.put(_tafseerCountKey, completed.toString());
            debugPrint('OfflineContentManager: Tafseer Surah $surahId downloaded');
          } else {
            debugPrint('OfflineContentManager: Tafseer Surah $surahId failed');
          }
        } catch (e) {
          debugPrint('OfflineContentManager: Error downloading tafseer $surahId: $e');
        }
        
        // Small delay to not overwhelm API
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      state = state.copyWith(
        tafseerComplete: completed >= totalSurahs,
        progress: 1.0,
        tafseersDownloaded: completed,
      );
      await _saveStatus();
      debugPrint('OfflineContentManager: Tafseer download complete: $completed/$totalSurahs');
    } catch (e) {
      debugPrint('OfflineContentManager: Tafseer download error: $e');
    }
  }

  Future<void> _saveStatus() async {
    try {
      final json = jsonEncode({
        'tafseerComplete': state.tafseerComplete,
        'hadithComplete': state.hadithComplete,
        'duaComplete': state.duaComplete,
      });
      await _box?.put(_statusKey, json);
    } catch (e) {
      debugPrint('OfflineContentManager: Error saving status: $e');
    }
  }

  Future<List<Hadith>> getCachedHadiths({String? collectionId}) async {
    if (_hadithBox == null) return [];
    
    try {
      // Since it's a LazyBox, we'd need to iterate keys to find by collection
      // For performance, we only return if we have a way to filter or just return all
      // But user wanted offline support "without informing user"
      
      final keys = _hadithBox!.keys.cast<String>();
      final results = <Hadith>[];
      
      String? filter;
      if (collectionId != null) {
        filter = collectionId.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
      }

      for (final key in keys) {
        if (filter != null && !key.startsWith(filter)) continue;
        
        final data = await _hadithBox!.get(key);
        if (data != null) {
          final map = jsonDecode(data) as Map<String, dynamic>;
          results.add(Hadith.fromJson(map, collection: map['collection'] ?? 'Unknown'));
        }
      }
      return results;
    } catch (e) {
      debugPrint('OfflineContentManager: Error getting cached hadiths: $e');
    }
    return [];
  }

  /// Get a single cached hadith by collection and number
  Future<Hadith?> getCachedHadith(String collection, int number) async {
    if (_hadithBox == null) return null;
    try {
      final key = _getHadithKey(collection, number);
      final data = await _hadithBox!.get(key);
      if (data != null) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        return Hadith.fromJson(map, collection: collection);
      }
    } catch (_) {}
    return null;
  }

  /// Get cached duas for offline use
  Future<List<Dua>> getCachedDuas() async {
    try {
      final cached = _box?.get(_duaCacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list.map((json) {
          final map = json as Map<String, dynamic>;
          return Dua.fromJson(map);
        }).toList();
      }
    } catch (e) {
      debugPrint('OfflineContentManager: Error getting cached duas: $e');
    }
    return [];
  }

  /// Force start download (manual trigger)
  Future<void> forceStartDownload() async {
    debugPrint('OfflineContentManager: Force starting download...');
    _isPaused = false;
    state = state.copyWith(error: null);
    await startBackgroundDownload();
  }

  /// Download tafseer on-demand (user-initiated only)
  Future<void> downloadTafseerManually() async {
    if (state.tafseerComplete) {
      debugPrint('OfflineContentManager: Tafseer already complete');
      return;
    }
    if (state.isDownloading) {
      debugPrint('OfflineContentManager: Already downloading');
      return;
    }

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity.any((r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet
    );
    if (!hasInternet) {
      state = state.copyWith(error: 'No internet connection');
      return;
    }

    _isPaused = false;
    state = state.copyWith(isDownloading: true, error: null);
    debugPrint('OfflineContentManager: Manual tafseer download started');

    try {
      await _downloadTafseer();
      state = state.copyWith(
        isDownloading: false,
        lastDownloadTime: DateTime.now(),
      );
      await _box?.put(_lastDownloadKey, DateTime.now().toIso8601String());
      debugPrint('OfflineContentManager: Manual tafseer download complete');
    } catch (e) {
      debugPrint('OfflineContentManager: Manual tafseer download error: $e');
      state = state.copyWith(
        isDownloading: false,
        error: 'Tafseer download failed. Tap to retry.',
      );
    }
  }

  /// Clear all and re-download
  Future<void> redownloadAll() async {
    debugPrint('OfflineContentManager: Re-downloading all content...');
    _isPaused = false;
    
    // Clear caches
    await _hadithBox?.clear();
    await _box?.delete(_hadithCountKey);
    await _box?.delete(_tafseerCountKey);
    await _box?.delete(_statusKey);
    await _tafseerService?.clearCache();
    
    state = const DownloadStatus();
    
    // Start fresh
    await startBackgroundDownload();
  }

  void pauseDownload() {
    _isPaused = true;
    state = state.copyWith(
      isDownloading: false,
      error: 'Download paused',
    );
  }

  void resumeDownload() {
    _isPaused = false;
    state = state.copyWith(error: null);
    _checkAndStartDownload();
  }

  Future<void> retryDownload() async {
    state = state.copyWith(error: null);
    _isPaused = false;
    await startBackgroundDownload();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Provider for offline content manager
final offlineContentProvider = StateNotifierProvider<OfflineContentManager, DownloadStatus>(
  (ref) => OfflineContentManager(),
);
