/// Typography tokens (Phase 1 của UI redesign).
///
/// Giữ Nunito (rounded, thân thiện — hợp shopping app VN) qua `google_fonts`,
/// wire y cách theme cũ (`GoogleFonts.nunitoTextTheme(base.textTheme)`) để
/// mọi style không override giữ nguyên như baseline.
///
/// So với theme cũ: thêm `displaySmall` (28/w800 — hero tổng chi tiêu),
/// nâng `displayLarge` lên 34/w800 (hero "Còn lại" — không screen nào đang
/// dùng displayLarge nên không đổi UI hiện có), thêm `titleSmall`.
/// Money style dùng `FontFeature.tabularFigures()` để danh sách giá thẳng cột.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Màu chữ theo brightness — map từ bảng màu dark mode trong memo:
  // textPrimary light #1A1A2E / dark #F2F2F7; textSecondary light #6B7280 /
  // dark #A5ADBB.
  static const Color onSurfaceLight = Color(0xFF1A1A2E);
  static const Color onSurfaceDark = Color(0xFFF2F2F7);
  static const Color onSurfaceVariantLight = Color(0xFF6B7280);
  static const Color onSurfaceVariantDark = Color(0xFFA5ADBB);

  static TextTheme buildTextTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final onSurface = dark ? onSurfaceDark : onSurfaceLight;
    final onSurfaceVariant =
        dark ? onSurfaceVariantDark : onSurfaceVariantLight;
    final base =
        ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    return GoogleFonts.nunitoTextTheme(base).copyWith(
      displayLarge: GoogleFonts.nunito(
          fontSize: 34, fontWeight: FontWeight.w800, color: onSurface),
      displaySmall: GoogleFonts.nunito(
          fontSize: 28, fontWeight: FontWeight.w800, color: onSurface),
      headlineMedium: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w700, color: onSurface),
      titleMedium: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyMedium: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceVariant),
      // Giữ nguyên như theme cũ: white cho chữ trên nút nền primary —
      // foregroundColor của từng button variant sẽ override khi cần.
      labelLarge: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }

  /// Style cho số tiền — LUÔN tabular figures để list giá thẳng cột.
  static TextStyle moneyOf(TextTheme t, {double size = 15, Color? color}) =>
      (t.titleMedium ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
