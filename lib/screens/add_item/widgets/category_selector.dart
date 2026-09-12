import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';

/// Lưới chip chọn category.
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
      spacing: 8,
      runSpacing: 8,
      children: [
        ...categories.map((cat) {
          final isSelected = selected == cat.id;
          final isSuggested = suggestedId != null && suggestedId == cat.id;
          return GestureDetector(
            onTap: () => onChanged(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        isSelected ? AppColors.primary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider, width: 1.5,
                ),
                boxShadow: isSelected
                    ? [const BoxShadow(color: Color(0x266C63FF), blurRadius: 8, offset: Offset(0, 2))]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cat.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(cat.name, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                )),
                // Badge "Gợi ý" — chỉ hiện khi chưa tự chọn tay
                if (isSuggested) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white24 : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('Gợi ý', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.primary,
                    )),
                  ),
                ],
              ]),
            ),
          );
        }),
        // Chip tạo nhanh category custom
        if (onAddCategory != null)
          GestureDetector(
            onTap: onAddCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                  color: AppColors.primary.withOpacity(0.45),
                  width: 1.5,
                ),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 15, color: AppColors.primary),
                SizedBox(width: 4),
                Text('Danh mục', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary,
                )),
              ]),
            ),
          ),
      ],
    );
  }
}
