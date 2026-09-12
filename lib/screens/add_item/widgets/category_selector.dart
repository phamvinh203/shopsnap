import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';

class CategorySelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String              selected;
  final ValueChanged<String> onChanged;

  const CategorySelector({
    required this.categories,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = selected == cat.id;
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
            ]),
          ),
        );
      }).toList(),
    );
  }
}
