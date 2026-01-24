// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameEventAdapter extends TypeAdapter<GameEvent> {
  @override
  final int typeId = 9;

  @override
  GameEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameEvent(
      id: fields[0] as String,
      gameId: fields[1] as String,
      teamId: fields[2] as String,
      type: fields[3] as String,
      period: fields[4] as int,
      playerId: fields[5] as String?,
      details: (fields[6] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, GameEvent obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gameId)
      ..writeByte(2)
      ..write(obj.teamId)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.period)
      ..writeByte(5)
      ..write(obj.playerId)
      ..writeByte(6)
      ..write(obj.details);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
