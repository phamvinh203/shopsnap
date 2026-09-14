import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/snap_colors.dart';

/// Item của bottom nav (icon + label) — mirror 4 mục của MainShell hiện có:
/// Trang chủ, Tổng kết, Lịch sử, Cài đặt. Vị trí FAB docked giữa do Scaffold
/// của screen quản lý (gap ở [AppBottomNav] giữ sẵn chỗ).
class AppBottomNavItem {
  final IconData icon;
  final String label;
  const AppBottomNavItem(this.icon, this.label);
}

/// Bottom nav restyle: BottomAppBar notched, cao 64, elevation 0 + hairline
/// top + floating shadow, item selected có pill tint + label w600.
///
/// KHÔNG wire vào MainShell ở phase này — chỉ là component mới (P3 mới thay).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<AppBottomNavItem> items = [
    AppBottomNavItem(Icons.home_outlined, 'Trang chủ'),
    AppBottomNavItem(Icons.bar_chart_outlined, 'Tổng kết'),
    AppBottomNavItem(Icons.history_outlined, 'Lịch sử'),
    AppBottomNavItem(Icons.settings_outlined, 'Cài đặt'),
  ];

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.snap;
    return Container(
      key: const Key('appBottomNav'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.hairline)),
        boxShadow: dark ? AppShadows.floatingDark : AppShadows.floating,
      ),
      child: BottomAppBar(
        color: context.cs.surface,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: AppSpacing.sm,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(index: 0, item: items[0], selected: currentIndex == 0, onTap: onTap),
              _NavItem(index: 1, item: items[1], selected: currentIndex == 1, onTap: onTap),
              // Gap cho FAB docked giữa (giống MainShell hiện có).
              const SizedBox(width: AppSizes.fabGap),
              _NavItem(index: 2, item: items[2], selected: currentIndex == 2, onTap: onTap),
              _NavItem(index: 3, item: items[3], selected: currentIndex == 3, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final AppBottomNavItem item;
  final bool selected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final color = selected ? colors.onTintPrimary : context.cs.onSurfaceVariant;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: context.text.labelSmall?.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );

    return InkWell(
      key: Key('appBottomNav_item_$index'),
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: selected
            ? BoxDecoration(
                color: colors.tintPrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              )
            : null,
        child: content,
      ),
    );
  }
}
