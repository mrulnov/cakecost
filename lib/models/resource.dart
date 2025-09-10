import 'package:hive/hive.dart';

part 'resource.g.dart';

/// Ресурсы для расчёта времени и коммуналки.
/// По ТЗ в рецепте:
///  - стоимость времени: timeHours * (salary / 160)
///  - коммуналка: (utilities * 12 / 8760) * timeHours
@HiveType(typeId: 4)
class Resource extends HiveObject {
  /// Ежемесячные коммунальные платежи (₽/месяц)
  @HiveField(0)
  double utilities;

  /// Ежемесячная зарплата (₽/месяц), из неё считаем часовую ставку = salary/160
  @HiveField(1)
  double salary;

  Resource({
    required this.utilities,
    required this.salary,
  });

  /// Часовая ставка (₽/час)
  double get hourlyRate => salary <= 0 ? 0 : salary / 160.0;

  /// Стоимость коммуналки за 1 час (₽/час), 8760 часов в году
  double get utilitiesPerHour =>
      utilities <= 0 ? 0 : (utilities * 12.0 / 8760.0);
}
