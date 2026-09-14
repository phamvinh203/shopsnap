import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Tone của snackbar — màu rule dọc trái map từ tokens ở MỘT chỗ (dưới đây).
enum AppSnackBarTone { neutral, success, warning, danger }

/// SnackBar chuẩn hoá — "toast mực + thanh tone" (INK LEDGER 3.9):
/// nền mực in ngược (light ink / dark kem), radius sm, tone thể hiện bằng
/// rule DỌC TRÁI 3dp (neutral = lime accent).
///
/// Mặc định floating + margin 12 (khớp style đang dùng ở home `_deleteItem`).
class AppSnackBar {
  AppSnackBar._();

  static void show({
    required BuildContext context,
    required String message,
    AppSnackBarTone tone = AppSnackBarTone.neutral,
    bool floating = true,
    Duration? duration,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final colors = context.snap;
    final cs = context.cs;

    // Nền = mực, foreground = đối ứng (kem light / ink dark — in ngược).
    final Color background = cs.onSurface;
    final Color foreground = cs.surface;

    // Tone = rule dọc trái 3dp (không còn nền màu).
    late final Color rule;
    switch (tone) {
      case AppSnackBarTone.neutral:
        rule = colors.accent;
      case AppSnackBarTone.success:
        rule = colors.success;
      case AppSnackBarTone.warning:
        rule = colors.warning;
      case AppSnackBarTone.danger:
        rule = colors.danger;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('appSnackBar'),
        content: Row(
          children: [
            Container(width: 3, color: rule),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                key: const Key('appSnackBar_message'),
                style: context.text.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior:
            floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        margin: floating ? const EdgeInsets.all(AppSpacing.md) : null,
        duration: duration ?? const Duration(seconds: 4),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                key: const Key('appSnackBar_action'),
                label: actionLabel,
                textColor: foreground,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
