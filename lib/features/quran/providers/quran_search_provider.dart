import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Recent search queries (chapter names or "2:188") ──────────────────────
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
        (ref) => RecentSearchesNotifier());

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  static const _key = 'quran_recent_searches';
  static const _max = 8;
  RecentSearchesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getStringList(_key) ?? const [];
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = <String>[
      q,
      ...state.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(_max).toList();
    state = list;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, list);
  }

  Future<void> clear() async {
    state = const [];
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}

// ── Last-used reader mode (persisted) ─────────────────────────────────────
// 'classic' (word-by-word) | 'focus' (clean) | 'mushaf' (page-faithful).
final quranReaderModeProvider =
    StateNotifierProvider<QuranReaderModeNotifier, String>(
        (ref) => QuranReaderModeNotifier());

class QuranReaderModeNotifier extends StateNotifier<String> {
  static const _key = 'quran_reader_mode';
  QuranReaderModeNotifier() : super('classic') {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v != null) state = v;
  }

  Future<void> set(String mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mode);
  }
}

// ── Recent reads ("surahId:ayah", most-recent first) ──────────────────────
final recentReadsProvider =
    StateNotifierProvider<RecentReadsNotifier, List<String>>(
        (ref) => RecentReadsNotifier());

class RecentReadsNotifier extends StateNotifier<List<String>> {
  static const _key = 'quran_recent_reads';
  static const _max = 6;
  RecentReadsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getStringList(_key) ?? const [];
  }

  Future<void> add(int surahId, int ayah) async {
    final token = '$surahId:$ayah';
    final list = <String>[
      token,
      ...state.where((e) => e.split(':').first != surahId.toString()),
    ].take(_max).toList();
    state = list;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, list);
  }
}
