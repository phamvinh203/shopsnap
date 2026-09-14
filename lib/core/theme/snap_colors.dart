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
  /// Container tint của brand tím (light #EEF0FF / dark #26244A).
  final Color tintPrimary;

  /// Chữ/icon trên nền tintPrimary.
  final Color onTintPrimary;

  final Color success;

  /// Success nhạt để làm background tint (badge, progress track).
  final Color successDim;

  final Color warning;
  final Color danger;

  /// Border hairline thay elevation (light #E5E7EB / dark #2A2A3A).
  final Color hairline;

  /// Màu nền shimmer/loading skeleton.
  final Color skeleton;

  /// Màu chữ chính trên surface — Phase 4 (dark mode), bảng memo redesign:
  /// light #1A1A2E / dark #F2F2F7. Map từ `AppTypography.onSurface*` để chỉ
  /// có MỘT nguồn sự thật cho giá trị hex.
  final Color textPrimary;

  /// Màu chữ phụ — light #6B7280 / dark #A5ADBB.
  final Color textSecondary;

  const SnapColors({
    required this.tintPrimary,
    required this.onTintPrimary,
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
    tintPrimary: Color(0xFFEEF0FF),
    onTintPrimary: Color(0xFF4B44CC),
    success: Color(0xFF00C48C),
    successDim: Color(0x1F00C48C),
    warning: Color(0xFFFFAB2D),
    danger: Color(0xFFFF4D4D),
    hairline: Color(0xFFE5E7EB),
    skeleton: Color(0xFFE5E7EB),
    textPrimary: AppTypography.onSurfaceLight,
    textSecondary: AppTypography.onSurfaceVariantLight,
  );

  static const SnapColors dark = SnapColors(
    tintPrimary: Color(0xFF26244A),
    onTintPrimary: Color(0xFF8B85FF),
    success: Color(0xFF2ADBA5),
    successDim: Color(0x1F2ADBA5),
    warning: Color(0xFFFFBC55),
    danger: Color(0xFFFF6B6B),
    hairline: Color(0xFF2A2A3A),
    skeleton: Color(0xFF2A2A3A),
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
