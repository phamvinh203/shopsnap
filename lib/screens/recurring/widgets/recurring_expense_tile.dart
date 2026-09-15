import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/recurring_expense_model.dart';
import '../../../widgets/ui/app_card.dart';

/// Dòng khoản định kỳ trong danh sách (AC 4.2): tên + số tiền VND nguyên +
/// nhãn "Hằng tháng, ngày X" + toggle bật/tắt. Entry tắt hiển thị mờ trong
/// mục "Đã tắt" (section ở màn cha), tap thân dòng → sheet sửa (AC 4.4).
///
/// KHÔNG có nút xóa cứng (out of scope M-2 — tắt là đủ, giữ lịch sử).
class RecurringExpenseTile extends StatelessWidget {
  final RecurringExpense entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const RecurringExpenseTile({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !entry.isActive;
    final ink = context.snap.textPrimary;

    return Opacity(
      // Entry "Đã tắt" → style mờ (AC 4.2).
      opacity: dimmed ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
        key: Key('recurringTile_${entry.id}'),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    key: Key('recurring_name_${entry.id}'),
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // AC 4.2: "Hằng tháng, ngày X" — kỳ đợt này chỉ monthly.
                    'Hằng tháng, ngày ${entry.dueDay}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.snap.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    CurrencyFormatter.format(entry.amount),
                    key: Key('recurring_amount_${entry.id}'),
                    style: context.text.titleSmall?.copyWith(
                      color: context.cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(
              key: Key('recurring_toggle_${entry.id}'),
              value: entry.isActive,
              onChanged: onToggle,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
