// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subrecipe_ingredient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubrecipeIngredientAdapter extends TypeAdapter<SubrecipeIngredient> {
  @override
  final int typeId = 2;

  @override
  SubrecipeIngredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubrecipeIngredient(
      ingredientKey: fields[0] as int,
      quantity: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SubrecipeIngredient obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.ingredientKey)
      ..writeByte(1)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubrecipeIngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
