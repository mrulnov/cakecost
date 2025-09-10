import 'package:flutter/material.dart';

enum _Lang { ru, en }

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  _Lang _lang = _Lang.ru;

  @override
  Widget build(BuildContext context) {
    final isRu = _lang == _Lang.ru;
    return Scaffold(
      appBar: AppBar(
        title: Text(isRu ? 'Политика конфиденциальности' : 'Privacy Policy'),
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
          _SectionTitle(isRu ? 'Кто мы' : 'Who we are'),
          _P(isRu
              ? '«Cake&Cost» — офлайн-приложение для расчёта себестоимости выпечки. Регистрация не требуется.'
              : '“Cake&Cost” is an offline app for calculating baking costs. No registration is required.'),
          _SectionTitle(isRu ? 'Какие данные мы обрабатываем' : 'What data we process'),
          _P(isRu
              ? '• Данные справочников и расчётов (ингредиенты, упаковка, ресурсы, субрецепты, рецепты, настройки) хранятся локально на вашем устройстве.\n'
                '• Приложение не передаёт данные на наши или сторонние серверы.'
              : '• Your catalog and calculation data (ingredients, packaging, resources, sub-recipes, recipes, settings) are stored locally on your device.\n'
                '• The app does not send data to our or third-party servers.'),
          _SectionTitle(isRu ? 'Доступы и разрешения' : 'Access and permissions'),
          _P(isRu
              ? 'Доступ к файлам выполняется через системные диалоги Android (SAF) при экспорте/импорте и резервном копировании. Постоянного доступа к памяти устройства приложение не имеет.'
              : 'File access is performed via Android system dialogs (SAF) for export/import and backups. The app has no permanent access to device storage.'),
          _SectionTitle(isRu ? 'Передача данных третьим лицам' : 'Sharing with third parties'),
          _P(isRu ? 'Не осуществляется.' : 'Not performed.'),
          _SectionTitle(isRu ? 'Хранение и безопасность' : 'Storage and security'),
          _P(isRu
              ? 'Данные остаются на устройстве. Рекомендуем регулярно создавать ZIP-резервную копию и хранить её в надёжном месте.'
              : 'Your data stays on the device. We recommend creating ZIP backups regularly and storing them safely.'),
          _SectionTitle(isRu ? 'Контакты' : 'Contacts'),
          _P(isRu
              ? 'По вопросам приватности: m.rulnov@yandex.ru'
              : 'Privacy contact: m.rulnov@yandex.ru'),
          const Divider(height: 24),
          _SectionTitle(isRu ? 'Важно' : 'Important'),
          _P(isRu
              ? 'Если в будущих версиях появятся функции, требующие сети (например, подписка), мы обновим этот документ и раздел о разрешениях.'
              : 'If future versions require network features (e.g., subscriptions), we will update this document and the permissions section.'),
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
