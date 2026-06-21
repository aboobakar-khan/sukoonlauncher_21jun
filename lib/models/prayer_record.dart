import 'package:hive/hive.dart';

part 'prayer_record.g.dart';

/// Model for tracking daily prayer completions
/// Stores which of the 5 daily prayers + 4 nafil prayers have been completed
@HiveType(typeId: 12)
class PrayerRecord {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date; // Date only (time set to midnight)

  @HiveField(2)
  bool fajr;

  @HiveField(3)
  bool dhuhr;

  @HiveField(4)
  bool asr;

  @HiveField(5)
  bool maghrib;

  @HiveField(6)
  bool isha;

  @HiveField(7)
  DateTime createdAt;

  // ── Nafil (voluntary) prayers ──
  @HiveField(8)
  bool tahajjud;

  @HiveField(9)
  bool ishraq;

  @HiveField(10)
  bool chasht;

  @HiveField(11)
  bool awwabin;

  PrayerRecord({
    required this.id,
    required this.date,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
    this.tahajjud = false,
    this.ishraq = false,
    this.chasht = false,
    this.awwabin = false,
    required this.createdAt,
  });

  /// Get the number of completed fard prayers (0-5)
  int get completedCount {
    int count = 0;
    if (fajr) count++;
    if (dhuhr) count++;
    if (asr) count++;
    if (maghrib) count++;
    if (isha) count++;
    return count;
  }

  /// Get the number of completed nafil prayers (0-4)
  int get completedNafilCount {
    int count = 0;
    if (tahajjud) count++;
    if (ishraq) count++;
    if (chasht) count++;
    if (awwabin) count++;
    return count;
  }

  /// Get date key for lookups (YYYY-MM-DD format)
  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Create a date-only DateTime (strips time component)
  static DateTime dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  PrayerRecord copyWith({
    String? id,
    DateTime? date,
    bool? fajr,
    bool? dhuhr,
    bool? asr,
    bool? maghrib,
    bool? isha,
    bool? tahajjud,
    bool? ishraq,
    bool? chasht,
    bool? awwabin,
    DateTime? createdAt,
  }) {
    return PrayerRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      tahajjud: tahajjud ?? this.tahajjud,
      ishraq: ishraq ?? this.ishraq,
      chasht: chasht ?? this.chasht,
      awwabin: awwabin ?? this.awwabin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
