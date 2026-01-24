// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opponent.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OpponentAdapter extends TypeAdapter<Opponent> {
  @override
  final int typeId = 3;

  @override
  Opponent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Opponent(
      name: fields[0] as String,
      colorValue: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Opponent obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpponentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
