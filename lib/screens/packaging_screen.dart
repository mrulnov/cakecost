import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/packaging.dart';
import '../providers/packaging_provider.dart';

class PackagingScreen extends StatefulWidget {
  const PackagingScreen({super.key});

  @override
  State<PackagingScreen> createState() => _PackagingScreenState();
}

class _PackagingScreenState extends State<PackagingScreen> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PackagingProvider>();
    final all = prov.entriesSorted();

    final q = _searchC.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((e) => e.value.name.toLowerCase().contains(q)).toList();

    final showEmptyAll = all.isEmpty;
    final showEmptyFiltered = all.isNotEmpty && filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Упаковка'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌 Упаковка',
              body: '''
• Сохраняйте используемую упаковку: 
  коробки, подложки, капсулы, ленты и т.п.
  
• Кнопка «+» для добавления новой позиции
• Нажмите на карточку, чтобы внести изменения
• Смахните карточку влево, чтобы удалить

• Указывайте название, 
  цену за упаковку, 
  количество в упаковке (шт/см)
  
• 1 метр = 100 сантиметров 
  (используйте для лент, тесьмы и т.п.)
  
• Добавляйте упаковку в рецептах, 
  чтобы учесть её цену в себестоимости 
  кондитерских изделий
''',
            ),
          ),
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
                hintText: 'Поиск упаковки...',
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
                  final key = filtered[i].key;
                  final p = filtered[i].value;
                  return Dismissible(
                    key: ValueKey('pkg_$key'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить позицию упаковки?'),
                          content: Text('«${p.name}» будет удалена.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            OutlinedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (ok == true) await context.read<PackagingProvider>().deleteByKey(key);
                      return ok ?? false;
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.25)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: DefaultTextStyle(
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(color: Theme.of(context).hintColor),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Цена без хвостовых нулей (фасовка оставляем как было)
                                Text('фасовка: ${_qtyStr(p.quantity)} ${p.unit} • цена: ${_trimZeros(p.price)} ₽'),
                                // За единицу — по-прежнему с двумя знаками
                                Text('за 1 ${p.unit} ≈ ${p.unitCost.toStringAsFixed(2)} ₽'),
                              ],
                            ),
                          ),
                        ),
                        onTap: () => _editDialog(context, key: key, initial: p),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _qtyStr(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  // Убираем хвостовые нули у чисел (12.00 -> 12, 12.50 -> 12.5)
  String _trimZeros(num v) {
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _editDialog(BuildContext context, {int? key, Packaging? initial}) async {
    final prov = context.read<PackagingProvider>();

    final isNew  = initial == null;
    final nameC  = TextEditingController(text: initial?.name ?? '');
    // В редакторе — цена и количество без хвостовых нулей
    final priceC = TextEditingController(text: isNew ? '' : _trimZeros(initial!.price));
    final qtyC   = TextEditingController(text: isNew ? '' : _trimZeros(initial!.quantity));
    String unit  = initial?.unit ?? 'шт';

    final nameFN  = FocusNode();
    final priceFN = FocusNode();
    final qtyFN   = FocusNode();

    var priceSelectAll = true;
    var qtySelectAll   = true;

    String? nameError, priceError, qtyError;
    double _parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? double.nan;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(key == null ? 'Новая упаковка' : 'Редактировать упаковку'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    focusNode: nameFN,
                    autofocus: isNew, // фокус сразу на названии
                    decoration: InputDecoration(
                      labelText: 'Название',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setSt(() => nameError = null),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceC,
                          focusNode: priceFN,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => qtyFN.requestFocus(),
                          onTap: () {
                            if (priceSelectAll) {
                              priceSelectAll = false;
                              priceC.selection = TextSelection(baseOffset: 0, extentOffset: priceC.text.length);
                            }
                          },
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          decoration: InputDecoration(
                            labelText: 'Цена, ₽',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            hintText: '0',
                            errorText: priceError,
                          ),
                          onChanged: (_) => setSt(() => priceError = null),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: unit,
                          items: const [
                            DropdownMenuItem(value: 'шт', child: Text('шт')),
                            DropdownMenuItem(value: 'см', child: Text('см')),
                          ],
                          onChanged: (v) => setSt(() => unit = v ?? unit),
                          decoration: const InputDecoration(
                            labelText: 'Ед.',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyC,
                    focusNode: qtyFN,
                    textInputAction: TextInputAction.done,
                    onTap: () {
                      if (qtySelectAll) {
                        qtySelectAll = false;
                        qtyC.selection = TextSelection(baseOffset: 0, extentOffset: qtyC.text.length);
                      }
                    },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(
                      labelText: 'Количество, $unit',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: '0',
                      errorText: qtyError,
                    ),
                    onChanged: (_) => setSt(() => qtyError = null),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(ctx).unfocus();

                final nm = nameC.text.trim();
                final pr = _parse(priceC.text);
                final qv = _parse(qtyC.text);

                if (nm.isEmpty) { setSt(() => nameError = 'Введите название'); HapticFeedback.lightImpact(); return; }
                if (prov.existsByName(nm, exceptKey: key)) { setSt(() => nameError = 'Такое имя уже есть'); HapticFeedback.lightImpact(); return; }
                if (pr.isNaN || pr < 0) { setSt(() => priceError = 'Некорректная цена'); HapticFeedback.lightImpact(); return; }
                if (qv.isNaN || qv <= 0) { setSt(() => qtyError = 'Некорректное количество'); HapticFeedback.lightImpact(); return; }

                final p = Packaging(name: nm, price: pr, quantity: qv, unit: unit);
                if (key == null) {
                  await prov.add(p);
                } else {
                  await prov.updateByKey(key, p);
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
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
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(999))),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text('Упаковки пока нет', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Нажмите «+», чтобы добавить первую позицию'),
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
