import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Tone ngữ nghĩa của price tag — map sang màu ở MỘT chỗ (dưới đây).
enum PriceTone { primary, success, danger }

/// Pill price tag thay Container pill copy-paste trong ItemCard.
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
      PriceTone.primary => context.cs.primary,
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
        color: base.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        CurrencyFormatter.format(amount),
        style: AppTypography.moneyOf(context.text, size: 13, color: base),
      ),
    );
  }
}
