import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Nút hành động chính — nền tím brand, chữ trắng.
///
/// Khi [loading]: thay label bằng spinner và disable nút.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// `true` (mặc định) → nút dài hết chiều ngang với chiều cao chuẩn 52dp;
  /// `false` → nút co theo nội dung (dùng trong dialog/hàng nút).
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('primaryButton'),
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: expand
            ? const Size.fromHeight(AppSizes.buttonHeight)
            : const Size(AppSizes.touchTarget, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
      child: loading
          ? SizedBox(
              key: const Key('primaryButton_loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: context.cs.onPrimary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Nút phụ — nền tint primary, chữ primary (hoặc tint danger khi [danger]).
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return FilledButton(
      key: const Key('secondaryButton'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor:
            danger ? colors.danger.withOpacity(0.12) : colors.tintPrimary,
        foregroundColor:
            danger ? colors.danger : colors.onTintPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
      child: Text(label),
    );
  }
}

/// Nút chữ — cho action phụ ("Huỷ", "Để sau"…), không nền.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('ghostButton'),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
