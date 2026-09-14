/// Semantic colors qua ThemeExtension (Phase 1 của UI redesign).
///
/// `SnapColors` chứa các màu ngữ nghĩa ĐỔI theo brightness (tint container,
/// success/warning/danger, hairline, skeleton) và được wire vào `ThemeData`
/// trong `app_theme.dart` → tự lerp khi chuyển light/dark.
///
/// ⚠️ BẮT BUỘC: khi consume luôn dùng `context.snap` (extension ở cuối file)
/// vì nó có fallback `?? SnapColors.light()` — widget test pump bare
/// `MaterialApp` (không qua `buildAppTheme`) sẽ KHÔNG có extension trong theme.
library;

import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Mức ngân sách — input ngữ nghĩa cho màu (QA plan mục 3.3: component nhận
/// semantic input, màu map ở MỘT chỗ trong token layer, test assert logic
/// chứ không assert hex).
enum BudgetLevel { ok, warning, danger }

/// Ngưỡng ngược lại với `BudgetProgressCard` hiện có:
/// ≥ 100% → danger, ≥ 80% → warning, còn lại → ok.
BudgetLevel budgetLevelFromRatio(double ratio) {
  if (ratio >= 1.0) return BudgetLevel.danger;
  if (ratio >= 0.80) return BudgetLevel.warning;
  return BudgetLevel.ok;
}

@immutable
class SnapColors extends ThemeExtension<SnapColors> {
  /// Container tint của brand pine (light #DDEBE3 / dark #1E3A2D).
  final Color tintPrimary;

  /// Chữ/icon trên nền tintPrimary.
  final Color onTintPrimary;

  /// Bút dạ lime (highlighter) — selected/badge nhấn.
  /// Light #CDF163 / dark #C7EE5E. (Field mới — UI refresh "INK LEDGER".)
  final Color accent;

  /// Chữ/icon trên nền accent (ink trên lime).
  /// Light #1C1B17 / dark #161A12. (Field mới — UI refresh "INK LEDGER".)
  final Color onAccent;

  final Color success;

  /// Success nhạt để làm background tint (badge, progress track).
  final Color successDim;

  final Color warning;
  final Color danger;

  /// Border hairline thay elevation (light #DDD6C6 / dark #343B2F).
  final Color hairline;

  /// Màu nền shimmer/loading skeleton.
  final Color skeleton;

  /// Màu chữ chính trên surface (mực đen ấm / phấn kem):
  /// light #1C1B17 / dark #F2EFE3. Map từ `AppTypography.onSurface*` để chỉ
  /// có MỘT nguồn sự thật cho giá trị hex.
  final Color textPrimary;

  /// Màu chữ phụ — light #6E6A5E / dark #A8A496.
  final Color textSecondary;

  const SnapColors({
    required this.tintPrimary,
    required this.onTintPrimary,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.successDim,
    required this.warning,
    required this.danger,
    required this.hairline,
    required this.skeleton,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const SnapColors light = SnapColors(
    tintPrimary: Color(0xFFDDEBE3),
    onTintPrimary: Color(0xFF0E4635),
    accent: Color(0xFFCDF163),
    onAccent: Color(0xFF1C1B17),
    success: Color(0xFF1E8E5A),
    successDim: Color(0x1F1E8E5A),
    warning: Color(0xFFC2801A),
    danger: Color(0xFFC0402E),
    hairline: Color(0xFFDDD6C6),
    skeleton: Color(0xFFE7E1D2),
    textPrimary: AppTypography.onSurfaceLight,
    textSecondary: AppTypography.onSurfaceVariantLight,
  );

  static const SnapColors dark = SnapColors(
    tintPrimary: Color(0xFF1E3A2D),
    onTintPrimary: Color(0xFF8FE3BE),
    accent: Color(0xFFC7EE5E),
    onAccent: Color(0xFF161A12),
    success: Color(0xFF4CC98B),
    successDim: Color(0x1F4CC98B),
    warning: Color(0xFFE0A33E),
    danger: Color(0xFFE86A57),
    hairline: Color(0xFF343B2F),
    skeleton: Color(0xFF2A3126),
    textPrimary: AppTypography.onSurfaceDark,
    textSecondary: AppTypography.onSurfaceVariantDark,
  );

  /// Map ngữ nghĩa → màu (một chỗ duy nhất, theo QA plan mục 3.3).
  Color colorFor(BudgetLevel level) {
    switch (level) {
      case BudgetLevel.ok:
        return success;
      case BudgetLevel.warning:
        return warning;
      case BudgetLevel.danger:
        return danger;
    }
  }

  @override
  SnapColors copyWith({
    Color? tintPrimary,
    Color? onTintPrimary,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? successDim,
    Color? warning,
    Color? danger,
    Color? hairline,
    Color? skeleton,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return SnapColors(
      tintPrimary: tintPrimary ?? this.tintPrimary,
      onTintPrimary: onTintPrimary ?? this.onTintPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successDim: successDim ?? this.successDim,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      hairline: hairline ?? this.hairline,
      skeleton: skeleton ?? this.skeleton,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  SnapColors lerp(SnapColors? other, double t) {
    if (other == null) return this;
    return SnapColors(
      tintPrimary: Color.lerp(tintPrimary, other.tintPrimary, t)!,
      onTintPrimary: Color.lerp(onTintPrimary, other.onTintPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successDim: Color.lerp(successDim, other.successDim, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Helper đọc token — DÙNG ĐỪNG QUÊN fallback `?? SnapColors.light()`.
extension SnapColorsX on BuildContext {
  /// Semantic colors của theme hiện tại, có fallback khi theme không wire
  /// SnapColors (widget test pump bare `MaterialApp`).
  SnapColors get snap =>
      Theme.of(this).extension<SnapColors>() ?? SnapColors.light;

  ColorScheme get cs => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;
}
