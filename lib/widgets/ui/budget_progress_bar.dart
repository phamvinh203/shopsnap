import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Progress bar ngân sách — giữ contract với `BudgetProgressCard` hiện có:
/// render `LinearProgressIndicator`, chuỗi "Đã dùng:" / "Còn lại:" /
/// "Chưa đặt ngân sách", màu semantic đổi ngưỡng 80% / 100%.
///
/// Màu KHÔNG hardcode: `spent/total` → [budgetLevelFromRatio] → `context.snap`.
class BudgetProgressBar extends StatelessWidget {
  final int spent;
  final int total;

  /// `true` → chỉ bar + % (dùng trong section header/item row);
  /// `false` → đầy đủ: Đã dùng + % + bar + Còn lại.
  final bool compact;

  const BudgetProgressBar({
    super.key,
    required this.spent,
    required this.total,
    this.compact = false,
  });

  double get _rawRatio => total > 0 ? spent / total : 0.0;
  double get _ratio => _rawRatio.toDouble().clamp(0.0, 1.0);
  int get _pct => total > 0 ? (spent / total * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final barColor = colors.colorFor(budgetLevelFromRatio(_rawRatio));

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _ratio),
        duration: AppDurations.slow,
        curve: Curves.easeOut,
        builder: (_, value, __) => LinearProgressIndicator(
          key: const Key('budgetProgressBar_indicator'),
          value: value,
          minHeight: compact ? 8 : 10,
          color: barColor,
          backgroundColor: barColor.withOpacity(0.12),
        ),
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: bar),
          const SizedBox(width: AppSpacing.sm),
          _PercentBadge(key: const Key('budgetProgressBar_percent'), pct: _pct, color: barColor),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đã dùng: ${CurrencyFormatter.format(spent)}',
              key: const Key('budgetProgressBar_spent'),
              style: context.text.bodySmall,
            ),
            _PercentBadge(
              key: const Key('budgetProgressBar_percent'),
              pct: _pct,
              color: barColor,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        bar,
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          total > 0
              ? 'Còn lại: ${CurrencyFormatter.format((total - spent).clamp(0, total))}'
              : 'Chưa đặt ngân sách',
          key: const Key('budgetProgressBar_remaining'),
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final int pct;
  final Color color;

  const _PercentBadge({super.key, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$pct%',
        style: context.text.labelLarge?.copyWith(fontSize: 13, color: color),
      ),
    );
  }
}
