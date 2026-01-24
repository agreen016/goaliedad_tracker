// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LineAdapter extends TypeAdapter<Line> {
  @override
  final int typeId = 8;

  @override
  Line read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Line(
      id: fields[0] as String,
      teamId: fields[1] as String,
      name: fields[2] as String,
      lwId: fields[3] as String,
      cId: fields[4] as String,
      rwId: fields[5] as String,
      ldId: fields[6] as String,
      rdId: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Line obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.lwId)
      ..writeByte(4)
      ..write(obj.cId)
      ..writeByte(5)
      ..write(obj.rwId)
      ..writeByte(6)
      ..write(obj.ldId)
      ..writeByte(7)
      ..write(obj.rdId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
