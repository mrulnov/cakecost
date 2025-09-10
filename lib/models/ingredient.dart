import 'package:hive/hive.dart';

part 'ingredient.g.dart';

@HiveType(typeId: 0)
class Ingredient extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double price;

  @HiveField(2)
  double quantity;

  @HiveField(3)
  String unit; // 'г', 'мл', 'шт'

  Ingredient({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
  });

  /// Цена за 1 единицу (За 1 г/мл/шт). Если количество 0 — 0, чтобы не делить на ноль.
  double get unitCost => quantity == 0 ? 0 : price / quantity;
}
