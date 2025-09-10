// lib/services/free_tier.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../models/subrecipe.dart';

/// Ограничения бесплатной версии и простая заглушка PRO
/// (пока биллинг не подключён — PRO всегда false).
class FreeTier {
  // ---------- публичные лимиты ----------
  static const int maxRecipes = 3;
  static const int maxSubrecipes = 3;

  // ---------- внутреннее хранилище ----------
  static const String _boxName = 'free_tier_meta';
  static const String _kIsPro = 'is_pro_override';      // зарезервировано под будущий биллинг
  static const String _kScaleTrialUsed = 'scale_trial_used';
  static const String _kPdfTrialUsed = 'pdf_trial_used';

  // Кэш (чтобы синхронные проверки работали без async)
  static bool _loaded = false;
  static bool _isProCached = false;
  static bool _scaleTrialUsedCached = false;
  static bool _pdfTrialUsedCached = false;

  /// Ленивая загрузка кэша из Hive
  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final b = Hive.box(_boxName);
    _isProCached = (b.get(_kIsPro) == true);
    _scaleTrialUsedCached = (b.get(_kScaleTrialUsed) == true);
    _pdfTrialUsedCached = (b.get(_kPdfTrialUsed) == true);
    _loaded = true;
  }

  // ===================== PRO-флаг (асинхронно) =====================

  /// PRO-статус (сейчас всегда false, оставлен для совместимости).
  static Future<bool> isPro() async {
    await _ensureLoaded();
    return _isProCached;
  }

  /// Отладочно включить/выключить PRO локально.
  static Future<void> debugSetPro(bool value) async {
    await _ensureLoaded();
    final b = Hive.box(_boxName);
    await b.put(_kIsPro, value);
    _isProCached = value;
  }

  // ===================== Проверки лимитов (синхронно) =====================

  /// Можно ли добавить ещё один рецепт (free: до 3).
  /// Предполагается, что боксы Hive уже открыты в bootstrap.
  static bool canAddRecipe() {
    if (_isProCached) return true;
    final box = Hive.box<Recipe>('recipes');
    return box.length < maxRecipes;
  }

  /// Можно ли добавить ещё один субрецепт (free: до 3).
  static bool canAddSubrecipe() {
    if (_isProCached) return true;
    final box = Hive.box<Subrecipe>('subrecipes');
    return box.length < maxSubrecipes;
  }

  // ===================== Диалог "фича в PRO" =====================

  /// Универсальный диалог-блокировка для бесплатной версии.
  static Future<void> showLockedDialog(
    BuildContext context, {
    String? title,
    required String message,
    String okLabel = 'Понятно',
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title ?? 'Доступно в подписке'),
        content: Text(message),
        actions: [
          if (actionLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onAction != null) onAction();
              },
              child: Text(actionLabel),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  // ===================== Пробные действия =====================

  /// 1) Пересчёт рецепта — разрешён 1 раз в free.
  static Future<bool> canUseScaleTrial() async {
    await _ensureLoaded();
    if (_isProCached) return true;
    return !_scaleTrialUsedCached;
  }

  static Future<void> markScaleTrialUsed() async {
    await _ensureLoaded();
    if (_scaleTrialUsedCached) return;
    final b = Hive.box(_boxName);
    await b.put(_kScaleTrialUsed, true);
    _scaleTrialUsedCached = true;
  }

  /// 2) Экспорт рецепта в PDF — разрешён 1 раз в free (любой из PDF-режимов).
  static Future<bool> canUsePdfTrial() async {
    await _ensureLoaded();
    if (_isProCached) return true;
    return !_pdfTrialUsedCached;
  }

  static Future<void> markPdfTrialUsed() async {
    await _ensureLoaded();
    if (_pdfTrialUsedCached) return;
    final b = Hive.box(_boxName);
    await b.put(_kPdfTrialUsed, true);
    _pdfTrialUsedCached = true;
  }
}
