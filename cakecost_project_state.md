cakecost_project_state.md
0) Паспорт проекта
•	Название: Cake&Cost
•	Платформа: Flutter (Android, релиз в RuStore)
•	Хранилище данных: Hive (локально)
•	Экспорт: PDF (package:pdf), Excel (Syncfusion XlsIO)
•	Поддержка: m.rulnov@yandex.ru
•	Языки UI: RU / EN переключатель на экранах с документами и FAQ
•	ID приложения (package name): ru.cakecost.app (плейсхолдер — уточнить)
________________________________________
1) Текущее состояние (реализовано)
1.1 Дом
•	Бесконечная карусель разделов, прелоад сплэш, фоновые изображения предпрекешены.
1.2 Модули данных
•	Ингредиенты / Упаковка / Субрецепты / Рецепты / Ассортимент / Ресурсы
o	CRUD, поиск по названию и компонентам, дублирование позиции (📄📄).
o	Время в рецепте — в минутах (хранится в часах).
1.3 Экспорт/Импорт
•	PDF (полный / короткий) — готово.
o	Округление количеств в PDF:
	г, мл → до целых;
	шт → шаг 0.5;
	прочее → как раньше.
•	Excel (всё / один рецепт) — через Syncfusion XlsIO.
o	Исправлено: нет пустого листа; переход с excel на syncfusion_flutter_xlsio.
o	«Все данные» создаёт 6 листов: Ингредиенты, Упаковка, Субрецепты, Рецепты, Ассортимент, Ресурсы.
•	Импорт (XLSX/XLS): поддержка листов ingredients / packaging, валидации ед. изм.
1.4 Пересчёт форм (ScaleScreen)
•	Фигуры: круг / квадрат / прямоугольник; опция «учитывать высоту изделия».
•	Масштабирует ингредиенты и субрецепты, но не упаковку.
•	Сохраняет новый рецепт с пометкой размеров (пример: Торт (Ø20см)).
1.5 Настройки/Поддержка/FAQ/Документы
•	Почта поддержки: m.rulnov@yandex.ru во всех местах (в кнопке подставляется в письмо).
•	Политика и Пользовательское соглашение — разные экраны, каждый с RU/EN-переключателем.
•	FAQ — единый экран с RU/EN-переключателем.
•	Исправлено: показ всех вопросов (не обрезается последним пунктом).
1.6 Ограничения бесплатной версии (в коде через FreeTier)
•	Лимиты:
o	Рецепты: до 3
o	Субрецепты: до 3
•	Триалы функций:
o	PDF-экспорт — 1 бесплатная попытка (любой из PDF-вариантов суммарно).
o	Пересчёт форм — 1 бесплатная попытка (с сохранением нового рецепта).
•	Только PRO:
o	Экспорт Excel (всё и один рецепт),
o	Импорт из Excel.
•	Поведение UI:
o	При попытке превысить лимит — диалог с предложением PRO.
o	Если доступен trial (PDF/пересчёт) — показывается диалог: «Использовать пробу?»; при согласии — фиксируем расход триала.
o	После покупки PRO — всё снимается без перезапуска (статус тянется из PurchaseService.isPro()).
(Примечание: на экране Пересчёта теперь проверяем лимит ДО сохранения, чтобы в free нельзя получить «четвёртый рецепт». Триал пересчёта даёт 1 сохранение, но не отменяет общий лимит 3 — если место занято, попросим удалить или купить PRO.)
1.7 Исправления багов
•	Убраны ошибки Excel: Unsupported operation: Cannot remove from an unmodifiable list.
•	Исправлен дублирующийся DropdownButtonFormField.value на экране Пересчёта (не выставляем несуществующее значение).
•	Обход несовместимости символа ₽ в PDF — используем руб..
________________________________________
2) Что осталось сделать до релиза в RuStore
2.1 Платёжка (RuStore Billing SDK)
•	Реализуем PurchaseService (Dart) + платформенные каналы (Kotlin):
o	Future<bool> isPro() — проверка entitlement (кешируем в Hive).
o	Future<bool> purchasePro() — запуск покупки.
o	Future<bool> restore() — восстановление.
•	Связка: FreeTier.isPro() → PurchaseService.isPro().
•	Обновить UI «Подписка»: преимущества, цена/период, кнопки «Купить»/«Восстановить», ссылки на Политику/Соглашение.
2.2 Документы для магазина
•	Опубликовать два URL (RU и EN) для:
o	Политика конфиденциальности
o	Пользовательское соглашение
•	Добавить эти URL и контакт поддержки в карточку приложения RuStore.
2.3 Сборка и публикация
•	Подготовить подписанный APK/AAB (как требует RuStore на момент релиза).
•	Заполнить карточку, возрастной рейтинг, Данные и безопасность, скриншоты/иконки.
•	Пройти модерацию.
2.4 (Опционально) Краши/аналитика
•	Crashlytics (работает без Google Play) / Sentry.
________________________________________
3) Технические заметки и контракты
3.1 Статусы PRO и кэш
•	На старте: спрашиваем PurchaseService.isPro(), сохраняем флаг в Hive, вызываем notifyListeners() чтобы снять блокировки.
•	При успешной покупке/восстановлении — сразу переключаем isPro = true.
3.2 Интерфейсы оплаты (Dart)
// lib/services/purchase_service.dart
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class PurchaseService {
  static const _ch = MethodChannel('ru.rustore.billing');

  static Future<bool> isPro() async {
    final box = await Hive.openBox('meta');
    final cached = box.get('isPro') as bool?;
    try {
      final res = await _ch.invokeMethod<bool>('isPro') ?? cached ?? false;
      await box.put('isPro', res);
      return res;
    } catch (_) {
      return cached ?? false;
    }
  }

  static Future<bool> purchasePro() async {
    try {
      final ok = await _ch.invokeMethod<bool>('purchasePro') ?? false;
      if (ok) (await Hive.openBox('meta')).put('isPro', true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restore() async {
    try {
      final ok = await _ch.invokeMethod<bool>('restore') ?? false;
      if (ok) (await Hive.openBox('meta')).put('isPro', true);
      return ok;
    } catch (_) {
      return false;
    }
  }
}
3.3 Канал оплаты (Kotlin — скелет)
// android/app/src/main/kotlin/ru/cakecost/app/BillingChannel.kt
package ru.cakecost.app

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BillingChannel: FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "ru.rustore.billing")
    channel.setMethodCallHandler(this)
    // TODO: init RuStore Billing client
  }
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isPro" -> { /* TODO: query purchases */ result.success(false) }
      "purchasePro" -> { /* TODO: launch purchase flow */ result.success(false) }
      "restore" -> { /* TODO: restore purchases */ result.success(false) }
      else -> result.notImplemented()
    }
  }
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
Подключение RuStore Billing SDK, конфиг, тестовые покупки — сделаем в следующем спринте.
3.4 FreeTier — действующие константы
•	maxRecipes = 3
•	maxSubrecipes = 3
•	trialPdf = 1
•	trialScale = 1
•	Excel/Import — только PRO.
(Логика отображения диалогов «закрыто/проба/купить» уже подключена в экранах: Recipes, Subrecipes, Scale, Export/Import.)
________________________________________
4) QA-чек-лист перед релизом
Free-лимиты
•	 Создать 3 рецепта, 3 субрецепта — ок.
•	 Попытка создать 4-й — диалог блокировки с предложением PRO.
•	 Удалить один — снова можно создать.
Триалы
•	 PDF: при первом экспорте — диалог «Использовать пробу?», PDF создаётся; второй раз — просит PRO.
•	 Пересчёт: один успешный «Сохранить как новый рецепт» — второй требует PRO.
•	 Триалы не обходят лимит 3 — если рецептов уже 3, пересчёт предложит купить PRO/удалить.
PRO (эмулировать isPro=true)
•	 Все блокировки сняты: Excel/Import, любые количества рецептов/субрецептов, без триальных диалогов.
Экспорт
•	 PDF округление по правилам (г/мл целые, шт шаг 0.5).
•	 Excel без пустых листов, все разделы заполняются, автоподбор ширины колонок.
UI/UX
•	 Кнопка «Написать в поддержку» везде открывает m.rulnov@yandex.ru.
•	 Политика и Соглашение — разные экраны, RU/EN переключатели работают.
•	 FAQ — показ всех вопросов, RU/EN переключатель.
________________________________________
5) Публикация в RuStore — чек-лист
Консоль RuStore
•	 Создать приложение, указать пакет (applicationId) и подпись (keystore).
•	 Заполнить карточку (RU), скриншоты, иконки, промо.
•	 Политика/Соглашение URL (RU/EN), контакт поддержки (m.rulnov@yandex.ru).
•	 Возрастной рейтинг, данные и безопасность.
•	 Настроить товары: PRO (подписка или разовая покупка) — финализировать модель.
Сборка
•	 Обновить versionName, versionCode.
•	 Выпустить подписанный APK/AAB.
•	 Загрузить артефакт в RuStore Console, пройти проверки/модерацию.
________________________________________
6) Дальнейший план (2 спринта)
Спринт 1: Платежи
1.	Подключить RuStore Billing SDK (Gradle, разрешения).
2.	Реализовать Kotlin-клиент, проверить ручейки покупок.
3.	Dart-обёртка PurchaseService, интеграция с FreeTier.isPro().
4.	Экран «Подписка» (RU/EN), навигация из диалогов блокировок.
5.	QA на реальных тестовых покупках RuStore.
Спринт 2: Релиз
1.	Финализация текстов/скриншотов/иконок.
2.	Политика/Соглашение — разместить и вставить URL.
3.	Сборка, подпись, загрузка в RuStore, модерация.
4.	Мониторинг крэшей/отзывов, минорный апдейт.
________________________________________

