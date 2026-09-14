import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/screens/auth/login_screen.dart';
import 'package:shopsnap/screens/auth/register_screen.dart';

/// AuthNotifier giả — login luôn trả 401 INVALID_CREDENTIALS.
class _InvalidCredentialsAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> login({required String email, required String password}) async {
    throw const ApiException(
      code: 'INVALID_CREDENTIALS',
      message: 'Unauthorized',
      statusCode: 401,
    );
  }
}

GoRouter _router() => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

Future<void> _pumpLogin(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LoginScreen (Phase 3b restyle)', () {
    testWidgets('submit form trống → validate chặn, KHÔNG gọi API/không lỗi server',
        (tester) async {
      await _pumpLogin(tester, const []);

      await tester.tap(find.byKey(const Key('loginScreen_submitButton')));
      await tester.pump();

      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(find.byKey(const Key('appSnackBar')), findsNothing);
    });

    testWidgets('sai mật khẩu (401) → hiện khối lỗi chuẩn, không raw exception',
        (tester) async {
      await _pumpLogin(tester, [
        authStateProvider.overrideWith(_InvalidCredentialsAuthNotifier.new),
      ]);

      await tester.enterText(
          find.byKey(const Key('loginScreen_emailField')), 'minh@shopsnap.dev');
      await tester.enterText(
          find.byKey(const Key('loginScreen_passwordField')), 'wrong-pass');
      await tester.tap(find.byKey(const Key('loginScreen_submitButton')));
      await tester.pumpAndSettle();

      // apiErrorMessage(ApiException INVALID_CREDENTIALS) → microcopy tiếng Việt.
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(find.byKey(const Key('appSnackBar_message')), findsOneWidget);

      // Cho snackbar chạy hết duration để không treo Timer khi kết thúc test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('link "Đăng ký" điều hướng sang /register', (tester) async {
      await _pumpLogin(tester, const []);

      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
    });
  });
}
