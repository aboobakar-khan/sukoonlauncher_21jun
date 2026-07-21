import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/surah.dart';
import '../models/verse.dart';
import 'alquran_api_service.dart';

class QuranService {
  final AlQuranApiService _apiService = AlQuranApiService();

  static List<dynamic>? _cachedQuranJson;

  /// Top-level function for compute() — must be static/top-level
  static List<dynamic> _parseJson(String jsonString) {
    return json.decode(jsonString) as List<dynamic>;
  }

  Future<List<dynamic>> _getQuranJson() async {
    if (_cachedQuranJson != null) return _cachedQuranJson!;
    final String jsonString = await rootBundle.loadString('assets/quran/quran_en.json');
    // Parse 2.4MB JSON in a background isolate to avoid blocking the UI thread
    _cachedQuranJson = await compute(_parseJson, jsonString);
    return _cachedQuranJson!;
  }

  /// Load surahs — tries API first (for current language), falls back to local JSON
  Future<List<Surah>> loadSurahs({String lang = 'en'}) async {
    // Try API for non-English or if we want fresh data
    if (lang != 'en') {
      try {
        final apiSurahs = await _apiService.getAllSurahs(lang: lang);
        if (apiSurahs.isNotEmpty) {
          return apiSurahs
              .map((s) => Surah(
                    id: s.id,
                    name: s.name,
                    transliteration: s.transliteration,
                    type: s.type,
                    totalVerses: s.totalVerses,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint('QuranService: API surah list failed, using local: $e');
      }
    }

    // Fallback to local JSON
    return _loadLocalSurahs();
  }

  Future<List<Surah>> _loadLocalSurahs() async {
    try {
      final jsonList = await _getQuranJson();
      return jsonList
          .map((json) => Surah.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Load verses — API-first with local JSON fallback.
  /// When [lang] != 'en', fetches translation from API.
  /// Returns verses with translations in the requested language.
  Future<List<Verse>> loadVerses(int surahId, {String lang = 'en'}) async {
    // Try API (especially for non-English)
    if (lang != 'en') {
      try {
        final apiDetail = await _apiService.getSurah(surahId, lang: lang);
        if (apiDetail != null && apiDetail.verses.isNotEmpty) {
          return apiDetail.verses
              .map((v) => Verse(
                    id: v.id,
                    arabic: v.text,
                    translation: v.translation,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint('QuranService: API verse fetch failed, using local: $e');
      }
    }

    // Fallback to local JSON (English only)
    return _loadLocalVerses(surahId);
  }

  Future<List<Verse>> _loadLocalVerses(int surahId) async {
    try {
      final jsonList = await _getQuranJson();

      final surahData = jsonList.firstWhere(
        (s) => s['id'] == surahId,
        orElse: () => null,
      );

      if (surahData == null) return [];

      final List<dynamic> versesJson = surahData['verses'] as List<dynamic>;
      return versesJson
          .map((json) => Verse.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get audio recitations for a surah
  Future<Map<String, AudioRecitation>> getAudioRecitations(int surahId) async {
    try {
      final detail = await _apiService.getSurah(surahId, lang: 'en');
      if (detail != null) {
        return detail.audio;
      }
    } catch (e) {
      debugPrint('QuranService: Failed to get audio: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>?> getRandomVerse({String lang = 'en'}) async {
    try {
      // Use the shared cache instead of re-loading the 2.4 MB file
      final jsonList = await _getQuranJson();

      // Pick a random surah
      final random = Random();
      final randomSurahIndex = random.nextInt(jsonList.length);
      final surahData = jsonList[randomSurahIndex];

      final List<dynamic> verses = surahData['verses'] as List<dynamic>;
      if (verses.isEmpty) return null;

      // Pick a random verse from that surah
      final randomVerseIndex = random.nextInt(verses.length);
      final verseData = verses[randomVerseIndex];

      return {
        'surahId': surahData['id'] as int,
        'surahName': surahData['name'] as String,
        'surahTransliteration': surahData['transliteration'] as String,
        'verseNumber': verseData['id'] as int,
        'arabic': verseData['text'] as String,
        'translation': verseData['translation'] as String?,
      };
    } catch (e) {
      return null;
    }
  }
}
