/// Design tokens — layout (Phase 1 của UI redesign).
///
/// Static const tokens cho spacing / radius / sizes / durations.
/// Các giá trị này KHÔNG đổi theo dark mode nên không cần ThemeExtension,
/// và chỉ static const mới giữ được khả năng `const` của widget hiện có
/// (vd `const EdgeInsets.all(AppSpacing.lg)`).
library;

/// Spacing theo grid 4pt — khớp usage hiện tại của app (gutter chuẩn = 16).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // gutter chuẩn của screen
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Bo góc — "kẻ dòng sách vở" (INK LEDGER): sắc hơn baseline cũ 8/12/16/20/24.
abstract final class AppRadius {
  static const double sm = 6; // chip nhỏ, badge, con dấu (PriceTag)
  static const double md = 10; // input, quick button, dialog nhỏ
  static const double lg = 14; // AppCard, item card, button chính, FAB
  static const double xl = 16; // hero/budget card, sheet content
  static const double sheet = 20; // top radius của bottom sheet
  static const double pill = 999; // price tag, progress bar, nav pill
}

/// Kích thước chuẩn hoá cho control (a11y: touch target ≥ 48dp).
abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double touchTarget = 48;
  static const double bottomNavHeight = 64;
  static const double fabGap = 60; // khoảng trống giữa nav cho FAB docked
  static const double thumbIcon = 24;
}

/// Duration chuẩn cho animation/micro-interaction (Phase 5 dùng tiếp).
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
}
