import 'package:flutter/material.dart';

/// Premium neon arcade palette for Tap & Dodge.
class AppColors {
  static const Color midnight = Color(0xFF070B1A);
  static const Color deepNavy = Color(0xFF0B1230);
  static const Color panel = Color(0xCC141C3D);
  static const Color panelBorder = Color(0x5539D2FF);
  static const Color accent = Color(0xFFFFD76A);
  static const Color player = Color(0xFF39F3FF);
  static const Color playerDeep = Color(0xFF1B8CFF);
  static const Color violet = Color(0xFF7B5CFF);
  static const Color obstacle = Color(0xFFFF3B6B);
  static const Color obstacleDeep = Color(0xFFB01040);
  static const Color coin = Color(0xFFFFD54A);
  static const Color softWhite = Color(0xFFE8F1FF);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: Brightness.dark,
        primary: AppColors.accent,
        secondary: AppColors.player,
      ),
      scaffoldBackgroundColor: AppColors.midnight,
    );

    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF101528),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.softWhite,
          side: const BorderSide(color: Color(0x66FFFFFF)),
          minimumSize: const Size(180, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.softWhite,
        ),
      ),
    );
  }
}
