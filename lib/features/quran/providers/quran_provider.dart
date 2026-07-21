import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/surah.dart';
import '../models/verse.dart';
import '../models/tafseer.dart';
import '../services/quran_service.dart';
import '../services/tafseer_service.dart';
import '../../../providers/tafseer_edition_provider.dart';
import '../../../utils/hive_box_manager.dart';
import 'quran_settings_provider.dart';

// Service providers
final quranServiceProvider = Provider((ref) => QuranService());
final tafseerServiceProvider = Provider((ref) => TafseerService());

// Surahs provider — language-aware
final surahsProvider = FutureProvider<List<Surah>>((ref) async {
  // Keep the parsed Quran in memory — 2.4 MB JSON only parsed once per session.
  ref.keepAlive();
  final service = ref.read(quranServiceProvider);
  final settings = ref.watch(quranSettingsProvider);
  return await service.loadSurahs(lang: settings.translationLang);
});

// Verses provider for a specific surah — language-aware
final versesProvider = FutureProvider.family<List<Verse>, int>((
  ref,
  surahId,
) async {
  final service = ref.read(quranServiceProvider);
  final settings = ref.watch(quranSettingsProvider);
  return await service.loadVerses(surahId, lang: settings.translationLang);
});

// Selected surah provider
final selectedSurahProvider = StateProvider<Surah?>((ref) => null);

// Random verse of the day provider
final randomVerseProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(quranServiceProvider);
  return await service.getRandomVerse();
});

// Tafseer provider for a specific ayah - uses selected edition
final tafseerProvider = FutureProvider.family<Tafseer?, ({int surahId, int ayahId})>((
  ref,
  params,
) async {
  final service = ref.read(tafseerServiceProvider);
  final selectedEdition = ref.watch(selectedTafseerEditionProvider);
  return await service.getTafseer(
    params.surahId, 
    params.ayahId, 
    edition: selectedEdition.slug,
  );
});

// Surah download status provider - uses selected edition
final surahDownloadedProvider = FutureProvider.family<bool, int>((
  ref,
  surahId,
) async {
  final service = ref.read(tafseerServiceProvider);
  final selectedEdition = ref.watch(selectedTafseerEditionProvider);
  return await service.isSurahDownloaded(surahId, edition: selectedEdition.slug);
});

// ============ READING PROGRESS ============

/// Last read position model
class LastReadPosition {
  final int surahId;
  final String surahName;
  final String surahTransliteration;
  final int ayahNumber;
  final int totalVerses;
  final DateTime timestamp;

  LastReadPosition({
    required this.surahId,
    required this.surahName,
    required this.surahTransliteration,
    required this.ayahNumber,
    required this.totalVerses,
    required this.timestamp,
  });

  factory LastReadPosition.fromJson(Map<String, dynamic> json) {
    return LastReadPosition(
      surahId: json['surahId'] as int? ?? 1,
      surahName: json['surahName'] as String? ?? '',
      surahTransliteration: json['surahTransliteration'] as String? ?? '',
      ayahNumber: json['ayahNumber'] as int? ?? 1,
      totalVerses: json['totalVerses'] as int? ?? 1,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'surahId': surahId,
    'surahName': surahName,
    'surahTransliteration': surahTransliteration,
    'ayahNumber': ayahNumber,
    'totalVerses': totalVerses,
    'timestamp': timestamp.toIso8601String(),
  };

  String get displayText {
    return '$surahTransliteration - Ayah $ayahNumber';
  }

  double get progressPercentage {
    if (totalVerses == 0) return 0;
    return (ayahNumber / totalVerses) * 100;
  }
}

/// Reading progress state
class ReadingProgressState {
  final LastReadPosition? lastPosition;
  final bool isLoading;

  ReadingProgressState({
    this.lastPosition,
    this.isLoading = true,
  });

  ReadingProgressState copyWith({
    LastReadPosition? lastPosition,
    bool? isLoading,
  }) {
    return ReadingProgressState(
      lastPosition: lastPosition ?? this.lastPosition,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Reading progress provider
final readingProgressProvider = StateNotifierProvider<ReadingProgressNotifier, ReadingProgressState>((ref) {
  return ReadingProgressNotifier();
});

class ReadingProgressNotifier extends StateNotifier<ReadingProgressState> {
  static const String _boxName = 'quran_reading_progress';
  Box<String>? _box;

  ReadingProgressNotifier() : super(ReadingProgressState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get<String>(_boxName);
      await _loadProgress();
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadProgress() async {
    try {
      final data = _box?.get('last_position');
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final position = LastReadPosition.fromJson(json);
        state = ReadingProgressState(
          lastPosition: position,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> saveProgress({
    required int surahId,
    required String surahName,
    required String surahTransliteration,
    required int ayahNumber,
    required int totalVerses,
  }) async {
    final position = LastReadPosition(
      surahId: surahId,
      surahName: surahName,
      surahTransliteration: surahTransliteration,
      ayahNumber: ayahNumber,
      totalVerses: totalVerses,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(lastPosition: position);

    try {
      _box ??= await HiveBoxManager.get<String>(_boxName);
      await _box!.put('last_position', jsonEncode(position.toJson()));
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> clearProgress() async {
    state = ReadingProgressState(isLoading: false);
    try {
      await _box?.delete('last_position');
    } catch (e) {
      // Silently fail
    }
  }
}

/// Helper to save reading position from anywhere
Future<void> saveQuranReadingPosition(
  WidgetRef ref, {
  required Surah surah,
  required int ayahNumber,
}) async {
  await ref.read(readingProgressProvider.notifier).saveProgress(
    surahId: surah.id,
    surahName: surah.name,
    surahTransliteration: surah.transliteration,
    ayahNumber: ayahNumber,
    totalVerses: surah.totalVerses,
  );
}
