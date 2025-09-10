import 'package:flutter/material.dart';

enum _Lang { ru, en }

class TermsOfUseScreen extends StatefulWidget {
  const TermsOfUseScreen({super.key});

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> {
  _Lang _lang = _Lang.ru;

  @override
  Widget build(BuildContext context) {
    final isRu = _lang == _Lang.ru;
    return Scaffold(
      appBar: AppBar(
        title: Text(isRu ? 'Пользовательское соглашение' : 'Terms of Use'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LanguageToggle(
              lang: _lang,
              onChanged: (v) => setState(() => _lang = v),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            (isRu ? 'Последнее обновление: ' : 'Last updated: ') +
                (isRu ? '8 сентября 2025' : '8 September 2025'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _SectionTitle(isRu ? '1. Предмет' : '1. Subject'),
          _P(isRu
              ? 'Приложение «Cake&Cost» помогает рассчитывать себестоимость изделий и управлять справочниками ингредиентов, субрецептов и рецептов. Работает офлайн.'
              : 'The “Cake&Cost” app helps calculate product costs and manage ingredient, sub-recipe, and recipe catalogs. It works offline.'),
          _SectionTitle(isRu ? '2. Ответственность и ограничение' : '2. Liability disclaimer'),
          _P(isRu
              ? 'Вы отвечаете за точность вводимой информации и применимость расчётов. Приложение предоставляется «как есть», без гарантий. В пределах, допустимых законом, ответственность разработчика ограничена фактически уплаченной суммой (если применимо).'
              : 'You are responsible for input accuracy and applicability of calculations. The app is provided “as is” without warranties. To the extent permitted by law, developer liability is limited to the amount actually paid (if applicable).'),
          _SectionTitle(isRu ? '3. Данные и резервное копирование' : '3. Data and backups'),
          _P(isRu
              ? 'Все данные хранятся на устройстве пользователя. Рекомендуется регулярно создавать резервные копии (ZIP) и хранить их в надёжном месте.'
              : 'All data is stored on your device. Create regular ZIP backups and keep them in a safe place.'),
          _SectionTitle(isRu ? '4. Ограничения бесплатной версии' : '4. Free version limitations'),
          _P(isRu
              ? 'В бесплатной версии действуют ограничения (например, количество субрецептов/рецептов, экспорт/импорт, масштабирование). Полный доступ будет предоставляться при оформлении подписки в будущих версиях.'
              : 'The free version has limitations (e.g., number of sub-recipes/recipes, export/import, scaling). Full access will be available with a subscription in future versions.'),
          _SectionTitle(isRu ? '5. Изменение условий' : '5. Changes'),
          _P(isRu
              ? 'Условия могут обновляться. Актуальная версия всегда доступна на этой странице.'
              : 'Terms may be updated. The current version is always available on this page.'),
          _SectionTitle(isRu ? '6. Контакты' : '6. Contacts'),
          _P(isRu
              ? 'Поддержка: m.rulnov@yandex.ru'
              : 'Support: m.rulnov@yandex.ru'),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final _Lang lang;
  final ValueChanged<_Lang> onChanged;
  const _LanguageToggle({required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isRu = lang == _Lang.ru;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SegBtn(label: 'RU', active: isRu, onTap: () => onChanged(_Lang.ru)),
          _SegBtn(label: 'EN', active: !isRu, onTap: () => onChanged(_Lang.en)),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? cs.primary : cs.onSurface.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text),
    );
  }
}
