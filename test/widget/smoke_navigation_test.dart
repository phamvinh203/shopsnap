import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shopsnap/core/router/app_router.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/app_update_model.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/summary_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/database_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/summary_provider.dart';
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/add_item/add_item_screen.dart';
import 'package:shopsnap/screens/budget_settings/budget_settings_screen.dart';
import 'package:shopsnap/screens/history/history_screen.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/screens/shell/main_shell.dart';
import 'package:shopsnap/screens/summary/summary_screen.dart';
import 'package:shopsnap/services/update_service.dart';

/// SMOKE NAVIGATION qua ROUTER THẬT của app (QA regression 2026-09-14, vòng
/// sau redesign). Phủ mệnh đề còn thiếu trong DoD mục 3 của 03-qa-regression-
/// plan.md: "boot → Home → bottom nav 3 tab, FAB → /add, settings sheet →
/// /budget" — các file test hiện có chỉ phủ một phần:
/// - `app_router_soft_gate_test.dart`: router thật nhưng chỉ Home + /add (go).
/// - `main_shell_test.dart`: tap đủ nav/FAB nhưng với ROUTER GIẢ (body stub).
///
/// Bộ override(ne): auth CHƯA đăng nhập (auth gate mềm), các provider nặng
/// trả dữ liệu tĩnh, sqflite bị thay bằng future lỗi (HistoryScreen/BudgetScreen
/// phải hiện ErrorState thay vì crash — đúng hành vi restyle P3).
/// KHÔNG có request HTTP thật trong toàn bộ flow.

// ── Fakes (cùng pattern với app_router_soft_gate_test / home_screen_test) ────

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

// ── Harness ───────────────────────────────────────────────────────────────────

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      itemsProvider.overrideWith(() => _FakeItemsNotifier(const [])),
      categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
      budgetStatusProvider.overrideWith(() => _FixedBudgetStatusNotifier(null)),
      updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      // Summary: offline-first provider đọc sqflite → thay bằng model rỗng
      // (serverSummary/insights/aiAssistant tự trả null/[] khi chưa đăng nhập
      // nên không cần override — không có HTTP thật).
      summaryProvider.overrideWith(
        (ref, params) async => SummaryModel.empty(DateTime(2026, 9, 14)),
      ),
      // sqflite cần platform channel — trong widget test thì thay bằng future
      // lỗi để khẳng định History/Budget hiện ErrorState thay vì crash.
      databaseProvider.overrideWith(
        (ref) => Future<Database>.error(
          StateError('sqflite không khả dụng trong widget test'),
        ),
      ),
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

void main() {
  setUpAll(() async {
    // DateHelper.formatDate dùng locale 'vi_VN'.
    await initializeDateFormatting('vi_VN', null);
  });

  setUp(() {
    // MainShell/_ThemeModeSection watch themeModeProvider (SharedPreferences).
    SharedPreferences.setMockInitialValues({});
  });

  group('Smoke navigation — router thật (regression sau redesign)', () {
    testWidgets('boot chưa đăng nhập → MainShell + HomeScreen + banner đăng nhập',
        (tester) async {
      await _pumpApp(tester);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      // Auth gate mềm: không bị đá về /login, chỉ hiện banner mời đăng nhập.
      expect(find.byKey(const Key('shell_loginBanner')), findsOneWidget);
      // Home empty state với items rỗng + CTA (hợp đồng restyle P3a).
      expect(find.text('Chưa có gì hôm nay'), findsOneWidget);
    });

    testWidgets('bottom nav chuyển 3 tab thật: / → /summary → /history → /',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('appBottomNav_item_1')));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);
      expect(find.text('Tổng kết chi tiêu'), findsOneWidget);

      await tester.tap(find.byKey(const Key('appBottomNav_item_2')));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Lịch sử chi tiêu'), findsOneWidget);
      // DB không có trong test env → màn phải hiện ErrorState + Thử lại,
      // KHÔNG crash và KHÔNG hiện raw 'Lỗi: ...' (hợp đồng P3).
      expect(find.byKey(const Key('errorState')), findsWidgets);
      expect(find.textContaining('StateError'), findsNothing);

      await tester.tap(find.byKey(const Key('appBottomNav_item_0')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('FAB giữa → /add (router thật, route ngoài shell)',
        (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('shell_fab')));
      await tester.pumpAndSettle();

      expect(find.byType(AddItemScreen), findsOneWidget);
      expect(find.byKey(const Key('addItem_nameField')), findsOneWidget);
    });

    testWidgets('sheet Cài đặt → mục Cài đặt ngân sách → /budget',
        (tester) async {
      await _pumpApp(tester);

      // Item 3 của bottom nav là pseudo-tab mở sheet Cài đặt.
      await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
      await tester.pumpAndSettle();

      // Text 'Cài đặt' trùng 2 chỗ trong sheet (title + label khác) nên
      // assert sheet qua key của mục Hồ sơ (F-#10 — theme đã chuyển sang
      // /profile theo AC 10.6) + text đầy đủ của mục ngân sách.
      expect(
          find.byKey(const Key('shell_settingsSheet_profileEntry')),
          findsOneWidget);
      expect(find.text('Cài đặt ngân sách'), findsOneWidget);

      await tester.tap(find.text('Cài đặt ngân sách'));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetSettingsScreen), findsOneWidget);
      // DB lỗi trong test env → ErrorState thay vì crash (hợp đồng P3c).
      expect(find.byKey(const Key('budgetSettings_errorState')), findsOneWidget);
    });
  });
}
