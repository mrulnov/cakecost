// lib/screens/settings_help_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Раздельные экраны с RU/EN-переключателем
import 'package:cake_cost/ui/policy/privacy_policy_screen.dart';
import 'package:cake_cost/ui/policy/terms_of_use_screen.dart';

enum _Lang { ru, en }

class SettingsHelpScreen extends StatefulWidget {
  const SettingsHelpScreen({Key? key}) : super(key: key);

  @override
  State<SettingsHelpScreen> createState() => _SettingsHelpScreenState();
}

class _SettingsHelpScreenState extends State<SettingsHelpScreen> {
  PackageInfo? _pkg;

  _Lang _lang = _Lang.ru;
  Future<List<_FaqItem>>? _faqFuture;

  @override
  void initState() {
    super.initState();
    _loadPkg();
    _reloadFaq(); // первая загрузка FAQ
  }

  Future<void> _loadPkg() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _pkg = info);
    } catch (_) {/* no-op */}
  }

  void _reloadFaq() {
    final asset = _lang == _Lang.ru ? 'assets/help/faq_ru.json' : 'assets/help/faq_en.json';
    setState(() {
      _faqFuture = _loadFaq(asset, _lang);
    });
  }

  Future<List<_FaqItem>> _loadFaq(String assetPath, _Lang lang) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((m) => _FaqItem(q: (m['q'] ?? '').toString(), a: (m['a'] ?? '').toString()))
          .where((e) => e.q.isNotEmpty && e.a.isNotEmpty)
          .toList();
    } catch (_) {
      // Фолбэк — короткий набор Q/A
      if (lang == _Lang.ru) {
        return const [
          _FaqItem(q: 'Что входит в бесплатную версию?', a: 'Справочники, ассортимент, резервное копирование. До 3 субрецептов и 3 рецептов, 1 пробный пересчёт и 1 демо-экспорт.'),
          _FaqItem(q: 'Что даёт Pro?', a: 'Безлимит рецептов/субрецептов, экспорт Excel/PDF без водяных знаков, масштабирование без ограничений. Покупка появится в 1.1.'),
        ];
      } else {
        return const [
          _FaqItem(q: 'What is included for free?', a: 'Catalogs, assortment, backups. Up to 3 sub-recipes and 3 recipes, 1 trial scaling and 1 demo export.'),
          _FaqItem(q: 'What does Pro include?', a: 'Unlimited items, Excel/PDF export without watermark, unlimited scaling. Purchases will arrive in v1.1.'),
        ];
      }
    }
  }

  Future<void> _emailSupport() async {
    final subject = Uri.encodeComponent('Cake&Cost — вопрос/обратная связь');
    final body = Uri.encodeComponent('Опишите вопрос/идею здесь:\n\n');
    final uri = Uri.parse('mailto:m.rulnov@yandex.ru?subject=$subject&body=$body');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lang == _Lang.ru ? 'Не удалось открыть почтовый клиент' : 'Failed to open email client')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pkg = _pkg;
    final version = (pkg == null) ? '—' : '${pkg.version} (${pkg.buildNumber})';
    final platform = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : Platform.operatingSystem;

    final isRu = _lang == _Lang.ru;

    return Scaffold(
      appBar: AppBar(title: Text(isRu ? 'Настройки и помощь' : 'Settings & Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- ПОМОЩЬ (FAQ) ----------
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(isRu ? 'Помощь' : 'Help',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      _LanguageToggle(
                        lang: _lang,
                        onChanged: (v) {
                          _lang = v;
                          _reloadFaq();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<List<_FaqItem>>(
                    future: _faqFuture,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final items = snap.data ?? const <_FaqItem>[];
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(isRu ? 'FAQ пока пуст.' : 'FAQ is empty for now.',
                              style: theme.textTheme.bodyMedium),
                        );
                      }
                      return _FaqList(items: items);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- ПОДДЕРЖКА ----------
          Center(
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: _emailSupport,
                  icon: const Icon(Icons.mail_outline),
                  label: Text(isRu ? 'Написать в поддержку' : 'Contact support'),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0.75,
                  child: Text(
                    isRu
                        ? 'Есть вопросы или идея? Напишите нам — мы отвечаем.'
                        : 'Got a question or an idea? Email us — we reply.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- ПОКУПКИ (плейсхолдер) ----------
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRu ? 'Покупки' : 'Purchases',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _soon(context, isRu ? 'Восстановить покупки' : 'Restore purchases'),
                        child: Text(isRu ? 'Восстановить' : 'Restore'),
                      ),
                      OutlinedButton(
                        onPressed: () => _soon(context, isRu ? 'Управлять подпиской' : 'Manage subscription'),
                        child: Text(isRu ? 'Управлять подпиской' : 'Manage'),
                      ),
                      OutlinedButton(
                        onPressed: () => _soon(context, isRu ? 'Скопировать App User ID' : 'Copy App User ID'),
                        child: Text(isRu ? 'Скопировать App User ID' : 'Copy App User ID'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.75,
                    child: Text(
                      isRu
                          ? 'Здесь появится управление покупками после подключения биллинга.'
                          : 'Purchase management will appear here after we add billing.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- О ПРИЛОЖЕНИИ ----------
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRu ? 'О приложении' : 'About the app',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _InfoRow(label: isRu ? 'Версия' : 'Version', value: version),
                  _InfoRow(label: isRu ? 'Платформа' : 'Platform', value: platform),
                  const Divider(height: 20),
                  _NavRow(
                    label: isRu ? 'Политика конфиденциальности' : 'Privacy Policy',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    ),
                  ),
                  _NavRow(
                    label: isRu ? 'Пользовательское соглашение' : 'Terms of Use',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label: ${_lang == _Lang.ru ? "скоро" : "soon"}')),
    );
  }
}

/// ---------- FAQ: модель ----------
class _FaqItem {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  factory _FaqItem.fromJson(Map<String, dynamic> m) =>
      _FaqItem(q: (m['q'] ?? '').toString(), a: (m['a'] ?? '').toString());
}

/// ---------- FAQ: список-аккордеон ----------
class _FaqList extends StatefulWidget {
  final List<_FaqItem> items;
  const _FaqList({required this.items});

  @override
  State<_FaqList> createState() => _FaqListState();
}

class _FaqListState extends State<_FaqList> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionPanelList.radio(
        animationDuration: const Duration(milliseconds: 200),
        expandedHeaderPadding: EdgeInsets.zero,
        elevation: 0,
        children: List.generate(widget.items.length, (i) {
          final it = widget.items[i];
          return ExpansionPanelRadio(
            value: i,
            canTapOnHeader: true,
            headerBuilder: (ctx, isExpanded) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isExpanded ? Icons.expand_circle_down : Icons.help_outline),
                title: Text(it.q, style: theme.textTheme.bodyLarge),
              );
            },
            body: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
                child: Text(
                  it.a,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// ---------- UI helpers ----------
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
