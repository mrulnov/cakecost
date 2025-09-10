import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/recipe_item.dart';
import '../providers/recipe_provider.dart';
import '../services/free_tier.dart';
import 'recipes_screen.dart';

enum _Shape { circle, rectangle, square }

String _shapeTitle(_Shape s) {
  switch (s) {
    case _Shape.circle:
      return 'Круг';
    case _Shape.rectangle:
      return 'Прямоугольник';
    case _Shape.square:
      return 'Квадрат';
  }
}

double _parseNum(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

class _FormDims {
  final _Shape shape;
  final double a; // диаметр (круг) или сторона A
  final double b; // сторона B (для прямоугольника)
  final double h; // высота/толщина

  const _FormDims({
    required this.shape,
    required this.a,
    required this.b,
    required this.h,
  });

  double area() {
    switch (shape) {
      case _Shape.circle:
        final r = a / 2.0;
        return math.pi * r * r;
      case _Shape.rectangle:
        return a * b;
      case _Shape.square:
        return a * a;
    }
  }

  double volume(bool includeHeight) => includeHeight ? area() * (h <= 0 ? 1.0 : h) : area();

  String shortLabelCm() {
    switch (shape) {
      case _Shape.circle:
        return 'Ø${_trim(a)}см';
      case _Shape.rectangle:
        return '${_trim(a)}×${_trim(b)}см';
      case _Shape.square:
        return '${_trim(a)}×${_trim(a)}см';
    }
  }

  String _trim(double v) => (v == v.roundToDouble()) ? v.toInt().toString() : v.toStringAsFixed(1);
}

class ScaleScreen extends StatefulWidget {
  const ScaleScreen({Key? key}) : super(key: key);

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  int? _recipeKey;

  _Shape _fromShape = _Shape.circle;
  _Shape _toShape = _Shape.circle;

  final _fromA = TextEditingController(text: '');
  final _fromB = TextEditingController(text: '');
  final _fromH = TextEditingController(text: '');

  final _toA = TextEditingController(text: '');
  final _toB = TextEditingController(text: '');
  final _toH = TextEditingController(text: '');

  bool _useHeight = false;

  @override
  void dispose() {
    _fromA.dispose();
    _fromB.dispose();
    _fromH.dispose();
    _toA.dispose();
    _toB.dispose();
    _toH.dispose();
    super.dispose();
  }

  _FormDims _readFrom() => _FormDims(
        shape: _fromShape,
        a: _parseNum(_fromA.text),
        b: _fromShape == _Shape.rectangle ? _parseNum(_fromB.text) : 0,
        h: _parseNum(_fromH.text),
      );

  _FormDims _readTo() => _FormDims(
        shape: _toShape,
        a: _parseNum(_toA.text),
        b: _toShape == _Shape.rectangle ? _parseNum(_toB.text) : 0,
        h: _parseNum(_toH.text),
      );

  double _calcK() {
    final fv = _readFrom().volume(_useHeight);
    final tv = _readTo().volume(_useHeight);
    if (fv <= 0 || tv <= 0) return 0;
    return tv / fv;
  }

  void _putExamplesFor(_Shape s, TextEditingController a, TextEditingController b) {
    if (a.text.isEmpty) {
      a.text = '20';
    }
    if (s == _Shape.rectangle && b.text.isEmpty) {
      b.text = '30';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rProv = context.watch<RecipeProvider>();
    final entries = rProv.entriesSorted();

    // === FIX: формируем список без дублей и валидируем выбранное значение ===
    final seenKeys = <int>{};
    final ddItems = <DropdownMenuItem<int>>[];
    for (final e in entries) {
      if (seenKeys.add(e.key)) {
        ddItems.add(
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );
      }
    }
    final int? safeRecipeKey =
        (_recipeKey != null && ddItems.any((it) => it.value == _recipeKey)) ? _recipeKey : null;
    // ======================================================================

    final k = _calcK();
    final kStr = k <= 0 ? '—' : k.toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пересчёт рецепта'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌Пересчёт рецепта',
              body: '''
• Пересчитывайте любой рецепт на формы с другими размерами:
  *Выберите исходный рецепт
  *Укажите «исходную форму» и её размеры (в см)
  *Укажите «новую форму» и её размеры
  *По желанию включите «учитывать высоту изделия» — тогда масштаб учитывает объём
  
• Коэффициент показывает, во сколько раз менять количество составляющих рецепта
• При сохранении создастся новый рецепт с пересчитанными составляющими

• Упаковка не масштабируется — редактируйте её на странице «Рецепты»

• Бесплатная версия: 1 пробное сохранение результата пересчёта; общий лимит рецептов — ${FreeTier.maxRecipes}.
''',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _section(
            context,
            title: 'Рецепт',
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              value: safeRecipeKey, // используем безопасное значение
              items: ddItems,       // список без дублей
              onChanged: (v) => setState(() => _recipeKey = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Выберите рецепт',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            context,
            title: null,
            dense: true,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              title: Text('учитывать высоту изделия', style: Theme.of(context).textTheme.bodySmall),
              value: _useHeight,
              onChanged: (v) => setState(() => _useHeight = v),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            context,
            title: 'Исходная форма',
            child: _formEditor(
              shape: _fromShape,
              onShapeChanged: (s) => setState(() {
                _fromShape = s;
                _putExamplesFor(s, _fromA, _fromB);
              }),
              aCtrl: _fromA,
              bCtrl: _fromB,
              hCtrl: _fromH,
              useHeight: _useHeight,
            ),
          ),
          const SizedBox(height: 12),
          _section(
            context,
            title: 'Новая форма',
            child: _formEditor(
              shape: _toShape,
              onShapeChanged: (s) => setState(() {
                _toShape = s;
                _putExamplesFor(s, _toA, _toB);
              }),
              aCtrl: _toA,
              bCtrl: _toB,
              hCtrl: _toH,
              useHeight: _useHeight,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text('Коэффициент пересчёта', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(kStr, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: (k <= 0 || safeRecipeKey == null)
                ? null
                : () async {
                    final rProv = context.read<RecipeProvider>();
                    final base = rProv.getByKey(safeRecipeKey!);
                    if (base == null) return;

                    final isPro = await FreeTier.isPro();

                    if (!isPro) {
                      final okTrial = await FreeTier.canUseScaleTrial();
                      if (!okTrial) {
                        await FreeTier.showLockedDialog(
                          context,
                          message:
                              'Пересчёт рецепта с сохранением в бесплатной версии доступен один раз. Оформите подписку, чтобы пользоваться без ограничений.',
                        );
                        return;
                      }

                      if (!FreeTier.canAddRecipe()) {
                        await FreeTier.showLockedDialog(
                          context,
                          message:
                              'В бесплатной версии можно хранить до ${FreeTier.maxRecipes} рецептов. '
                              'Удалите один из существующих или оформите подписку.',
                          actionLabel: 'Открыть «Рецепты»',
                          onAction: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RecipesScreen()),
                            );
                          },
                        );
                        return;
                      }
                    }

                    // Пересчёт
                    final to = _readTo();
                    final newItems = <RecipeItem>[];

                    for (final it in base.items) {
                      final q = it.quantity;
                      final double newQ = (it.kind == RecipeItemKind.packaging) ? q : q * k;
                      newItems.add(RecipeItem(kind: it.kind, refKey: it.refKey, quantity: newQ));
                    }

                    final newName = '${base.name} (${to.shortLabelCm()})';
                    final newRec = Recipe(
                      name: newName,
                      items: newItems,
                      timeHours: base.timeHours,
                    );

                    await rProv.add(newRec);

                    if (!isPro) {
                      await FreeTier.markScaleTrialUsed();
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Сохранено: $newName')));
                  },
            icon: const Icon(Icons.save),
            label: const Text('Сохранить как новый рецепт'),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, {String? title, required Widget child, bool dense = false}) {
    final hasTitle = (title != null && title.isNotEmpty);
    return Container(
      padding: EdgeInsets.all(dense ? 10 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: hasTitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: dense ? 6 : 10),
                  child: Text(
                    title!,
                    style: dense ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                child,
              ],
            )
          : child,
    );
  }

  Widget _formEditor({
    required _Shape shape,
    required ValueChanged<_Shape> onShapeChanged,
    required TextEditingController aCtrl,
    required TextEditingController bCtrl,
    required TextEditingController hCtrl,
    required bool useHeight,
  }) {
    final numFormatter = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<_Shape>(
          isExpanded: true,
          value: shape,
          items: [
            for (final s in _Shape.values) DropdownMenuItem(value: s, child: Text(_shapeTitle(s))),
          ],
          onChanged: (s) {
            if (s != null) onShapeChanged(s);
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        if (shape == _Shape.circle) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: aCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numFormatter,
                  decoration: const InputDecoration(
                    labelText: 'Диаметр, см',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              if (useHeight)
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numFormatter,
                    decoration: const InputDecoration(
                      labelText: 'Высота, см',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
            ],
          ),
        ] else if (shape == _Shape.square) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: aCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numFormatter,
                  decoration: const InputDecoration(
                    labelText: 'Сторона, см',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              if (useHeight)
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numFormatter,
                    decoration: const InputDecoration(
                      labelText: 'Высота, см',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: aCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numFormatter,
                  decoration: const InputDecoration(
                    labelText: 'Сторона A, см',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: bCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numFormatter,
                  decoration: const InputDecoration(
                    labelText: 'Сторона B, см',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (useHeight)
            TextField(
              controller: hCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numFormatter,
              decoration: const InputDecoration(
                labelText: 'Высота, см',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
      ],
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
