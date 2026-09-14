import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Nút hành động chính — "mực in": nền mực (light #1C1B17 / dark kem, in
/// ngược), chữ màu đối ứng, radius md (10), cao 52.
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
    // Nền = mực (cs.onSurface); chữ/spinner = đối ứng (giấy — cs.surface):
    // light kem trên ink, dark ink trên kem — đúng chất "in ngược".
    return FilledButton(
      key: const Key('primaryButton'),
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: context.cs.onSurface,
        foregroundColor: context.cs.surface,
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
                color: context.cs.surface,
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

/// Nút phụ — "quét bút dạ": nền lime [SnapColors.accent], chữ ink
/// [SnapColors.onAccent]. Variant [danger]: bg danger @12%, chữ danger.
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
            danger ? colors.danger.withOpacity(0.12) : colors.accent,
        foregroundColor: danger ? colors.danger : colors.onAccent,
        elevation: 0,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
      child: Text(label),
    );
  }
}

/// Nút chữ — action phụ ("Huỷ", "Để sau"…), không nền, CHỮ GẠCH CHÂN
/// (chất editorial editorial của Ink Ledger).
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
    final ink = context.snap.textPrimary;
    return TextButton(
      key: const Key('ghostButton'),
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: ink),
      child: Text(
        label,
        style: TextStyle(
          color: ink,
          decoration: TextDecoration.underline,
          decorationColor: ink,
          decorationStyle: TextDecorationStyle.solid,
          // Flutter TextStyle không có "offset" cho gạch chân (khác CSS) —
          // chỉ kiểm soát được độ dày tương đối.
          decorationThickness: 1.5,
        ),
      ),
    );
  }
}
