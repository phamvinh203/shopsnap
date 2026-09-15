import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/logout_flow.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/ui.dart';

/// Shell của 3 tab chính (Trang chủ / Tổng kết / Lịch sử) + FAB giữa.
///
/// Auth gate MỀM (PO chốt 2026-09-14): khi CHƯA đăng nhập vẫn xem/sửa dữ liệu
/// local bình thường — chỉ hiện 1 banner mảnh mời đăng nhập, và trong sheet
/// Cài đặt thay mục "Đăng xuất" bằng mục "Đăng nhập". Khi đã đăng nhập, banner
/// tự ẩn (không chiếm chỗ).
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
    // watch (không read) — banner phải phản ứng ngay khi login/logout/401.
    final authenticated =
        ref.watch(authStateProvider).valueOrNull?.isAuthenticated == true;

    return Scaffold(
      body: Column(
        children: [
          if (!authenticated) const _LoginBanner(),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('shell_fab'),
        onPressed: () => context.push('/add'),
        child: const Icon(Icons.add_a_photo_outlined, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNav(
        currentIndex: idx,
        onTap: (i) {
          // Item 3 = "Cài đặt" — pseudo-tab mở sheet, không có route riêng
          // (F-#10: phần tài khoản/dữ liệu đã gom về /profile — sheet giữ lại
          // làm trạm trung chuyển nhanh).
          if (i == 3) {
            _showSettingsSheet(context, ref);
            return;
          }
          context.go(_tabs[i]);
        },
      ),
    );
  }

  // ── Sheet Cài đặt: tài khoản + ngân sách + đăng xuất ──────────────────────

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    // ref.read (không watch) — sheet tĩnh theo trạng thái lúc mở; khi auth
    // state đổi giữa chừng, MainShell build lại nhưng sheet không cần rebuild.
    final auth = ref.read(authStateProvider).valueOrNull;
    final authenticated = auth?.isAuthenticated == true;
    final user = auth?.user;

    AppBottomSheet.show<void>(
      context: context,
      title: 'Cài đặt',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: context.snap.tintPrimary,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: context.text.titleMedium
                      ?.copyWith(color: context.cs.primary),
                ),
              ),
              title: Text(user.displayName,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(user.email, style: context.text.bodySmall),
            ),
          // Auth gate mềm: chưa đăng nhập → mời đăng nhập thay vì đăng xuất.
          if (!authenticated)
            ListTile(
              key: const Key('shell_settingsSheet_loginEntry'),
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.login_rounded, color: context.cs.primary),
              title: const Text('Đăng nhập để đồng bộ dữ liệu'),
              subtitle: Text('Dữ liệu đang lưu trên máy này',
                  style: context.text.bodySmall),
              trailing: Icon(Icons.chevron_right,
                  color: context.cs.onSurfaceVariant),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/login');
              },
            ),
          // F-#10 (AC 10.6): appearance (Giao diện) đã CHUYỂN sang /profile —
          // sheet không còn tuỳ chọn theme để tránh 2 nơi cấu hình lệch nhau.
          ListTile(
            key: const Key('shell_settingsSheet_profileEntry'),
            contentPadding: EdgeInsets.zero,
            leading:
                Icon(Icons.person_outline_rounded, color: context.cs.primary),
            title: const Text('Hồ sơ & dữ liệu'),
            subtitle: Text('Tài khoản, đồng bộ, giao diện, xuất dữ liệu',
                style: context.text.bodySmall),
            trailing: Icon(Icons.chevron_right,
                color: context.cs.onSurfaceVariant),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/profile');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet_outlined,
                color: context.cs.primary),
            title: const Text('Cài đặt ngân sách'),
            trailing:
                Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/budget');
            },
          ),
          if (authenticated)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: context.snap.danger),
              title: Text('Đăng xuất',
                  style: context.text.titleSmall
                      ?.copyWith(color: context.snap.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                // Dùng chung luồng với /profile: confirm dialog (AC 10.7) +
                // cảnh báo pending changes (AC 10.8) trước khi xoá token.
                confirmAndLogout(context, ref);
              },
            ),
        ],
      ),
    );
  }
}

/// Banner mảnh mời đăng nhập khi chưa có token — nhỏ gọn, không chặn việc
/// dùng app (auth gate mềm). Bấm → push /login.
class _LoginBanner extends StatelessWidget {
  const _LoginBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Material(
      key: const Key('shell_loginBanner'),
      color: colors.tintPrimary,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.account_circle_outlined,
                size: 20, color: colors.onTintPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Đăng nhập để đồng bộ dữ liệu lên máy chủ',
                key: const Key('shell_loginBanner_text'),
                style: context.text.bodySmall
                    ?.copyWith(color: colors.onTintPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              key: const Key('shell_loginBanner_action'),
              onPressed: () => context.push('/login'),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
