import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Chip chọn category — icon là EMOJI (dữ liệu user/server, không đổi),
/// badge "Gợi ý" tích hợp khi hệ thống AI đề xuất category cho item.
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
        selected ? colors.onTintPrimary : context.cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.tintPrimary : context.cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? colors.onTintPrimary : colors.hairline,
          ),
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
                  color: context.cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Gợi ý',
                  style: context.text.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
