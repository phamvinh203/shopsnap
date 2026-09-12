import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';

class CategoryChipsRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final String?             selected;
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
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(label: 'Tất cả', emoji: '🔍', isSelected: selected == null,
              onTap: () => onSelected(null)),
          ...categories.map((cat) => _Chip(
            label: cat.name, emoji: cat.icon, isSelected: selected == cat.id,
            onTap: () => onSelected(selected == cat.id ? null : cat.id),
          )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool   isSelected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.emoji, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x266C63FF), blurRadius: 6, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          )),
        ]),
      ),
    );
  }
}
