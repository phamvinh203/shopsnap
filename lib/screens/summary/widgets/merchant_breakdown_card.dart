import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/merchant_insights.dart';
import '../../../widgets/ui/app_card.dart';
import '../../../widgets/ui/money_text.dart';
import '../../../widgets/ui/section_header.dart';

/// M-3 — Card "Chi tiêu theo nơi mua" trên Summary (AC 7.8–7.12):
///
/// - Top 5 nơi mua theo tổng chi GIẢM DẦN, dạng thanh ngang (pattern
///   `category_breakdown_card`): tên + tổng chi VND + số lần mua (AC 7.8).
///   Bar ratio tính theo nơi mua LỚN NHẤT (top-N chart — khác category
///   breakdown chia cho tổng toàn kỳ vì đây chỉ là top 5).
/// - Caveat bắt buộc "Độ chính xác thấp — tên cửa hàng chưa chuẩn hóa"
///   (AC 7.9 — gỡ khi BE normalize xong, AC 7.15).
/// - Insight so sánh giá dưới các bar: "Bạn thường mua X rẻ hơn ~Y% ở Z"
///   (AC 7.11) — pure function đã lọc edge Y ≤ 0 / thiếu dữ liệu (AC 7.12).
/// - Không có lượt mua nào có nơi mua → ẨN TOÀN BỘ section, không bar rỗng,
///   không "0đ" (AC 7.10).
class MerchantBreakdownCard extends StatelessWidget {
  final MerchantSummary data;

  const MerchantBreakdownCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // AC 7.10 — empty state: ẩn card thay vì render bar rỗng.
    if (data.isEmpty) return const SizedBox.shrink();

    final maxSpent = data.topStores.first.totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
          child: SectionHeader(title: 'Chi tiêu theo nơi mua'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            key: const Key('summaryMerchant_card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < data.topStores.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _MerchantRow(
                    key: Key('summaryMerchant_row_$i'),
                    index: i,
                    store: data.topStores[i],
                    maxSpent: maxSpent,
                  ),
                ],

                // AC 7.9 — caveat độ chính xác (tên cửa hàng free-text).
                const SizedBox(height: AppSpacing.md),
                Row(
                  key: const Key('summaryMerchant_caveat'),
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: context.cs.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Độ chính xác thấp — tên cửa hàng chưa chuẩn hóa',
                        style: context.text.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),

                // AC 7.11 — insight so sánh giá (đã lọc edge ở pure function).
                for (var i = 0; i < data.insights.length; i++) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _InsightLine(
                    key: Key('summaryMerchant_insight_$i'),
                    insight: data.insights[i],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MerchantRow extends StatelessWidget {
  final int index;
  final MerchantSpend store;
  final int maxSpent;

  const _MerchantRow({
    super.key,
    required this.index,
    required this.store,
    required this.maxSpent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storefront_outlined,
                size: 14, color: context.cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                store.storeName,
                key: Key('summaryMerchant_name_$index'),
                style: context.text.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Số lần mua (AC 7.8) — tone bút chì.
            Text(
              '${store.purchaseCount} lần',
              key: Key('summaryMerchant_count_$index'),
              style: context.text.bodySmall,
            ),
            const SizedBox(width: AppSpacing.md),
            MoneyText(
              key: Key('summaryMerchant_total_$index'),
              amount: store.totalSpent,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            key: Key('summaryMerchant_bar_$index'),
            value: maxSpent > 0
                ? (store.totalSpent / maxSpent).clamp(0.0, 1.0)
                : 0,
            minHeight: 8,
            color: context.cs.primary,
            backgroundColor: colors.skeleton,
          ),
        ),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  final MerchantPriceInsight insight;

  const _InsightLine({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.tintPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(Icons.savings_outlined, size: 16, color: context.cs.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Bạn thường mua ${insight.itemName} rẻ hơn '
            '~${insight.percentSaved}% ở ${insight.cheapestStore}',
            key: const Key('summaryMerchant_insightText'),
            style: context.text.bodySmall,
          ),
        ),
      ]),
    );
  }
}
