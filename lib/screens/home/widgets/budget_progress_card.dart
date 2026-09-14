import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../widgets/ui/money_text.dart';

/// Hero card của Home theo "INK LEDGER" — **thỏi mực** (3.6):
/// light = khối mực đen #1C1B17 in trên giấy (KHÔNG gradient, KHÔNG glow);
/// dark = #0E120D (đen hơn surface) + hairline border — "mực trên bảng đen".
/// Số "Còn lại" 34sp kem + badge % LIME (điểm nhấn highlighter duy nhất).
///
/// Contract giữ nguyên với `budget_progress_card_test.dart`:
/// - render `LinearProgressIndicator` với màu semantic theo ngưỡng
///   80% / 100% (màu map qua `context.snap`);
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
  Widget _heroNumber(BuildContext context, Color cream) {
    if (total <= 0) {
      return Text(
        'Chưa đặt ngân sách',
        key: const Key('budgetProgressCard_remaining'),
        style: context.text.titleMedium?.copyWith(color: cream),
      );
    }
    return Text(
      'Còn lại: ${CurrencyFormatter.format(_remaining)}',
      key: const Key('budgetProgressCard_remaining'),
      style: AppTypography.moneyOf(context.text, size: 34, color: cream)
          .copyWith(fontWeight: FontWeight.w800),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barColor = colors.colorFor(budgetLevelFromRatio(_rawRatio));

    // Bảng 3.6: hero luôn là khối TỐI trên cả 2 mode (thỏi mực / bảng đen).
    // #0E120D là hex proposal ghi rõ (3.6) — không có token tương ứng.
    const Color heroBgDark = Color(0xFF0E120D);
    final Color heroBg = dark ? heroBgDark : AppColors.textPrimary;
    // "Kem" chữ trên thỏi mực — token giấy kem của brand.
    const Color cream = AppColors.bgMain;
    final Color creamDim = cream.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: heroBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // Dark phân tách bằng hairline border; không shadow (print flat).
        border: dark ? Border.all(color: colors.hairline) : null,
        boxShadow: dark ? AppShadows.cardDark : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngân sách hôm nay'.toUpperCase(),
                style: AppTypography.overlineOf(context.text, color: creamDim),
              ),
              // Badge % = nền LIME, chữ ink — highlighter duy nhất của màn.
              Container(
                key: const Key('budgetProgressCard_percent'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$_pct%',
                  style: AppTypography.moneyOf(
                    context.text,
                    size: 13,
                    color: colors.onAccent,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Số tiền đổi (sửa/xoá item) → fade + slide-up ~4dp, 200ms (2.7);
          // a11y tắt animation → render thẳng số mới.
          if (MediaQuery.disableAnimationsOf(context))
            _heroNumber(context, cream)
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(0, 0.12), end: Offset.zero),
                  ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('$total-$spent'),
                child: _heroNumber(context, cream),
              ),
            ),
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
                // Track kem @18% (light) / hairline (dark) — bảng 3.6.
                backgroundColor:
                    dark ? colors.hairline : cream.withOpacity(0.18),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Đã dùng:',
                style: context.text.bodySmall?.copyWith(color: creamDim),
              ),
              const SizedBox(width: AppSpacing.xs),
              MoneyText(
                amount: spent,
                style: TextStyle(fontSize: 12, color: creamDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
