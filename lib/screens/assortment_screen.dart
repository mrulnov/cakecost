import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/assortment_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/subrecipe_provider.dart';
import '../providers/resource_provider.dart';
import '../models/recipe.dart';

class AssortmentScreen extends StatelessWidget {
  const AssortmentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rProv = context.watch<RecipeProvider>();
    final entries = rProv.entriesSorted();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ассортимент'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌 Ассортимент',
              body: '''
• Здесь отображаются все ваши рецепты, их себестоимость и прибыльность

• Вводите цену продажи и отслеживайте прибыльность рецепта
• Себестоимость складывается из введённых вами данных на предыдущих страницах

На себестоимость влияют:
• «Ингредиенты» и «Упаковка» — их цены и фасовки  
• «Ресурсы» — зарплата и коммуналка 
• Время приготовления (минуты)
''',
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final key = entries[i].key;
          final recipe = entries[i].value;
          return _AssortmentCard(recipeKey: key, recipe: recipe);
        },
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

class _AssortmentCard extends StatefulWidget {
  final int recipeKey;
  final Recipe recipe;

  const _AssortmentCard({
    Key? key,
    required this.recipeKey,
    required this.recipe,
  }) : super(key: key);

  @override
  State<_AssortmentCard> createState() => _AssortmentCardState();
}

class _AssortmentCardState extends State<_AssortmentCard> {
  static const double _cellHeight = 44;

  late final TextEditingController _priceC;
  late final FocusNode _priceF;

  @override
  void initState() {
    super.initState();
    final aProv = context.read<AssortmentProvider>();
    _priceC = TextEditingController(text: _fmt(aProv.priceFor(widget.recipeKey)));
    _priceF = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _AssortmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final aProv = context.read<AssortmentProvider>();
    final now = _fmt(aProv.priceFor(widget.recipeKey));
    if (!_priceF.hasFocus && _priceC.text != now) {
      _priceC.text = now;
    }
  }

  @override
  void dispose() {
    _priceC.dispose();
    _priceF.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      (v == v.roundToDouble()) ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final aProv = context.watch<AssortmentProvider>();
    final rProv = context.read<RecipeProvider>();
    final sProv = context.read<SubrecipeProvider>();
    final resProv = context.read<ResourceProvider>();

    final price = context.select<AssortmentProvider, double>(
      (p) => p.priceFor(widget.recipeKey),
    );

    final fullCost = rProv.costOf(widget.recipe, sProv, resProv);
    final profit = price - fullCost;
    final marginPct = fullCost > 0 ? (profit / fullCost * 100) : 0;

    late final Color badgeColor;
    if (marginPct >= 30) {
      badgeColor = Colors.green;
    } else if (marginPct >= 0) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.red;
    }

    final String badgeText = profit >= 0
        ? 'Прибыль +${profit.toStringAsFixed(2)} ₽ (${marginPct.toStringAsFixed(0)}%)'
        : 'Убыток ${profit.toStringAsFixed(2)} ₽ (${marginPct.toStringAsFixed(0)}%)';

    Widget priceBox(AssortmentProvider prov) => _LabeledBox(
          label: 'Цена продажи, ₽',
          child: SizedBox(
            height: _cellHeight,
            child: TextField(
              controller: _priceC,
              focusNode: _priceF,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (s) {
                final v = double.tryParse(s.replaceAll(',', '.')) ?? 0;
                prov.setPrice(widget.recipeKey, v);
              },
            ),
          ),
        );

    Widget costBox() => _LabeledBox(
          label: 'Себестоимость',
          child: Container(
            constraints: const BoxConstraints(minHeight: _cellHeight),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.25)),
            ),
            child: Text(
              '${fullCost.toStringAsFixed(2)} ₽',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.recipe.name,
            style: Theme.of(context).textTheme.titleMedium,
            softWrap: true,
          ),
        ),
        const SizedBox(height: 2),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: priceBox(aProv)),
                    const SizedBox(width: 12),
                    Expanded(child: costBox()),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    badgeText,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: badgeColor),
                    softWrap: true,
                  ),
                ),
                if (widget.recipe.timeHours > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Учитывает время приготовления: ${(widget.recipe.timeHours * 60).round()} мин',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledBox({
    Key? key,
    required this.label,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
        child,
      ],
    );
  }
}
