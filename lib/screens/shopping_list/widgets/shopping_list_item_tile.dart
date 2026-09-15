import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shopping_list_item_model.dart';
import '../../../providers/shopping_list_provider.dart';
import '../../../widgets/ui/app_snack_bar.dart';
import 'price_intel_block.dart';
import 'shopping_item_edit_sheet.dart';

/// Một dòng trong Shopping List (F-#6).
///
/// Tương tác theo AC:
/// - Checkbox tick mua xong — đổi NGAY, tên gạch ngang (AC 6.4).
/// - Xoá: swipe (Dismissible) HOẶC nút xoá — không dialog xác nhận (AC 6.5).
/// - Tap thân dòng → sheet chỉnh số lượng / giá dự kiến / danh mục (AC 6.6).
/// - Khối price intelligence ẩn khi không khớp sản phẩm đã mua (AC 6.9/6.10).
class ShoppingListItemTile extends ConsumerWidget {
  final ShoppingListItem item;

  /// AC 12.5 — dòng vừa được deep-link từ price alert: viền nhấn mạnh để user
  /// nhận ra ngay món đang được thông báo (tự tắt sau vài giây ở màn list).
  final bool highlighted;

  const ShoppingListItemTile({
    super.key,
    required this.item,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = context.snap;

    return Dismissible(
      key: Key('shoppingItem_dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: snap.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.delete_outline_rounded, color: snap.danger),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: Container(
        key: Key(
          'shoppingListItem_${item.id}${highlighted ? '_highlighted' : ''}',
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            // AC 12.5: deep-link highlight dùng màu primary + viền dày hơn.
            color: highlighted ? context.cs.primary : snap.hairline,
            width: highlighted ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => ShoppingItemEditSheet.show(context, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.sm, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: AppSizes.touchTarget - 4,
                      height: AppSizes.touchTarget - 4,
                      child: Checkbox(
                        key: Key('shoppingItem_check_${item.id}'),
                        value: item.checked,
                        onChanged: (_) => ref
                            .read(shoppingListProvider.notifier)
                            .toggleChecked(item.id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.watched) ...[
                                Icon(
                                  Icons.notifications_active_rounded,
                                  size: 15,
                                  color: snap.warning,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              Expanded(
                                child: Text(
                                  item.name,
                                  key: Key('shoppingItem_name_${item.id}'),
                                  style: context.text.titleSmall?.copyWith(
                                    decoration: item.checked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.checked
                                        ? snap.textSecondary
                                        : snap.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_metaParts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _metaParts.join('  ·  '),
                                key: Key('shoppingItem_meta_${item.id}'),
                                style: context.text.bodySmall?.copyWith(
                                  color: snap.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('shoppingItem_delete_${item.id}'),
                      tooltip: 'Xoá món',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 20, color: snap.textSecondary),
                      onPressed: () => _remove(context, ref),
                    ),
                  ],
                ),
                // AC 6.9/6.10: khối intel tự ẩn khi không khớp sản phẩm nào.
                PriceIntelBlock(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> get _metaParts => [
        if (item.quantity != null) 'SL: ${item.quantity}',
        if (item.expectedPrice != null)
          'Dự kiến: ${CurrencyFormatter.format(item.expectedPrice!)}',
      ];

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    await ref.read(shoppingListProvider.notifier).remove(item.id);
    // Feedback nhẹ sau khi xoá (không chặn, không xác nhận — AC 6.5).
    if (context.mounted) {
      AppSnackBar.show(
        context: context,
        message: 'Đã xoá "${item.name}"',
        duration: const Duration(seconds: 1),
      );
    }
  }
}
