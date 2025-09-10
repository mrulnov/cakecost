import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Для Excel-экспорта используем Syncfusion XlsIO
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as sf;

import '../models/ingredient.dart';
import '../models/packaging.dart';
import '../models/subrecipe.dart';
import '../models/subrecipe_ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_item.dart';
import '../models/resource.dart';
import '../models/assortment_item.dart';

class ExportService {
  // ---------- FS ----------
  static Future<Directory> _appDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(dir.path);
  }

  static Future<Directory> _outDir() async {
    final d = Directory('${(await _appDir()).path}/backups');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ---------- Utils ----------
  static String _fmtNum(num v, {int frac = 2}) => v.toStringAsFixed(frac);

  static String _fmtQty(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3);
  }

  /// Для PDF: г/мл -> целые; шт -> шаг 0.5; иначе как раньше.
  static String _fmtQtyPdf(num v, String unitRaw) {
    final u = unitRaw.trim().toLowerCase();
    final x = v.toDouble();

    bool isInt(double n) => n == n.roundToDouble();

    if (u == 'г' || u == 'гр' || u == 'g' || u == 'gram' || u == 'мл' || u == 'ml') {
      return x.round().toString();
    }
    if (u == 'шт' || u == 'pcs' || u == 'piece') {
      final r = (x * 2).round() / 2.0;
      return isInt(r) ? r.toInt().toString() : r.toStringAsFixed(1);
    }
    return isInt(x) ? x.toInt().toString() : x.toStringAsFixed(3);
  }

  static String _sanitizeFileName(String name) {
    final s = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return s.isEmpty ? 'export' : s;
  }

  static const String _rub = 'руб.'; // для PDF вместо ₽

  // ---------- PDF fonts (Cyrillic) ----------
  static pw.Font? _pdfBaseFont;
  static pw.Font? _pdfBoldFont;

  static Future<void> _ensurePdfFonts() async {
    if (_pdfBaseFont != null && _pdfBoldFont != null) return;
    try {
      final reg = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _pdfBaseFont = pw.Font.ttf(reg);
      _pdfBoldFont = pw.Font.ttf(bold);
    } catch (_) {
      _pdfBaseFont = pw.Font.helvetica();
      _pdfBoldFont = pw.Font.helvetica();
    }
  }

  // ---------- Cost calc ----------
  static double _subrecipeCost(Subrecipe sr, Box<Ingredient> ingBox) {
    double total = 0;
    for (final SubrecipeIngredient si in sr.ingredients) {
      final ing = ingBox.get(si.ingredientKey);
      if (ing == null) continue;
      final unit = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
      total += si.quantity * unit;
    }
    return total;
  }

  static double _recipeCost(
    Recipe r, {
    required Box<Ingredient> ingBox,
    required Box<Packaging> packBox,
    required Box<Subrecipe> subBox,
    required Resource res,
  }) {
    double total = 0;

    for (final it in r.items) {
      switch (it.kind) {
        case RecipeItemKind.ingredient:
          final ing = ingBox.get(it.refKey);
          if (ing == null) continue;
          final unit = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
          total += it.quantity * unit;
          break;
        case RecipeItemKind.packaging:
          final p = packBox.get(it.refKey);
          if (p == null) continue;
          final unit = p.quantity == 0 ? 0.0 : p.price / p.quantity;
          total += it.quantity * unit;
          break;
        case RecipeItemKind.subrecipe:
          final sr = subBox.get(it.refKey);
          if (sr == null) continue;
          final sc = _subrecipeCost(sr, ingBox);
          total += it.quantity * sc;
          break;
      }
    }

    final hourly = (res.salary ?? 0) / 160.0;
    final utilPerHour = ((res.utilities ?? 0) * 12.0) / 8760.0;

    total += r.timeHours * hourly;
    total += r.timeHours * utilPerHour;
    return total;
  }

  static double _timeCost(Recipe r, {required Resource res}) {
    final hourly = (res.salary ?? 0) / 160.0;
    final utilPerHour = ((res.utilities ?? 0) * 12.0) / 8760.0;
    return r.timeHours * (hourly + utilPerHour);
  }

  // ======================================================================
  // Excel (Syncfusion) — ЭКСПОРТ ВСЕХ ДАННЫХ
  // ======================================================================
  static Future<File> exportAllToExcel() async {
    final ingBox = Hive.box<Ingredient>('ingredients');
    final packBox = Hive.box<Packaging>('packaging');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final recipeBox = Hive.box<Recipe>('recipes');
    final assortBox = Hive.box<AssortmentItem>('assortment');
    final resBox = Hive.box<Resource>('resources');
    final res = resBox.isEmpty ? Resource(utilities: 0, salary: 0) : resBox.values.first;

    // 6 листов
    final wb = sf.Workbook(6);
    final wsIng = wb.worksheets[0]..name = 'Ингредиенты';
    final wsPkg = wb.worksheets[1]..name = 'Упаковка';
    final wsSub = wb.worksheets[2]..name = 'Субрецепты';
    final wsRec = wb.worksheets[3]..name = 'Рецепты';
    final wsAs  = wb.worksheets[4]..name = 'Ассортимент';
    final wsRes = wb.worksheets[5]..name = 'Ресурсы';

    // Ингредиенты
    {
      int r = 1;
      wsIng.getRangeByName('A$r').setText('Название');
      wsIng.getRangeByName('B$r').setText('Цена, ₽');
      wsIng.getRangeByName('C$r').setText('Кол-во');
      wsIng.getRangeByName('D$r').setText('Ед.');
      wsIng.getRangeByName('E$r').setText('Цена за ед., ₽');
      wsIng.getRangeByName('A$r:E$r').cellStyle.bold = true;

      for (final e in ingBox.toMap().entries) {
        final ing = e.value as Ingredient;
        final unit = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
        r++;
        wsIng.getRangeByName('A$r').setText(ing.name);
        wsIng.getRangeByName('B$r').number = ing.price.toDouble();
        wsIng.getRangeByName('C$r').number = ing.quantity.toDouble();
        wsIng.getRangeByName('D$r').setText(ing.unit);
        wsIng.getRangeByName('E$r').number = unit.toDouble();
      }
      wsIng.getRangeByName('A1:E$r').autoFitColumns();
    }

    // Упаковка
    {
      int r = 1;
      wsPkg.getRangeByName('A$r').setText('Название');
      wsPkg.getRangeByName('B$r').setText('Цена, ₽');
      wsPkg.getRangeByName('C$r').setText('Кол-во');
      wsPkg.getRangeByName('D$r').setText('Ед.');
      wsPkg.getRangeByName('E$r').setText('Цена за ед., ₽');
      wsPkg.getRangeByName('A$r:E$r').cellStyle.bold = true;

      for (final e in packBox.toMap().entries) {
        final p = e.value as Packaging;
        final unit = p.quantity == 0 ? 0.0 : p.price / p.quantity;
        r++;
        wsPkg.getRangeByName('A$r').setText(p.name);
        wsPkg.getRangeByName('B$r').number = p.price.toDouble();
        wsPkg.getRangeByName('C$r').number = p.quantity.toDouble();
        wsPkg.getRangeByName('D$r').setText(p.unit);
        wsPkg.getRangeByName('E$r').number = unit.toDouble();
      }
      wsPkg.getRangeByName('A1:E$r').autoFitColumns();
    }

    // Субрецепты
    {
      int r = 1;
      wsSub.getRangeByName('A$r').setText('Название');
      wsSub.getRangeByName('B$r').setText('Себестоимость, ₽');
      wsSub.getRangeByName('C$r').setText('Состав (кратко)');
      wsSub.getRangeByName('A$r:C$r').cellStyle.bold = true;

      for (final e in subBox.toMap().entries) {
        final sr = e.value as Subrecipe;
        final cost = _subrecipeCost(sr, ingBox);
        final short = sr.ingredients.map((si) {
          final ing = ingBox.get(si.ingredientKey);
          final n = ing?.name ?? 'ингр#${si.ingredientKey}';
          return '$n × ${_fmtQty(si.quantity)}';
        }).join('; ');
        r++;
        wsSub.getRangeByName('A$r').setText(sr.name);
        wsSub.getRangeByName('B$r').number = cost.toDouble();
        wsSub.getRangeByName('C$r').setText(short);
      }
      wsSub.getRangeByName('A1:C$r').autoFitColumns();
    }

    // Рецепты
    {
      int r = 1;
      wsRec.getRangeByName('A$r').setText('Название');
      wsRec.getRangeByName('B$r').setText('Компонентов');
      wsRec.getRangeByName('C$r').setText('Себестоимость, ₽');
      wsRec.getRangeByName('A$r:C$r').cellStyle.bold = true;

      for (final e in recipeBox.toMap().entries) {
        final rcp = e.value as Recipe;
        final cost = _recipeCost(rcp,
            ingBox: ingBox, packBox: packBox, subBox: subBox, res: res);
        r++;
        wsRec.getRangeByName('A$r').setText(rcp.name);
        wsRec.getRangeByName('B$r').number = rcp.items.length.toDouble();
        wsRec.getRangeByName('C$r').number = cost.toDouble();
      }
      wsRec.getRangeByName('A1:C$r').autoFitColumns();
    }

    // Ассортимент
    {
      int r = 1;
      wsAs.getRangeByName('A$r').setText('Название');
      wsAs.getRangeByName('B$r').setText('Цена продажи, ₽');
      wsAs.getRangeByName('C$r').setText('Себестоимость, ₽');
      wsAs.getRangeByName('D$r').setText('Прибыль, ₽');
      wsAs.getRangeByName('E$r').setText('Маржа, %');
      wsAs.getRangeByName('A$r:E$r').cellStyle.bold = true;

      for (final e in recipeBox.toMap().entries) {
        final key = e.key as int;
        final rcp = e.value as Recipe;
        final cost = _recipeCost(rcp,
            ingBox: ingBox, packBox: packBox, subBox: subBox, res: res);

        double price = 0.0;
        for (final it in assortBox.values) {
          if (it.recipeKey == key) {
            price = it.sellPrice.toDouble();
            break;
          }
        }
        final double profit = price - cost;
        final double margin = price <= 0.0 ? 0.0 : ((profit / price) * 100.0);

        r++;
        wsAs.getRangeByName('A$r').setText(rcp.name);
        wsAs.getRangeByName('B$r').number = price;
        wsAs.getRangeByName('C$r').number = cost.toDouble();
        wsAs.getRangeByName('D$r').number = profit;
        wsAs.getRangeByName('E$r').number = margin; // уже double
      }
      wsAs.getRangeByName('A1:E$r').autoFitColumns();
    }

    // Ресурсы
    {
      wsRes.getRangeByName('A1').setText('Коммуналка, ₽/мес');
      wsRes.getRangeByName('B1').setText('Ставка, ₽/мес');
      wsRes.getRangeByName('A1:B1').cellStyle.bold = true;
      wsRes.getRangeByName('A2').number = (res.utilities ?? 0).toDouble();
      wsRes.getRangeByName('B2').number = (res.salary ?? 0).toDouble();
      wsRes.getRangeByName('A1:B2').autoFitColumns();
    }

    final List<int> bytes = wb.saveAsStream();
    wb.dispose();

    final outDir = await _outDir();
    final file = File('${outDir.path}/CakeCost-Export.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ======================================================================
  // Excel (Syncfusion) — ЭКСПОРТ ОДНОГО РЕЦЕПТА
  // ======================================================================
  static Future<File> exportRecipeToExcel(
    int recipeKey, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final recipeBox = Hive.box<Recipe>('recipes');
    final ingBox = Hive.box<Ingredient>('ingredients');
    final packBox = Hive.box<Packaging>('packaging');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final resBox = Hive.box<Resource>('resources');

    final r = recipeBox.get(recipeKey);
    if (r == null) throw Exception('Рецепт #$recipeKey не найден');
    final res = resBox.isEmpty ? Resource(utilities: 0, salary: 0) : resBox.values.first;

    final wb = sf.Workbook(1);
    final ws = wb.worksheets[0]..name = _safeSheetName(r.name);

    int row = 1;

    ws.getRangeByName('A$row').setText('Рецепт');
    ws.getRangeByName('A$row').cellStyle.bold = true;
    row++;

    ws.getRangeByName('A$row').setText(r.name);
    row++;

    ws.getRangeByName('A$row').setText('Время (мин):');
    ws.getRangeByName('B$row').number = (r.timeHours * 60).roundToDouble();
    row++;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      ws.getRangeByName('A$row').setText('Фото:');
      ws.getRangeByName('B$row').setText(
          imageName ?? 'пользовательское изображение (не встраивается в .xlsx)');
      row++;
    }

    row++; // пустая строка

    // Заголовки таблицы
    ws.getRangeByName('A$row').setText('Тип');
    ws.getRangeByName('B$row').setText('Название');
    ws.getRangeByName('C$row').setText('Ед.');
    ws.getRangeByName('D$row').setText('Кол-во');
    ws.getRangeByName('E$row').setText('Цена за ед., ₽');
    ws.getRangeByName('F$row').setText('Сумма, ₽');
    ws.getRangeByName('A$row:F$row').cellStyle.bold = true;

    double materials = 0;
    final usedSubrecipes = <Subrecipe>{};
    final headerRow = row;

    for (final it in r.items) {
      switch (it.kind) {
        case RecipeItemKind.ingredient:
          final ing = ingBox.get(it.refKey);
          if (ing == null) continue;
          final unitPrice = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
          final sum = unitPrice * it.quantity;
          materials += sum;
          row++;
          ws.getRangeByName('A$row').setText('Сырьё');
          ws.getRangeByName('B$row').setText(ing.name);
          ws.getRangeByName('C$row').setText(ing.unit.isEmpty ? '—' : ing.unit);
          ws.getRangeByName('D$row').setText(_fmtQty(it.quantity));
          ws.getRangeByName('E$row').number = unitPrice.toDouble();
          ws.getRangeByName('F$row').number = sum.toDouble();
          break;

        case RecipeItemKind.packaging:
          final p = packBox.get(it.refKey);
          if (p == null) continue;
          final unitPrice = p.quantity == 0 ? 0.0 : p.price / p.quantity;
          final sum = unitPrice * it.quantity;
          materials += sum;
          row++;
          ws.getRangeByName('A$row').setText('Упаковка');
          ws.getRangeByName('B$row').setText(p.name);
          ws.getRangeByName('C$row').setText(p.unit.isEmpty ? '—' : p.unit);
          ws.getRangeByName('D$row').setText(_fmtQty(it.quantity));
          ws.getRangeByName('E$row').number = unitPrice.toDouble();
          ws.getRangeByName('F$row').number = sum.toDouble();
          break;

        case RecipeItemKind.subrecipe:
          final sr = subBox.get(it.refKey);
          if (sr == null) continue;
          final srCost = _subrecipeCost(sr, ingBox);
          final sum = srCost * it.quantity;
          materials += sum;
          usedSubrecipes.add(sr);
          row++;
          ws.getRangeByName('A$row').setText('Субрецепт');
          ws.getRangeByName('B$row').setText(sr.name);
          ws.getRangeByName('C$row').setText('шт');
          ws.getRangeByName('D$row').setText(_fmtQty(it.quantity));
          ws.getRangeByName('E$row').number = srCost.toDouble();
          ws.getRangeByName('F$row').number = sum.toDouble();
          break;
      }
    }

    // Итого
    final time = _timeCost(r, res: res);
    final total = materials + time;

    row += 2;
    ws.getRangeByName('A$row').setText('Материалы, ₽');
    ws.getRangeByName('B$row').number = materials.toDouble();
    row++;
    ws.getRangeByName('A$row').setText('Время, ₽');
    ws.getRangeByName('B$row').number = time.toDouble();
    row++;
    ws.getRangeByName('A$row').setText('Итого, ₽');
    ws.getRangeByName('A$row').cellStyle.bold = true;
    ws.getRangeByName('B$row').number = total.toDouble();

    // Состав субрецептов
    if (usedSubrecipes.isNotEmpty) {
      row += 2;
      ws.getRangeByName('A$row').setText('Состав субрецептов');
      ws.getRangeByName('A$row').cellStyle.bold = true;
      row++;

      for (final sr in usedSubrecipes) {
        ws.getRangeByName('A$row').setText(sr.name);
        ws.getRangeByName('A$row').cellStyle.bold = true;
        row++;

        ws.getRangeByName('A$row').setText('Ингредиент');
        ws.getRangeByName('B$row').setText('Ед.');
        ws.getRangeByName('C$row').setText('Кол-во');
        ws.getRangeByName('D$row').setText('Цена/ед., ₽');
        ws.getRangeByName('E$row').setText('Сумма, ₽');
        ws.getRangeByName('A$row:E$row').cellStyle.bold = true;

        for (final si in sr.ingredients) {
          final ing = ingBox.get(si.ingredientKey);
          if (ing == null) continue;
          final unitPrice = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
          final sum = unitPrice * si.quantity;
          row++;
          ws.getRangeByName('A$row').setText(ing.name);
          ws.getRangeByName('B$row').setText(ing.unit.isEmpty ? '—' : ing.unit);
          ws.getRangeByName('C$row').setText(_fmtQty(si.quantity));
          ws.getRangeByName('D$row').number = unitPrice.toDouble();
          ws.getRangeByName('E$row').number = sum.toDouble();
        }
        row++;
      }
    }

    // авто-ширина
    ws.getRangeByName('A$headerRow:F$row').autoFitColumns();

    final List<int> bytes = wb.saveAsStream();
    wb.dispose();

    final outDir = await _outDir();
    final safe = _sanitizeFileName(r.name);
    final file = File('${outDir.path}/CakeCost-Recipe-$safe.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ======================================================================
  // PDF — ПОЛНЫЙ
  // ======================================================================
  static Future<File> exportRecipeToPdf(
    int recipeKey, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    await _ensurePdfFonts();

    final recipeBox = Hive.box<Recipe>('recipes');
    final ingBox = Hive.box<Ingredient>('ingredients');
    final packBox = Hive.box<Packaging>('packaging');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final resBox = Hive.box<Resource>('resources');

    final r = recipeBox.get(recipeKey);
    if (r == null) throw Exception('Рецепт #$recipeKey не найден');

    final res = resBox.isEmpty ? Resource(utilities: 0, salary: 0) : resBox.values.first;

    final rows = <List<String>>[];
    double materials = 0;
    final breakdown = <Map<String, dynamic>>[];

    void addRow(String type, String name, String unit, double qty, double unitPrice) {
      final sum = unitPrice * qty;
      materials += sum;
      rows.add([
        type,
        name,
        unit.isEmpty ? '—' : unit,
        _fmtQtyPdf(qty, unit),
        _fmtNum(unitPrice),
        _fmtNum(sum)
      ]);
    }

    for (final it in r.items) {
      switch (it.kind) {
        case RecipeItemKind.ingredient:
          final ing = ingBox.get(it.refKey);
          if (ing == null) continue;
          final unitPrice = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
          addRow('Сырьё', ing.name, ing.unit, it.quantity, unitPrice);
          break;
        case RecipeItemKind.packaging:
          final p = packBox.get(it.refKey);
          if (p == null) continue;
          final unitPrice = p.quantity == 0 ? 0.0 : p.price / p.quantity;
          addRow('Упаковка', p.name, p.unit, it.quantity, unitPrice);
          break;
        case RecipeItemKind.subrecipe:
          final sr = subBox.get(it.refKey);
          if (sr == null) continue;
          final srCost = _subrecipeCost(sr, ingBox);
          addRow('Субрецепт', sr.name, 'шт', it.quantity, srCost);

          final subRows = <List<String>>[];
          for (final si in sr.ingredients) {
            final ing = ingBox.get(si.ingredientKey);
            if (ing == null) continue;
            final unitPrice = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
            final sum = unitPrice * si.quantity;
            subRows.add([
              ing.name,
              ing.unit.isEmpty ? '—' : ing.unit,
              _fmtQtyPdf(si.quantity, ing.unit),
              _fmtNum(unitPrice),
              _fmtNum(sum)
            ]);
          }
          breakdown.add({'name': sr.name, 'rows': subRows});
          break;
      }
    }

    final time = _timeCost(r, res: res);
    final total = materials + time;

    final baseFont = _pdfBaseFont ?? pw.Font.helvetica();
    final boldFont = _pdfBoldFont ?? baseFont;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pw.Widget buildHeader() {
      final left = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Рецепт', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(r.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Время приготовления: ${_fmtNum(r.timeHours * 60, frac: 0)} мин',
              style: const pw.TextStyle(fontSize: 10)),
        ],
      );

      final hasImage = imageBytes != null && imageBytes.isNotEmpty;
      if (!hasImage) return left;

      final double pageW = pageTheme.pageFormat.availableWidth;
      final double imgW = pageW * 0.28;
      final double imgH = imgW * 0.66;

      final right = pw.Container(
        width: imgW,
        height: imgH,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Image(pw.MemoryImage(imageBytes!), fit: pw.BoxFit.cover),
        ),
      );

      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: left),
          pw.SizedBox(width: 16),
          right,
        ],
      );
    }

    pw.Widget buildMainTable() {
      final data = rows.isEmpty
          ? <List<String>>[['—', 'Нет компонентов', '—', '—', '—', '—']]
          : rows;

      return pw.TableHelper.fromTextArray(
        headers: ['Тип', 'Название', 'Ед.', 'Кол-во', 'Цена/ед., $_rub', 'Сумма, $_rub'],
        data: data,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        headerHeight: 22,
        cellHeight: 20,
        columnWidths: {
          0: const pw.FlexColumnWidth(1.2),
          1: const pw.FlexColumnWidth(3.0),
          2: const pw.FlexColumnWidth(0.8),
          3: const pw.FlexColumnWidth(1.2),
          4: const pw.FlexColumnWidth(1.4),
          5: const pw.FlexColumnWidth(1.4),
        },
        oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F6F6)),
      );
    }

    pw.Widget buildBreakdowns() {
      if (breakdown.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 12),
          pw.Text('Состав субрецептов', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final b in breakdown) ...[
            pw.Text(b['name'] as String, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Ингредиент', 'Ед.', 'Кол-во', 'Цена/ед., $_rub', 'Сумма, $_rub'],
              data: (b['rows'] as List<List<String>>),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey600),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              headerHeight: 20,
              cellHeight: 18,
            ),
            pw.SizedBox(height: 8),
          ],
        ],
      );
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (_) => [
          buildHeader(),
          pw.SizedBox(height: 12),
          buildMainTable(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Материалы: ${_fmtNum(materials)} $_rub'),
                  pw.Text('Время: ${_fmtNum(_timeCost(r, res: res))} $_rub'),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Итого: ${_fmtNum(_recipeCost(r, ingBox: ingBox, packBox: packBox, subBox: subBox, res: res))} $_rub',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          buildBreakdowns(),
        ],
      ),
    );

    final bytes = await doc.save();
    final outDir = await _outDir();
    final safe = _sanitizeFileName(r.name);
    final file = File('${outDir.path}/CakeCost-Recipe-$safe.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ======================================================================
  // PDF — КОРОТКИЙ
  // ======================================================================
  static Future<File> exportRecipeToPdfShort(
    int recipeKey, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    await _ensurePdfFonts();

    final recipeBox = Hive.box<Recipe>('recipes');
    final ingBox = Hive.box<Ingredient>('ingredients');
    final packBox = Hive.box<Packaging>('packaging');
    final subBox = Hive.box<Subrecipe>('subrecipes');

    final r = recipeBox.get(recipeKey);
    if (r == null) throw Exception('Рецепт #$recipeKey не найден');

    final baseFont = _pdfBaseFont ?? pw.Font.helvetica();
    final boldFont = _pdfBoldFont ?? baseFont;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pw.Widget buildHeader() {
      final left = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Рецепт', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(r.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ],
      );

      final hasImage = imageBytes != null && imageBytes.isNotEmpty;
      if (!hasImage) return left;

      final double pageW = pageTheme.pageFormat.availableWidth;
      final double imgW = pageW * 0.28;
      final double imgH = imgW * 0.66;

      final right = pw.Container(
        width: imgW,
        height: imgH,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Image(pw.MemoryImage(imageBytes!), fit: pw.BoxFit.cover),
        ),
      );

      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: left),
          pw.SizedBox(width: 16),
          right,
        ],
      );
    }

    final ingredientRows = <pw.TableRow>[];
    final packagingRows = <pw.TableRow>[];

    pw.TableRow headerRow() => pw.TableRow(
          children: [
            _cell('Название', bold: true, bg: PdfColors.grey700, color: PdfColors.white, padV: 6),
            _cell('Ед.', bold: true, bg: PdfColors.grey700, color: PdfColors.white, padV: 6, align: pw.Alignment.center),
            _cell('Кол-во', bold: true, bg: PdfColors.grey700, color: PdfColors.white, padV: 6, align: pw.Alignment.centerRight),
          ],
        );

    pw.TableRow blockTitle(String text) => pw.TableRow(
          children: [
            _cell(text, bold: true, bg: PdfColor.fromInt(0xFFEFEFEF), padV: 5),
            _cell('', bg: PdfColor.fromInt(0xFFEFEFEF)),
            _cell('', bg: PdfColor.fromInt(0xFFEFEFEF)),
          ],
        );

    void addItemRow(String name, String unit, String qty) {
      ingredientRows.add(
        pw.TableRow(
          children: [
            _cell(name),
            _cell(unit.isEmpty ? '—' : unit, align: pw.Alignment.center),
            _cell(qty, align: pw.Alignment.centerRight),
          ],
        ),
      );
    }

    void addPackagingRow(String name, String unit, String qty) {
      packagingRows.add(
        pw.TableRow(
          children: [
            _cell(name),
            _cell(unit.isEmpty ? '—' : unit, align: pw.Alignment.center),
            _cell(qty, align: pw.Alignment.centerRight),
          ],
        ),
      );
    }

    for (final it in r.items) {
      switch (it.kind) {
        case RecipeItemKind.ingredient:
          final ing = ingBox.get(it.refKey);
          if (ing == null) continue;
          addItemRow(ing.name, ing.unit, _fmtQtyPdf(it.quantity, ing.unit));
          break;

        case RecipeItemKind.subrecipe:
          final sr = subBox.get(it.refKey);
          if (sr == null) continue;
          ingredientRows.add(blockTitle(sr.name));
          for (final si in sr.ingredients) {
            final ing = ingBox.get(si.ingredientKey);
            if (ing == null) continue;
            final qty = si.quantity * it.quantity;
            addItemRow(ing.name, ing.unit, _fmtQtyPdf(qty, ing.unit));
          }
          break;

        case RecipeItemKind.packaging:
          final p = packBox.get(it.refKey);
          if (p == null) continue;
          addPackagingRow(p.name, p.unit, _fmtQtyPdf(it.quantity, p.unit));
          break;
      }
    }

    if (ingredientRows.isEmpty && packagingRows.isEmpty) {
      ingredientRows.add(
        pw.TableRow(children: [
          _cell('Нет компонентов'),
          _cell('—', align: pw.Alignment.center),
          _cell('—', align: pw.Alignment.centerRight),
        ]),
      );
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(3.0),
      1: const pw.FlexColumnWidth(0.9),
      2: const pw.FlexColumnWidth(1.2),
    };

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (_) => [
          buildHeader(),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E5E5), width: 0.3),
              outside: pw.BorderSide(width: 0),
            ),
            columnWidths: columnWidths,
            children: [headerRow(), ...ingredientRows],
          ),

          if (packagingRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.symmetric(
                inside: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E5E5), width: 0.3),
                outside: pw.BorderSide(width: 0),
              ),
              columnWidths: columnWidths,
              children: [
                blockTitle('Упаковка'),
                ...packagingRows,
              ],
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final outDir = await _outDir();
    final safe = _sanitizeFileName(r.name);
    final file = File('${outDir.path}/CakeCost-Recipe-$safe-short.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ячейка таблицы для короткой PDF-версии
  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? bg,
    PdfColor? color,
    double padV = 4,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: padV),
      color: bg,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static String _safeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ');
    if (s.isEmpty) s = 'Рецепт';
    if (s.length > 31) s = s.substring(0, 31);
    return s;
  }
}

final exportService = ExportService();
