import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/recurring_suggest.dart';
import '../../../widgets/ui/app_card.dart';
import 'recurring_expense_edit_sheet.dart';

/// Card "Có vẻ là khoản định kỳ" (AC 4.10 — [DECISION] đặt TRONG màn
/// /recurring, KHÔNG trên Home): mỗi gợi ý gồm tên + số tiền + "xuất hiện
/// N lần/3 tháng"; tap → mở sheet thêm đã prefill. Ẩn hoàn toàn khi không
/// có gợi ý (màn cha tự quyết định render).
class RecurringSuggestionCard extends StatelessWidget {
  final List<RecurringSuggestion> suggestions;

  const RecurringSuggestionCard({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('recurringSuggestionCard'),
      tint: context.snap.accent.withOpacity(0.12),
      hairline: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: context.cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Có vẻ là khoản định kỳ',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nhận diện từ các lần mua lặp lại đều đều 3 tháng gần nhất.',
            style: context.text.bodySmall
                ?.copyWith(color: context.snap.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SuggestionRow(
                key: Key('recurringSuggestion_${s.matchKey}'),
                suggestion: s,
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final RecurringSuggestion suggestion;

  const _SuggestionRow({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => RecurringExpenseEditSheet.showForCreate(
        context,
        prefill: RecurringExpensePrefill(
          name: s.name,
          amount: s.amount,
          // AC 4.10: ngày đến hạn = ngày của lần mua gần nhất (đã chặn 1..28).
          dueDay: s.lastPurchasedAt.day.clamp(1, 28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${CurrencyFormatter.format(s.amount)} · '
                  'xuất hiện ${s.occurrences} lần/3 tháng',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.snap.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: Key('recurringSuggestion_convert_${s.matchKey}'),
            onPressed: () => RecurringExpenseEditSheet.showForCreate(
              context,
              prefill: RecurringExpensePrefill(
                name: s.name,
                amount: s.amount,
                dueDay: s.lastPurchasedAt.day.clamp(1, 28),
              ),
            ),
            child: const Text('Tạo khoản định kỳ'),
          ),
        ],
      ),
    );
  }
}
