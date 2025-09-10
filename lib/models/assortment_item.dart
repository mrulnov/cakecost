import 'package:hive/hive.dart';

part 'assortment_item.g.dart';

/// Позиция ассортимента = ссылка на рецепт + цена продажи
@HiveType(typeId: 8)
class AssortmentItem extends HiveObject {
  /// Отображаемое имя (обычно = имени рецепта)
  @HiveField(0)
  String name;

  /// Ключ рецепта (Hive key)
  @HiveField(1)
  int recipeKey;

  /// Цена продажи в ₽
  @HiveField(2)
  double sellPrice;

  AssortmentItem({
    required this.name,
    required this.recipeKey,
    required this.sellPrice,
  });
}
