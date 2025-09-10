import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/resource_provider.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ResourceProvider>();
    final r = prov.data;

    final utilC = TextEditingController(
      text: r.utilities == 0 ? '' : _fmt(r.utilities),
    );
    final salC = TextEditingController(
      text: r.salary == 0 ? '' : _fmt(r.salary),
    );

    void showMsg(String m) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ресурсы'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(
              context,
              title: '📌 Ресурсы',
              body: '''
•Ресурсы добавляют к себестоимости честную долю затрат на труд и коммунальные расходы

• Добавляйте данные по средним коммунальным затратам в месяц  
• Добавляйте данные по желаемой зарплате в месяц  

• Можно начать с примерных цифр — потом откорректируете 
• Если не учитывать время в рецепте — часть затрат останется «за кадром»
''',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: utilC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Коммуналка (₽/месяц)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Зарплата (₽/месяц)',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final utilities =
                          double.tryParse(utilC.text.replaceAll(',', '.')) ?? 0;
                      final salary =
                          double.tryParse(salC.text.replaceAll(',', '.')) ?? 0;

                      if (utilities < 0) {
                        showMsg('Коммуналка не может быть отрицательной');
                        return;
                      }
                      if (salary < 0) {
                        showMsg('Зарплата не может быть отрицательной');
                        return;
                      }

                      prov.setBoth(utilities: utilities, salary: salary);
                      showMsg('Сохранено');
                    },
                    child: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// Тот же стиль всплывающего окна, что и на экране «Упаковка».
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
