import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF2D5A27);
  static const Color primaryDark = Color(0xFF1A3A18);
  static const Color primaryLight = Color(0xFF3D7A35);
  static const Color gold = Color(0xFFD4A847);
  static const Color goldLight = Color(0xFFE8C97A);

  // Light theme surfaces
  static const Color bgLight = Color(0xFFF7F4EF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFEDE8E0);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color dividerLight = Color(0xFFE8E3D8);

  // Dark theme surfaces
  static const Color bgDark = Color(0xFF0F1A0E);
  static const Color cardDark = Color(0xFF1A2E19);
  static const Color surfaceDark = Color(0xFF243222);
  static const Color textPrimaryDark = Color(0xFFF0EDE8);
  static const Color textSecondaryDark = Color(0xFFAAAAAA);
  static const Color dividerDark = Color(0xFF2D3E2C);

  // Semantic
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}

// ─── Theme-adaptive accessor ───

extension AppColorsX on BuildContext {
  AppColorScheme get colors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? _darkScheme : _lightScheme;
  }
}

const _lightScheme = AppColorScheme(
  bg: AppColors.bgLight,
  card: AppColors.cardLight,
  surface: AppColors.surfaceLight,
  textPrimary: AppColors.textPrimaryLight,
  textSecondary: AppColors.textSecondaryLight,
  divider: AppColors.dividerLight,
);

const _darkScheme = AppColorScheme(
  bg: AppColors.bgDark,
  card: AppColors.cardDark,
  surface: AppColors.surfaceDark,
  textPrimary: AppColors.textPrimaryDark,
  textSecondary: AppColors.textSecondaryDark,
  divider: AppColors.dividerDark,
);

class AppColorScheme {
  final Color bg;
  final Color card;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  const AppColorScheme({
    required this.bg,
    required this.card,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });
}
