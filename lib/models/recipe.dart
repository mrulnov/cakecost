import 'package:hive/hive.dart';
import 'recipe_item.dart';

part 'recipe.g.dart';

@HiveType(typeId: 7)
class Recipe extends HiveObject {
  @HiveField(0)
  String name;

  /// Позиции рецепта: ингредиенты / упаковка / субрецепты
  @HiveField(1)
  List<RecipeItem> items;

  /// Время приготовления, в ЧАСАХ (0 — не указано).
  @HiveField(2)
  double timeHours;

  Recipe({
    required this.name,
    required this.items,
    required this.timeHours,
  });
}
