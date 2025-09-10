// lib/screens/subrecipes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/subrecipe.dart';
import '../models/subrecipe_ingredient.dart';
import '../models/recipe.dart';
import '../providers/subrecipe_provider.dart';
import '../services/free_tier.dart';

class SubrecipesScreen extends StatefulWidget {
  const SubrecipesScreen({super.key});

  @override
  State<SubrecipesScreen> createState() => _SubrecipesScreenState();
}

class _SubrecipesScreenState extends State<SubrecipesScreen> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SubrecipeProvider>();
    final entries = prov.entriesSorted();

    final ingBox = Hive.box<Ingredient>('ingredients');

    final q = _searchC.text.trim().toLowerCase();
    List<MapEntry<int, Subrecipe>> filtered;
    if (q.isEmpty) {
      filtered = entries;
    } else {
      filtered = entries.where((e) {
        final byName = e.value.name.toLowerCase().contains(q);
        if (byName) return true;
        final names = e.value.ingredients
            .map((si) => ingBox.get(si.ingredientKey)?.name ?? '')
            .map((s) => s.toLowerCase());
        return names.any((n) => n.contains(q));
      }).toList();
    }

    final showEmptyAll = entries.isEmpty;
    final showEmptyFiltered = entries.isNotEmpty && filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Субрецепты'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌 Субрецепты',
              body: '''
• Сохраняйте «заготовки», которые повторяются в разных изделиях:
  бисквит, крем, ганаш, сироп, начинка и т.п.

• Нажмите «+» для добавления новой позиции
• Нажмите по карточке, чтобы редактировать состав
• Нажмите 📄📄 на карточке для быстрого дублирования
• Смахните карточку влево, чтобы удалить

• Для единицы «шт» количество округляется кратно 0,5 (0,5; 1; 1,5 и т. д.)

• Бесплатная версия: до ${FreeTier.maxSubrecipes} субрецептов. Больше — в подписке.
''',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchC,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по названию и ингредиентам',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchC.text.isEmpty
                    ? null
                    : IconButton(
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
                  final k = filtered[i].key;
                  final sr = filtered[i].value;

                  final subtitle = _subtitle(sr, ingBox);

                  return Dismissible(
                    key: ValueKey('sr_$k'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      final ok = await _confirmDelete(context, sr.name);
                      if (ok) context.read<SubrecipeProvider>().deleteByKey(k);
                      return ok;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.25),
                            ),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            title: Text(
                              sr.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                            onTap: () => _openEditor(context, key: k, initial: sr),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _TinyIconButton(
                            tooltip: 'Дублировать',
                            icon: Icons.copy_rounded,
                            onTap: () async {
                              // Лимит бесплатной версии на создание новой записи (дубликат = новая запись)
                              if (!FreeTier.canAddSubrecipe()) {
                                await FreeTier.showLockedDialog(
                                  context,
                                  message:
                                      'В бесплатной версии можно создать до ${FreeTier.maxSubrecipes} субрецептов. '
                                      'Подписка снимет ограничение.',
                                );
                                return;
                              }
                              await _duplicate(context, k);
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
          // Лимит бесплатной версии на создание новой записи
          if (!FreeTier.canAddSubrecipe()) {
            await FreeTier.showLockedDialog(
              context,
              message:
                  'В бесплатной версии можно создать до ${FreeTier.maxSubrecipes} субрецептов. '
                  'Подписка снимет ограничение.',
            );
            return;
          }
          _openEditor(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _subtitle(Subrecipe s, Box<Ingredient> ingBox) {
    final names = s.ingredients
        .map((e) => ingBox.get(e.ingredientKey)?.name)
        .whereType<String>()
        .toList();
    final comp = names.isEmpty ? 'состав не задан' : names.join(', ');

    double cost = 0;
    for (final it in s.ingredients) {
      final ing = ingBox.get(it.ingredientKey);
      if (ing == null) continue;
      final unit = ing.quantity == 0 ? 0.0 : ing.price / ing.quantity;
      cost += unit * it.quantity;
    }

    final line2 =
        'себестоимость: ${cost.toStringAsFixed(2)} ₽ • компонентов: ${s.ingredients.length}';

    return 'состав: $comp\n$line2';
  }

  Future<void> _duplicate(BuildContext context, int key) async {
    final provider = context.read<SubrecipeProvider>();
    final newKey = await provider.duplicateByKey(key);
    final newItem = provider.getByKey(newKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано: ${newItem?.name ?? 'Субрецепт'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    HapticFeedback.selectionClick();
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Удалить субрецепт?'),
            content: Text('«$name» будет удалён без возможности восстановления.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Отмена')),
              OutlinedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Удалить')),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ) ??
        false;
  }

  // ===== РЕДАКТОР =====
  Future<void> _openEditor(BuildContext context, {int? key, Subrecipe? initial}) async {
    final prov = context.read<SubrecipeProvider>();

    final ingBox = Hive.box<Ingredient>('ingredients');
    final subBox = Hive.box<Subrecipe>('subrecipes');
    final recBox = Hive.box<Recipe>('recipes');

    final nameC = TextEditingController(text: initial?.name ?? '');
    final items = List<SubrecipeIngredient>.from(initial?.ingredients ?? const []);

    bool _nameExistsEverywhere(String nm) {
      final n = nm.trim().toLowerCase();
      for (final e in subBox.toMap().entries) {
        if (key != null && e.key == key) continue;
        if (e.value.name.trim().toLowerCase() == n) return true;
      }
      for (final r in recBox.values) {
        if (r.name.trim().toLowerCase() == n) return true;
      }
      return false;
    }

    String? nameError;

    Future<void> addRow() async {
      if (ingBox.isEmpty) {
        _showBar(context, 'Сначала добавьте ингредиенты в разделе «Ингредиенты».');
        return;
      }

      // Выбор ингредиента — из нижнего списка с поиском
      final selectedKey = await _pickIngredient(context);
      if (selectedKey == null) return;

      // Количество — отдельным диалогом, по умолчанию пусто
      final qtyC = TextEditingController(text: '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Количество'),
          content: TextField(
            controller: qtyC,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
              hintText: 'Например, 250',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Добавить')),
          ],
        ),
      );

      if (ok == true) {
        final qRaw = double.tryParse(qtyC.text.replaceAll(',', '.')) ?? 0;
        if (qRaw <= 0) return;
        final unitSel = ingBox.get(selectedKey)?.unit ?? '';
        final q = unitSel == 'шт' ? _roundToHalf(qRaw) : qRaw;
        items.add(SubrecipeIngredient(ingredientKey: selectedKey, quantity: q));
      }
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stateCtx, setSt) => AlertDialog(
            title: Text(initial == null ? 'Новый субрецепт' : 'Редактировать субрецепт'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameC,
                    onChanged: (_) => setSt(() => nameError = null),
                    decoration: InputDecoration(
                      hintText: 'Название',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text('Ингредиенты ещё не добавлены')
                  else
                    Column(
                      children: [
                        const Divider(),
                        ...List.generate(items.length, (i) {
                          final it = items[i];
                          final ing = ingBox.get(it.ingredientKey);
                          final unit = ing?.unit ?? '';
                          final controller = TextEditingController(
                            text: _formatQtyForUnit(it.quantity, unit),
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 8,
                                  child: _IngredientSelectorField(
                                    selectedKey: it.ingredientKey,
                                    onTap: () async {
                                      final v = await _pickIngredient(context, selected: it.ingredientKey);
                                      if (v == null) return;
                                      items[i] = SubrecipeIngredient(
                                        ingredientKey: v,
                                        quantity: it.quantity,
                                      );
                                      setSt(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      TextField(
                                        controller: controller,
                                        onChanged: (t) {
                                          final qRaw = double.tryParse(t.replaceAll(',', '.')) ?? it.quantity;
                                          final q = unit == 'шт' ? _roundToHalf(qRaw) : qRaw;
                                          items[i] = SubrecipeIngredient(
                                            ingredientKey: it.ingredientKey,
                                            quantity: q,
                                          );
                                        },
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        ),
                                      ),
                                      if (unit.isNotEmpty)
                                        Positioned(
                                          right: 12,
                                          bottom: -9,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surface,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: const [
                                                BoxShadow(color: Colors.black12, blurRadius: 3)
                                              ],
                                            ),
                                            child: Text(
                                              unit,
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.outline,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: 'Удалить',
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        content: const Text('Удалить ингредиент из субрецепта?'),
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
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  visualDensity:
                                      const VisualDensity(horizontal: -4, vertical: -4),
                                  constraints:
                                      const BoxConstraints.tightFor(width: 36, height: 36),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await addRow();
                        setSt(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить ингредиент'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () {
                  FocusScope.of(dialogCtx).unfocus();

                  final nm = nameC.text.trim();
                  final nameChanged = initial == null
                      ? true
                      : nm.toLowerCase() != initial!.name.trim().toLowerCase();

                  if (nm.isEmpty) {
                    setSt(() => nameError = 'Введите название');
                    HapticFeedback.lightImpact();
                    return;
                  }
                  if (nameChanged && _nameExistsEverywhere(nm)) {
                    setSt(() => nameError = 'Такое название уже используется');
                    HapticFeedback.lightImpact();
                    return;
                  }

                  // Если создаём новую запись — проверяем лимит бесплатной версии
                  if (key == null && !FreeTier.canAddSubrecipe()) {
                    FreeTier.showLockedDialog(
                      context,
                      message:
                          'В бесплатной версии можно создать до ${FreeTier.maxSubrecipes} субрецептов. '
                          'Подписка снимет ограничение.',
                    );
                    return;
                  }

                  final sr = Subrecipe(name: nm, ingredients: items);
                  if (key == null) {
                    prov.add(sr);
                  } else {
                    prov.updateByKey(key, sr);
                  }
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _pickIngredient(BuildContext context, {int? selected}) async {
    final box = Hive.box<Ingredient>('ingredients');
    final all = box.toMap().cast<int, Ingredient>().entries.toList()
      ..sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));

    String q = '';

    return await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, setSt) {
          final filtered = q.isEmpty
              ? all
              : all.where((e) => e.value.name.toLowerCase().contains(q.toLowerCase())).toList();
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx2).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Поиск ингредиента',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setSt(() => q = v.trim()),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final isSel = e.key == selected;
                        return ListTile(
                          title: Text(e.value.name),
                          trailing: isSel ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.pop(sheetCtx2, e.key),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== HELP (как на экране «Ингредиенты») =====
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
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ВСПОМОГАТЕЛЬНОЕ =====

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

class _IngredientSelectorField extends StatelessWidget {
  const _IngredientSelectorField({
    required this.selectedKey,
    required this.onTap,
    this.hint,
    super.key,
  });

  final int? selectedKey;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Ingredient>('ingredients');
    final ing = selectedKey == null ? null : box.get(selectedKey!);

    final textStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ing?.name ?? (hint ?? 'Выбрать ингредиент'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

String _formatQtyForUnit(double qty, String unit) {
  if (unit == 'шт') {
    final r = _roundToHalf(qty);
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toStringAsFixed(1);
  }
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  return qty.toStringAsFixed(2);
}

double _roundToHalf(double v) => (v * 2).round() / 2.0;

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

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
              Text('Субрецептов пока нет', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Нажмите «+», чтобы создать первый субрецепт'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  final String q;
  const _NothingFound({required this.q});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Ничего не найдено по запросу «$q»',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

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
