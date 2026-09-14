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
        // Top rule 1.2px: light = MỰC (đường kẻ đậm — signature), dark =
        // hairline. Dark phân tách bằng border, không shadow (3.7).
        border: Border(
          top: BorderSide(
            color: dark ? colors.hairline : colors.textPrimary,
            width: 1.2,
          ),
        ),
        boxShadow: dark ? AppShadows.floatingDark : AppShadows.floating,
      ),
      child: BottomAppBar(
        color: context.cs.surface,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        // Notch ôm FAB vuông-bo: 8 → 10 (bảng 3.7).
        notchMargin: 10,
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
    // Selected = pill LIME, chữ/icon ink w600 (highlighter); unselected =
    // textSecondary. Icon 22 theo spec (3.7).
    final color =
        selected ? colors.onAccent : context.cs.onSurfaceVariant;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    // Highlighter swipe cho pill lime (2.7), gate a11y.
    final noMotion = MediaQuery.disableAnimationsOf(context);
    final sweep = noMotion ? (selected ? 1.0 : 0.0) : null;

    return InkWell(
      key: Key('appBottomNav_item_$index'),
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(children: [
            Positioned.fill(
              child: IgnorePointer(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: sweep ?? value,
                  heightFactor: 1,
                  child: ColoredBox(color: colors.accent),
                ),
              ),
            ),
            child!,
          ]),
        ),
        child: content,
      ),
    );
  }
}
