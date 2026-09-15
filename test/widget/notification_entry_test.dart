import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/app_update_model.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/notification_provider.dart';
import 'package:shopsnap/providers/shopping_list_provider.dart';
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/services/update_service.dart';

/// F-#12 — Bell icon + badge unread trên app bar Home (AC 12.8) và banner
/// hướng dẫn bật quyền notification (AC 12.13).

const _categories = [
  CategoryModel(
    id: 'cat_food',
    name: 'Ăn uống',
    icon: '🍔',
    color: '#FF6B6B',
    isDefault: true,
    sortOrder: 0,
    createdAt: 0,
  ),
];

class _FakeItemsNotifier extends ItemsNotifier {
  _FakeItemsNotifier(this.items);
  final List<ItemModel> items;

  @override
  Future<List<ItemModel>> build() async => items;
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => _categories;
}

class _FixedBudgetStatusNotifier extends BudgetStatusNotifier {
  _FixedBudgetStatusNotifier();
  @override
  Future<BudgetStatus?> build() async => null;
}

class _FakeUpdateService extends UpdateService {
  @override
  Future<AppUpdateInfo> checkForUpdate({bool forceRefresh = false}) async =>
      AppUpdateInfo.noUpdate('1.0.0');
}

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/notifications',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('NOTIFICATIONS_STUB'))),
        ),
      ],
    );

Future<void> _pumpHome(
  WidgetTester tester, {
  int unread = 0,
  bool permissionDenied = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => _FakeItemsNotifier(const [])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider.overrideWith(_FixedBudgetStatusNotifier.new),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
        unreadNotificationsCountProvider.overrideWith((ref) async => unread),
        shoppingListUnseenAlertsProvider.overrideWith((ref) async => 0),
        notificationPermissionDeniedProvider
            .overrideWith((ref) => permissionDenied),
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
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('AC 12.8 — bell icon trên app bar Home, badge hiển thị số chưa đọc',
      (tester) async {
    await _pumpHome(tester, unread: 3);

    expect(find.byKey(const Key('homeScreen_notificationBell')), findsOneWidget);
    expect(find.byKey(const Key('homeScreen_notificationBadge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('AC 12.8 — unread = 0 → badge biến mất', (tester) async {
    await _pumpHome(tester, unread: 0);

    expect(find.byKey(const Key('homeScreen_notificationBell')), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('AC 12.9 — bấm bell → mở Notification Feed', (tester) async {
    await _pumpHome(tester, unread: 2);

    await tester.tap(find.byKey(const Key('homeScreen_notificationBell')));
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS_STUB'), findsOneWidget);
  });

  testWidgets('AC 12.13 — bị chặn quyền → banner hướng dẫn + nút mở cài đặt, dismiss được',
      (tester) async {
    await _pumpHome(tester, permissionDenied: true);

    expect(
        find.byKey(const Key('homeNotificationPermissionBanner')), findsOneWidget);
    expect(
        find.byKey(const Key('homeNotificationPermissionSettings')), findsOneWidget);
    expect(find.text('Mở cài đặt'), findsOneWidget);

    // Dismiss → banner biến mất (không gọi openAppSettings, không crash).
    await tester.tap(find.byKey(const Key('homeNotificationPermissionDismiss')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('homeNotificationPermissionBanner')), findsNothing);
  });

  testWidgets('AC 12.13 — có quyền → KHÔNG hiển thị banner', (tester) async {
    await _pumpHome(tester, permissionDenied: false);

    expect(
        find.byKey(const Key('homeNotificationPermissionBanner')), findsNothing);
  });
}
