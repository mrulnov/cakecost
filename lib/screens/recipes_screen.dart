// lib/screens/recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/packaging.dart';
import '../models/subrecipe.dart';
import '../models/recipe.dart';
import '../models/recipe_item.dart';
import '../providers/recipe_provider.dart';
import '../providers/subrecipe_provider.dart';
import '../services/free_tier.dart';

enum _AddKind { ingredient, subrecipe, packaging, time }

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({Key? key}) : super(key: key);

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rProv = context.watch<RecipeProvider>();
    final sProv = context.watch<SubrecipeProvider>();

    // Боксы для расширенного поиска
    final ingBox = Hive.box<Ingredient>('ingredients');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final pkgBox = Hive.box<Packaging>('packaging');

    final all = rProv.entriesSorted();
    final q = _searchC.text.trim().toLowerCase();

    bool _matchesRecipe(Recipe r, String q) {
      if (q.isEmpty) return true;
      if (r.name.toLowerCase().contains(q)) return true;
      for (final it in r.items) {
        switch (it.kind) {
          case RecipeItemKind.ingredient:
            final ing = ingBox.get(it.refKey);
            if (ing != null && ing.name.toLowerCase().contains(q)) return true;
            break;
          case RecipeItemKind.subrecipe:
            final sr = subBox.get(it.refKey);
            if (sr != null && sr.name.toLowerCase().contains(q)) return true;
            break;
          case RecipeItemKind.packaging:
            final pk = pkgBox.get(it.refKey);
            if (pk != null && pk.name.toLowerCase().contains(q)) return true;
            break;
        }
      }
      return false;
    }

    final filtered = q.isEmpty ? all : all.where((e) => _matchesRecipe(e.value, q)).toList();
    final showEmptyAll = all.isEmpty;
    final showEmptyFiltered = all.isNotEmpty && filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепты'),
        actions: [
          IconButton(
            tooltip: 'Справка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpSheet(
              context,
              assetPath: 'assets/help/recipes.md',
              fallbackTitle: '📌 Рецепты',
              fallbackText: '''
• Сохраняйте готовые изделия: торты, капкейки, пирожные и т.п.

• Нажмите «+» для добавления новой позиции.
• Нажмите по карточке, чтобы редактировать состав.
• Нажмите 📄📄 на карточке для быстрого дублирования рецепта.
• Смахните карточку влево, чтобы удалить.

• Время приготовления вводите в минутах (1 час = 60 минут).
• Субрецепты добавляйте в порциях (штуках)

• Бесплатная версия: до 3 рецептов. Больше—в подписке.
          ''',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchC,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по названию и компонентам',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchC.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        onPressed: () {
                          _searchC.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),

          if (showEmptyAll)
            const _EmptyState()
          else if (showEmptyFiltered)
            _NothingFound(q: _searchC.text)
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final key = filtered[i].key;
                  final r = filtered[i].value;

                  final materials = rProv.materialCost(r, sProv); // только материалы
                  final compCount = r.items.length;
                  final timeLabel = (r.timeHours <= 0)
                      ? 'время не указано'
                      : 'время: ${(r.timeHours * 60).round()} мин';

                  final subtitle =
                      'себестоимость: ${materials.toStringAsFixed(2)} ₽ • компонентов: $compCount\n$timeLabel';

                  return Dismissible(
                    key: ValueKey('rec_$key'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить рецепт?'),
                          content: Text('«${r.name}» будет удалён.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            OutlinedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await rProv.deleteByKey(key);
                        return true;
                      }
                      return false;
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.25)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).hintColor,
                                      height: 1.25,
                                    ),
                              ),
                            ),
                            onTap: () => _editDialog(context, key: key, initial: r),
                          ),
                        ),

                        // маленькая кнопка «копировать»
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _TinyIconButton(
                            tooltip: 'Дублировать',
                            icon: Icons.copy_rounded,
                            onTap: () async {
                              // Лимит free-тиpa на дублирование (создание новой записи)
                              if (!FreeTier.canAddRecipe()) {
                                await FreeTier.showLockedDialog(
                                  context,
                                  message:
                                      'В бесплатной версии можно создать до ${FreeTier.maxRecipes} рецептов. '
                                      'Подписка снимет ограничение.',
                                );
                                return;
                              }
                              await _duplicateRecipe(context, key);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Лимит free-тиpa на создание новой записи
          if (!FreeTier.canAddRecipe()) {
            await FreeTier.showLockedDialog(
              context,
              message:
                  'В бесплатной версии можно создать до ${FreeTier.maxRecipes} рецептов. '
                  'Подписка снимет ограничение.',
            );
            return;
          }
          _editDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---- копирование рецепта ----
  Future<void> _duplicateRecipe(BuildContext context, int key) async {
    final rProv = context.read<RecipeProvider>();
    final newKey = await rProv.duplicateByKey(key);
    final newItem = rProv.getByKey(newKey);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано: ${newItem?.name ?? 'Рецепт'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    HapticFeedback.selectionClick();
  }

  // ================= редактирование =================
  Future<void> _editDialog(BuildContext context, {int? key, Recipe? initial}) async {
    final rProv = context.read<RecipeProvider>();

    final nameC = TextEditingController(text: initial?.name ?? '');
    final items = List<RecipeItem>.from(initial?.items ?? const []);

    int? timeMinutes = (initial != null && initial.timeHours > 0)
        ? (initial.timeHours * 60).round()
        : null;

    bool _nameExistsEverywhere(String nm) {
      final n = nm.trim().toLowerCase();
      final box = Hive.box<Recipe>('recipes');
      for (final e in box.toMap().entries) {
        if (key != null && e.key == key) continue;
        if (e.value.name.trim().toLowerCase() == n) return true;
      }
      return false;
    }

    Future<void> _add<T>({
      required String title,
      required Box<T> box,
      required String Function(MapEntry<int, T>) optionTitle,
      required RecipeItem Function(int key, double qty) make,
    }) async {
      if (box.isEmpty) {
        _showBar(context, 'Нет позиций: ${title.toLowerCase()}');
        return;
      }
      int selKey = box.keyAt(0) as int;
      final qtyC = TextEditingController(text: '1');

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final opts = box.toMap().cast<int, T>().entries.toList();
          return AlertDialog(
            title: Text('Добавить $title'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatefulBuilder(
                    builder: (ctx, setSt) => DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selKey,
                      items: opts
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(optionTitle(e), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      selectedItemBuilder: (ctx) => opts
                          .map((e) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(optionTitle(e), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setSt(() => selKey = v ?? selKey),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(
                      labelText: 'Количество',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
            ],
          );
        },
      );

      if (ok == true) {
        final q = double.tryParse(qtyC.text.replaceAll(',', '.')) ?? 0;
        if (q > 0) items.add(make(selKey, q));
      }
    }

    Future<_AddKind?> _showAddMenu(BuildContext context) {
      return showModalBottomSheet<_AddKind>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.restaurant_outlined)),
                  title: const Text('Ингредиент'),
                  subtitle: const Text('Добавить сырьё из списка ингредиентов'),
                  onTap: () => Navigator.pop(ctx, _AddKind.ingredient),
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.layers_outlined)),
                  title: const Text('Субрецепт'),
                  subtitle: const Text('Добавить полуфабрикат'),
                  onTap: () => Navigator.pop(ctx, _AddKind.subrecipe),
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                  title: const Text('Упаковка'),
                  subtitle: const Text('Добавить расход упаковки'),
                  onTap: () => Navigator.pop(ctx, _AddKind.packaging),
                ),
                const Divider(height: 10),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.timer_outlined)),
                  title: const Text('Время приготовления'),
                  subtitle: const Text('Добавь время в минутах'),
                  onTap: () => Navigator.pop(ctx, _AddKind.time),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> _editTime() async {
      final res = await _askTimeMinutes(context, initial: timeMinutes);
      if (res != null) timeMinutes = res;
    }

    String? nameError;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: Text(initial == null ? 'Новый рецепт' : 'Редактировать рецепт'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameC,
                      onChanged: (_) => setSt(() => nameError = null),
                      decoration: InputDecoration(
                        labelText: 'Название',
                        border: const OutlineInputBorder(),
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final kind = await _showAddMenu(context);
                        if (kind == null) return;

                        switch (kind) {
                          case _AddKind.ingredient:
                            await _add<Ingredient>(
                              title: 'ингредиент',
                              box: Hive.box<Ingredient>('ingredients'),
                              optionTitle: (e) => '${e.value.name} (${e.value.unit})',
                              make: (k, q) =>
                                  RecipeItem(kind: RecipeItemKind.ingredient, refKey: k, quantity: q),
                            );
                            break;
                          case _AddKind.subrecipe:
                            await _add<Subrecipe>(
                              title: 'субрецепт',
                              box: Hive.box<Subrecipe>('subrecipes'),
                              optionTitle: (e) => e.value.name,
                              make: (k, q) =>
                                  RecipeItem(kind: RecipeItemKind.subrecipe, refKey: k, quantity: q),
                            );
                            break;
                          case _AddKind.packaging:
                            await _add<Packaging>(
                              title: 'упаковку',
                              box: Hive.box<Packaging>('packaging'),
                              optionTitle: (e) => '${e.value.name} (${e.value.unit})',
                              make: (k, q) =>
                                  RecipeItem(kind: RecipeItemKind.packaging, refKey: k, quantity: q),
                            );
                            break;
                          case _AddKind.time:
                            await _editTime();
                            break;
                        }
                        setSt(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeMinutes == null
                          ? 'Время приготовления не указано'
                          : 'Время приготовления: $timeMinutes мин',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Состав ещё не задан',
                            style: Theme.of(context).textTheme.bodyMedium),
                      )
                    else
                      Column(
                        children: List.generate(items.length, (i) {
                          final it = items[i];
                          final title = _titleForItem(it);
                          final qtyStr = (it.quantity == it.quantity.roundToDouble())
                              ? it.quantity.toInt().toString()
                              : it.quantity.toStringAsFixed(2);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withOpacity(0.25),
                                ),
                              ),
                              child: ListTile(
                                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text('× $qtyStr'),
                                trailing: IconButton(
                                  tooltip: 'Удалить',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        content: const Text('Удалить позицию из рецепта?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
                                          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Удалить')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      items.removeAt(i);
                                      setSt(() {});
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  final nm = nameC.text.trim();

                  if (nm.isEmpty) {
                    setSt(() => nameError = 'Введите название');
                    HapticFeedback.lightImpact();
                    return;
                  }
                  if (_nameExistsEverywhere(nm)) {
                    setSt(() => nameError = 'Такое имя уже есть');
                    HapticFeedback.lightImpact();
                    return;
                  }

                  if ((timeMinutes ?? 0) <= 0) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        content: const Text('Время приготовления не указано. Продолжить?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Ввести')),
                          ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Продолжить')),
                        ],
                      ),
                    );
                    if (proceed != true) {
                      final res = await _askTimeMinutes(context, initial: timeMinutes);
                      if (res == null) return;
                      timeMinutes = res;
                    }
                  }

                  // При создании новой записи ещё раз проверяем лимит
                  if (key == null && !FreeTier.canAddRecipe()) {
                    await FreeTier.showLockedDialog(
                      context,
                      message:
                          'В бесплатной версии можно создать до ${FreeTier.maxRecipes} рецептов. '
                          'Подписка снимет ограничение.',
                    );
                    return;
                  }

                  final rec = Recipe(
                    name: nm,
                    items: items,
                    timeHours: (timeMinutes ?? 0) / 60.0,
                  );

                  if (key == null) {
                    await rProv.add(rec);
                  } else {
                    await rProv.updateByKey(key, rec);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _titleForItem(RecipeItem it) {
    switch (it.kind) {
      case RecipeItemKind.ingredient:
        final b = Hive.box<Ingredient>('ingredients');
        final x = b.get(it.refKey);
        return x == null ? 'ингредиент #${it.refKey}' : '${x.name} (${x.unit})';
      case RecipeItemKind.subrecipe:
        final b = Hive.box<Subrecipe>('subrecipes');
        final x = b.get(it.refKey);
        return x?.name ?? 'субрецепт #${it.refKey}';
      case RecipeItemKind.packaging:
        final b = Hive.box<Packaging>('packaging');
        final x = b.get(it.refKey);
        return x == null ? 'упаковка #${it.refKey}' : '${x.name} (${x.unit})';
    }
  }
}

// ===== маленькие утилиты =====

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TinyIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            child: Center(
              child: Icon(icon, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> _askTimeMinutes(BuildContext context, {int? initial}) {
  final c = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Время приготовления (мин)'),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          hintText: 'Например, 90',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: () {
            final v = int.tryParse(c.text.trim());
            if (v == null || v <= 0) {
              _showBar(ctx, 'Введите целое число минут (> 0)');
              return;
            }
            Navigator.pop(ctx, v);
          },
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}

/// Единое «плавающее» уведомление.
void _showBar(BuildContext context, String text) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, (bottomInset > 0 ? bottomInset : 0) + 16),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

/// Ничего не найдено по поисковому запросу.
class _NothingFound extends StatelessWidget {
  final String q;
  const _NothingFound({Key? key, required this.q}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 10),
              Text('Ничего не найдено', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Запрос: «${q.trim()}»', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пустой список рецептов.
class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cookie_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text('Рецептов пока нет', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Нажмите «+», чтобы создать первый рецепт'),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== справка =====
Future<void> _showHelpSheet(
  BuildContext context, {
  required String assetPath,
  required String fallbackTitle,
  required String fallbackText,
}) async {
  String text;
  try {
    text = await rootBundle.loadString(assetPath);
    if (text.trim().isEmpty) text = fallbackText;
  } catch (_) {
    text = fallbackText;
  }

  // Стиль как на «Упаковке» + защита от переполнения
  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
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
              Text(fallbackTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
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
