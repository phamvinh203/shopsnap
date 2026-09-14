import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/snap_colors.dart';

/// Card phẳng chuẩn hệ thống: elevation 0 + hairline border + shadow bậc `card`.
///
/// Consume tokens qua `context.snap` / `context.cs` — không hardcode màu.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Nền override (vd tint primary cho banner) — mặc định dùng surface.
  final Color? tint;

  /// Bật/tắt hairline border.
  final bool hairline;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.tint,
    this.hairline = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.snap;
    return Container(
      decoration: BoxDecoration(
        color: tint ?? context.cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: hairline ? Border.all(color: colors.hairline) : null,
        boxShadow: dark ? AppShadows.cardDark : AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
