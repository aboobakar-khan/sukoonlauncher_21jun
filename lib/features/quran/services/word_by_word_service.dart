import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One Arabic word paired with its English gloss.
class WbwWord {
  final String arabic;
  final String english;
  const WbwWord(this.arabic, this.english);
}

/// Word-by-word English glosses for the whole Quran.
///
/// Source: `assets/english-wbw-translation.json` — a flat map of
/// `"surah:ayah:word" → english`. The final word of every ayah is an
/// ayah-number marker like `"(7)"`, which we drop. Validated to align with
/// the Arabic ayah text (split on whitespace) for 6229/6236 ayahs (99.9%);
/// the few mismatches fall back gracefully (English left blank for any word
/// past the available glosses).
class WordByWordService {
  /// "surah:ayah" → ordered list of English word glosses.
  final Map<String, List<String>> _byAyah;

  WordByWordService._(this._byAyah);

  static final _markerRe = RegExp(r'^\(\d+\)$');

  static Future<WordByWordService> load() async {
    final raw =
        await rootBundle.loadString('assets/english-wbw-translation.json');
    final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;

    // Group by "surah:ayah", keeping word-index order, skipping the (n) marker.
    final tmp = <String, Map<int, String>>{};
    data.forEach((key, value) {
      final en = value as String;
      if (_markerRe.hasMatch(en)) return; // ayah-number marker, not a word
      final parts = key.split(':');
      if (parts.length != 3) return;
      final sa = '${parts[0]}:${parts[1]}';
      final w = int.tryParse(parts[2]);
      if (w == null) return;
      (tmp[sa] ??= <int, String>{})[w] = en;
    });

    final byAyah = <String, List<String>>{};
    tmp.forEach((sa, words) {
      final idxs = words.keys.toList()..sort();
      byAyah[sa] = [for (final i in idxs) words[i]!];
    });

    return WordByWordService._(byAyah);
  }

  List<String> englishFor(int surah, int ayah) =>
      _byAyah['$surah:$ayah'] ?? const [];

  /// Pair an ayah's Arabic text (split on whitespace) with its English glosses.
  /// Trailing Arabic words without a gloss get an empty string.
  List<WbwWord> pair(String arabicText, int surah, int ayah) {
    final arWords = arabicText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();
    final en = englishFor(surah, ayah);
    return [
      for (int i = 0; i < arWords.length; i++)
        WbwWord(arWords[i], i < en.length ? en[i] : ''),
    ];
  }
}

/// Loads + caches the word-by-word data (one-time async parse).
final wordByWordServiceProvider = FutureProvider<WordByWordService>((ref) {
  return WordByWordService.load();
});
