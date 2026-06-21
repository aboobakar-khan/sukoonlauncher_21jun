import 'dart:convert';
import 'package:flutter/services.dart';

// ── Wisdom model ──────────────────────────────────────────────────────────────

class WisdomDetail {
  final String biography;
  final String context;
  final String lesson;
  final String deedOrReward;
  final String relatedAyah;

  const WisdomDetail({
    required this.biography,
    required this.context,
    required this.lesson,
    required this.deedOrReward,
    required this.relatedAyah,
  });

  factory WisdomDetail.fromJson(Map<String, dynamic> j) => WisdomDetail(
        biography:    j['biography']      ?? '',
        context:      j['context']        ?? '',
        lesson:       j['lesson']         ?? '',
        deedOrReward: j['deed_or_reward'] ?? '',
        relatedAyah:  j['related_ayah']   ?? '',
      );
}

class WisdomEntry {
  final int id;
  final int day;
  final String wisdom;
  final String sourceType;
  final String attributedTo;
  final String knownAs;
  final String? hadithReference;
  final String category;
  final WisdomDetail detail;

  const WisdomEntry({
    required this.id,
    required this.day,
    required this.wisdom,
    required this.sourceType,
    required this.attributedTo,
    required this.knownAs,
    this.hadithReference,
    required this.category,
    required this.detail,
  });

  factory WisdomEntry.fromJson(Map<String, dynamic> j) => WisdomEntry(
        id:              j['id']              as int,
        day:             j['day']             as int,
        wisdom:          j['wisdom']          as String,
        sourceType:      j['source_type']     as String,
        attributedTo:    j['attributed_to']   as String,
        knownAs:         j['known_as']        as String,
        hadithReference: j['hadith_reference'] as String?,
        category:        j['category']        as String,
        detail:          WisdomDetail.fromJson(j['detail'] as Map<String, dynamic>),
      );
}

// ── Wisdom Service ────────────────────────────────────────────────────────────

class WisdomService {
  static List<WisdomEntry>? _cache;

  /// Loads wisdom.json from assets (cached after first load).
  static Future<List<WisdomEntry>> _loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/wisdom.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => WisdomEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// Returns today's wisdom based on day-of-year, cycling through the full list.
  static Future<WisdomEntry> todaysWisdom() async {
    final all = await _loadAll();
    final dayOfYear = _dayOfYear(DateTime.now());
    final idx = (dayOfYear - 1) % all.length;
    return all[idx];
  }

  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }
}
