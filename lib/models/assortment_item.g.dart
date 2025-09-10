// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assortment_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AssortmentItemAdapter extends TypeAdapter<AssortmentItem> {
  @override
  final int typeId = 8;

  @override
  AssortmentItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssortmentItem(
      name: fields[0] as String,
      recipeKey: fields[1] as int,
      sellPrice: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, AssortmentItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.recipeKey)
      ..writeByte(2)
      ..write(obj.sellPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssortmentItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
