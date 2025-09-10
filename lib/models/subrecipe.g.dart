// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subrecipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubrecipeAdapter extends TypeAdapter<Subrecipe> {
  @override
  final int typeId = 3;

  @override
  Subrecipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subrecipe(
      name: fields[0] as String,
      ingredients: (fields[1] as List).cast<SubrecipeIngredient>(),
    );
  }

  @override
  void write(BinaryWriter writer, Subrecipe obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.ingredients);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubrecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
