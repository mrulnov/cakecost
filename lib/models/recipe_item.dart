import 'package:hive/hive.dart';

part 'recipe_item.g.dart';

/// Тип компонента рецепта
@HiveType(typeId: 5)
enum RecipeItemKind {
  @HiveField(0)
  ingredient,   // ссылка на Ingredient
  @HiveField(1)
  subrecipe,    // ссылка на Subrecipe (множитель)
  @HiveField(2)
  packaging,    // ссылка на Packaging
}

@HiveType(typeId: 6)
class RecipeItem extends HiveObject {
  /// Тип компонента
  @HiveField(0)
  RecipeItemKind kind;

  /// Ключ (key) в соответствующем боксе Hive
  @HiveField(1)
  int refKey;

  /// Количество (для subrecipe — множитель)
  @HiveField(2)
  double quantity;

  RecipeItem({
    required this.kind,
    required this.refKey,
    required this.quantity,
  });
}
