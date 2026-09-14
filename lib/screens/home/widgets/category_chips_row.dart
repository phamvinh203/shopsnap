import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../models/category_model.dart';
import '../../../widgets/ui/category_chip.dart';

/// Hàng chip lọc danh mục trên Home — dùng `CategoryChip` của component
/// library (selected = tint brand), có key theo id để test tìm theo `byKey`.
class CategoryChipsRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const CategoryChipsRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CategoryChip(
              key: const Key('categoryChipsRow_all'),
              // "Tất cả" không phải ngữ nghĩa search → bỏ emoji 🔍 (audit H6).
              icon: '🗂️',
              label: 'Tất cả',
              selected: selected == null,
              onTap: () => onSelected(null),
            ),
          ),
          for (final cat in categories)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: CategoryChip(
                key: Key('categoryChipsRow_${cat.id}'),
                icon: cat.icon,
                label: cat.name,
                selected: selected == cat.id,
                onTap: () => onSelected(selected == cat.id ? null : cat.id),
              ),
            ),
        ],
      ),
    );
  }
}
