import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';
import 'snap_colors.dart';

/// Build theme cho app — bảng "INK LEDGER" (UI refresh 2026-09-14).
///
/// `[brightness]` giữ nguyên signature (mặc định [Brightness.light]). Chỉ ĐỔI
/// GIÁ TRỊ token + wire thêm segmented/FAB/input theme; không đổi kiến trúc:
/// seed vẫn `primary`, SnapColors vẫn là ThemeExtension với fallback
/// `?? SnapColors.light` ở `context.snap`.
///
/// Light = giấy kem #F6F3EA + mực #1C1B17 + pine #175E48; dark = bảng đen
/// #141812 + phấn kem #F2EFE3 + mint #8FE3BE.
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final snap = dark ? SnapColors.dark : SnapColors.light;
  final ink = dark ? AppTypography.onSurfaceDark : AppTypography.onSurfaceLight;

  final Color primary = dark ? const Color(0xFF8FE3BE) : AppColors.primary;
  // Kem trên pine (light) / pine đậm trên mint (dark) — dùng cho pie chart
  // title trên slice màu và nút nền brand.
  final Color onPrimary = dark ? const Color(0xFF0F2A20) : const Color(0xFFF6F3EA);
  final Color scaffoldBg = dark ? const Color(0xFF141812) : AppColors.bgMain;
  final Color surface = dark ? const Color(0xFF1C221B) : AppColors.bgCard;
  final Color surfaceVariant =
      dark ? const Color(0xFF252C23) : const Color(0xFFEFE9DC);

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

  // CTA = "mực in": nền mực + chữ ĐỐI ỨNG (kem light / ink dark) — in ngược.
  final Color onInk =
      dark ? AppTypography.onSurfaceLight : AppTypography.onSurfaceDark;

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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: onInk,
        minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    // FilledButton: nền móng cho PrimaryButton (Phase 2) — radius md (10).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: onInk,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor:
            dark ? AppTypography.onSurfaceDark : AppTypography.onSurfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    // FAB "dấu sao": rounded-square 14, nền mực (dark: kem), icon lime
    // (dark: ink) — elevation 0, nổi bằng offset shadow cứng (3.7).
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: dark
          ? snap.onAccent
          : snap.accent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    // ── Input ───────────────────────────────────────────────────────────────
    // "Ruled line" (3.3): chỉ gạch chân, bỏ hộp. Chỗ nào cần khối nền sẽ set
    // local `filled: true, fillColor: surfaceVariant` (quick-amount add_item).
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(
        color: (dark
                ? AppTypography.onSurfaceVariantDark
                : AppTypography.onSurfaceVariantLight)
            .withOpacity(0.7),
      ),
      labelStyle: GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color:
            dark ? AppTypography.onSurfaceVariantDark : AppColors.textSecondary,
      ),
      floatingLabelStyle: GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: ink,
      ),
      errorStyle: GoogleFonts.beVietnamPro(
        fontSize: 12,
        color: snap.danger,
      ),
      prefixIconColor:
          dark ? AppTypography.onSurfaceVariantDark : AppColors.textSecondary,
      suffixIconColor:
          dark ? AppTypography.onSurfaceVariantDark : AppColors.textSecondary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      border: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: snap.hairline),
      ),
      enabledBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: snap.hairline, width: 1.2),
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: ink, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: snap.danger, width: 1.5),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: snap.danger, width: 1.5),
      ),
    ),

    // ── Dialog / Sheet / Snackbar ───────────────────────────────────────────
    dialogTheme: DialogTheme(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      contentTextStyle: GoogleFonts.beVietnamPro(
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
      backgroundColor: ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      // margin không có trong SnackBarThemeData (Flutter 3.22) — set per-SnackBar
      // trong AppSnackBar (lib/widgets/ui/app_snack_bar.dart).
    ),

    // ── Segmented (period tabs + theme switcher) ────────────────────────────
    // Selected = lime + ink w600 (highlighter swipe), radius sm (6),
    // border hairline; unselected fg = textSecondary (3.10).
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: snap.hairline)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? snap.accent : null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? snap.onAccent
              : (dark
                  ? AppTypography.onSurfaceVariantDark
                  : AppTypography.onSurfaceVariantLight);
        }),
        textStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
    ),

    // ── App bar / nav ───────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: ink,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
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
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: snap.hairline),
  );
}
