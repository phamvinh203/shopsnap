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
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/profile_provider.dart';
import 'package:shopsnap/providers/sync_provider.dart';
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/screens/profile/profile_screen.dart';
import 'package:shopsnap/services/sync_engine.dart';
import 'package:shopsnap/services/update_service.dart';

/// AC 10.1 — bấm avatar/icon ở app bar (header) màn hình chính → mở /profile.
/// Harness override đúng bộ provider nặng của HomeScreen (pattern
/// home_screen_test); ProfileScreen render THẬT để khẳng định điều hướng.

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
  @override
  Future<List<ItemModel>> build() async => const [];
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => _categories;
}

class _FixedBudgetStatusNotifier extends BudgetStatusNotifier {
  @override
  Future<BudgetStatus?> build() async => null;
}

class _FakeUpdateService extends UpdateService {
  @override
  Future<AppUpdateInfo> checkForUpdate({bool forceRefresh = false}) async =>
      AppUpdateInfo.noUpdate('1.0.0');
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(super.ref) {
    state = const SyncUIState(status: SyncStatus.idle, pendingCount: 0);
  }
}

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        itemsProvider.overrideWith(_FakeItemsNotifier.new),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider.overrideWith(_FixedBudgetStatusNotifier.new),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
        syncProvider.overrideWith(_FakeSyncNotifier.new),
        localDataStatsProvider.overrideWith(
          (ref) async =>
              const LocalDataStats(items: 0, products: 0, priceHistories: 0),
        ),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: GoRouter(initialLocation: '/', routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
              path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/login',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
          ),
          GoRoute(
            path: '/add',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('ADD_STUB'))),
          ),
        ]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('AC 10.1: bấm icon hồ sơ ở header Home → mở màn /profile',
      (tester) async {
    await _pumpHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('homeScreen_profileButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeScreen_profileButton')));
    await tester.pumpAndSettle();

    // Màn profile thật render với 6 section (ít nhất section account).
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('profile_accountLoggedOut')), findsOneWidget);
    expect(find.text('Hồ sơ & dữ liệu'), findsOneWidget);
  });
}
