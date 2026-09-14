/// Typography tokens (UI refresh "INK LEDGER" 2026-09-14).
///
/// Hệ 3 font (đều support tiếng Việt trên Google Fonts, load runtime như
/// Nunito trước đây — KHÔNG bundle thêm assets):
/// - Tiêu đề serif editorial: **Fraunces** (display/headline/titleLarge);
/// - Thân grotesque: **Be Vietnam Pro** (thân mặc định + label);
/// - Số tiền: **Space Grotesk** qua `moneyOf` (tabular figures — số thẳng
///   cột chất "máy tính sổ sách").
///
/// Kiến thức hàm giữ nguyên: `buildAppTheme(Brightness)` / `buildTextTheme`
/// / `moneyOf(TextTheme, {size, color})` — chỉ đổi font/hex bên trong.
/// Money style dùng `FontFeature.tabularFigures()` để danh sách giá thẳng cột.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Màu chữ theo brightness — bảng "INK LEDGER": mực đen ấm #1C1B17 /
  // phấn kem #F2EFE3; bút chì #6E6A5E / #A8A496.
  static const Color onSurfaceLight = Color(0xFF1C1B17);
  static const Color onSurfaceDark = Color(0xFFF2EFE3);
  static const Color onSurfaceVariantLight = Color(0xFF6E6A5E);
  static const Color onSurfaceVariantDark = Color(0xFFA8A496);

  static TextTheme buildTextTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final onSurface = dark ? onSurfaceDark : onSurfaceLight;
    final onSurfaceVariant =
        dark ? onSurfaceVariantDark : onSurfaceVariantLight;
    final base =
        ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    return GoogleFonts.beVietnamProTextTheme(base).copyWith(
      // Statement lớn — Fraunces editorial, hơi "wonky".
      displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: onSurface),
      displaySmall: GoogleFonts.fraunces(
          fontSize: 26, fontWeight: FontWeight.w700, color: onSurface),
      // Tiêu đề màn ("Xin chào!", "Tổng kết chi tiêu").
      headlineMedium: GoogleFonts.fraunces(
          fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
      // Appbar title.
      titleLarge: GoogleFonts.fraunces(
          fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: GoogleFonts.beVietnamPro(
          fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: GoogleFonts.beVietnamPro(
          fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyMedium: GoogleFonts.beVietnamPro(
          fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          color: onSurfaceVariant),
      // Button — foregroundColor của từng button variant sẽ override màu
      // khi cần (M3: foregroundColor của ButtonStyle đè màu trong textStyle).
      labelLarge: GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  /// Style cho số tiền — LUÔN tabular figures để list giá thẳng cột.
  /// Font Space Grotesk (grotesque mộc ra từ Space Mono); giữ nguyên
  /// signature, chỉ đổi font bên trong.
  static TextStyle moneyOf(TextTheme t, {double size = 15, Color? color}) =>
      (t.titleMedium ?? const TextStyle()).copyWith(
        fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Kicker/section label — 11/w700, letterSpacing 1.2, chữ HOA do caller
  /// tự `toUpperCase()` khi cần (Flutter không có textTransform trong style).
  static TextStyle? overlineOf(TextTheme t, {Color? color}) =>
      (t.labelSmall ?? const TextStyle()).copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      );
}
