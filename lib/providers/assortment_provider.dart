import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/assortment_item.dart';
import '../models/recipe.dart';

class AssortmentProvider extends ChangeNotifier {
  Box<AssortmentItem> get _box => Hive.box<AssortmentItem>('assortment');
  Box<Recipe> get _recBox => Hive.box<Recipe>('recipes');

  /// Цена продажи для конкретного рецепта (если нет записи — 0).
  double priceFor(int recipeKey) => _box.get(recipeKey)?.sellPrice ?? 0.0;

  /// Установить/обновить цену продажи для рецепта.
  Future<void> setPrice(int recipeKey, double price) async {
    final name = _recBox.get(recipeKey)?.name ?? 'Рецепт #$recipeKey';
    final existing = _box.get(recipeKey);
    if (existing == null) {
      await _box.put(
        recipeKey,
        AssortmentItem(name: name, recipeKey: recipeKey, sellPrice: price),
      );
    } else {
      existing.sellPrice = price;
      await _box.put(recipeKey, existing);
    }
    notifyListeners();
  }

  /// Вспомогательный метод, который можно использовать в других местах:
  /// вернуть все элементы ассортимента с автодобавлением "виртуальных" нулевых.
  List<AssortmentItem> itemsSortedByNameWithFallback() {
    final List<AssortmentItem> result = [];
    for (final e in _recBox.toMap().cast<int, Recipe>().entries) {
      final existing = _box.get(e.key);
      if (existing != null) {
        // синхронизируем имя
        if (existing.name != e.value.name) {
          existing.name = e.value.name;
          _box.put(e.key, existing);
        }
        result.add(existing);
      } else {
        result.add(AssortmentItem(
          name: e.value.name,
          recipeKey: e.key,
          sellPrice: 0.0,
        ));
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}
