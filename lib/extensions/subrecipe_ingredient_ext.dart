import '../models/subrecipe_ingredient.dart';

extension SubrecipeIngredientCopyExt on SubrecipeIngredient {
  SubrecipeIngredient copyWith({int? ingredientKey, double? quantity}) {
    return SubrecipeIngredient(
      ingredientKey: ingredientKey ?? this.ingredientKey,
      quantity: quantity ?? this.quantity,
    );
  }
}
