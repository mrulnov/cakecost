import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/ingredient.dart';

class IngredientProvider extends ChangeNotifier {
  Box<Ingredient> get _box => Hive.box<Ingredient>('ingredients');

  /// Пары [key, item] в алфавитном порядке
  List<MapEntry<int, Ingredient>> entriesSorted() {
    final map = _box.toMap().cast<int, Ingredient>();
    final list = map.entries.toList();
    list.sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return list;
  }

  List<Ingredient> get items => entriesSorted().map((e) => e.value).toList();

  Ingredient? getByKey(int key) => _box.get(key);

  Future<void> add(Ingredient i) async {
    await _box.add(i);
    notifyListeners();
  }

  Future<void> updateByKey(int key, Ingredient i) async {
    await _box.put(key, i);
    notifyListeners();
  }

  Future<void> deleteByKey(int key) async {
    await _box.delete(key);
    notifyListeners();
  }

  /// Проверка наличия имени (регистронезависимо).
  bool existsByName(String name, {int? exceptKey}) {
    final n = name.trim().toLowerCase();
    for (final entry in _box.toMap().cast<int, Ingredient>().entries) {
      final k = entry.key;
      final v = entry.value;
      if (exceptKey != null && k == exceptKey) continue;
      if (v.name.trim().toLowerCase() == n) return true;
    }
    return false;
  }
}
