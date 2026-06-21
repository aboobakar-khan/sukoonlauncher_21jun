import 'package:hive/hive.dart';

part 'qadha_record.g.dart';

/// Model for tracking Qadha (missed) prayers
/// 
/// The user sets their total estimated missed prayers per type.
/// Once locked, they can only decrement (+1 prayed) or increment (-1 undo).
/// Each prayer type tracks: total (locked), remaining, and completed.
@HiveType(typeId: 13)
class QadhaRecord {
  /// Unique identifier
  @HiveField(0)
  String id;

  /// Whether the user has locked their qadha counts (cannot change totals after)
  @HiveField(1)
  bool isLocked;

  /// Total estimated missed Fajr prayers
  @HiveField(2)
  int totalFajr;

  /// Remaining Fajr qadha to pray
  @HiveField(3)
  int remainingFajr;

  /// Total estimated missed Dhuhr prayers
  @HiveField(4)
  int totalDhuhr;

  @HiveField(5)
  int remainingDhuhr;

  @HiveField(6)
  int totalAsr;

  @HiveField(7)
  int remainingAsr;

  @HiveField(8)
  int totalMaghrib;

  @HiveField(9)
  int remainingMaghrib;

  @HiveField(10)
  int totalIsha;

  @HiveField(11)
  int remainingIsha;

  /// Timestamp of when the record was created/locked
  @HiveField(12)
  DateTime createdAt;

  QadhaRecord({
    required this.id,
    this.isLocked = false,
    this.totalFajr = 0,
    this.remainingFajr = 0,
    this.totalDhuhr = 0,
    this.remainingDhuhr = 0,
    this.totalAsr = 0,
    this.remainingAsr = 0,
    this.totalMaghrib = 0,
    this.remainingMaghrib = 0,
    this.totalIsha = 0,
    this.remainingIsha = 0,
    required this.createdAt,
  });

  /// Total prayers completed across all types
  int get totalCompleted {
    return (totalFajr - remainingFajr) +
        (totalDhuhr - remainingDhuhr) +
        (totalAsr - remainingAsr) +
        (totalMaghrib - remainingMaghrib) +
        (totalIsha - remainingIsha);
  }

  /// Total prayers remaining across all types
  int get totalRemaining {
    return remainingFajr + remainingDhuhr + remainingAsr + remainingMaghrib + remainingIsha;
  }

  /// Grand total of all estimated missed prayers
  int get grandTotal {
    return totalFajr + totalDhuhr + totalAsr + totalMaghrib + totalIsha;
  }

  /// Overall progress (0.0 to 1.0)
  double get progress {
    if (grandTotal == 0) return 0.0;
    return totalCompleted / grandTotal;
  }

  /// Get remaining count for a prayer by name
  int remainingFor(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return remainingFajr;
      case 'dhuhr': return remainingDhuhr;
      case 'asr': return remainingAsr;
      case 'maghrib': return remainingMaghrib;
      case 'isha': return remainingIsha;
      default: return 0;
    }
  }

  /// Get total count for a prayer by name
  int totalFor(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return totalFajr;
      case 'dhuhr': return totalDhuhr;
      case 'asr': return totalAsr;
      case 'maghrib': return totalMaghrib;
      case 'isha': return totalIsha;
      default: return 0;
    }
  }

  /// Get completed count for a prayer by name
  int completedFor(String prayer) {
    return totalFor(prayer) - remainingFor(prayer);
  }

  QadhaRecord copyWith({
    String? id,
    bool? isLocked,
    int? totalFajr,
    int? remainingFajr,
    int? totalDhuhr,
    int? remainingDhuhr,
    int? totalAsr,
    int? remainingAsr,
    int? totalMaghrib,
    int? remainingMaghrib,
    int? totalIsha,
    int? remainingIsha,
    DateTime? createdAt,
  }) {
    return QadhaRecord(
      id: id ?? this.id,
      isLocked: isLocked ?? this.isLocked,
      totalFajr: totalFajr ?? this.totalFajr,
      remainingFajr: remainingFajr ?? this.remainingFajr,
      totalDhuhr: totalDhuhr ?? this.totalDhuhr,
      remainingDhuhr: remainingDhuhr ?? this.remainingDhuhr,
      totalAsr: totalAsr ?? this.totalAsr,
      remainingAsr: remainingAsr ?? this.remainingAsr,
      totalMaghrib: totalMaghrib ?? this.totalMaghrib,
      remainingMaghrib: remainingMaghrib ?? this.remainingMaghrib,
      totalIsha: totalIsha ?? this.totalIsha,
      remainingIsha: remainingIsha ?? this.remainingIsha,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
