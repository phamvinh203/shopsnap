import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/add_item/add_item_screen.dart';
import '../../screens/ar_sticker/ar_sticker_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/budget_settings/budget_settings_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/notifications/notification_feed_screen.dart';
import '../../screens/ocr/ocr_screen.dart';
import '../../screens/profile/export_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/recurring/recurring_screen.dart';
import '../../screens/scan/scan_screen.dart';
import '../../screens/shopping_list/shopping_list_screen.dart';
import '../../screens/summary/summary_screen.dart';
import '../../screens/shell/main_shell.dart';

/// Router lắng nghe [authStateProvider] — mỗi lần trạng thái auth đổi,
/// go_router chạy lại redirect (refreshListenable).
final appRouterProvider = Provider<GoRouter>((ref) {
  // Bộ đếm tăng mỗi khi auth state đổi → go_router đánh giá lại redirect
  final authListener = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => authListener.value++);
  ref.onDispose(authListener.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListener,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider).valueOrNull ?? const AuthState.restoring();
      final loc  = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/register';

      // 1. Đang khôi phục session lúc mở app → cho route hiện tại đi qua,
      //    khi restore xong (state đổi) → redirect được chạy lại tự động.
      if (auth.status == AuthStatus.restoring) return null;

      // 2. AUTH GATE MỀM (PO chốt 2026-09-14, biên bản redesign mục 5.1):
      //    cho phép dùng app KHÔNG đăng nhập — dữ liệu local (sqflite) vẫn xem
      //    và sửa được offline. Không còn redirect ép về /login; các affordance
      //    cần tài khoản (đồng bộ, đóng góp barcode, đăng xuất…) tự điều hướng
      //    về /login ở tầng UI (MainShell banner/sheet, guard sẵn trong
      //    AddItemScreen cho suggest/contribute).
      //
      //    Refresh-token/401 flow giữ nguyên: khi ApiClient báo session hết hạn
      //    (refresh hỏng), authStateProvider về unauthenticated →
      //    refreshListenable chạy lại redirect — giờ chỉ ẩn affordance và hiện
      //    banner đăng nhập, không đá user đang đứng giữa app ra /login.

      // 3. Đã đăng nhập mà vào lại trang auth → về trang chủ.
      if (auth.isAuthenticated && onAuthScreen) return '/';
      return null;
    },
    routes: [
      // ── Auth (ngoài shell — không có bottom nav) ──────────────────────────
      GoRoute(path: '/login',    builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/',        builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/summary', builder: (c, s) => const SummaryScreen()),
          GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
        ],
      ),
      GoRoute(path: '/add',    builder: (c, s) => const AddItemScreen()),
      GoRoute(path: '/scan',   builder: (c, s) => const ScanScreen()),
      GoRoute(path: '/ocr',    builder: (c, s) => const OcrScreen()),
      GoRoute(path: '/ar',     builder: (c, s) => const ArStickerScreen()),
      GoRoute(path: '/budget', builder: (c, s) => const BudgetSettingsScreen()),
      // F-#10: Hồ sơ & dữ liệu — mở từ app bar Home + settings sheet, KHÔNG
      // thêm bottom nav tab (shell giữ nguyên 3 tab). Ngoài shell → có AppBar
      // back riêng. Auth gate mềm: chưa đăng nhập vẫn mở được.
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      // F-#11: entry từ section Export của /profile.
      GoRoute(path: '/export', builder: (c, s) => const ExportScreen()),
      // M-2: Khoản định kỳ — entry từ section "Dữ liệu local" của /profile
      // (spec Notes — [ASSUMPTION] vị trí entry point), KHÔNG thêm bottom-nav
      // tab. Ngoài shell → có AppBar back riêng. Cũng là đích deep-link khi
      // user bấm recurring reminder (AC 4.13, qua whitelist
      // parseNotificationRoute — NotificationService.onNotificationTap).
      GoRoute(path: '/recurring', builder: (c, s) => const RecurringScreen()),
      // F-#6: Danh sách mua — entry từ app bar Home (không thêm bottom-nav
      // tab). Ngoài shell → có AppBar back riêng. Offline hoàn toàn, auth gate
      // mềm: chưa đăng nhập vẫn dùng được.
      GoRoute(
        path: '/shopping-list',
        // AC 12.5 — deep-link từ price alert: `?item=<id>` để màn list
        // scroll-to + highlight đúng món user vừa được thông báo.
        builder: (c, s) => ShoppingListScreen(
          highlightItemId: s.uri.queryParameters['item'],
        ),
      ),
      // F-#12: Notification Feed — entry từ bell icon app bar Home. Ngoài
      // shell → có AppBar back riêng. Cũng là đích deep-link khi user bấm
      // notification hệ thống (AC 12.5, qua NotificationService.onNotificationTap).
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationFeedScreen(),
      ),
    ],
  );
});
