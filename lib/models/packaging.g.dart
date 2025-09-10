// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packaging.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackagingAdapter extends TypeAdapter<Packaging> {
  @override
  final int typeId = 1;

  @override
  Packaging read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Packaging(
      name: fields[0] as String,
      price: fields[1] as double,
      quantity: fields[2] as double,
      unit: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Packaging obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackagingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
