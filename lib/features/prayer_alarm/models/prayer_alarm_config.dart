import 'package:hive/hive.dart';

part 'prayer_alarm_config.g.dart';

/// Persisted configuration for prayer time source + user preferences.
@HiveType(typeId: 60)
class PrayerAlarmConfig extends HiveObject {
  /// Aladhan calculation method (2=ISNA, 3=MWL, 4=Egypt, 5=Makkah, etc.)
  @HiveField(0)
  int calculationMethod;

  /// Latitude for prayer time calculation
  @HiveField(1)
  double latitude;

  /// Longitude for prayer time calculation
  @HiveField(2)
  double longitude;

  /// IANA timezone identifier (e.g. "Asia/Kolkata")
  @HiveField(3)
  String timezone;

  /// User-friendly location label (e.g. "Mumbai, India")
  @HiveField(4)
  String locationLabel;

  /// Last date prayer times were fetched for (yyyy-MM-dd)
  @HiveField(5)
  String? lastFetchDate;

  /// Asr calculation school: 0 = Shafi'i (Standard), 1 = Hanafi
  /// Hanafi: Asr starts when shadow = 2x object length (used in Indo-Pak region)
  /// Shafi'i: Asr starts when shadow = 1x object length (default)
  @HiveField(6)
  int asrCalculationSchool;

  /// Start of the cached prayer times range (yyyy-MM-dd)
  @HiveField(7)
  String? cacheRangeStart;

  /// End of the cached prayer times range (yyyy-MM-dd)
  @HiveField(8)
  String? cacheRangeEnd;

  PrayerAlarmConfig({
    this.calculationMethod = 2,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.timezone = 'UTC',
    this.locationLabel = '',
    this.lastFetchDate,
    this.asrCalculationSchool = 0, // Default to Shafi'i
    this.cacheRangeStart,
    this.cacheRangeEnd,
  });

  PrayerAlarmConfig copyWith({
    int? calculationMethod,
    double? latitude,
    double? longitude,
    String? timezone,
    String? locationLabel,
    String? lastFetchDate,
    int? asrCalculationSchool,
    String? cacheRangeStart,
    String? cacheRangeEnd,
  }) {
    return PrayerAlarmConfig(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      locationLabel: locationLabel ?? this.locationLabel,
      lastFetchDate: lastFetchDate ?? this.lastFetchDate,
      asrCalculationSchool: asrCalculationSchool ?? this.asrCalculationSchool,
      cacheRangeStart: cacheRangeStart ?? this.cacheRangeStart,
      cacheRangeEnd: cacheRangeEnd ?? this.cacheRangeEnd,
    );
  }
}

/// Cached prayer times for a single day — fetched from API or manual override.
@HiveType(typeId: 61)
class DailyPrayerTimes extends HiveObject {
  @HiveField(0)
  String dateKey; // yyyy-MM-dd

  /// Time strings in 24h "HH:mm" format
  @HiveField(1)
  String fajr;

  @HiveField(2)
  String dhuhr;

  @HiveField(3)
  String asr;

  @HiveField(4)
  String maghrib;

  @HiveField(5)
  String isha;

  /// Sunrise time (not a prayer, but needed for display between Fajr and Dhuhr)
  @HiveField(6)
  String sunrise;

  DailyPrayerTimes({
    required this.dateKey,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.sunrise = '',
  });

  String timeFor(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return fajr;
      case 'Sunrise':
        return sunrise;
      case 'Dhuhr':
        return dhuhr;
      case 'Asr':
        return asr;
      case 'Maghrib':
        return maghrib;
      case 'Isha':
        return isha;
      default:
        return '00:00';
    }
  }

  Map<String, String> toMap() => {
        'Fajr': fajr,
        'Sunrise': sunrise,
        'Dhuhr': dhuhr,
        'Asr': asr,
        'Maghrib': maghrib,
        'Isha': isha,
      };
}

/// Per-prayer reminder settings (sound, enabled, manual override).
@HiveType(typeId: 62)
class PrayerReminderSettings extends HiveObject {
  /// Whether this prayer's alarm is enabled
  @HiveField(0)
  bool fajrEnabled;

  @HiveField(1)
  bool dhuhrEnabled;

  @HiveField(2)
  bool asrEnabled;

  @HiveField(3)
  bool maghribEnabled;

  @HiveField(4)
  bool ishaEnabled;

  /// Manual override time per prayer (empty string = use API time).  "HH:mm"
  @HiveField(5)
  String fajrOverride;

  @HiveField(6)
  String dhuhrOverride;

  @HiveField(7)
  String asrOverride;

  @HiveField(8)
  String maghribOverride;

  @HiveField(9)
  String ishaOverride;

  /// Sound type: 'soft', 'adhan', 'vibrate_only'
  @HiveField(10)
  String soundType;

  /// Volume level 0.0 – 1.0
  @HiveField(11)
  double volume;

  /// Vibration enabled
  @HiveField(12)
  bool vibrationEnabled;

  /// Snooze duration in minutes
  @HiveField(13)
  int snoozeDurationMinutes;

  /// Path to a custom audio file chosen by the user (empty = use built-in)
  @HiveField(14)
  String customSoundPath;

  /// Per-prayer alarm mode:
  /// - 'off': no alert (disabled)
  /// - 'notify': silent notification banner (no sound)
  /// - 'adhan': notification + adhan audio
  /// Sunrise only supports 'off' and 'notify'.
  @HiveField(15)
  String fajrNotifType;

  @HiveField(16)
  String dhuhrNotifType;

  @HiveField(17)
  String asrNotifType;

  @HiveField(18)
  String maghribNotifType;

  @HiveField(19)
  String ishaNotifType;

  @HiveField(20)
  String sunriseNotifType;

  /// Per-prayer time adjustment in minutes (-60 to +60).
  /// Positive = alarm fires later, Negative = alarm fires earlier.
  /// e.g. fajrAdjustment = -5 means alarm 5 minutes before Fajr time.
  @HiveField(21)
  int fajrAdjustment;

  @HiveField(22)
  int sunriseAdjustment;

  @HiveField(23)
  int dhuhrAdjustment;

  @HiveField(24)
  int asrAdjustment;

  @HiveField(25)
  int maghribAdjustment;

  @HiveField(26)
  int ishaAdjustment;

  PrayerReminderSettings({
    this.fajrEnabled = true,
    this.dhuhrEnabled = true,
    this.asrEnabled = true,
    this.maghribEnabled = true,
    this.ishaEnabled = true,
    this.fajrOverride = '',
    this.dhuhrOverride = '',
    this.asrOverride = '',
    this.maghribOverride = '',
    this.ishaOverride = '',
    this.soundType = 'namaz_reminder',
    this.volume = 0.8,
    this.vibrationEnabled = true,
    this.snoozeDurationMinutes = 10,
    this.customSoundPath = '',
    this.fajrNotifType = 'off',
    this.dhuhrNotifType = 'off',
    this.asrNotifType = 'off',
    this.maghribNotifType = 'off',
    this.ishaNotifType = 'off',
    this.sunriseNotifType = 'off',
    this.fajrAdjustment = 0,
    this.sunriseAdjustment = 0,
    this.dhuhrAdjustment = 0,
    this.asrAdjustment = 0,
    this.maghribAdjustment = 0,
    this.ishaAdjustment = 0,
  });

  bool isEnabled(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return fajrEnabled;
      case 'Dhuhr':
        return dhuhrEnabled;
      case 'Asr':
        return asrEnabled;
      case 'Maghrib':
        return maghribEnabled;
      case 'Isha':
        return ishaEnabled;
      default:
        return false;
    }
  }

  /// Returns override time string, empty if none set.
  String overrideFor(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return fajrOverride;
      case 'Dhuhr':
        return dhuhrOverride;
      case 'Asr':
        return asrOverride;
      case 'Maghrib':
        return maghribOverride;
      case 'Isha':
        return ishaOverride;
      default:
        return '';
    }
  }

  /// Returns the alarm mode for a specific prayer.
  /// Values: 'off', 'notify', 'adhan'
  String notifTypeFor(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return fajrNotifType;
      case 'Dhuhr':
        return dhuhrNotifType;
      case 'Asr':
        return asrNotifType;
      case 'Maghrib':
        return maghribNotifType;
      case 'Isha':
        return ishaNotifType;
      case 'Sunrise':
        return sunriseNotifType;
      default:
        return 'off';
    }
  }

  /// Alarm mode cycle order for regular prayers.
  static const modeOrder = ['off', 'notify', 'adhan'];

  /// Alarm mode cycle order for Sunrise (no adhan).
  static const sunriseModeOrder = ['off', 'notify'];

  /// Returns the next alarm mode in the cycle.
  static String nextMode(String current, {bool isSunrise = false}) {
    final order = isSunrise ? sunriseModeOrder : modeOrder;
    final idx = order.indexOf(current);
    return order[(idx + 1) % order.length];
  }

  /// Returns a copy with the time adjustment for a specific prayer updated.
  PrayerReminderSettings withAdjustment(String prayer, int minutes) {
    switch (prayer) {
      case 'Fajr':
        return copyWith(fajrAdjustment: minutes, fajrOverride: '');
      case 'Sunrise':
        return copyWith(sunriseAdjustment: minutes);
      case 'Dhuhr':
        return copyWith(dhuhrAdjustment: minutes, dhuhrOverride: '');
      case 'Asr':
        return copyWith(asrAdjustment: minutes, asrOverride: '');
      case 'Maghrib':
        return copyWith(maghribAdjustment: minutes, maghribOverride: '');
      case 'Isha':
        return copyWith(ishaAdjustment: minutes, ishaOverride: '');
      default:
        return this;
    }
  }

  /// Returns the minute adjustment for a specific prayer.
  /// Positive = later, Negative = earlier.
  int adjustmentFor(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return fajrAdjustment;
      case 'Sunrise':
        return sunriseAdjustment;
      case 'Dhuhr':
        return dhuhrAdjustment;
      case 'Asr':
        return asrAdjustment;
      case 'Maghrib':
        return maghribAdjustment;
      case 'Isha':
        return ishaAdjustment;
      default:
        return 0;
    }
  }

  PrayerReminderSettings copyWith({
    bool? fajrEnabled,
    bool? dhuhrEnabled,
    bool? asrEnabled,
    bool? maghribEnabled,
    bool? ishaEnabled,
    String? fajrOverride,
    String? dhuhrOverride,
    String? asrOverride,
    String? maghribOverride,
    String? ishaOverride,
    String? soundType,
    double? volume,
    bool? vibrationEnabled,
    int? snoozeDurationMinutes,
    String? customSoundPath,
    String? fajrNotifType,
    String? dhuhrNotifType,
    String? asrNotifType,
    String? maghribNotifType,
    String? ishaNotifType,
    String? sunriseNotifType,
    int? fajrAdjustment,
    int? sunriseAdjustment,
    int? dhuhrAdjustment,
    int? asrAdjustment,
    int? maghribAdjustment,
    int? ishaAdjustment,
  }) {
    return PrayerReminderSettings(
      fajrEnabled: fajrEnabled ?? this.fajrEnabled,
      dhuhrEnabled: dhuhrEnabled ?? this.dhuhrEnabled,
      asrEnabled: asrEnabled ?? this.asrEnabled,
      maghribEnabled: maghribEnabled ?? this.maghribEnabled,
      ishaEnabled: ishaEnabled ?? this.ishaEnabled,
      fajrOverride: fajrOverride ?? this.fajrOverride,
      dhuhrOverride: dhuhrOverride ?? this.dhuhrOverride,
      asrOverride: asrOverride ?? this.asrOverride,
      maghribOverride: maghribOverride ?? this.maghribOverride,
      ishaOverride: ishaOverride ?? this.ishaOverride,
      soundType: soundType ?? this.soundType,
      volume: volume ?? this.volume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      customSoundPath: customSoundPath ?? this.customSoundPath,
      fajrNotifType: fajrNotifType ?? this.fajrNotifType,
      dhuhrNotifType: dhuhrNotifType ?? this.dhuhrNotifType,
      asrNotifType: asrNotifType ?? this.asrNotifType,
      maghribNotifType: maghribNotifType ?? this.maghribNotifType,
      ishaNotifType: ishaNotifType ?? this.ishaNotifType,
      sunriseNotifType: sunriseNotifType ?? this.sunriseNotifType,
      fajrAdjustment: fajrAdjustment ?? this.fajrAdjustment,
      sunriseAdjustment: sunriseAdjustment ?? this.sunriseAdjustment,
      dhuhrAdjustment: dhuhrAdjustment ?? this.dhuhrAdjustment,
      asrAdjustment: asrAdjustment ?? this.asrAdjustment,
      maghribAdjustment: maghribAdjustment ?? this.maghribAdjustment,
      ishaAdjustment: ishaAdjustment ?? this.ishaAdjustment,
    );
  }

  /// Returns a copy with the notification type for a specific prayer updated.
  PrayerReminderSettings withNotifType(String prayer, String type) {
    switch (prayer) {
      case 'Fajr':
        return copyWith(fajrNotifType: type);
      case 'Dhuhr':
        return copyWith(dhuhrNotifType: type);
      case 'Asr':
        return copyWith(asrNotifType: type);
      case 'Maghrib':
        return copyWith(maghribNotifType: type);
      case 'Isha':
        return copyWith(ishaNotifType: type);
      case 'Sunrise':
        return copyWith(sunriseNotifType: type);
      default:
        return this;
    }
  }
}
