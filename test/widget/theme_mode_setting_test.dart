import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/theme_provider.dart';
import 'package:shopsnap/screens/profile/profile_screen.dart';

/// F-#10 (AC 10.5/10.6): appearance chuyển từ sheet Cài đặt (MainShell) sang
/// màn /profile. Test cũ bấm theo key `shell_settingsSheet_themeSection` đã
/// được rewrite: cùng các kịch bản, vị trí mới là ProfileScreen với keys
/// `profile_themeSection` / `profile_themeOption_*`.

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', email: 'minh@shopsnap.dev', name: 'Minh'),
      );
}

/// Pump app đúng cách ShopSnapApp wiring theme (Phase 4): light + darkTheme
/// cùng nguồn `buildAppTheme`, themeMode theo provider. Consumer đặt NGOÀI
/// MaterialApp để watch được themeModeProvider; router tạo MỘT lần (như
/// appRouterProvider trong app thật) — nếu tạo trong builder, mỗi lần
/// themeMode đổi sẽ dựng lại navigator và màn bị đóng.
Future<void> _pumpApp(WidgetTester tester) async {
  // Section Giao diện nằm sâu trong ListView của /profile — surface mặc định
  // 800x600 không build tới (lazy) → nới surface, reset sau test.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
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
        find.byKey(const Key('profile_themeSection')),
      ),
    ).brightness;

void main() {
  setUp(() {
    // themeModeProvider đọc SharedPreferences lúc build → mock plugin.
    SharedPreferences.setMockInitialValues({});
  });

  group('Dark mode (F-#10) — chọn theme trong màn /profile', () {
    testWidgets(
        'mở /profile có mục Giao diện; mặc định theo system (test env = light)',
        (tester) async {
      await _pumpApp(tester);

      expect(
        find.byKey(const Key('profile_themeSection')),
        findsOneWidget,
      );
      expect(find.text('Giao diện'), findsOneWidget);
      expect(_brightnessAtThemeSection(tester), Brightness.light);
    });

    testWidgets('AC 10.5: đổi theme bằng "Hệ thống" về ThemeMode.system',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('profile_themeOption_dark')));
      await tester.pumpAndSettle();
      expect(_brightnessAtThemeSection(tester), Brightness.dark);

      await tester.tap(find.byKey(const Key('profile_themeOption_system')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeController.prefKey), 'system');
    });

    testWidgets('chọn Tối → MaterialApp chuyển dark (AnimatedTheme 200ms → '
        'pumpAndSettle), chọn Sáng → quay lại light', (tester) async {
      await _pumpApp(tester);

      // Chọn "Tối" — key-based tap (memo redesign mục 5: control mới có Key).
      await tester.tap(find.byKey(const Key('profile_themeOption_dark')));
      await tester.pumpAndSettle(); // đợi AnimatedTheme 200ms lerp xong
      expect(_brightnessAtThemeSection(tester), Brightness.dark);

      // Chọn "Sáng" → light trở lại.
      await tester.tap(find.byKey(const Key('profile_themeOption_light')));
      await tester.pumpAndSettle();
      expect(_brightnessAtThemeSection(tester), Brightness.light);
    });

    testWidgets('lựa chọn trong /profile persist vào SharedPreferences',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('profile_themeOption_dark')));
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

      // Theme đọc từ profile screen (provider đã restore).
      expect(_brightnessAtThemeSection(tester), Brightness.dark);
    });
  });
}
