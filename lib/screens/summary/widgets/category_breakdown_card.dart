import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/spending_dashboard.dart';
import '../../../models/summary_model.dart';
import '../../../widgets/ui/app_card.dart';
import '../../../widgets/ui/money_text.dart';
import '../../../widgets/ui/section_header.dart';

/// F-#2 (AC 2.3): breakdown danh mục dạng progress bar, xếp GIẢM DẦN theo số
/// tiền. Mỗi dòng: icon + tên, số tiền, % trên tổng, thanh tiến độ theo màu
/// category (fallback primary khi hex hỏng — pattern pie đang dùng).
///
/// Thanh tự vẽ bằng `LinearProgressIndicator` — không thêm dependency mới.
class CategoryBreakdownCard extends StatelessWidget {
  final List<CategorySummary> categories;
  final int totalSpent;

  const CategoryBreakdownCard({
    super.key,
    required this.categories,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    // AC 2.3: sắp xếp GIẢM DẦN — pure function để unit test riêng.
    final sorted = sortCategoriesDesc(categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
          child: SectionHeader(title: 'Chi tiêu theo danh mục'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            key: const Key('summaryBreakdown_card'),
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _BreakdownRow(
                    key: Key('summaryBreakdown_row_$i'),
                    index: i,
                    category: sorted[i],
                    totalSpent: totalSpent,
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

class _BreakdownRow extends StatelessWidget {
  final int index;
  final CategorySummary category;
  final int totalSpent;

  const _BreakdownRow({
    super.key,
    required this.index,
    required this.category,
    required this.totalSpent,
  });

  /// Màu category từ hex — hỏng/decode lỗi → token primary (pattern pie).
  Color _categoryColor(BuildContext context) {
    try {
      return Color(
          int.parse(category.categoryColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final color = _categoryColor(context);
    final share = shareOfTotal(part: category.totalSpent, total: totalSpent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(category.categoryIcon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                category.categoryName,
                key: Key('summaryBreakdown_name_$index'),
                style: context.text.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // % trên tổng (AC 2.3) — tone bút chì, số tiền là ngôi sao.
            Text(
              '${share.toStringAsFixed(0)}%',
              key: Key('summaryBreakdown_percent_$index'),
              style: context.text.bodySmall,
            ),
            const SizedBox(width: AppSpacing.md),
            MoneyText(amount: category.totalSpent, style: const TextStyle(fontSize: 14)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            key: Key('summaryBreakdown_bar_$index'),
            value: barRatio(part: category.totalSpent, total: totalSpent),
            minHeight: 8,
            color: color,
            backgroundColor: colors.skeleton,
          ),
        ),
      ],
    );
  }
}
