// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calm_watch_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalmWatchItemAdapter extends TypeAdapter<CalmWatchItem> {
  @override
  final int typeId = 50;

  @override
  CalmWatchItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalmWatchItem(
      id: fields[0] as String,
      title: fields[1] as String,
      youtubeId: fields[2] as String,
      isPlaylist: fields[3] as bool,
      originalUrl: fields[4] as String,
      addedAt: fields[5] as DateTime,
      isCompleted: fields[6] as bool,
      reflection: fields[7] as String,
      tag: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CalmWatchItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.youtubeId)
      ..writeByte(3)
      ..write(obj.isPlaylist)
      ..writeByte(4)
      ..write(obj.originalUrl)
      ..writeByte(5)
      ..write(obj.addedAt)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.reflection)
      ..writeByte(8)
      ..write(obj.tag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalmWatchItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
