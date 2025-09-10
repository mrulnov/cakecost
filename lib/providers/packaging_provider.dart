import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/packaging.dart';

class PackagingProvider extends ChangeNotifier {
  Box<Packaging> get _box => Hive.box<Packaging>('packaging');

  List<MapEntry<int, Packaging>> entriesSorted() {
    final map = _box.toMap().cast<int, Packaging>();
    final list = map.entries.toList();
    list.sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return list;
  }

  List<Packaging> get items => entriesSorted().map((e) => e.value).toList();

  Packaging? getByKey(int key) => _box.get(key);

  Future<void> add(Packaging p) async {
    await _box.add(p);
    notifyListeners();
  }

  Future<void> updateByKey(int key, Packaging p) async {
    await _box.put(key, p);
    notifyListeners();
  }

  Future<void> deleteByKey(int key) async {
    await _box.delete(key);
    notifyListeners();
  }

  bool existsByName(String name, {int? exceptKey}) {
    final n = name.trim().toLowerCase();
    for (final entry in _box.toMap().cast<int, Packaging>().entries) {
      final k = entry.key;
      final v = entry.value;
      if (exceptKey != null && k == exceptKey) continue;
      if (v.name.trim().toLowerCase() == n) return true;
    }
    return false;
  }
}
