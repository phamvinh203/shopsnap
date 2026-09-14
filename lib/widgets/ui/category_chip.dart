import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Chip chọn category — "bút dạ quét" (INK LEDGER 2.7/3.4):
/// unselected = trong suốt + border hairline; selected = không border,
/// nền lime [SnapColors.accent] QUÉT VÀO TỪ TRÁI ~220ms easeOutCubic
/// (tôn trọng `MediaQuery.disableAnimationsOf`). Badge "Gợi ý" = con dấu
/// pill nền mực, chữ giấy. Icon là EMOJI (dữ liệu user/server, không đổi).
class CategoryChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final bool suggested;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.suggested = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final foreground =
        selected ? colors.onAccent : context.cs.onSurfaceVariant;

    // Highlighter swipe: widthFactor 0→1 ~220ms easeOutCubic; không animation
    // khi a11y yêu cầu tắt (nhảy thẳng tới trạng thái đích).
    final noMotion = MediaQuery.disableAnimationsOf(context);
    final sweep = noMotion ? (selected ? 1.0 : 0.0) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          // Selected: KHÔNG border (spec 3.4) — border trong suốt để layout
          // không nhảy 1px khi chuyển trạng thái.
          border: Border.all(
            color: selected ? Colors.transparent : colors.hairline,
          ),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, content) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm - 1),
            child: Stack(children: [
              // Lớp lime quét từ trái sang phải (nằm dưới nội dung).
              Positioned.fill(
                child: IgnorePointer(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: sweep ?? value,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.accent),
                  ),
                ),
              ),
              content!,
            ]),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: context.text.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (suggested) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    key: const Key('categoryChip_suggestedBadge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Gợi ý',
                      style: context.text.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.cs.surface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
