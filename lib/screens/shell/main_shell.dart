import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  static const _tabs = ['/', '/summary', '/history'];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = _tabs.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _NavItem(icon: Icons.settings_outlined, label: 'Cài đặt',   selected: false,    onTap: () => _showSettingsSheet(context, ref)),
          ],
        ),
      ),
    );
  }

  // ── Sheet Cài đặt: tài khoản + ngân sách + đăng xuất ──────────────────────

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    // ref.read (không watch) — sheet không cần rebuild theo auth state
    final user = ref.read(authStateProvider).valueOrNull?.user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tay cầm sheet
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (user != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(user.email,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                title: const Text('Cài đặt ngân sách'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/budget');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                title: const Text('Đăng xuất',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmLogout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn chắc chắn muốn đăng xuất khỏi ShopSnap?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      // authStateProvider đổi → router redirect về /login
    }
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
