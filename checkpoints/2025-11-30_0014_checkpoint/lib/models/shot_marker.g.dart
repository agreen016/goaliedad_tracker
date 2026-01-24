// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shot_marker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShotMarkerAdapter extends TypeAdapter<ShotMarker> {
  @override
  final int typeId = 10;

  @override
  ShotMarker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShotMarker(
      dx: fields[0] as double,
      dy: fields[1] as double,
      isGoal: fields[2] as bool,
      teamColorValue: fields[3] as int,
      playerNumber: fields[4] as String?,
      shooterId: fields[5] as String?,
      goalScorerId: fields[6] as String?,
      assist1Id: fields[7] as String?,
      assist2Id: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShotMarker obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.dx)
      ..writeByte(1)
      ..write(obj.dy)
      ..writeByte(2)
      ..write(obj.isGoal)
      ..writeByte(3)
      ..write(obj.teamColorValue)
      ..writeByte(4)
      ..write(obj.playerNumber)
      ..writeByte(5)
      ..write(obj.shooterId)
      ..writeByte(6)
      ..write(obj.goalScorerId)
      ..writeByte(7)
      ..write(obj.assist1Id)
      ..writeByte(8)
      ..write(obj.assist2Id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotMarkerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
