// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

/// Простой провайдер темы (без сохранения на диск).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light; // стартуем со светлой темы
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void setDark(bool value) {
    _mode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
