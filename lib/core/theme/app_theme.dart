import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.bgMain,
      surface: AppColors.bgCard,
    ),
    scaffoldBackgroundColor: AppColors.bgMain,
  );

  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      displayLarge:   GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium:    GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyMedium:     GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodySmall:      GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge:     GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    cardTheme: const CardTheme(
      color: AppColors.bgCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgMain,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgMain,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgCard,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
