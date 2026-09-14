import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../models/item_model.dart';
import '../../../widgets/ui/confirm_dialog.dart';
import '../../../widgets/ui/price_tag.dart';

/// Card mặt hàng trên Home — nền phẳng radius 16 + hairline border (tokens).
///
/// Cấu trúc giữ nguyên hợp đồng với `item_card_test.dart`:
/// `Dismissible` (swipe xoá) + confirm dialog "Xóa vật phẩm?"/"Huỷ" +
/// `GestureDetector` ngoài cùng cho tap + icon placeholder
/// `Icons.shopping_bag_outlined`.
class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ItemCard({
    required this.item,
    required this.onDelete,
    required this.onTap,
    super.key,
  });

  Future<bool> _confirmDelete(BuildContext context) {
    // Chuỗi "Xóa vật phẩm?" / "Huỷ" bị widget test khoá — KHÔNG đổi chính tả.
    return ConfirmDialog.show(
      context: context,
      title: 'Xóa vật phẩm?',
      message: 'Bạn có chắc muốn xóa "${item.name}" không?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.danger,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 22),
          SizedBox(height: 2),
          Text(
            'Xoá',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      // GestureDetector giữ ở ngoài cùng (test cũ find theo type + tap).
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.hairline), // hairline thay elevation
            boxShadow: dark ? AppShadows.cardDark : AppShadows.card,
          ),
          child: Row(children: [
            // Thumbnail — placeholder: viền hairline + icon mực @40%
            // (không còn khối tint tím; icon giữ `shopping_bag_outlined`).
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.hairline),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: colors.textPrimary.withOpacity(0.4),
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Tên + danh mục + giờ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(children: [
                    Text(item.categoryIcon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item.categoryName,
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateHelper.formatTime(item.createdAt),
                      style: context.text.bodySmall,
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Giá — pill tabular figures
            PriceTag(amount: item.price),
          ]),
        ),
      ),
    );
  }
}
