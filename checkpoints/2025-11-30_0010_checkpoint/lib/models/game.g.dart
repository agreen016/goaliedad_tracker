// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 2;

  @override
  Game read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Game(
      id: fields[0] as String,
      teamId: fields[1] as String,
      dateTime: fields[2] as DateTime,
      opponent: fields[3] as String,
      gameType: fields[4] as String,
      result: fields[5] as String,
      name: fields[6] as String?,
      location: fields[7] as String?,
      homeScore: fields[8] as int,
      visitorScore: fields[9] as int,
      homeShots: fields[10] as int,
      visitorShots: fields[11] as int,
      isFinal: fields[12] as bool,
      startingGoalie: fields[13] as String?,
      events: (fields[21] as List?)?.cast<GameEvent>(),
      availablePlayerIds: (fields[14] as List?)?.cast<String>(),
      unavailablePlayerReasons: (fields[15] as Map?)?.cast<String, String>(),
      opponentTeamId: fields[16] as int?,
      homeShotsByPeriod: (fields[17] as Map?)?.cast<String, int>(),
      visitorShotsByPeriod: (fields[18] as Map?)?.cast<String, int>(),
      homePPO: fields[19] as int,
      visitorPPO: fields[20] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.dateTime)
      ..writeByte(3)
      ..write(obj.opponent)
      ..writeByte(4)
      ..write(obj.gameType)
      ..writeByte(5)
      ..write(obj.result)
      ..writeByte(6)
      ..write(obj.name)
      ..writeByte(7)
      ..write(obj.location)
      ..writeByte(8)
      ..write(obj.homeScore)
      ..writeByte(9)
      ..write(obj.visitorScore)
      ..writeByte(10)
      ..write(obj.homeShots)
      ..writeByte(11)
      ..write(obj.visitorShots)
      ..writeByte(12)
      ..write(obj.isFinal)
      ..writeByte(13)
      ..write(obj.startingGoalie)
      ..writeByte(14)
      ..write(obj.availablePlayerIds)
      ..writeByte(15)
      ..write(obj.unavailablePlayerReasons)
      ..writeByte(16)
      ..write(obj.opponentTeamId)
      ..writeByte(17)
      ..write(obj.homeShotsByPeriod)
      ..writeByte(18)
      ..write(obj.visitorShotsByPeriod)
      ..writeByte(19)
      ..write(obj.homePPO)
      ..writeByte(20)
      ..write(obj.visitorPPO)
      ..writeByte(21)
      ..write(obj.events);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
