import 'package:hive/hive.dart';
import 'subrecipe_ingredient.dart';

part 'subrecipe.g.dart';

@HiveType(typeId: 3)
class Subrecipe extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<SubrecipeIngredient> ingredients;

  Subrecipe({required this.name, required this.ingredients});
}