// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrayerRecordAdapter extends TypeAdapter<PrayerRecord> {
  @override
  final int typeId = 12;

  @override
  PrayerRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerRecord(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      fajr: fields[2] as bool,
      dhuhr: fields[3] as bool,
      asr: fields[4] as bool,
      maghrib: fields[5] as bool,
      isha: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      tahajjud: fields[8] as bool? ?? false,
      ishraq: fields[9] as bool? ?? false,
      chasht: fields[10] as bool? ?? false,
      awwabin: fields[11] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.fajr)
      ..writeByte(3)
      ..write(obj.dhuhr)
      ..writeByte(4)
      ..write(obj.asr)
      ..writeByte(5)
      ..write(obj.maghrib)
      ..writeByte(6)
      ..write(obj.isha)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.tahajjud)
      ..writeByte(9)
      ..write(obj.ishraq)
      ..writeByte(10)
      ..write(obj.chasht)
      ..writeByte(11)
      ..write(obj.awwabin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
