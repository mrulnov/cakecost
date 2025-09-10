import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/subrecipe.dart';
import '../models/subrecipe_ingredient.dart';
import '../models/ingredient.dart';

class SubrecipeProvider extends ChangeNotifier {
  Box<Subrecipe> get _box => Hive.box<Subrecipe>('subrecipes');

  // --- CRUD ---
  Future<void> add(Subrecipe s) async {
    await _box.add(s);
    notifyListeners();
  }

  Future<void> updateByKey(int key, Subrecipe s) async {
    await _box.put(key, s);
    notifyListeners();
  }

  Future<void> deleteByKey(int key) async {
    await _box.delete(key);
    notifyListeners();
  }

  Subrecipe? getByKey(int key) => _box.get(key);

  // --- utils ---
  List<MapEntry<int, Subrecipe>> entriesSorted() {
    final list = _box.toMap().cast<int, Subrecipe>().entries.toList();
    list.sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return list;
  }

  int usageCountForIngredient(int ingredientKey) {
    int cnt = 0;
    for (final s in _box.values) {
      cnt += s.ingredients.where((si) => si.ingredientKey == ingredientKey).length;
    }
    return cnt;
  }

  Future<void> removeIngredientEverywhere(int ingredientKey) async {
    bool changed = false;
    final map = _box.toMap().cast<int, Subrecipe>();
    for (final e in map.entries) {
      final filtered = e.value.ingredients.where((si) => si.ingredientKey != ingredientKey).toList();
      if (filtered.length != e.value.ingredients.length) {
        await _box.put(e.key, Subrecipe(name: e.value.name, ingredients: filtered));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Стоимость субрецепта (только материалы, через справочник ингредиентов)
  double costOf(Subrecipe s) {
    final ingBox = Hive.box<Ingredient>('ingredients');
    double sum = 0;
    for (final si in s.ingredients) {
      final ing = ingBox.get(si.ingredientKey);
      if (ing == null) continue;
      final unit = ing.quantity == 0 ? 0 : (ing.price / ing.quantity);
      sum += unit * si.quantity;
    }
    return sum;
  }

  // --- duplication ---
  /// Создаёт глубокую копию субрецепта по ключу.
  /// Возвращает ключ новой записи.
  Future<int> duplicateByKey(int key) async {
    final orig = _box.get(key);
    if (orig == null) {
      throw ArgumentError('Subrecipe with key $key not found');
    }

    final newName = _generateUniqueName(orig.name);

    final copiedIngredients = orig.ingredients
        .map((si) => SubrecipeIngredient(ingredientKey: si.ingredientKey, quantity: si.quantity))
        .toList();

    final newSub = Subrecipe(name: newName, ingredients: copiedIngredients);
    final newKey = await _box.add(newSub);
    notifyListeners();
    return newKey;
  }

  String _generateUniqueName(String base) {
    final existing = _box.values.map((s) => s.name.toLowerCase()).toSet();
    String candidate = '$base (копия)';
    int i = 2;
    while (existing.contains(candidate.toLowerCase())) {
      candidate = '$base (копия $i)';
      i++;
    }
    return candidate;
  }
}
