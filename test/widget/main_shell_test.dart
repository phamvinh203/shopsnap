import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/screens/shell/main_shell.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', email: 'minh@shopsnap.dev', name: 'Minh'),
      );
}

class _Body extends StatelessWidget {
  final String label;
  const _Body(this.label);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(
                path: '/',
                builder: (_, __) => const _Body('HOME_BODY')),
            GoRoute(
                path: '/summary',
                builder: (_, __) => const _Body('SUMMARY_BODY')),
            GoRoute(
                path: '/history',
                builder: (_, __) => const _Body('HISTORY_BODY')),
          ],
        ),
        GoRoute(path: '/add', builder: (_, __) => const _Body('ADD_BODY')),
        GoRoute(path: '/login', builder: (_, __) => const _Body('LOGIN_BODY')),
        GoRoute(
            path: '/budget',
            builder: (_, __) => const _Body('BUDGET_BODY')),
      ],
    );

Future<void> _pumpShell(
  WidgetTester tester, {
  required bool authenticated,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          authenticated
              ? _AuthenticatedAuthNotifier.new
              : _UnauthenticatedAuthNotifier.new,
        ),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Phase 4 (dark mode): sheet Cài đặt giờ chứa mục chọn theme, watch
    // themeModeProvider đọc SharedPreferences → mock plugin cho môi trường test.
    SharedPreferences.setMockInitialValues({});
  });

  group('MainShell (Phase 3b — AppBottomNav + auth gate mềm)', () {
    testWidgets('chuyển tab theo key appBottomNav_item_N, giữ nguyên 3 route',
        (tester) async {
      await _pumpShell(tester, authenticated: false);

      await tester.tap(find.byKey(const Key('appBottomNav_item_1')));
      await tester.pumpAndSettle();
      expect(find.text('SUMMARY_BODY'), findsOneWidget);

      await tester.tap(find.byKey(const Key('appBottomNav_item_2')));
      await tester.pumpAndSettle();
      expect(find.text('HISTORY_BODY'), findsOneWidget);

      await tester.tap(find.byKey(const Key('appBottomNav_item_0')));
      await tester.pumpAndSettle();
      expect(find.text('HOME_BODY'), findsOneWidget);
    });

    testWidgets('FAB giữa mở /add', (tester) async {
      await _pumpShell(tester, authenticated: false);

      await tester.tap(find.byKey(const Key('shell_fab')));
      await tester.pumpAndSettle();

      expect(find.text('ADD_BODY'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập: banner mời đăng nhập → push /login',
        (tester) async {
      await _pumpShell(tester, authenticated: false);

      expect(find.byKey(const Key('shell_loginBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('shell_loginBanner_action')));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_BODY'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập: sheet Cài đặt có mục Đăng nhập, không Đăng xuất',
        (tester) async {
      await _pumpShell(tester, authenticated: false);

      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell_settingsSheet_loginEntry')),
          findsOneWidget);
      expect(find.text('Cài đặt ngân sách'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsNothing);

      await tester
          .tap(find.byKey(const Key('shell_settingsSheet_loginEntry')));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_BODY'), findsOneWidget);
    });

    testWidgets('đã đăng nhập: ẩn banner, sheet có Đăng xuất',
        (tester) async {
      await _pumpShell(tester, authenticated: true);

      expect(find.byKey(const Key('shell_loginBanner')), findsNothing);

      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell_settingsSheet_loginEntry')),
          findsNothing);
      expect(find.text('Cài đặt ngân sách'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });
  });
}
