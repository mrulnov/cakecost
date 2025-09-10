import 'package:hive/hive.dart';

part 'packaging.g.dart';

@HiveType(typeId: 1)
class Packaging extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double price;

  @HiveField(2)
  double quantity;

  @HiveField(3)
  String unit; // 'шт', 'см'

  Packaging({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
  });

  /// Внутренний расчёт: цена за 1 единицу ('шт' или 'см')
  double get unitCost => quantity == 0 ? 0 : price / quantity;
}
