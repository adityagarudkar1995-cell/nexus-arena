import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background   = Color(0xFF0D0D0D);
  static const card         = Color(0xFF1A1A2E);
  static const accent       = Color(0xFF00FF88);
  static const danger       = Color(0xFFFF4655);
  static const surface      = Color(0xFF16213E);
  static const onSurface    = Color(0xFFE0E0E0);
  static const muted        = Color(0xFF6B6B8A);
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF9E9E9E);
  static const gold         = Color(0xFFFFD700);
  static const silver       = Color(0xFFC0C0C0);
  static const bronze       = Color(0xFFCD7F32);
  static const purple       = Color(0xFF7B2FBE);
  static const shimmerBase  = Color(0xFF1A1A2E);
  static const shimmerHighlight = Color(0xFF2A2A4E);
}

ThemeData appTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface:         AppColors.background,
      primaryContainer: AppColors.card,
      primary:         AppColors.accent,
      error:           AppColors.danger,
      onSurface:       AppColors.onSurface,
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(
      bodyColor:    AppColors.onSurface,
      displayColor: AppColors.onSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
