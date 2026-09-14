/// Design tokens — shadow (Phase 1 của UI redesign).
///
/// Thang 3 bậc (card / floating / modal) + glow cho hero card.
/// Dark mode dùng đen đậm hơn; glow bị bỏ ở dark (dùng hairline border thay)
/// theo memo redesign 2026-09-14.
library;

import 'package:flutter/material.dart';

abstract final class AppShadows {
  // ── Light ────────────────────────────────────────────────────────────────
  /// Card phẳng mặc định — elevation 0 + hairline + shadow bậc 1.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D101828), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Phần tử trôi nổi: FAB, bottom nav, snackbar.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Bottom sheet / overlay hứng bóng từ trên xuống.
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x26000000), blurRadius: 28, offset: Offset(0, -4)),
  ];

  /// Glow tím cho hero card (DUY NHẤT 1 hero card mỗi màn).
  static const List<BoxShadow> glowPrimary = [
    BoxShadow(color: Color(0x406C63FF), blurRadius: 22, offset: Offset(0, 8)),
  ];

  // ── Dark ─────────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardDark = [
    BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> floatingDark = [
    BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> modalDark = [
    BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, -4)),
  ];

  /// Dark không có glowPrimary — dùng hairline border thay (xem memo mục 1.3).
}
