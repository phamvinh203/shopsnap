import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/screens/profile/profile_screen.dart';

/// F-#12 (AC 12.7) — toggle "Budget alerts" / "Price alerts" trong /profile:
/// render trạng thái đúng, persist local qua SharedPreferences (BE chưa có
/// endpoint preference → chỉ lưu máy này).
void main() {
  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: GoRouter(
            initialLocation: '/profile',
            routes: [
              GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SwitchListTile switchOf(WidgetTester tester, Key key) =>
      tester.widget<SwitchListTile>(find.byKey(key));

  testWidgets('section "Thông báo" hiện 2 toggle, mặc định BẬT khi chưa có lựa chọn',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    expect(find.byKey(const Key('profile_notificationSection')), findsOneWidget);
    expect(switchOf(tester, const Key('profile_budgetAlertsToggle')).value, isTrue);
    expect(switchOf(tester, const Key('profile_priceAlertsToggle')).value, isTrue);
  });

  testWidgets('tắt "Budget alerts" → persist false vào SharedPreferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    await tester.ensureVisible(find.byKey(const Key('profile_budgetAlertsToggle')));
    await tester.tap(find.byKey(const Key('profile_budgetAlertsToggle')));
    await tester.pumpAndSettle();

    expect(switchOf(tester, const Key('profile_budgetAlertsToggle')).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pref_notify_budget_alerts'), isFalse);
    // Toggle kia không bị ảnh hưởng.
    expect(switchOf(tester, const Key('profile_priceAlertsToggle')).value, isTrue);
  });

  testWidgets('bật lại "Price alerts" sau khi đã tắt → persist true',
      (tester) async {
    SharedPreferences.setMockInitialValues({'pref_notify_price_alerts': false});
    await pumpProfile(tester);

    // State khởi tạo từ prefs đã lưu → OFF.
    expect(switchOf(tester, const Key('profile_priceAlertsToggle')).value, isFalse);

    await tester.ensureVisible(find.byKey(const Key('profile_priceAlertsToggle')));
    await tester.tap(find.byKey(const Key('profile_priceAlertsToggle')));
    await tester.pumpAndSettle();

    expect(switchOf(tester, const Key('profile_priceAlertsToggle')).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pref_notify_price_alerts'), isTrue);
  });
}
