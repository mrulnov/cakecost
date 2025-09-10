import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/assortment_provider.dart';
import '../providers/ingredient_provider.dart';
import '../providers/packaging_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/subrecipe_provider.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File> _backups = [];
  bool _busy = false;
  String? _folderPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await backupService.listBackups();
    final folder = await backupService.backupsFolderPath();
    setState(() {
      _backups = list;
      _folderPath = folder;
    });
  }

  Future<File> _ensureBackup() async {
    final list = await backupService.listBackups();
    if (list.isEmpty) {
      return await backupService.createBackupZip();
    }
    return list.first;
  }

  Future<void> _makeBackup() async {
    setState(() => _busy = true);
    try {
      final f = await backupService.createBackupZip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Резервная копия создана: ${f.uri.pathSegments.last}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания резервной копии: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Восстановить данные?'),
        content: Text(
          'Текущие данные будут заменены содержимым:\n"${f.uri.pathSegments.last}".\n'
          'Продолжить?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Восстановить')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await backupService.restoreFromZip(f);

      context.read<IngredientProvider>().notifyListeners();
      context.read<PackagingProvider>().notifyListeners();
      context.read<SubrecipeProvider>().notifyListeners();
      context.read<ResourceProvider>().notifyListeners();
      context.read<RecipeProvider>().notifyListeners();
      context.read<AssortmentProvider>().notifyListeners();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Восстановление завершено')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка восстановления: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final f = await _ensureBackup();
      await Share.shareXFiles(
        [XFile(f.path, mimeType: 'application/zip', name: 'CakeCost-backup.zip')],
        subject: 'Cake Cost — резервная копия',
        text: 'Во вложении резервная копия данных приложения Cake Cost.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromPicker() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withReadStream: false,
      );
      if (pick == null || pick.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(pick.files.single.path!);

      final meta = await backupService.readMetadata(file);
      String? warn;
      if (meta == null) {
        warn = 'Выбранный файл не содержит метаданных резервной копии.\n'
            'Возможно, это не файл Cake&Cost. Продолжить восстановление?';
      } else if (!backupService.metaLooksSupported(meta)) {
        final fmt = (meta['format'] ?? 'неизвестно').toString();
        warn = 'Формат файла: $fmt\nОжидается: ${BackupService.expectedFormat}.\n'
            'Продолжить восстановление из этого файла?';
      }

      if (warn != null) {
        final goOn = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Проверка файла'),
            content: Text(warn!),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Продолжить')),
            ],
          ),
        );
        if (goOn != true) {
          setState(() => _busy = false);
          return;
        }
      }

      await _restore(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выбрать файл: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDownloads() async {
    setState(() => _busy = true);
    try {
      final f = await _ensureBackup();
      final ok = await _confirmSaveDialog(f);
      if (ok == true) {
        await _saveSpecific(f);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено в «Файлы» (или выбранную папку)')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareSpecific(File f) async {
    try {
      await Share.shareXFiles(
        [XFile(f.path, mimeType: 'application/zip', name: f.uri.pathSegments.last)],
        subject: 'Cake Cost — резервная копия',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $e')),
      );
    }
  }

  Future<void> _saveSpecific(File f) async {
    final Uint8List bytes = await f.readAsBytes();
    await FileSaver.instance.saveAs(
      name: f.uri.pathSegments.last.replaceAll('.zip', ''),
      bytes: bytes,
      ext: 'zip',
      mimeType: MimeType.other,
      customMimeType: 'application/zip',
    );
  }

  Future<bool?> _confirmSaveDialog(File f) {
    final hint = _saveDestinationHint();
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Сохранить резервную копию?'),
        content: Text('Файл «${backupService.prettyName(f)}» будет сохранён.\n\n$hint'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
  }

  String _saveDestinationHint() {
    if (Platform.isAndroid) {
      return 'Android: по умолчанию — в папку «Загрузки». На некоторых устройствах система предложит выбрать папку.';
    } else if (Platform.isIOS) {
      return 'iOS: откроется системное окно «Сохранить в Файлы». Можно выбрать iCloud Drive или «На iPhone».';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'ПК: появится диалог выбора расположения файла.';
    }
    return 'Файл будет сохранён в выбранную пользователем папку.';
    }

  Future<void> _copyPath() async {
    if (_folderPath == null || _folderPath!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _folderPath!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Путь скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBackup = _backups.isNotEmpty;
    final sorted = [..._backups]..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final last = hasBackup ? sorted.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Резервное копирование'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌 Резервные копии',
              body: '''
Резервная копия позволяет сохранить ваши данные, перенести их на другое устройство или восстановиться после сбоя/переустановки.

• Будьте внимательны: текущие данные будут заменены содержимым копии при восстановлении данных из архива. Перед восстановлением при необходимости сохраните актуальную копию.
• Кнопка «копировать путь» поможет быстро открыть её через файловый менеджер.
• Данные хранятся только у вас — приложение не отправляет их на сервер.  
• При восстановлении данные сразу обновятся в приложении (перезапуск не нужен).
''',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context,
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _makeBackup,
                          icon: const Icon(Icons.archive),
                          label: const Text('Создать копию (ZIP)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _saveToDownloads,
                          icon: const Icon(Icons.download),
                          label: const Text('Сохранить в «Файлы»'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _shareBackup,
                          icon: const Icon(Icons.mail_outlined),
                          label: const Text('Отправить по почте'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _restoreFromPicker,
                          icon: const Icon(Icons.restore),
                          label: const Text('Восстановить из файла'),
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
          if (last != null) _lastBackupCard(context, last),
          if (_folderPath != null && _folderPath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              context,
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.folder_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Внутренняя копия (для восстановления) хранится здесь:\n$_folderPath',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Скопировать путь',
                      onPressed: _busy ? null : _copyPath,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lastBackupCard(BuildContext context, File f) {
    final name = backupService.prettyName(f);
    final dt = f.lastModifiedSync().toLocal();
    final size = _formatFileSize(f.lengthSync());

    return _card(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 22,
              child: Icon(Icons.backup, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Последняя копия', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(name, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtDateTime(dt)} • $size',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (v) async {
                switch (v) {
                  case 'restore':
                    await _restore(f);
                    break;
                  case 'share':
                    await _shareSpecific(f);
                    break;
                  case 'save':
                    final ok = await _confirmSaveDialog(f);
                    if (ok == true) await _saveSpecific(f);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restore', child: Text('Восстановить')),
                PopupMenuItem(value: 'share', child: Text('Отправить')),
                PopupMenuItem(value: 'save', child: Text('Сохранить в файлы')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatFileSize(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  void _showHelp(BuildContext context, {required String title, required String body}) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
            ),
          ],
        ),
      ),
    );
  }
}
