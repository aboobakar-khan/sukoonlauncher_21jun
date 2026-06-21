import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/prayer_record.dart';
import '../utils/hive_box_manager.dart';

/// Provider for the list of prayer records
final prayerRecordListProvider =
    StateNotifierProvider<PrayerRecordListNotifier, List<PrayerRecord>>((ref) {
  return PrayerRecordListNotifier();
});

/// Provider to get today's prayer record
final todayPrayerRecordProvider = Provider<PrayerRecord?>((ref) {
  final records = ref.watch(prayerRecordListProvider);
  final today = PrayerRecord.dateOnly(DateTime.now());
  final todayKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  try {
    return records.firstWhere((r) => r.dateKey == todayKey);
  } catch (e) {
    return null;
  }
});

/// Provider to get prayer records for the past year (for the contribution grid)
final prayerRecordsMapProvider = Provider<Map<String, PrayerRecord>>((ref) {
  final records = ref.watch(prayerRecordListProvider);
  final map = <String, PrayerRecord>{};
  for (final record in records) {
    map[record.dateKey] = record;
  }
  return map;
});

class PrayerRecordListNotifier extends StateNotifier<List<PrayerRecord>> {
  Box<PrayerRecord>? _box;

  PrayerRecordListNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get<PrayerRecord>('prayer_records');

      // ── Migration: re-key old UUID-based entries to dateKey ──────────
      // Old records used UUID as Hive key. New approach uses dateKey
      // (e.g. "2026-04-02") for O(1) lookups. This runs once on upgrade
      // and is a no-op if already migrated.
      final values = _box!.values.toList();
      for (final record in values) {
        if (!_box!.containsKey(record.dateKey)) {
          await _box!.put(record.dateKey, record);
        }
        // Remove old UUID key if it still exists
        if (_box!.containsKey(record.id) && record.id != record.dateKey) {
          await _box!.delete(record.id);
        }
      }

      state = _box!.values.toList();
    } catch (e) {
      state = [];
    }
  }

  /// Toggle a specific prayer for a given date
  Future<void> togglePrayer(DateTime date, String prayerName) async {
    _box ??= await HiveBoxManager.get<PrayerRecord>('prayer_records');

    final dateOnly = PrayerRecord.dateOnly(date);
    final dateKey =
        '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';

    // O(1) lookup by dateKey instead of scanning all records
    PrayerRecord? existing = _box!.get(dateKey);

    if (existing != null) {
      // Update existing record
      PrayerRecord updated;
      switch (prayerName.toLowerCase()) {
        case 'fajr':
          updated = existing.copyWith(fajr: !existing.fajr);
          break;
        case 'dhuhr':
          updated = existing.copyWith(dhuhr: !existing.dhuhr);
          break;
        case 'asr':
          updated = existing.copyWith(asr: !existing.asr);
          break;
        case 'maghrib':
          updated = existing.copyWith(maghrib: !existing.maghrib);
          break;
        case 'isha':
          updated = existing.copyWith(isha: !existing.isha);
          break;
        case 'tahajjud':
          updated = existing.copyWith(tahajjud: !existing.tahajjud);
          break;
        case 'ishraq':
          updated = existing.copyWith(ishraq: !existing.ishraq);
          break;
        case 'chasht':
          updated = existing.copyWith(chasht: !existing.chasht);
          break;
        case 'awwabin':
          updated = existing.copyWith(awwabin: !existing.awwabin);
          break;
        default:
          return;
      }
      await _box!.put(dateKey, updated);
      state = _box!.values.toList();
    } else {
      // Create new record for this date — use dateKey as both id and Hive key
      final newRecord = PrayerRecord(
        id: dateKey,
        date: dateOnly,
        createdAt: DateTime.now(),
      );

      // Set the toggled prayer
      PrayerRecord recordWithPrayer;
      switch (prayerName.toLowerCase()) {
        case 'fajr':
          recordWithPrayer = newRecord.copyWith(fajr: true);
          break;
        case 'dhuhr':
          recordWithPrayer = newRecord.copyWith(dhuhr: true);
          break;
        case 'asr':
          recordWithPrayer = newRecord.copyWith(asr: true);
          break;
        case 'maghrib':
          recordWithPrayer = newRecord.copyWith(maghrib: true);
          break;
        case 'isha':
          recordWithPrayer = newRecord.copyWith(isha: true);
          break;
        case 'tahajjud':
          recordWithPrayer = newRecord.copyWith(tahajjud: true);
          break;
        case 'ishraq':
          recordWithPrayer = newRecord.copyWith(ishraq: true);
          break;
        case 'chasht':
          recordWithPrayer = newRecord.copyWith(chasht: true);
          break;
        case 'awwabin':
          recordWithPrayer = newRecord.copyWith(awwabin: true);
          break;
        default:
          return;
      }

      await _box!.put(dateKey, recordWithPrayer);
      state = [...state, recordWithPrayer];
    }
  }

  /// Get prayer record for a specific date — O(1) via Hive
  PrayerRecord? getRecordForDate(DateTime date) {
    final dateOnly = PrayerRecord.dateOnly(date);
    final dateKey =
        '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';
    return _box?.get(dateKey);
  }
}
