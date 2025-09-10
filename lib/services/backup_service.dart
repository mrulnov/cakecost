// lib/services/backup_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Модели — чтобы иметь типобезопасное повторное открытие боксов
import '../models/ingredient.dart';
import '../models/packaging.dart';
import '../models/subrecipe.dart';
import '../models/resource.dart';
import '../models/recipe.dart';
import '../models/assortment_item.dart';

/// Сервис резервного копирования Cake&Cost.
/// Формат архива: ZIP с `metadata.json` и папкой `hive/*.hive`.
class BackupService {
  // Поддерживаемые боксы Hive — обновляй при добавлении новых
  static const List<String> _boxNames = <String>[
    'ingredients',
    'packaging',
    'subrecipes',
    'resources',
    'recipes',
    'assortment',
  ];

  /// Ожидаемый формат метаданных
  static const String expectedFormat = 'hive-raw-zip/v1';

  /// Папка, где лежат файлы Hive (Hive.initFlutter использует её же).
  Future<Directory> _hiveDir() async => getApplicationDocumentsDirectory();

  /// Папка для ZIP-бэкапов.
  Future<Directory> _backupsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Путь к папке бэкапов — для показа пользователю.
  Future<String> backupsFolderPath() async => (await _backupsDir()).path;

  /// Список имеющихся ZIP-бэкапов (свежие — сверху).
  Future<List<File>> listBackups() async {
    final dir = await _backupsDir();
    if (!await dir.exists()) return <File>[];
    final all = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return all;
    }

  /// Человекочитаемое имя файла.
  String prettyName(File f) => p.basename(f.path);

  // ---------------------------
  // Служебные: закрыть/открыть
  // ---------------------------

  Future<void> _closeAllBoxes() async {
    Future<void> closeIfOpen<T>(String name) async {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<T>(name).close();
      }
    }

    await closeIfOpen<Ingredient>('ingredients');
    await closeIfOpen<Packaging>('packaging');
    await closeIfOpen<Subrecipe>('subrecipes');
    await closeIfOpen<Resource>('resources');
    await closeIfOpen<Recipe>('recipes');
    await closeIfOpen<AssortmentItem>('assortment');
  }

  Future<void> _openAllBoxes() async {
    // Адаптеры зарегистрированы в main.dart
    await Hive.openBox<Ingredient>('ingredients');
    await Hive.openBox<Packaging>('packaging');
    await Hive.openBox<Subrecipe>('subrecipes');
    await Hive.openBox<Resource>('resources');
    await Hive.openBox<Recipe>('recipes');
    await Hive.openBox<AssortmentItem>('assortment');
  }

  // ---------------------------
  // Создание бэкапа
  // ---------------------------

  /// Создаёт ZIP со всеми .hive-файлами и metadata.json.
  Future<File> createBackupZip() async {
    final hiveDir = await _hiveDir();
    final backupDir = await _backupsDir();

    final archive = Archive();

    // Метаданные
    final pkg = await PackageInfo.fromPlatform();
    final meta = {
      'app': 'Cake&Cost',
      'format': expectedFormat,
      'version': pkg.version,
      'build': pkg.buildNumber,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'boxes': _boxNames,
    };
    final metaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(meta));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    // Сами файлы боксов
    for (final name in _boxNames) {
      final file = File(p.join(hiveDir.path, '$name.hive'));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile('hive/$name.hive', bytes.length, bytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive)!;

    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final fileName =
        'cakecost_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.zip';
    final outFile = File(p.join(backupDir.path, fileName));
    await outFile.writeAsBytes(zipBytes, flush: true);
    return outFile;
  }

  // ---------------------------
  // Восстановление из ZIP
  // ---------------------------

  /// Закрывает все боксы, перезаписывает .hive-файлы, заново открывает боксы.
  Future<void> restoreFromZip(File zipFile) async {
    if (!await zipFile.exists()) {
      throw 'Файл не найден: ${zipFile.path}';
    }

    final raw = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(raw);

    await _closeAllBoxes();
    try {
      final hiveDir = await _hiveDir();
      if (!await hiveDir.exists()) {
        await hiveDir.create(recursive: true);
      }

      for (final name in _boxNames) {
        final entryName = 'hive/$name.hive';
        final entry = archive.files.firstWhere(
          (f) => f.name == entryName,
          orElse: () => ArchiveFile('none', 0, const []),
        );

        if (entry.size > 0 && entry.content is List<int>) {
          final dst = File(p.join(hiveDir.path, '$name.hive'));
          await dst.writeAsBytes(entry.content as List<int>, flush: true);
        }
      }
    } finally {
      // В любом случае возвращаем приложение в рабочее состояние
      await _openAllBoxes();
    }
  }

  // -----------------------------
  //   Мини-проверка метаданных
  // -----------------------------

  /// Прочитать metadata.json из ZIP. Возвращает Map или null.
  Future<Map<String, dynamic>?> readMetadata(File zipFile) async {
    if (!await zipFile.exists()) return null;
    try {
      final raw = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(raw);
      final metaEntry = archive.files.firstWhere(
        (f) => f.name == 'metadata.json',
        orElse: () => ArchiveFile('none', 0, const []),
      );
      if (metaEntry.size <= 0 || metaEntry.content is! List<int>) return null;
      final metaStr = utf8.decode(metaEntry.content as List<int>);
      final obj = jsonDecode(metaStr);
      return obj is Map<String, dynamic> ? obj : null;
    } catch (_) {
      return null;
    }
  }

  /// Простой чек: метаданные похожи на нашу резервную копию.
  bool metaLooksSupported(Map<String, dynamic> meta) {
    final fmt = (meta['format'] ?? '').toString();
    return fmt == expectedFormat;
  }
}

// Глобальный экземпляр
final backupService = BackupService();
