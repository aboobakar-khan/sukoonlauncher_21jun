import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/qadha_record.dart';
import '../utils/hive_box_manager.dart';

const _uuid = Uuid();

/// Provider for the Qadha record (single record per user)
final qadhaRecordProvider =
    StateNotifierProvider<QadhaRecordNotifier, QadhaRecord?>((ref) {
  return QadhaRecordNotifier();
});

/// Qadha estimation parameters — stored alongside the record
class QadhaEstimation {
  final int yearsNotPraying;
  final String missFrequency; // 'rarely', 'sometimes', 'often', 'almost_all'
  final String estimationStyle; // 'conservative', 'balanced', 'strict'
  final int estimatedTotal;

  const QadhaEstimation({
    required this.yearsNotPraying,
    required this.missFrequency,
    required this.estimationStyle,
    required this.estimatedTotal,
  });

  Map<String, dynamic> toJson() => {
    'yearsNotPraying': yearsNotPraying,
    'missFrequency': missFrequency,
    'estimationStyle': estimationStyle,
    'estimatedTotal': estimatedTotal,
  };

  factory QadhaEstimation.fromJson(Map<String, dynamic> json) {
    return QadhaEstimation(
      yearsNotPraying: json['yearsNotPraying'] as int? ?? 0,
      missFrequency: json['missFrequency'] as String? ?? 'sometimes',
      estimationStyle: json['estimationStyle'] as String? ?? 'balanced',
      estimatedTotal: json['estimatedTotal'] as int? ?? 0,
    );
  }

  /// Calculate estimated qadha from wizard inputs
  static int calculate({
    required int yearsNotPraying,
    required String missFrequency,
    required String estimationStyle,
  }) {
    final daysMissed = yearsNotPraying * 365;

    // Miss factor: how often they missed
    double missFactor;
    switch (missFrequency) {
      case 'rarely':
        missFactor = 0.2;
        break;
      case 'sometimes':
        missFactor = 0.5;
        break;
      case 'often':
        missFactor = 0.75;
        break;
      case 'almost_all':
        missFactor = 1.0;
        break;
      default:
        missFactor = 0.5;
    }

    // Style multiplier
    double styleMultiplier;
    switch (estimationStyle) {
      case 'conservative':
        styleMultiplier = 0.8;
        break;
      case 'balanced':
        styleMultiplier = 1.0;
        break;
      case 'strict':
        styleMultiplier = 1.2;
        break;
      default:
        styleMultiplier = 1.0;
    }

    return (daysMissed * 5 * missFactor * styleMultiplier).round();
  }
}

class QadhaRecordNotifier extends StateNotifier<QadhaRecord?> {
  Box<QadhaRecord>? _box;
  Box<String>? _metaBox;

  QadhaRecordNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get<QadhaRecord>('qadha_records');
      _metaBox = await HiveBoxManager.get<String>('qadha_meta');
      if (_box!.isNotEmpty) {
        state = _box!.values.first;
      }
    } catch (e) {
      state = null;
    }
  }

  /// Get estimation data if it exists
  QadhaEstimation? getEstimation() {
    final json = _metaBox?.get('estimation');
    if (json == null) return null;
    try {
      return QadhaEstimation.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Save estimation from wizard and create/update qadha record
  Future<void> applyEstimation(QadhaEstimation estimation) async {
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');
    _metaBox ??= await HiveBoxManager.get<String>('qadha_meta');

    // Save estimation metadata
    await _metaBox!.put('estimation', jsonEncode(estimation.toJson()));

    // Distribute evenly across 5 prayers
    final perPrayer = estimation.estimatedTotal ~/ 5;
    final remainder = estimation.estimatedTotal % 5;

    final record = QadhaRecord(
      id: state?.id ?? _uuid.v4(),
      isLocked: true,
      totalFajr: perPrayer + (remainder > 0 ? 1 : 0),
      remainingFajr: perPrayer + (remainder > 0 ? 1 : 0),
      totalDhuhr: perPrayer + (remainder > 1 ? 1 : 0),
      remainingDhuhr: perPrayer + (remainder > 1 ? 1 : 0),
      totalAsr: perPrayer + (remainder > 2 ? 1 : 0),
      remainingAsr: perPrayer + (remainder > 2 ? 1 : 0),
      totalMaghrib: perPrayer + (remainder > 3 ? 1 : 0),
      remainingMaghrib: perPrayer + (remainder > 3 ? 1 : 0),
      totalIsha: perPrayer,
      remainingIsha: perPrayer,
      createdAt: state?.createdAt ?? DateTime.now(),
    );

    await _box!.put(record.id, record);
    state = record;
  }

  /// Create initial qadha record with manual totals per prayer
  Future<void> setTotals({
    required int fajr,
    required int dhuhr,
    required int asr,
    required int maghrib,
    required int isha,
  }) async {
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    final record = QadhaRecord(
      id: state?.id ?? _uuid.v4(),
      isLocked: false,
      totalFajr: fajr,
      remainingFajr: fajr,
      totalDhuhr: dhuhr,
      remainingDhuhr: dhuhr,
      totalAsr: asr,
      remainingAsr: asr,
      totalMaghrib: maghrib,
      remainingMaghrib: maghrib,
      totalIsha: isha,
      remainingIsha: isha,
      createdAt: state?.createdAt ?? DateTime.now(),
    );

    await _box!.put(record.id, record);
    state = record;
  }

  /// Lock the qadha totals — user can no longer change the estimated counts
  Future<void> lockTotals() async {
    if (state == null) return;
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    final updated = state!.copyWith(isLocked: true);
    await _box!.put(updated.id, updated);
    state = updated;
  }

  /// Decrement remaining count for a prayer (user prayed one qadha)
  Future<void> prayedOne(String prayerName) async {
    if (state == null || !state!.isLocked) return;
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    QadhaRecord updated;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        if (state!.remainingFajr <= 0) return;
        updated = state!.copyWith(remainingFajr: state!.remainingFajr - 1);
        break;
      case 'dhuhr':
        if (state!.remainingDhuhr <= 0) return;
        updated = state!.copyWith(remainingDhuhr: state!.remainingDhuhr - 1);
        break;
      case 'asr':
        if (state!.remainingAsr <= 0) return;
        updated = state!.copyWith(remainingAsr: state!.remainingAsr - 1);
        break;
      case 'maghrib':
        if (state!.remainingMaghrib <= 0) return;
        updated = state!.copyWith(remainingMaghrib: state!.remainingMaghrib - 1);
        break;
      case 'isha':
        if (state!.remainingIsha <= 0) return;
        updated = state!.copyWith(remainingIsha: state!.remainingIsha - 1);
        break;
      default:
        return;
    }

    await _box!.put(updated.id, updated);
    state = updated;
  }

  /// Pray all 5 prayers (mark a full day)
  Future<void> prayedFullDay() async {
    if (state == null || !state!.isLocked) return;
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    final updated = state!.copyWith(
      remainingFajr: (state!.remainingFajr - 1).clamp(0, state!.totalFajr),
      remainingDhuhr: (state!.remainingDhuhr - 1).clamp(0, state!.totalDhuhr),
      remainingAsr: (state!.remainingAsr - 1).clamp(0, state!.totalAsr),
      remainingMaghrib: (state!.remainingMaghrib - 1).clamp(0, state!.totalMaghrib),
      remainingIsha: (state!.remainingIsha - 1).clamp(0, state!.totalIsha),
    );

    await _box!.put(updated.id, updated);
    state = updated;
  }

  /// Increment remaining count (undo — user made a mistake)
  Future<void> undoOne(String prayerName) async {
    if (state == null || !state!.isLocked) return;
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    QadhaRecord updated;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        if (state!.remainingFajr >= state!.totalFajr) return;
        updated = state!.copyWith(remainingFajr: state!.remainingFajr + 1);
        break;
      case 'dhuhr':
        if (state!.remainingDhuhr >= state!.totalDhuhr) return;
        updated = state!.copyWith(remainingDhuhr: state!.remainingDhuhr + 1);
        break;
      case 'asr':
        if (state!.remainingAsr >= state!.totalAsr) return;
        updated = state!.copyWith(remainingAsr: state!.remainingAsr + 1);
        break;
      case 'maghrib':
        if (state!.remainingMaghrib >= state!.totalMaghrib) return;
        updated = state!.copyWith(remainingMaghrib: state!.remainingMaghrib + 1);
        break;
      case 'isha':
        if (state!.remainingIsha >= state!.totalIsha) return;
        updated = state!.copyWith(remainingIsha: state!.remainingIsha + 1);
        break;
      default:
        return;
    }

    await _box!.put(updated.id, updated);
    state = updated;
  }

  /// Automatically or manually add a new missed prayer (increases both total and remaining)
  Future<void> addOne(String prayerName) async {
    if (state == null || !state!.isLocked) return;
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');

    QadhaRecord updated;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        updated = state!.copyWith(totalFajr: state!.totalFajr + 1, remainingFajr: state!.remainingFajr + 1);
        break;
      case 'dhuhr':
        updated = state!.copyWith(totalDhuhr: state!.totalDhuhr + 1, remainingDhuhr: state!.remainingDhuhr + 1);
        break;
      case 'asr':
        updated = state!.copyWith(totalAsr: state!.totalAsr + 1, remainingAsr: state!.remainingAsr + 1);
        break;
      case 'maghrib':
        updated = state!.copyWith(totalMaghrib: state!.totalMaghrib + 1, remainingMaghrib: state!.remainingMaghrib + 1);
        break;
      case 'isha':
        updated = state!.copyWith(totalIsha: state!.totalIsha + 1, remainingIsha: state!.remainingIsha + 1);
        break;
      default:
        return;
    }

    await _box!.put(updated.id, updated);
    state = updated;
  }

  /// Reset all qadha data (allows re-setup)
  Future<void> reset() async {
    _box ??= await HiveBoxManager.get<QadhaRecord>('qadha_records');
    _metaBox ??= await HiveBoxManager.get<String>('qadha_meta');
    await _box!.clear();
    await _metaBox!.clear();
    state = null;
  }
}
