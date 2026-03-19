import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/calm_watch_item.dart';
import '../../../utils/hive_box_manager.dart';

/// ──────────────────────────────────────────────────────────
///  Calm Watch Provider
/// ──────────────────────────────────────────────────────────
/// Manages the user's saved YouTube videos/playlists for
/// distraction-free Islamic media viewing.
///
/// Data is persisted in a Hive box named `calm_watch_items`.
/// ──────────────────────────────────────────────────────────

const _boxName = 'calm_watch_items';
const _uuid = Uuid();

final calmWatchProvider =
    StateNotifierProvider<CalmWatchNotifier, List<CalmWatchItem>>((ref) {
  return CalmWatchNotifier();
});

class CalmWatchNotifier extends StateNotifier<List<CalmWatchItem>> {
  CalmWatchNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await HiveBoxManager.get<CalmWatchItem>(_boxName);
    state = box.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  /// Parse a YouTube URL and save the item.
  /// Returns `null` on success, or an error message string.
  /// [tag] is an optional collection name (e.g. "Quran Recitations").
  Future<String?> addFromUrl(String url, {String tag = ''}) async {
    final parsed = _parseYoutubeUrl(url.trim());
    if (parsed == null) {
      return 'Could not parse YouTube link.\nPaste a valid video or playlist URL.';
    }

    // Duplicate check
    if (state.any((item) =>
        item.youtubeId == parsed.youtubeId &&
        item.isPlaylist == parsed.isPlaylist)) {
      return 'This ${parsed.isPlaylist ? "playlist" : "video"} is already saved.';
    }

    // Fetch real title from YouTube oEmbed API (no API key needed)
    String title = parsed.isPlaylist
        ? 'Playlist • ${parsed.youtubeId.substring(0, 8)}…'
        : 'Video • ${parsed.youtubeId}';
    try {
      final oEmbedUrl = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url.trim())}&format=json',
      );
      final response = await http.get(oEmbedUrl).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['title'] != null && (json['title'] as String).isNotEmpty) {
          title = json['title'] as String;
        }
      }
    } catch (_) {
      // oEmbed failed — keep the fallback ID-based title
    }

    final item = CalmWatchItem(
      id: _uuid.v4(),
      title: title,
      youtubeId: parsed.youtubeId,
      isPlaylist: parsed.isPlaylist,
      originalUrl: url.trim(),
      addedAt: DateTime.now(),
      tag: tag.trim(),
    );

    final box = await HiveBoxManager.get<CalmWatchItem>(_boxName);
    await box.add(item);
    state = [item, ...state];
    return null; // success
  }

  /// Returns all unique non-empty tag names currently in use.
  List<String> get existingTags {
    final tags = state
        .map((e) => e.tag)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    tags.sort();
    return tags;
  }

  /// Add a curated item (from the recommended section).
  Future<void> addCurated({
    required String title,
    required String youtubeId,
    required bool isPlaylist,
  }) async {
    if (state.any((item) =>
        item.youtubeId == youtubeId && item.isPlaylist == isPlaylist)) {
      return; // already exists
    }

    final item = CalmWatchItem(
      id: _uuid.v4(),
      title: title,
      youtubeId: youtubeId,
      isPlaylist: isPlaylist,
      originalUrl: isPlaylist
          ? 'https://youtube.com/playlist?list=$youtubeId'
          : 'https://youtube.com/watch?v=$youtubeId',
      addedAt: DateTime.now(),
      tag: '',
    );

    final box = await HiveBoxManager.get<CalmWatchItem>(_boxName);
    await box.add(item);
    state = [item, ...state];
  }

  Future<void> remove(String id) async {
    final box = await HiveBoxManager.get<CalmWatchItem>(_boxName);
    final key = box.keys.firstWhere(
      (k) => box.get(k)?.id == id,
      orElse: () => null,
    );
    if (key != null) await box.delete(key);
    state = state.where((item) => item.id != id).toList();
  }

  /// Mark a video as completed with an optional reflection note.
  Future<void> markCompleted(String id, {String reflection = ''}) async {
    await _updateItem(id, (old) => CalmWatchItem(
          id: old.id,
          title: old.title,
          youtubeId: old.youtubeId,
          isPlaylist: old.isPlaylist,
          originalUrl: old.originalUrl,
          addedAt: old.addedAt,
          isCompleted: true,
          reflection: reflection,
          tag: old.tag,
        ));
  }

  /// Move a completed video back to saved.
  Future<void> markSaved(String id) async {
    await _updateItem(id, (old) => CalmWatchItem(
          id: old.id,
          title: old.title,
          youtubeId: old.youtubeId,
          isPlaylist: old.isPlaylist,
          originalUrl: old.originalUrl,
          addedAt: old.addedAt,
          isCompleted: false,
          reflection: old.reflection,
          tag: old.tag,
        ));
  }

  Future<void> _updateItem(
      String id, CalmWatchItem Function(CalmWatchItem) update) async {
    final box = await HiveBoxManager.get<CalmWatchItem>(_boxName);
    final key = box.keys.firstWhere(
      (k) => box.get(k)?.id == id,
      orElse: () => null,
    );
    if (key == null) return;
    final updated = update(box.get(key)!);
    await box.put(key, updated);
    state = [for (final item in state) if (item.id == id) updated else item];
  }
}

// ─── YouTube URL parser ─────────────────────────────────────

class _ParseResult {
  final String youtubeId;
  final bool isPlaylist;
  _ParseResult(this.youtubeId, this.isPlaylist);
}

_ParseResult? _parseYoutubeUrl(String url) {
  // Playlist: youtube.com/playlist?list=PLxxxxxx
  final playlistRegex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
  final playlistMatch = playlistRegex.firstMatch(url);
  if (playlistMatch != null && url.contains('playlist')) {
    return _ParseResult(playlistMatch.group(1)!, true);
  }

  // Standard video: youtube.com/watch?v=xxxxx
  final watchRegex = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})');
  final watchMatch = watchRegex.firstMatch(url);
  if (watchMatch != null) {
    return _ParseResult(watchMatch.group(1)!, false);
  }

  // Short link: youtu.be/xxxxx
  final shortRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
  final shortMatch = shortRegex.firstMatch(url);
  if (shortMatch != null) {
    return _ParseResult(shortMatch.group(1)!, false);
  }

  // Embed link: youtube.com/embed/xxxxx
  final embedRegex = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})');
  final embedMatch = embedRegex.firstMatch(url);
  if (embedMatch != null) {
    return _ParseResult(embedMatch.group(1)!, false);
  }

  return null;
}
