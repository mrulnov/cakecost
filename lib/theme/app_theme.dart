import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF8A4F3B); // тёплый коричневый
  static const Color _bg   = Color(0xFFF4EAE3); // кремовый фон

  static ThemeData get lightTheme {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      background: _bg,
      surface: Colors.white,
    );

    const radius = 16.0;
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _bg,
      fontFamily: 'NotoSans',

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: cs.background.withOpacity(0.9),
        foregroundColor: cs.onBackground,
        titleTextStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),

      // Карточки
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: rounded,
        clipBehavior: Clip.antiAlias,
      ),

      // ListTile — именно здесь делаем заголовки «чуть жирнее и выразительнее»
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSans',
          color: cs.onSurface,
          fontWeight: FontWeight.w700,   // жирнее
          fontSize: 17,                  // немного крупнее
          height: 1.1,
          letterSpacing: 0.2,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'NotoSans',
          color: cs.onSurface.withOpacity(0.72),
          fontSize: 14.5,
          height: 1.15,
        ),
        iconColor: cs.onSurface.withOpacity(0.80),
      ),

      // Кнопки
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withOpacity(0.35), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: rounded,
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.45)),
      ),

      // Диалоги
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          fontFamily: 'NotoSans',
        ),
        contentTextStyle: TextStyle(
          color: cs.onSurface.withOpacity(0.9),
          fontFamily: 'NotoSans',
          fontSize: 16,
        ),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant.withOpacity(0.35)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Базовые тексты
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        bodyMedium: TextStyle(fontSize: 16),
      ),
    );
  }
}
