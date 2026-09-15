import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/budget_insights.dart';
import '../../core/utils/currency_formatter.dart';

/// F-#3 Smart Budget — dải "ghi chú dán sổ" 3 chỉ số: burn rate / safe daily
/// / forecast + trạng thái cảnh báo (đỏ/vàng) hoặc dòng tích cực.
///
/// Dùng chung cho hero card Home (nền mực tối — strip giấy kem nổi như tờ
/// note) và card ngân sách ở Cài đặt (nền giấy — strip tone skeleton +
/// hairline), tuỳ cờ [onDark]. Màu 100% tokens, không hardcode hex.
class BudgetInsightsStrip extends StatelessWidget {
  final BudgetInsights insights;

  /// `true` khi đặt trên nền TỐI (hero mực) → strip nền giấy kem đầy đủ;
  /// `false` → nền skeleton + hairline cho bề mặt giấy sẵn.
  final bool onDark;

  const BudgetInsightsStrip({
    super.key,
    required this.insights,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // AC 3.7: ngày cuối kỳ (days_remaining = 0) → ẩn toàn bộ insights, chỉ
    // còn spent vs budget + trạng thái đạt/vượt (badge % + màu bar của card).
    if (!insights.showInsights) return const SizedBox.shrink();

    final colors = context.snap;
    final bg = onDark ? AppColors.bgMain : colors.skeleton;
    final label = onDark ? colors.textSecondary : colors.textSecondary;
    final ink = colors.textPrimary;

    return Container(
      key: const Key('budgetInsights_strip'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: onDark ? null : Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Burn rate — 1 chữ số thập phân (AC 3.10) ────────────────────
          _Row(
            icon: Icons.speed_outlined,
            iconColor: label,
            text: 'Đã chi TB ${insights.burnRateLabel}đ/ngày',
            key: const Key('budgetInsights_burnRate'),
            textColor: ink,
          ),

          // ── Safe daily — chỉ khi còn tiền, KHÔNG bao giờ âm (AC 3.2/3.3) ─
          if (insights.safeDaily != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _Row(
              icon: Icons.savings_outlined,
              iconColor: colors.success,
              text:
                  'Có thể chi ~${CurrencyFormatter.format(insights.safeDaily!)}/ngày',
              key: const Key('budgetInsights_safeDaily'),
              textColor: ink,
            ),
          ],

          // ── Cảnh báo ĐỎ: đã vượt (AC 3.3 — không hiện số âm safe daily) ─
          if (insights.isOverBudget) ...[
            const SizedBox(height: AppSpacing.xs),
            _Row(
              icon: Icons.error_outline,
              iconColor: colors.danger,
              text:
                  'Đã vượt ngân sách ${CurrencyFormatter.format(insights.overAmount)}',
              key: const Key('budgetInsights_overWarning'),
              textColor: colors.danger,
              bold: true,
            ),
          ] else if (insights.isForecastOver) ...[
            // ── Cảnh báo VÀNG: forecast vượt (AC 3.4) — chỉ khi chưa đỏ ────
            const SizedBox(height: AppSpacing.xs),
            _Row(
              icon: Icons.trending_up,
              iconColor: colors.warning,
              text:
                  'Dự kiến vượt ~${CurrencyFormatter.format(insights.projectedOverage)}',
              key: const Key('budgetInsights_forecastWarning'),
              textColor: colors.warning,
              bold: true,
            ),
          ] else if (insights.showPositive) ...[
            // ── Dòng tích cực (AC 3.5) — đầu kỳ chưa chi thì im lặng (3.6) ─
            const SizedBox(height: AppSpacing.xs),
            _Row(
              icon: Icons.check_circle_outline,
              iconColor: colors.success,
              text: 'Đang đúng tốc độ',
              key: const Key('budgetInsights_okLine'),
              textColor: colors.success,
            ),
          ],

          // ── Forecast cuối kỳ — burn_rate × tổng số ngày kỳ (AC 3.1/3.4) ──
          const SizedBox(height: AppSpacing.xs),
          _Row(
            icon: Icons.event_outlined,
            iconColor: label,
            text:
                'Dự phóng cuối kỳ ~${CurrencyFormatter.format(insights.forecastVnd)}',
            key: const Key('budgetInsights_forecast'),
            textColor: ink,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final bool bold;

  const _Row({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: textColor,
              fontWeight: bold ? FontWeight.w700 : null,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
