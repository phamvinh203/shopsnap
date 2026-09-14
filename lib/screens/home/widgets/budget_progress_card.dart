import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../widgets/ui/money_text.dart';

/// Hero card của Home theo hướng "Friendly Ledger" (memo redesign 02):
/// DUY NHẤT 1 card gradient tím radius 20 mỗi màn — hero number "Còn lại"
/// 34sp/w800 tabular figures + progress tổng quan.
///
/// Contract giữ nguyên với `budget_progress_card_test.dart`:
/// - render `LinearProgressIndicator` với màu semantic theo ngưỡng
///   80% / 100% (màu map qua `context.snap` — cùng hex `AppColors`);
/// - chuỗi "Chưa đặt ngân sách" / "Đã dùng: ..." / "Còn lại: ..." / "%".
class BudgetProgressCard extends StatelessWidget {
  final int spent;
  final int total;

  const BudgetProgressCard({required this.spent, required this.total, super.key});

  double get _rawRatio => total > 0 ? spent / total : 0.0;
  double get _ratio => _rawRatio.toDouble().clamp(0.0, 1.0);
  int get _pct => total > 0 ? (spent / total * 100).round() : 0;
  int get _remaining => (total - spent).clamp(0, total);

  /// Hero number: "Còn lại: 60.000đ" ở 34sp/w800 tabular figures.
  /// Chưa đặt ngân sách → hiển thị text thay cho số.
  Widget _heroNumber(BuildContext context) {
    if (total <= 0) {
      return Text(
        'Chưa đặt ngân sách',
        key: const Key('budgetProgressCard_remaining'),
        style: context.text.titleMedium?.copyWith(color: Colors.white),
      );
    }
    return Text(
      'Còn lại: ${CurrencyFormatter.format(_remaining)}',
      key: const Key('budgetProgressCard_remaining'),
      style: AppTypography.moneyOf(context.text, size: 34, color: Colors.white)
          .copyWith(fontWeight: FontWeight.w800),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barColor = colors.colorFor(budgetLevelFromRatio(_rawRatio));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // Dark mode bỏ glow, dùng shadow đậm hơn (memo 1.3).
        boxShadow: dark ? AppShadows.cardDark : AppShadows.glowPrimary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngân sách hôm nay',
                style: context.text.titleSmall?.copyWith(color: Colors.white70),
              ),
              Container(
                key: const Key('budgetProgressCard_percent'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$_pct%',
                  style: context.text.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _heroNumber(context),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _ratio),
              duration: AppDurations.slow,
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                key: const Key('budgetProgressCard_indicator'),
                value: value,
                minHeight: 10,
                color: barColor,
                backgroundColor: barColor.withOpacity(0.12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Đã dùng:',
                style: context.text.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(width: AppSpacing.xs),
              MoneyText(
                amount: spent,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
