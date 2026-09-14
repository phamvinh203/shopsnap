import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/theme_provider.dart';
import 'package:shopsnap/screens/shell/main_shell.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
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
            GoRoute(path: '/', builder: (_, __) => const _Body('HOME_BODY')),
          ],
        ),
      ],
    );

/// Pump app đúng cách ShopSnapApp wiring theme (Phase 4): light + darkTheme
/// cùng nguồn `buildAppTheme`, themeMode theo provider. Consumer đặt NGOÀI
/// MaterialApp để watch được themeModeProvider; router tạo MỘT lần (như
/// appRouterProvider trong app thật) — nếu tạo trong builder, mỗi lần
/// themeMode đổi sẽ dựng lại navigator và sheet bị đóng.
Future<void> _pumpApp(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      ],
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp.router(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode:
              ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
          routerConfig: router,
        );
      }),
    ),
  );
  await tester.pumpAndSettle();
}

Brightness _brightnessAtThemeSection(WidgetTester tester) => Theme.of(
      tester.element(
        find.byKey(const Key('shell_settingsSheet_themeSection')),
      ),
    ).brightness;

void main() {
  setUp(() {
    // themeModeProvider đọc SharedPreferences lúc build → mock plugin.
    SharedPreferences.setMockInitialValues({});
  });

  group('Dark mode (Phase 4) — chọn theme trong sheet Cài đặt', () {
    testWidgets(
        'mở sheet có mục Giao diện; mặc định theo system (test env = light)',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle(); // animation mở sheet

      expect(
        find.byKey(const Key('shell_settingsSheet_themeSection')),
        findsOneWidget,
      );
      expect(find.text('Giao diện'), findsOneWidget);
      expect(_brightnessAtThemeSection(tester), Brightness.light);
    });

    testWidgets('chọn Tối → MaterialApp chuyển dark (AnimatedTheme 200ms → '
        'pumpAndSettle), chọn Sáng → quay lại light', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle();

      // Chọn "Tối" — key-based tap (memo redesign mục 5: control mới có Key).
      await tester.tap(find.byKey(const Key('shell_themeOption_dark')));
      await tester.pumpAndSettle(); // đợi AnimatedTheme 200ms lerp xong
      expect(_brightnessAtThemeSection(tester), Brightness.dark);

      // Chọn "Sáng" → light trở lại.
      await tester.tap(find.byKey(const Key('shell_themeOption_light')));
      await tester.pumpAndSettle();
      expect(_brightnessAtThemeSection(tester), Brightness.light);
    });

    testWidgets('lựa chọn trong sheet persist vào SharedPreferences',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shell_themeOption_dark')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeController.prefKey), 'dark');
    });

    testWidgets('prefs đã lưu "dark" → app khởi động thẳng vào dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeModeController.prefKey: 'dark',
      });

      await _pumpApp(tester);

      // Chưa mở sheet — Theme đọc từ HOME_BODY (provider đã restore).
      final context = tester.element(find.text('HOME_BODY'));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });
}
