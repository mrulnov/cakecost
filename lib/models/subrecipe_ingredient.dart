import 'package:hive/hive.dart';

part 'subrecipe_ingredient.g.dart';

@HiveType(typeId: 2)
class SubrecipeIngredient extends HiveObject {
  @HiveField(0)
  int ingredientKey;

  @HiveField(1)
  double quantity;

  SubrecipeIngredient({required this.ingredientKey, required this.quantity});
}