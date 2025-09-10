import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;

import '../models/ingredient.dart';
import '../models/packaging.dart';
import '../models/subrecipe.dart';
import '../models/subrecipe_ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_item.dart';
import '../models/resource.dart';

class PdfService {
  static const _fontAsset = 'assets/fonts/NotoSans-Regular.ttf';

  static Future<pw.Font> _loadFont() async {
    final data = await rootBundle.load(_fontAsset);
    return pw.Font.ttf(data);
  }

  static Future<Directory> _outDir() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory('${app.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fmtInt(num v) => v.round().toString();

  static String _fmtStep05(num v) {
    final r = (v * 2).round() / 2.0;
    return (r == r.roundToDouble()) ? r.toInt().toString() : r.toStringAsFixed(1);
  }

  static String _qtyForUnit(num qty, String unit) {
    final u = unit.trim().toLowerCase();
    if (u == 'шт' || u == 'см') return _fmtStep05(qty);
    return _fmtInt(qty);
  }

  static List<List<String>> _rowsForIngredients(
    Iterable<RecipeItem> items,
    Box<Ingredient> ingBox,
  ) {
    final rows = <List<String>>[];
    for (final it in items) {
      final ing = ingBox.get(it.refKey);
      final name = ing?.name ?? 'ингр#${it.refKey} (удалён)';
      final unit = ing?.unit ?? '';
      rows.add([name, _qtyForUnit(it.quantity, unit), unit]);
    }
    return rows;
  }

  static List<List<String>> _rowsForPackaging(
    Iterable<RecipeItem> items,
    Box<Packaging> packBox,
  ) {
    final rows = <List<String>>[];
    for (final it in items) {
      final p = packBox.get(it.refKey);
      final name = p?.name ?? 'упак#${it.refKey} (удалена)';
      final unit = p?.unit ?? '';
      rows.add([name, _qtyForUnit(it.quantity, unit), unit]);
    }
    return rows;
  }

  static List<List<String>> _rowsFromSubrecipe(
    Subrecipe sr,
    double mult,
    Box<Ingredient> ingBox,
  ) {
    final rows = <List<String>>[];
    // строка-заголовок субрецепта (в таблицу положим одну ячейку и пустые остальные)
    rows.add(['— ${sr.name} × ${mult.toStringAsFixed(3)} —', '', '']);
    for (final SubrecipeIngredient si in sr.ingredients) {
      final ing = ingBox.get(si.ingredientKey);
      final name = ing?.name ?? 'ингр#${si.ingredientKey} (удалён)';
      final unit = ing?.unit ?? '';
      final qty = si.quantity * mult;
      rows.add(['• $name', _qtyForUnit(qty, unit), unit]);
    }
    return rows;
  }

  /// Генерирует PDF рецепта (состав без цен) и сохраняет файл во внутреннюю папку.
  static Future<File> generateRecipePdf(int recipeKey) async {
    final font = await _loadFont();

    final ingBox = Hive.box<Ingredient>('ingredients');
    final packBox = Hive.box<Packaging>('packaging');
    final subBox  = Hive.box<Subrecipe>('subrecipes');
    final recBox  = Hive.box<Recipe>('recipes');
    final resBox  = Hive.box<Resource>('resources');

    final recipe = recBox.get(recipeKey);
    if (recipe == null) throw 'Рецепт не найден';

    final res = resBox.isEmpty ? Resource(utilities: 0, salary: 0) : resBox.values.first;

    // Блоки
    final ingrItems = recipe.items.where((it) => it.kind == RecipeItemKind.ingredient);
    final packItems = recipe.items.where((it) => it.kind == RecipeItemKind.packaging);
    final subrItems = recipe.items.where((it) => it.kind == RecipeItemKind.subrecipe);

    final doc = pw.Document();
    final base = pw.TextStyle(font: font, fontSize: 11);

    pw.Widget _blockTitle(String t) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(t, style: base.copyWith(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

    pw.Widget _table(List<List<String>> rows) => pw.Table.fromTextArray(
      headers: const ['Наименование', 'Кол-во', 'Ед.'],
      data: rows,
      headerStyle: base.copyWith(fontSize: 11),
      cellStyle: base,
      headerDecoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
      border: pw.TableBorder.all(color: pdf.PdfColors.grey600, width: 0.5),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(36),
      },
    );

    final content = <pw.Widget>[
      pw.Text('Рецепт: ${recipe.name}', style: base.copyWith(fontSize: 16)),
    ];

    // Блок «Ингредиенты рецепта»
    final ingrRows = _rowsForIngredients(ingrItems, ingBox);
    if (ingrRows.isNotEmpty) {
      content.addAll([_blockTitle('Ингредиенты'), _table(ingrRows)]);
    }

    // Блоки по каждому субрецепту
    for (final it in subrItems) {
      final sr = subBox.get(it.refKey);
      if (sr == null) continue;
      final rows = _rowsFromSubrecipe(sr, it.quantity, ingBox);
      content.addAll([_blockTitle('Субрецепт: ${sr.name} × ${it.quantity.toStringAsFixed(3)}'), _table(rows)]);
    }

    // Блок «Упаковка»
    final packRows = _rowsForPackaging(packItems, packBox);
    if (packRows.isNotEmpty) {
      content.addAll([_blockTitle('Упаковка'), _table(packRows)]);
    }

    if (recipe.timeHours > 0) {
      content.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Время на рецепт: ${recipe.timeHours.toStringAsFixed(2)} ч', style: base),
        ),
      );
    }

    content.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Дата: ${DateTime.now().toLocal()}',
          style: base.copyWith(color: pdf.PdfColors.grey600, fontSize: 9),
        ),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: font),
        ),
        build: (ctx) => content,
      ),
    );

    final bytes = await doc.save();
    final out = await _outDir();
    final safeName = recipe.name.replaceAll(RegExp(r'[^\w\- ]+'), '_');
    final file = File('${out.path}/Recipe-$safeName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Uint8List> generateRecipePdfBytes(int recipeKey) async {
    final f = await generateRecipePdf(recipeKey);
    return f.readAsBytes();
  }
}
