import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Tone ngữ nghĩa của price tag — map sang màu ở MỘT chỗ (dưới đây).
enum PriceTone { primary, success, danger }

/// "Con dấu" (stamp) price tag thay pill: radius vuông [AppRadius.sm],
/// border tone 1.2 + nền tone @8%. Giá mặc định là MỰC ĐEN (không còn
/// tô primary — tránh xung đột thị giác với success xanh).
class PriceTag extends StatelessWidget {
  final int amount;
  final PriceTone tone;

  const PriceTag({
    super.key,
    required this.amount,
    this.tone = PriceTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final Color base = switch (tone) {
      // Giá = mực đen (textPrimary), không phải cs.primary (bảng 3.5).
      PriceTone.primary => colors.textPrimary,
      PriceTone.success => colors.success,
      PriceTone.danger => colors.danger,
    };
    return Container(
      key: const Key('priceTag'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: base.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: base, width: 1.2),
      ),
      child: Text(
        CurrencyFormatter.format(amount),
        style: AppTypography.moneyOf(context.text, size: 13, color: base),
      ),
    );
  }
}
