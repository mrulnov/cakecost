// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeItemAdapter extends TypeAdapter<RecipeItem> {
  @override
  final int typeId = 6;

  @override
  RecipeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeItem(
      kind: fields[0] as RecipeItemKind,
      refKey: fields[1] as int,
      quantity: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.kind)
      ..writeByte(1)
      ..write(obj.refKey)
      ..writeByte(2)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeItemKindAdapter extends TypeAdapter<RecipeItemKind> {
  @override
  final int typeId = 5;

  @override
  RecipeItemKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecipeItemKind.ingredient;
      case 1:
        return RecipeItemKind.subrecipe;
      case 2:
        return RecipeItemKind.packaging;
      default:
        return RecipeItemKind.ingredient;
    }
  }

  @override
  void write(BinaryWriter writer, RecipeItemKind obj) {
    switch (obj) {
      case RecipeItemKind.ingredient:
        writer.writeByte(0);
        break;
      case RecipeItemKind.subrecipe:
        writer.writeByte(1);
        break;
      case RecipeItemKind.packaging:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeItemKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
