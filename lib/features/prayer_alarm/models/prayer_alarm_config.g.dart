// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_alarm_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrayerAlarmConfigAdapter extends TypeAdapter<PrayerAlarmConfig> {
  @override
  final int typeId = 60;

  @override
  PrayerAlarmConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerAlarmConfig(
      calculationMethod: fields[0] as int,
      latitude: fields[1] as double,
      longitude: fields[2] as double,
      timezone: fields[3] as String,
      locationLabel: fields[4] as String,
      lastFetchDate: fields[5] as String?,
      asrCalculationSchool: fields[6] as int,
      cacheRangeStart: fields[7] as String?,
      cacheRangeEnd: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerAlarmConfig obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.calculationMethod)
      ..writeByte(1)
      ..write(obj.latitude)
      ..writeByte(2)
      ..write(obj.longitude)
      ..writeByte(3)
      ..write(obj.timezone)
      ..writeByte(4)
      ..write(obj.locationLabel)
      ..writeByte(5)
      ..write(obj.lastFetchDate)
      ..writeByte(6)
      ..write(obj.asrCalculationSchool)
      ..writeByte(7)
      ..write(obj.cacheRangeStart)
      ..writeByte(8)
      ..write(obj.cacheRangeEnd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerAlarmConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyPrayerTimesAdapter extends TypeAdapter<DailyPrayerTimes> {
  @override
  final int typeId = 61;

  @override
  DailyPrayerTimes read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyPrayerTimes(
      dateKey: fields[0] as String,
      fajr: fields[1] as String,
      dhuhr: fields[2] as String,
      asr: fields[3] as String,
      maghrib: fields[4] as String,
      isha: fields[5] as String,
      sunrise: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DailyPrayerTimes obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.fajr)
      ..writeByte(2)
      ..write(obj.dhuhr)
      ..writeByte(3)
      ..write(obj.asr)
      ..writeByte(4)
      ..write(obj.maghrib)
      ..writeByte(5)
      ..write(obj.isha)
      ..writeByte(6)
      ..write(obj.sunrise);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyPrayerTimesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrayerReminderSettingsAdapter
    extends TypeAdapter<PrayerReminderSettings> {
  @override
  final int typeId = 62;

  @override
  PrayerReminderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerReminderSettings(
      fajrEnabled: fields[0] as bool,
      dhuhrEnabled: fields[1] as bool,
      asrEnabled: fields[2] as bool,
      maghribEnabled: fields[3] as bool,
      ishaEnabled: fields[4] as bool,
      fajrOverride: fields[5] as String,
      dhuhrOverride: fields[6] as String,
      asrOverride: fields[7] as String,
      maghribOverride: fields[8] as String,
      ishaOverride: fields[9] as String,
      soundType: fields[10] as String,
      volume: fields[11] as double,
      vibrationEnabled: fields[12] as bool,
      snoozeDurationMinutes: fields[13] as int,
      customSoundPath: fields[14] as String,
      fajrNotifType: fields[15] as String,
      dhuhrNotifType: fields[16] as String,
      asrNotifType: fields[17] as String,
      maghribNotifType: fields[18] as String,
      ishaNotifType: fields[19] as String,
      sunriseNotifType: fields[20] as String,
      fajrAdjustment: fields[21] as int,
      sunriseAdjustment: fields[22] as int,
      dhuhrAdjustment: fields[23] as int,
      asrAdjustment: fields[24] as int,
      maghribAdjustment: fields[25] as int,
      ishaAdjustment: fields[26] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerReminderSettings obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.fajrEnabled)
      ..writeByte(1)
      ..write(obj.dhuhrEnabled)
      ..writeByte(2)
      ..write(obj.asrEnabled)
      ..writeByte(3)
      ..write(obj.maghribEnabled)
      ..writeByte(4)
      ..write(obj.ishaEnabled)
      ..writeByte(5)
      ..write(obj.fajrOverride)
      ..writeByte(6)
      ..write(obj.dhuhrOverride)
      ..writeByte(7)
      ..write(obj.asrOverride)
      ..writeByte(8)
      ..write(obj.maghribOverride)
      ..writeByte(9)
      ..write(obj.ishaOverride)
      ..writeByte(10)
      ..write(obj.soundType)
      ..writeByte(11)
      ..write(obj.volume)
      ..writeByte(12)
      ..write(obj.vibrationEnabled)
      ..writeByte(13)
      ..write(obj.snoozeDurationMinutes)
      ..writeByte(14)
      ..write(obj.customSoundPath)
      ..writeByte(15)
      ..write(obj.fajrNotifType)
      ..writeByte(16)
      ..write(obj.dhuhrNotifType)
      ..writeByte(17)
      ..write(obj.asrNotifType)
      ..writeByte(18)
      ..write(obj.maghribNotifType)
      ..writeByte(19)
      ..write(obj.ishaNotifType)
      ..writeByte(20)
      ..write(obj.sunriseNotifType)
      ..writeByte(21)
      ..write(obj.fajrAdjustment)
      ..writeByte(22)
      ..write(obj.sunriseAdjustment)
      ..writeByte(23)
      ..write(obj.dhuhrAdjustment)
      ..writeByte(24)
      ..write(obj.asrAdjustment)
      ..writeByte(25)
      ..write(obj.maghribAdjustment)
      ..writeByte(26)
      ..write(obj.ishaAdjustment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerReminderSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
