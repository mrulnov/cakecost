// lib/screens/export_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// Генерация шаблона Excel — через Syncfusion XlsIO
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as sf;

import '../models/recipe.dart';
import '../providers/assortment_provider.dart';
import '../providers/ingredient_provider.dart';
import '../providers/packaging_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/subrecipe_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/free_tier.dart';

// ⬇️ ограничения бесплатной версии / проба PDF
import '../services/free_tier.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _busy = false;
  File? _lastFile;

  // ---- для «Экспорт рецепта» ----
  int? _recipeKey;
  Uint8List? _imageBytes;
  String? _imageName;

  // ================== ЭКСПОРТ ВСЕХ ДАННЫХ ==================

  Future<File> _makeExcel() async {
    final f = await ExportService.exportAllToExcel();
    setState(() => _lastFile = f);
    return f;
  }

  Future<void> _exportExcel({bool andShare = false}) async {
    setState(() => _busy = true);
    try {
      // платно: экспорт всех данных
      if (!await FreeTier.isPro()) {
        await FreeTier.showLockedDialog(context,
            message: 'Экспорт всех данных в Excel доступен в подписке.');
        return;
      }

      final f = await _makeExcel();
      if (!mounted) return;
      _toast('Экспорт создан: ${f.uri.pathSegments.last}');
      if (andShare) {
        await _shareSpecific(f);
      } else {
        await _openFile(f);
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка экспорта: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDownloads() async {
    setState(() => _busy = true);
    try {
      // платно: сохранение общего Excel
      if (!await FreeTier.isPro()) {
        await FreeTier.showLockedDialog(context,
            message: 'Сохранение Excel доступно в подписке.');
        return;
      }

      final f = _lastFile ?? await _makeExcel();
      final ok = await _confirmSaveDialog(f);
      if (ok == true) {
        final Uint8List bytes = await f.readAsBytes();
        await FileSaver.instance.saveAs(
          name: 'CakeCost-Export',
          bytes: bytes,
          ext: 'xlsx',
          mimeType: MimeType.other,
          customMimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!mounted) return;
        _toast('Сохранено в «Загрузки» (или выбранную папку)');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ================== ЭКСПОРТ ОДНОГО РЕЦЕПТА ==================

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
        allowCompression: false,
      );
      if (res == null || res.files.isEmpty) return;

      final pf = res.files.first;
      Uint8List? bytes = pf.bytes;

      if (bytes == null && pf.readStream != null) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in pf.readStream!) {
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      }
      if (bytes == null && pf.path != null && pf.path!.isNotEmpty) {
        bytes = await File(pf.path!).readAsBytes();
      }
      if (bytes == null) {
        _toast('Не удалось прочитать выбранный файл');
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = pf.name;
      });
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось выбрать изображение: $e');
    }
  }

  Future<void> _exportRecipeExcel() async {
    if (_recipeKey == null) {
      _toast('Выберите рецепт');
      return;
    }
    setState(() => _busy = true);
    try {
      // платно: экспорт рецепта в Excel
      if (!await FreeTier.isPro()) {
        await FreeTier.showLockedDialog(context,
            message: 'Экспорт рецепта в Excel доступен в подписке.');
        return;
      }

      final f = await ExportService.exportRecipeToExcel(
        _recipeKey!,
        imageBytes: _imageBytes, // в xlsx только примечание
        imageName: _imageName,
      );
      if (!mounted) return;
      _toast('Создан Excel: ${f.uri.pathSegments.last}');
      await _openFile(f);
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка экспорта: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportRecipePdf() async {
    if (_recipeKey == null) {
      _toast('Выберите рецепт');
      return;
    }
    setState(() => _busy = true);
    try {
      // 1 бесплатная проба PDF (для не-Pro)
      if (!await FreeTier.isPro()) {
        final okTrial = await FreeTier.canUsePdfTrial();
        if (!okTrial) {
          await FreeTier.showLockedDialog(context,
              message: 'Экспорт рецепта в PDF доступен в подписке.');
          return;
        }
      }

      final f = await ExportService.exportRecipeToPdf(
        _recipeKey!,
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      if (!mounted) return;
      _toast('Создан PDF: ${f.uri.pathSegments.last}');
      await _openFile(f);

      if (!await FreeTier.isPro()) {
        await FreeTier.markPdfTrialUsed();
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка экспорта: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportRecipePdfShort() async {
    if (_recipeKey == null) {
      _toast('Выберите рецепт');
      return;
    }
    setState(() => _busy = true);
    try {
      // 1 бесплатная проба PDF (для не-Pro)
      if (!await FreeTier.isPro()) {
        final okTrial = await FreeTier.canUsePdfTrial();
        if (!okTrial) {
          await FreeTier.showLockedDialog(context,
              message: 'Экспорт рецепта в PDF доступен в подписке.');
          return;
        }
      }

      final f = await ExportService.exportRecipeToPdfShort(
        _recipeKey!,
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      if (!mounted) return;
      _toast('Создан PDF (кратко): ${f.uri.pathSegments.last}');
      await _openFile(f);

      if (!await FreeTier.isPro()) {
        await FreeTier.markPdfTrialUsed();
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка экспорта: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ================== ШАБЛОН EXCEL (только XLSX) ==================

  Future<void> _saveExcelTemplate() async {
    setState(() => _busy = true);
    try {
      final bytes = _buildExcelTemplateBytesSf(); // надежный xlsx
      final ts = _timestamp();
      await FileSaver.instance.saveAs(
        name: 'CakeCost-import-template_$ts',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.other,
        customMimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      _toast('Шаблон Excel сохранён');
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось сохранить шаблон: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Генерация шаблона через Syncfusion XlsIO — без предупреждений в MS 365.
  Uint8List _buildExcelTemplateBytesSf() {
    final wb = sf.Workbook(2); // ровно 2 листа
    final wsIng = wb.worksheets[0]..name = 'ingredients';
    final wsPkg = wb.worksheets[1]..name = 'packaging';

    // Заголовки
    void header(sf.Worksheet ws) {
      ws.getRangeByName('A1').setText('name');
      ws.getRangeByName('B1').setText('unit');
      ws.getRangeByName('C1').setText('quantity');
      ws.getRangeByName('D1').setText('price');
      final h = ws.getRangeByName('A1:D1');
      h.cellStyle.bold = true;
    }

    header(wsIng);
    header(wsPkg);

    // Примеры (ингредиенты)
    wsIng.getRangeByName('A2').setText('Мука пшеничная');
    wsIng.getRangeByName('B2').setText('г');
    wsIng.getRangeByName('C2').number = 1000;
    wsIng.getRangeByName('D2').number = 75;

    wsIng.getRangeByName('A3').setText('Сахар');
    wsIng.getRangeByName('B3').setText('г');
    wsIng.getRangeByName('C3').number = 1000;
    wsIng.getRangeByName('D3').number = 65.5;

    wsIng.getRangeByName('A4').setText('Яйцо куриное');
    wsIng.getRangeByName('B4').setText('шт');
    wsIng.getRangeByName('C4').number = 10;
    wsIng.getRangeByName('D4').number = 120;

    // Примеры (упаковка)
    wsPkg.getRangeByName('A2').setText('Коробка 20x20');
    wsPkg.getRangeByName('B2').setText('шт');
    wsPkg.getRangeByName('C2').number = 1;
    wsPkg.getRangeByName('D2').number = 50;

    wsPkg.getRangeByName('A3').setText('Лента атласная');
    wsPkg.getRangeByName('B3').setText('см');
    wsPkg.getRangeByName('C3').number = 100;
    wsPkg.getRangeByName('D3').number = 120;

    // Ширина колонок
    wsIng.getRangeByName('A1:D1').autoFitColumns();
    wsPkg.getRangeByName('A1:D1').autoFitColumns();

    final List<int> raw = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(raw);
  }

  // ================== ИМПОРТ (внизу экрана) ==================

  Future<void> _importFromFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // платно: импорт данных
      if (!await FreeTier.isPro()) {
        await FreeTier.showLockedDialog(context,
            message: 'Импорт данных доступен в подписке.');
        return;
      }

      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withReadStream: false,
      );
      if (pick == null || pick.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(pick.files.single.path!);

      final result = await ImportService.importDataFromFile(file);

      if (!mounted) return;
      // Обновляем провайдеры
      context.read<IngredientProvider>().notifyListeners();
      context.read<PackagingProvider>().notifyListeners();
      context.read<SubrecipeProvider>().notifyListeners();
      context.read<ResourceProvider>().notifyListeners();
      context.read<RecipeProvider>().notifyListeners();
      context.read<AssortmentProvider>().notifyListeners();

      _toast(result.message);
    } catch (e) {
      if (!mounted) return;
      _toast('Импорт не выполнен: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ================== ОБЩЕЕ ==================

  Future<void> _shareSpecific(File f) async {
    await Share.shareXFiles(
      [XFile(f.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Cake Cost — экспорт в Excel',
      text: 'Во вложении Excel-отчёт из приложения Cake Cost.',
    );
  }

  Future<void> _openFile(File f) async {
    final res = await OpenFilex.open(f.path);
    if (!mounted) return;
    if (res.type != ResultType.done) {
      _toast('Не удалось открыть файл: ${res.message}');
    }
  }

  Future<bool?> _confirmSaveDialog(File f) {
    final hint = _saveDestinationHint();
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Сохранить файл?'),
        content: Text('«${f.uri.pathSegments.last}» будет сохранён.\n\n$hint'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
  }

  String _saveDestinationHint() {
    if (Platform.isAndroid) {
      return 'По умолчанию файл попадёт в «Загрузки». На некоторых устройствах система предложит выбрать папку.';
    } else if (Platform.isIOS) {
      return 'Откроется окно «Сохранить в Файлы». Можно выбрать iCloud Drive или «На iPhone».';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'Появится стандартный диалог выбора расположения файла.';
    }
    return 'Файл будет сохранён в выбранную пользователем папку.';
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _timestamp() {
    String two(int n) => n.toString().padLeft(2, '0');
    final dt = DateTime.now();
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}';
  }

  // ================== UI ==================

  void _showHelp() {
    // Фикс переполнения: ограничение высоты + скролл, стиль как на «Упаковке»
    const String helpTitle = '📌 Экспорт / Импорт';
    const String helpText =
        '• Создавайте таблицы Excel — выгружайте все ингредиенты, упаковку, субрецепты, рецепты, ассортимент и ресурсы.\n'
        '• Сохраняйте файлы — формат .xlsx в «Загрузки»/«Файлы».\n'
        '• Отправляйте файлы — делитесь данными через почту или мессенджер\n\n'
        '• Экспортируйте рецепты\n'
        'Добавляйте рецепт, прикрепляйте фото своего десерта (показывается только в PDF), выбирайте формат для экспорта:\n'
        '* Excel — таблица состава и итогов.\n'
        '* PDF (полный) — с ценами; PDF (коротко) — компактный список без цен.\n\n'
        'Импортируйте списки своих ингредиентов и упаковки в приложение\n'
        '• Сначала скачайте шаблон Excel.\n'
        '• Заполните листы «Ингредиенты» и «Упаковка».\n'
        '• Вернитесь в приложение и выберите заполненный файл — данные добавятся к существующим.\n'
        '• Импорт не удаляет ваши записи, а добавляет новые из файла.';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewPadding.bottom;
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Text(helpTitle, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      helpText,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Понятно'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeBox = Hive.box<Recipe>('recipes');
    final entries = recipeBox.toMap().cast<int, Recipe>().entries.toList()
      ..sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Экспорт / Импорт'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Экспорт данных (всё) ----
          _card(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Экспорт данных', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.table_view, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Экспортирует все данные в Excel (.xlsx): ингредиенты, упаковка, '
                          'субрецепты (себестоимость), рецепты (себестоимость), ассортимент '
                          '(цена/прибыль/маржа), ресурсы.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : () => _exportExcel(andShare: false),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Создать Excel (всё)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _saveToDownloads,
                          icon: const Icon(Icons.download),
                          label: const Text('Сохранить в файлы'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : () => _exportExcel(andShare: true),
                          icon: const Icon(Icons.send),
                          label: const Text('Создать и отправить'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ---- Экспорт одного рецепта ----
          _card(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Экспорт рецепта', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _recipeKey,
                    items: [
                      for (final e in entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _recipeKey = v),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Выберите рецепт',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Выбрать фото (необязательно)'),
                        ),
                      ),
                    ],
                  ),
                  if (_imageBytes != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_imageBytes!, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _imageName ?? 'изображение',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Удалить фото',
                          onPressed: () => setState(() {
                            _imageBytes = null;
                            _imageName = null;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Примечание: в Excel фото не встраивается — смотрите PDF для варианта с изображением.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _exportRecipeExcel,
                          icon: const Icon(Icons.grid_on),
                          label: const Text('Excel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _exportRecipePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _exportRecipePdfShort,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('PDF (коротко)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ---- Шаблон Excel ----
          _card(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Шаблон для импорта (Excel)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Скачайте шаблон Excel (.xlsx), заполните листы «ingredients» и «packaging», '
                    'а затем импортируйте файл ниже.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _saveExcelTemplate,
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Скачать шаблон Excel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ---- Импорт данных (внизу) ----
          _card(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Импорт данных', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.upload_file, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Поддерживаются Excel-файлы (.xlsx/.xls). '
                          'Используйте листы «ingredients» и «packaging», столбцы: name, unit, quantity, price.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _importFromFile,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Выбрать файл для импорта'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- helpers ---

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: child,
    );
  }
}
