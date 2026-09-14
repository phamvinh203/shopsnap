import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';
import 'snap_colors.dart';

/// Build theme cho app.
///
/// `[brightness]` là tham số tuỳ chọn (mặc định [Brightness.light]) nên mọi
/// chỗ gọi `buildAppTheme()` cũ vẫn hoạt động. Dark mode được wire đầy đủ từ
/// Phase 1 nhưng CHỈ bật ở Phase 4 (themeMode provider — ngoài phạm vi hiện tại).
///
/// Light mode giữ đúng baseline đã duyệt: brand tím #6C63FF + Nunito.
/// Các màu semantic được map vào [ColorScheme] và [SnapColors] (ThemeExtension)
/// để Material component tự dark và widget đọc qua `context.snap`.
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final snap = dark ? SnapColors.dark : SnapColors.light;

  final Color primary = dark ? const Color(0xFF8B85FF) : AppColors.primary;
  final Color onPrimary = dark ? const Color(0xFF12121E) : Colors.white;
  final Color scaffoldBg = dark ? const Color(0xFF12121E) : AppColors.bgMain;
  final Color surface = dark ? const Color(0xFF1C1C2C) : AppColors.bgCard;
  final Color surfaceVariant =
      dark ? const Color(0xFF262638) : const Color(0xFFF1F2F8);

  final ColorScheme scheme = dark
      ? ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: snap.tintPrimary,
          onPrimaryContainer: snap.onTintPrimary,
          surface: surface,
          onSurface: AppTypography.onSurfaceDark,
          surfaceContainerHighest: surfaceVariant,
          onSurfaceVariant: AppTypography.onSurfaceVariantDark,
          outline: snap.hairline,
          error: snap.danger,
        )
      : ColorScheme.fromSeed(
          seedColor: primary,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: snap.tintPrimary,
          onPrimaryContainer: snap.onTintPrimary,
          surfaceContainerHighest: surfaceVariant,
          onSurfaceVariant: AppTypography.onSurfaceVariantLight,
          outline: snap.hairline,
          error: snap.danger,
        );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    extensions: <ThemeExtension<dynamic>>[snap],
  );

  return base.copyWith(
    textTheme: AppTypography.buildTextTheme(brightness),

    // ── Card ────────────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    // ── Buttons ─────────────────────────────────────────────────────────────
    // ElevatedButton: giữ Y HÌNH baseline (52dp, radius 16, bg tím).
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    // FilledButton: nền móng cho PrimaryButton (Phase 2) — radius md (12).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 4,
      shape: const CircleBorder(),
    ),

    // ── Input ───────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: snap.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: snap.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
    ),

    // ── Dialog / Sheet / Snackbar ───────────────────────────────────────────
    dialogTheme: DialogTheme(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: dark ? AppTypography.onSurfaceDark : AppTypography.onSurfaceLight,
      ),
      contentTextStyle: GoogleFonts.nunito(
        fontSize: 14,
        color: dark
            ? AppTypography.onSurfaceVariantDark
            : AppTypography.onSurfaceVariantLight,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      // margin không có trong SnackBarThemeData (Flutter 3.22) — set per-SnackBar
      // trong AppSnackBar (lib/widgets/ui/app_snack_bar.dart).
    ),

    // ── App bar / nav ───────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: dark ? AppTypography.onSurfaceDark : AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor:
          dark ? AppTypography.onSurfaceVariantDark : AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    dividerTheme: DividerThemeData(color: snap.hairline),
  );
}
