import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/deal_badge.dart';
import '../../../models/price_history_model.dart';
import '../../../widgets/ui/app_card.dart';
import '../../../widgets/ui/money_text.dart';

/// F-#1 Deal Badge — card "Smart Purchase Recommendation" trong item detail
/// sheet: đánh giá giá hiện tại so với trung bình / thấp nhất / lần mua trước
/// dựa trên price history của chính user (user-scoped, AC 1.10).
///
/// - ≥ 2 records: badge 3 mức (DEAL TỐT / GIÁ CAO / GIÁ BÌNH THƯỜNG) + % lệch
///   so avg (1 chữ số thập phân) + dòng gợi ý (AC 1.1–1.4, 1.7–1.9).
/// - Đúng 1 record: badge GIÁ BÌNH THƯỜNG + note thiếu dữ liệu (AC 1.5).
/// - 0 record: KHÔNG render card — caller lo việc này (AC 1.6).
///
/// Màu 100% qua tokens (`context.snap`) — không hardcode hex.
class DealBadgeCard extends StatelessWidget {
  final PriceHistorySummary summary;
  final DealBadgeResult badge;

  const DealBadgeCard({
    super.key,
    required this.summary,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;

    return AppCard(
      key: const Key('dealBadge_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + badge chip ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'ĐÁNH GIÁ GIÁ',
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              _levelChip(context),
            ],
          ),

          // ── % lệch so avg (nổi bật — chỉ khi đủ dữ liệu, AC 1.4: mức
          //    BÌNH THƯỜNG không hiển thị % lệch lớn nổi bật) ─────────────
          if (badge.hasEnoughData &&
              badge.level != DealBadgeLevel.normal) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              badge.deviationLabel,
              key: const Key('dealBadge_deviation'),
              style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w800,
                color: badge.level == DealBadgeLevel.goodDeal
                    ? colors.onTintPrimary // pine — "giá tốt"
                    : colors.danger, // đỏ — "giá cao"
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── 4 mốc giá: current / avg / min / previous (AC 1.1) ──────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PriceTile(
                  key: const Key('dealBadge_current'),
                  label: 'Hiện tại',
                  amount: summary.latestPrice,
                  emphasize: true,
                ),
              ),
              Expanded(
                child: _PriceTile(
                  key: const Key('dealBadge_avg'),
                  label: 'Trung bình',
                  amount: summary.avgPrice,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PriceTile(
                  key: const Key('dealBadge_min'),
                  label: 'Thấp nhất',
                  amount: summary.minPrice,
                  valueColor: colors.success,
                ),
              ),
              Expanded(
                child: _PriceTile(
                  key: const Key('dealBadge_previous'),
                  label: 'Lần mua trước',
                  amount: summary.previousPrice,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Dòng gợi ý / note thiếu dữ liệu ─────────────────────────────
          if (badge.hasEnoughData)
            Text(
              badge.suggestion,
              key: const Key('dealBadge_suggestion'),
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            )
          else
            Text(
              badge.insufficientNote!,
              key: const Key('dealBadge_insufficientNote'),
              style: context.text.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// Chip badge 3 màu theo tokens:
  /// DEAL TỐT = lime highlighter + mực; GIÁ CAO = đỏ danger;
  /// GIÁ BÌNH THƯỜNG = trung tính.
  Widget _levelChip(BuildContext context) {
    final colors = context.snap;

    final (Color bg, Color fg, IconData icon) = switch (badge.level) {
      DealBadgeLevel.goodDeal => (
          colors.accent,
          colors.onAccent,
          Icons.check_circle_outline
        ),
      DealBadgeLevel.highPrice => (
          colors.danger.withOpacity(0.12),
          colors.danger,
          Icons.trending_up
        ),
      DealBadgeLevel.normal => (
          colors.textSecondary.withOpacity(0.12),
          colors.textSecondary,
          Icons.remove_circle_outline
        ),
    };

    return Container(
      key: const Key('dealBadge_level'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            badge.label,
            style: (context.text.labelLarge ?? const TextStyle()).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một mốc giá trong card (label nhỏ + số tiền tabular).
class _PriceTile extends StatelessWidget {
  final String label;
  final int? amount;
  final Color? valueColor;
  final bool emphasize;

  const _PriceTile({
    super.key,
    required this.label,
    required this.amount,
    this.valueColor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        if (amount != null)
          MoneyText(
            amount: amount!,
            style: TextStyle(
              fontSize: emphasize ? 17 : 15,
              color: valueColor,
            ),
          )
        else
          Text('—', style: context.text.titleSmall),
      ],
    );
  }
}
