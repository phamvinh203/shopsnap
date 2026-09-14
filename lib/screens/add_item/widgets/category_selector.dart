import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../models/category_model.dart';
import '../../../widgets/ui/ui.dart';

/// Lưới chip chọn category — dùng CategoryChip của component library (P2).
///
/// Wave 2 (API integration):
/// - [suggestedId] — category được server gợi ý (GET /categories/suggest):
///   chip đó hiện badge nhỏ "Gợi ý" để giải thích vì sao tự chọn.
/// - [onAddCategory] — nếu truyền, hiện thêm chip "+ Danh mục" ở cuối
///   để tạo nhanh category custom (POST /categories).
class CategorySelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String              selected;
  final ValueChanged<String> onChanged;
  final String?             suggestedId;
  final VoidCallback?       onAddCategory;

  const CategorySelector({
    required this.categories,
    required this.selected,
    required this.onChanged,
    this.suggestedId,
    this.onAddCategory,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ...categories.map((cat) => CategoryChip(
          icon:      cat.icon,
          label:     cat.name,
          selected:  selected == cat.id,
          suggested: suggestedId != null && suggestedId == cat.id,
          onTap:     () => onChanged(cat.id),
        )),
        // Chip tạo nhanh category custom
        if (onAddCategory != null) _AddCategoryChip(onTap: onAddCategory!),
      ],
    );
  }
}

/// Chip "+ Danh mục" — viền hairline, chữ primary, InkWell có ripple.
class _AddCategoryChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCategoryChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.cs.primary.withOpacity(0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 15, color: context.cs.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Danh mục',
            style: context.text.labelLarge?.copyWith(
              fontSize: 13,
              color: context.cs.primary,
            ),
          ),
        ]),
      ),
    );
  }
}
