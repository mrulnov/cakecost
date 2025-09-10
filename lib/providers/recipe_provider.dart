import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../models/recipe_item.dart';
import '../models/ingredient.dart';
import '../models/subrecipe.dart';
import '../models/packaging.dart';
import '../models/resource.dart';
import 'subrecipe_provider.dart';
import 'resource_provider.dart';

class RecipeProvider extends ChangeNotifier {
  Box<Recipe> get _box => Hive.box<Recipe>('recipes');

  // --- CRUD ---
  Future<void> add(Recipe r) async {
    await _box.add(r);
    notifyListeners();
  }

  Future<void> updateByKey(int key, Recipe r) async {
    await _box.put(key, r);
    notifyListeners();
  }

  Future<void> deleteByKey(int key) async {
    await _box.delete(key);
    notifyListeners();
  }

  Recipe? getByKey(int key) => _box.get(key);

  /// Список рецептов с ключами, отсортирован A–Z по названию.
  List<MapEntry<int, Recipe>> entriesSorted() {
    final list = _box.toMap().cast<int, Recipe>().entries.toList();
    list.sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return list;
  }

  // ===================== ДУБЛИРОВАНИЕ =====================

  /// Создаёт глубокую копию рецепта по ключу.
  /// Возвращает ключ новой записи.
  Future<int> duplicateByKey(int key) async {
    final orig = _box.get(key);
    if (orig == null) {
      throw ArgumentError('Recipe with key $key not found');
    }

    final newName = _generateUniqueName(orig.name);

    final copiedItems = orig.items
        .map((it) => RecipeItem(kind: it.kind, refKey: it.refKey, quantity: it.quantity))
        .toList();

    final copy = Recipe(
      name: newName,
      items: copiedItems,
      timeHours: orig.timeHours,
    );

    final newKey = await _box.add(copy);
    notifyListeners();
    return newKey;
  }

  String _generateUniqueName(String base) {
    final existing = _box.values.map((r) => r.name.toLowerCase()).toSet();
    String candidate = '$base (копия)';
    int i = 2;
    while (existing.contains(candidate.toLowerCase())) {
      candidate = '$base (копия $i)';
      i++;
    }
    return candidate;
  }

  // ===================== СЕБЕСТОИМОСТЬ =====================

  /// Себестоимость **материалов** (ингредиенты + упаковка + субрецепты как материалы).
  double materialCost(Recipe r, SubrecipeProvider subProv) {
    final ingBox = Hive.box<Ingredient>('ingredients');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final packBox = Hive.box<Packaging>('packaging');

    double sum = 0;

    for (final it in r.items) {
      switch (it.kind) {
        case RecipeItemKind.ingredient: {
          final ing = ingBox.get(it.refKey);
          if (ing == null) break;
          final unit = ing.quantity == 0 ? 0 : (ing.price / ing.quantity);
          sum += unit * it.quantity;
          break;
        }
        case RecipeItemKind.subrecipe: {
          final sr = subBox.get(it.refKey);
          if (sr == null) break;
          // У вашей модели Subrecipe нет времени — его стоимость = только материалы
          sum += subProv.costOf(sr) * it.quantity;
          break;
        }
        case RecipeItemKind.packaging: {
          final p = packBox.get(it.refKey);
          if (p == null) break;
          final unit = p.quantity == 0 ? 0 : (p.price / p.quantity);
          sum += unit * it.quantity;
          break;
        }
      }
    }
    return sum;
  }

  /// Стоимость **времени** (труд + коммуналка) по поминутной формуле,
  /// без изменения экрана/модели ресурсов.
  ///
  /// utilitiesPerMinute = (utilities_per_month * 12) / 525600
  /// salaryPerMinute    = salary_per_month / 9600
  /// timeCost           = timeMinutes * (utilitiesPerMinute + salaryPerMinute)
  double timeCost(Recipe r, ResourceProvider resProv) {
    if (r.timeHours <= 0) return 0;

    final Resource res = resProv.data;
    final double timeMinutes = r.timeHours * 60.0;

    const double minutesInYear = 525600.0;
    const double minutesInMonth = 9600.0;

    final double utilitiesPerMinute = (res.utilities ?? 0) * 12.0 / minutesInYear;
    final double salaryPerMinute = (res.salary ?? 0) / minutesInMonth;

    return timeMinutes * (utilitiesPerMinute + salaryPerMinute);
  }

  /// **Полная** себестоимость: материалы + время.
  /// Параметр [res] допускает:
  ///  - ResourceProvider
  ///  - Resource
  ///  - null (будет взята первая запись из бокса 'resources', если есть)
  double costOf(Recipe r, SubrecipeProvider subProv, dynamic res) {
    final materials = materialCost(r, subProv);

    // Определяем ресурс (коммуналка/зарплата)
    Resource? resource;
    if (res is ResourceProvider) {
      resource = res.data;
    } else if (res is Resource) {
      resource = res;
    } else {
      final box = Hive.box<Resource>('resources');
      if (!box.isEmpty) resource = box.values.first;
    }

    double time = 0;
    if (resource != null && r.timeHours > 0) {
      const double minutesInYear = 525600.0;
      const double minutesInMonth = 9600.0;

      final double timeMinutes = r.timeHours * 60.0;
      final double utilitiesPerMinute = (resource.utilities ?? 0) * 12.0 / minutesInYear;
      final double salaryPerMinute = (resource.salary ?? 0) / minutesInMonth;
      time = timeMinutes * (utilitiesPerMinute + salaryPerMinute);
    }

    return double.parse((materials + time).toStringAsFixed(2));
  }
}
