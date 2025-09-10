// lib/services/import_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:hive/hive.dart';

import '../models/ingredient.dart';
import '../models/packaging.dart';

class ImportResult {
  final int addedIngredients;
  final int updatedIngredients;
  final int addedPackaging;
  final int updatedPackaging;
  final List<String> warnings;

  ImportResult({
    required this.addedIngredients,
    required this.updatedIngredients,
    required this.addedPackaging,
    required this.updatedPackaging,
    required this.warnings,
  });

  String get message {
    final w = warnings.isEmpty ? '' : '\nЗамечания:\n• ${warnings.join('\n• ')}';
    return 'Импорт завершён:\n'
        '• ингредиенты — добавлено $addedIngredients, обновлено $updatedIngredients\n'
        '• упаковка — добавлено $addedPackaging, обновлено $updatedPackaging$w';
  }
}

class ImportService {
  static Future<ImportResult> importDataFromFile(File file) async {
    final name = file.path.toLowerCase();
    if (!(name.endsWith('.xlsx') || name.endsWith('.xls'))) {
      throw 'Ожидается Excel (.xlsx или .xls)';
    }
    final bytes = await file.readAsBytes();
    return _importFromExcel(bytes);
  }

  // ---------- XLSX/XLS ----------
  static ImportResult _importFromExcel(Uint8List bytes) {
    final book = xls.Excel.decodeBytes(bytes);

    final ingSheet = _sheetByName(book, ['ingredients', 'ингредиенты']);
    final pkgSheet = _sheetByName(book, ['packaging', 'упаковка', 'упаковки']);

    if (ingSheet == null && pkgSheet == null) {
      throw 'В файле нет листов «ingredients» или «packaging».';
    }

    final ingBox = Hive.box<Ingredient>('ingredients');
    final pkgBox = Hive.box<Packaging>('packaging');

    // Карты имен (низкий регистр) -> ключ
    final ingIndex = <String, int>{};
    final pkgIndex = <String, int>{};
    for (final e in ingBox.toMap().cast<int, Ingredient>().entries) {
      ingIndex[e.value.name.trim().toLowerCase()] = e.key;
    }
    for (final e in pkgBox.toMap().cast<int, Packaging>().entries) {
      pkgIndex[e.value.name.trim().toLowerCase()] = e.key;
    }

    int addIng = 0, updIng = 0, addPkg = 0, updPkg = 0;
    final warnings = <String>[];

    // ---- INGREDIENTS ----
    if (ingSheet != null) {
      final rows = _rows(ingSheet);
      final map = _headerMap(rows);
      if (map == null) {
        warnings.add('Лист ingredients: не найдены столбцы name/unit/quantity/price.');
      } else {
        for (var i = 1; i < rows.length; i++) {
          final r = rows[i];
          final name = _asString(r, map['name']);
          final unit = _asString(r, map['unit']);
          final qty = _asDouble(r, map['quantity']);
          final price = _asDouble(r, map['price']);

          if (name.isEmpty) continue;
          if (!_isAllowedUnitIngredient(unit)) {
            warnings.add('ingredients: «$name» — недопустимая единица ($unit). Разрешено: г, мл, шт.');
            continue;
          }
          if (qty <= 0 || price < 0) {
            warnings.add('ingredients: «$name» — quantity>0, price≥0. Пропущено.');
            continue;
          }

          final key = ingIndex[name.toLowerCase()];
          final item = Ingredient(name: name, unit: unit, quantity: qty, price: price);
          if (key == null) {
            ingBox.add(item);
            addIng++;
          } else {
            ingBox.put(key, item);
            updIng++;
          }
        }
      }
    }

    // ---- PACKAGING ----
    if (pkgSheet != null) {
      final rows = _rows(pkgSheet);
      final map = _headerMap(rows);
      if (map == null) {
        warnings.add('Лист packaging: не найдены столбцы name/unit/quantity/price.');
      } else {
        for (var i = 1; i < rows.length; i++) {
          final r = rows[i];
          final name = _asString(r, map['name']);
          final unit = _asString(r, map['unit']);
          final qty = _asDouble(r, map['quantity']);
          final price = _asDouble(r, map['price']);

          if (name.isEmpty) continue;
          if (!_isAllowedUnitPackaging(unit)) {
            warnings.add('packaging: «$name» — недопустимая единица ($unit). Разрешено: шт, см.');
            continue;
          }
          if (qty <= 0 || price < 0) {
            warnings.add('packaging: «$name» — quantity>0, price≥0. Пропущено.');
            continue;
          }

          final key = pkgIndex[name.toLowerCase()];
          final item = Packaging(name: name, unit: unit, quantity: qty, price: price);
          if (key == null) {
            pkgBox.add(item);
            addPkg++;
          } else {
            pkgBox.put(key, item);
            updPkg++;
          }
        }
      }
    }

    return ImportResult(
      addedIngredients: addIng,
      updatedIngredients: updIng,
      addedPackaging: addPkg,
      updatedPackaging: updPkg,
      warnings: warnings,
    );
  }

  // ===== helpers =====

  static xls.Sheet? _sheetByName(xls.Excel book, List<String> names) {
    final want = names.map((e) => e.toLowerCase()).toList();
    for (final entry in book.sheets.entries) {
      final n = entry.key.toLowerCase();
      if (want.contains(n)) return entry.value;
    }
    return null;
  }

  static List<List<dynamic>> _rows(xls.Sheet sheet) {
    return sheet.rows
        .map((row) => row.map((c) => c?.value).toList())
        .toList();
  }

  static Map<String, int>? _headerMap(List<List<dynamic>> rows) {
    if (rows.isEmpty) return null;
    final hdr = rows.first.map((e) => (e?.toString() ?? '').trim().toLowerCase()).toList();
    final need = ['name', 'unit', 'quantity', 'price'];
    if (!need.every(hdr.contains)) return null;
    return {
      for (final k in need) k: hdr.indexOf(k),
    };
  }

  static String _asString(List<dynamic> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return '';
    final v = row[idx];
    if (v == null) return '';
    return v.toString().trim();
  }

  static double _asDouble(List<dynamic> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return double.nan;
    final v = row[idx];
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? double.nan;
  }

  static bool _isAllowedUnitIngredient(String u) {
    final x = u.trim().toLowerCase();
    return x == 'г' || x == 'мл' || x == 'шт';
    // при необходимости дополним
  }

  static bool _isAllowedUnitPackaging(String u) {
    final x = u.trim().toLowerCase();
    return x == 'шт' || x == 'см';
  }
}
