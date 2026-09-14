/// Design tokens — shadow (UI refresh "INK LEDGER": "in phẳng" — print flat).
///
/// Không còn soft elevation hay glow: hierarchy = độ đậm mực + kẻ dòng +
/// chênh tone giấy. Shadow chỉ còn kiểu offset cứng KHÔNG blur cho phần tử
/// nổi (giấy chồng nhau lệch 2px). Tên field giữ nguyên — chỉ đổi giá trị.
library;

import 'package:flutter/material.dart';

abstract final class AppShadows {
  // ── Light ────────────────────────────────────────────────────────────────
  /// Card phẳng mặc định — 0 shadow, chỉ hairline border.
  static const List<BoxShadow> card = [];

  /// Phần tử trôi nổi: FAB, bottom nav, snackbar — offset cứng không blur.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x291C1B17), blurRadius: 0, offset: Offset(0, 2)),
  ];

  /// Bottom sheet / overlay hứng bóng từ trên xuống.
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, -4)),
  ];

  /// Không còn glow tím — field giữ lại chỉ để tương thích import cũ.
  static const List<BoxShadow> glowPrimary = [];

  // ── Dark ─────────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardDark = [];

  /// Dark phân tách bằng border, không shadow.
  static const List<BoxShadow> floatingDark = [];

  static const List<BoxShadow> modalDark = [
    BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, -4)),
  ];

  /// Dark không có glowPrimary — dùng hairline border thay.
}
