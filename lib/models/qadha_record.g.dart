// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qadha_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QadhaRecordAdapter extends TypeAdapter<QadhaRecord> {
  @override
  final int typeId = 13;

  @override
  QadhaRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QadhaRecord(
      id: fields[0] as String,
      isLocked: fields[1] as bool? ?? false,
      totalFajr: fields[2] as int? ?? 0,
      remainingFajr: fields[3] as int? ?? 0,
      totalDhuhr: fields[4] as int? ?? 0,
      remainingDhuhr: fields[5] as int? ?? 0,
      totalAsr: fields[6] as int? ?? 0,
      remainingAsr: fields[7] as int? ?? 0,
      totalMaghrib: fields[8] as int? ?? 0,
      remainingMaghrib: fields[9] as int? ?? 0,
      totalIsha: fields[10] as int? ?? 0,
      remainingIsha: fields[11] as int? ?? 0,
      createdAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, QadhaRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.isLocked)
      ..writeByte(2)
      ..write(obj.totalFajr)
      ..writeByte(3)
      ..write(obj.remainingFajr)
      ..writeByte(4)
      ..write(obj.totalDhuhr)
      ..writeByte(5)
      ..write(obj.remainingDhuhr)
      ..writeByte(6)
      ..write(obj.totalAsr)
      ..writeByte(7)
      ..write(obj.remainingAsr)
      ..writeByte(8)
      ..write(obj.totalMaghrib)
      ..writeByte(9)
      ..write(obj.remainingMaghrib)
      ..writeByte(10)
      ..write(obj.totalIsha)
      ..writeByte(11)
      ..write(obj.remainingIsha)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QadhaRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
