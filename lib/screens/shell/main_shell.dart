import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  static const _tabs = ['/', '/summary', '/history'];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = _tabs.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.bgCard,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_outlined,     label: 'Trang chủ', selected: idx == 0, onTap: () => context.go('/')),
            _NavItem(icon: Icons.bar_chart_outlined, label: 'Tổng kết',  selected: idx == 1, onTap: () => context.go('/summary')),
            const SizedBox(width: 60), // FAB gap
            _NavItem(icon: Icons.history_outlined,  label: 'Lịch sử',   selected: idx == 2, onTap: () => context.go('/history')),
            _NavItem(icon: Icons.settings_outlined, label: 'Cài đặt',   selected: false,    onTap: () => context.push('/budget')),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}
