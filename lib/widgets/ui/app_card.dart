import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/snap_colors.dart';

/// "Tờ giấy" chuẩn hệ thống: surface phẳng + hairline border, KHÔNG shadow
/// (`AppShadows.card` = [] — hierarchy bằng chênh tone giấy + kẻ dòng).
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

  /// `true` → vẽ rule ngang đỉnh 3dp màu mực (dự phòng cho card section,
  /// không bắt buộc gọi).
  final bool topRule;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.tint,
    this.hairline = true,
    this.topRule = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.snap;

    Widget card = Container(
      clipBehavior: topRule ? Clip.antiAlias : Clip.none,
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
          // "Press = mực đậm xuống": nền hạ sáng ~6% bằng mực (không scale
          // bounce — chất in ấn, không chất game; bảng 2.7).
          overlayColor: WidgetStateProperty.resolveWith((states) {
            final pressed =
                states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered);
            return pressed ? colors.textPrimary.withOpacity(0.06) : null;
          }),
          child: topRule
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 3, color: colors.textPrimary),
                    Padding(padding: padding, child: child),
                  ],
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap != null) card = _PressTranslate(child: card);
    return card;
  }
}

/// Dịch card xuống 0.5dp khi đang nhấn ("mực đậm xuống") — tôn trọng
/// `MediaQuery.disableAnimationsOf`.
class _PressTranslate extends StatefulWidget {
  final Widget child;
  const _PressTranslate({required this.child});

  @override
  State<_PressTranslate> createState() => _PressTranslateState();
}

class _PressTranslateState extends State<_PressTranslate> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        // 0.5dp — đủ "hạ xuống" khi chạm, không đổi hit-test đáng kể.
        transform: Matrix4.translationValues(0, _pressed ? 0.5 : 0, 0),
        child: widget.child,
      ),
    );
  }
}
