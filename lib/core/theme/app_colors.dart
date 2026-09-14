import 'package:flutter/material.dart';

/// Bảng màu brand "INK LEDGER" (UI refresh 2026-09-14):
/// xanh pine thay tím, giấy kem thay trắng lạnh, mực đen ấm thay navy.
/// Chỉ ĐỔI GIÁ TRỊ field — tên field giữ nguyên (ràng buộc mục 2 proposal).
abstract class AppColors {
  // Light mode (giấy kem / mực đen). Dark mode được map riêng trong
  // app_theme.dart + snap_colors.dart theo bảng 2.1.
  static const primary       = Color(0xFF175E48); // xanh pine
  static const primaryDark   = Color(0xFF0E4635); // pressed/ripple
  static const primaryLight  = Color(0xFFDDEBE3); // tint pine nhạt
  static const accent        = Color(0xFFCDF163); // bút dạ lime (highlighter)
  static const success       = Color(0xFF1E8E5A);
  static const warning       = Color(0xFFC2801A); // ochre
  static const danger        = Color(0xFFC0402E); // đỏ gạch ấm
  static const bgMain        = Color(0xFFF6F3EA); // giấy kem
  static const bgCard        = Color(0xFFFFFDF6); // giấy in
  static const textPrimary   = Color(0xFF1C1B17); // mực đen ấm
  static const textSecondary = Color(0xFF6E6A5E); // bút chì
  static const divider       = Color(0xFFDDD6C6); // kẻ dòng giấy
}
