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
import '../../screens/ocr/ocr_screen.dart';
import '../../screens/scan/scan_screen.dart';
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

      // 2. Chưa đăng nhập → chỉ cho phép /login và /register.
      if (!auth.isAuthenticated) return onAuthScreen ? null : '/login';

      // 3. Đã đăng nhập mà vào lại trang auth → về trang chủ.
      if (onAuthScreen) return '/';
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
    ],
  );
});
