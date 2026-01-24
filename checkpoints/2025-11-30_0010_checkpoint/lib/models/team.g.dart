// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamAdapter extends TypeAdapter<Team> {
  @override
  final int typeId = 0;

  @override
  Team read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Team(
      id: fields[0] as String,
      name: fields[1] as String,
      league: fields[2] as String,
      division: fields[3] as String,
      seasonStartYear: fields[4] as int,
      seasonEndYear: fields[5] as int,
      primaryColorHex: fields[6] as String,
      secondaryColorHex: fields[7] as String,
      logoPath: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Team obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.league)
      ..writeByte(3)
      ..write(obj.division)
      ..writeByte(4)
      ..write(obj.seasonStartYear)
      ..writeByte(5)
      ..write(obj.seasonEndYear)
      ..writeByte(6)
      ..write(obj.primaryColorHex)
      ..writeByte(7)
      ..write(obj.secondaryColorHex)
      ..writeByte(8)
      ..write(obj.logoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
