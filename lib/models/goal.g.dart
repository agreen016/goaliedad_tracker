// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 7;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      gameId: fields[1] as String,
      teamId: fields[2] as String,
      period: fields[3] as String,
      scorerId: fields[4] as String,
      assistIds: (fields[5] as List).cast<String>(),
      goalType: fields[6] as String,
      time: fields[7] as String,
      goalieId: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gameId)
      ..writeByte(2)
      ..write(obj.teamId)
      ..writeByte(3)
      ..write(obj.period)
      ..writeByte(4)
      ..write(obj.scorerId)
      ..writeByte(5)
      ..write(obj.assistIds)
      ..writeByte(6)
      ..write(obj.goalType)
      ..writeByte(7)
      ..write(obj.time)
      ..writeByte(8)
      ..write(obj.goalieId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
