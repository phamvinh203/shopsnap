import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helper.dart';
import '../../../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final ItemModel    item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ItemCard({required this.item, required this.onDelete, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 22),
          SizedBox(height: 2),
          Text('Xóa', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xóa vật phẩm?'),
            content: Text('Bạn có chắc muốn xóa "${item.name}" không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imagePath != null
                  ? Image.file(File(item.imagePath!), width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56, height: 56,
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text(item.categoryIcon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(item.categoryName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                Text(DateHelper.formatTime(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ])),
            const SizedBox(width: 10),
            // Price tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                CurrencyFormatter.format(item.price),
                style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
