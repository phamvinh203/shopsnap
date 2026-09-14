import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/router/app_router.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/app_update_model.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/auth/login_screen.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/screens/shell/main_shell.dart';
import 'package:shopsnap/services/update_service.dart';

// ── Fakes (không chạm DAO/API thật — cùng pattern với home_screen_test) ──────

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
  final List<ItemModel> items;
  _FakeItemsNotifier(this.items);

  @override
  Future<List<ItemModel>> build() async => items;
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => _categories;
}

class _FixedBudgetStatusNotifier extends BudgetStatusNotifier {
  final BudgetStatus? status;
  _FixedBudgetStatusNotifier(this.status);

  @override
  Future<BudgetStatus?> build() async => status;
}

/// Chặn call GitHub thật từ initState của HomeScreen.
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

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', email: 'minh@shopsnap.dev', name: 'Minh'),
      );
}

// ── Harness: dùng ROUTER THẬT của app, chỉ override provider nặng ────────────

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required bool authenticated,
}) async {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(
        authenticated
            ? _AuthenticatedAuthNotifier.new
            : _UnauthenticatedAuthNotifier.new,
      ),
      itemsProvider.overrideWith(() => _FakeItemsNotifier(const [])),
      categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
      budgetStatusProvider.overrideWith(() => _FixedBudgetStatusNotifier(null)),
      updateServiceProvider.overrideWithValue(_FakeUpdateService()),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

/// Router guard cũ (wave1) ép redirect mọi route về /login khi chưa đăng nhập.
/// PO đã chốt AUTH GATE MỀM (biên bản redesign 2026-09-14 mục 5.1): cho phép
/// dùng app local-only không cần đăng nhập → các test guard cũ bị thay bởi
/// nhóm test này với hành vi mới.
void main() {
  setUpAll(() async {
    // DateHelper.formatDate dùng locale 'vi_VN'.
    await initializeDateFormatting('vi_VN', null);
  });

  group('AppRouter — auth gate MỀM (PO chốt 2026-09-14)', () {
    testWidgets('chưa đăng nhập vẫn vào được Home (không bị đá về /login)',
        (tester) async {
      await _pumpApp(tester, authenticated: false);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      // Affordance đăng nhập nhỏ gọn ở shell, không chặn việc dùng app.
      expect(find.byKey(const Key('shell_loginBanner')), findsOneWidget);
    });

    testWidgets('chưa đăng nhập bấm affordance đăng nhập → /login',
        (tester) async {
      await _pumpApp(tester, authenticated: false);

      await tester.tap(find.byKey(const Key('shell_loginBanner_action')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('chưa đăng nhập vẫn mở được /add (thêm mặt hàng offline)',
        (tester) async {
      final router = await _pumpApp(tester, authenticated: false);

      router.go('/add');
      await tester.pumpAndSettle();

      expect(find.text('Thêm mặt hàng'), findsOneWidget);
      expect(find.byKey(const Key('addItem_nameField')), findsOneWidget);

      // Nút lưu nằm cuối ListView (lazy build) → cuộn tới rồi assert.
      // (Scrollable đầu tiên là của ListView — các TextField cũng có Scrollable riêng.)
      await tester.scrollUntilVisible(
        find.byKey(const Key('addItem_saveButton')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('addItem_saveButton')), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('đã đăng nhập vào /login → redirect về trang chủ',
        (tester) async {
      final router = await _pumpApp(tester, authenticated: true);

      router.go('/login');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
