import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Tone của snackbar — màu map từ tokens ở MỘT chỗ (dưới đây).
enum AppSnackBarTone { neutral, success, warning, danger }

/// SnackBar chuẩn hoá — thay ~8 chỗ `ScaffoldMessenger…showSnackBar` lặp.
///
/// Mặc định floating + radius 12 + margin 12 (khớp style đang dùng ở
/// home `_deleteItem`).
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

    late final Color background;
    late final Color foreground;
    switch (tone) {
      case AppSnackBarTone.neutral:
        background = cs.inverseSurface;
        foreground = cs.onInverseSurface;
      case AppSnackBarTone.success:
        background = colors.success;
        // onPrimary = màu chữ chuẩn trên màu vivid — đúng cả light (trắng)
        // lẫn dark (navy) nhờ bảng dark mode.
        foreground = cs.onPrimary;
      case AppSnackBarTone.warning:
        background = colors.warning;
        foreground = cs.onPrimary;
      case AppSnackBarTone.danger:
        background = colors.danger;
        foreground = cs.onPrimary;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('appSnackBar'),
        content: Text(
          message,
          key: const Key('appSnackBar_message'),
          style: context.text.bodyMedium?.copyWith(color: foreground),
        ),
        backgroundColor: background,
        behavior:
            floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
