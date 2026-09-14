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
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/services/update_service.dart';

// ── Fakes (không chạm DAO/API thật) ───────────────────────────────────────────

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

ItemModel _item() => const ItemModel(
      id: 'i1',
      name: 'Cà phê',
      price: 25000,
      categoryId: 'cat_food',
      categoryName: 'Ăn uống',
      categoryIcon: '🍔',
      categoryColor: '#FF6B6B',
      createdAt: 1705302600000,
      updatedAt: 1705302600000,
    );

class _FakeItemsNotifier extends ItemsNotifier {
  final List<ItemModel> items;
  _FakeItemsNotifier(this.items);

  @override
  Future<List<ItemModel>> build() async => items;
}

/// Lưu ý Riverpod 2.x: `invalidate` CHẠY LẠI `build()` trên cùng notifier,
/// KHÔNG gọi lại factory của override → bộ đếm phải nằm trong `build()`.
int _itemsBuildCalls = 0;

class _ErrorItemsNotifier extends ItemsNotifier {
  @override
  Future<List<ItemModel>> build() async {
    _itemsBuildCalls++;
    throw StateError('DB down');
  }
}

int _budgetBuildCalls = 0;

class _ErrorBudgetStatusNotifier extends BudgetStatusNotifier {
  @override
  Future<BudgetStatus?> build() async {
    _budgetBuildCalls++;
    throw StateError('budget down');
  }
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

// ── Harness ───────────────────────────────────────────────────────────────────

BudgetStatus? _budget({int spent = 40000, int amount = 100000}) => BudgetStatus(
      budget: BudgetModel(
        id: 'b1',
        amount: amount,
        period: BudgetPeriod.day,
        startDate: '2026-09-14',
        endDate: '2026-09-14',
        isActive: true,
        createdAt: 0,
      ),
      spent: spent,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/add',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('ADD_SCREEN'))),
        ),
      ],
    );

Future<void> _pumpHome(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    // DateHelper.formatDate dùng locale 'vi_VN'.
    await initializeDateFormatting('vi_VN', null);
  });

  group('HomeScreen (Phase 3a restyle)', () {
    testWidgets('hiện hero card Còn lại + section header + chips + item list',
        (tester) async {
      await _pumpHome(tester, [
        itemsProvider.overrideWith(() => _FakeItemsNotifier([_item()])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider
            .overrideWith(() => _FixedBudgetStatusNotifier(_budget())),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ]);

      // Hero card: số tiền "Còn lại" (100.000 − 40.000) + % badge.
      expect(find.byKey(const Key('budgetProgressCard_remaining')),
          findsOneWidget);
      expect(find.textContaining('Còn lại: 60.000đ'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      // Section header + chips.
      // SectionHeader hiện overline HOA (INK LEDGER 3.11) — finder cập nhật theo chuỗi render mới.
      expect(find.text('HÔM NAY · 1 MẶT HÀNG'), findsOneWidget);
      expect(find.byKey(const Key('categoryChipsRow_all')), findsOneWidget);

      // Item card theo key convention P3a.
      expect(find.byKey(const Key('itemCard_i1')), findsOneWidget);
    });

    testWidgets('budget provider lỗi → ErrorState, Thử lại gọi lại provider',
        (tester) async {
      await _pumpHome(tester, [
        itemsProvider.overrideWith(() => _FakeItemsNotifier([_item()])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider.overrideWith(_ErrorBudgetStatusNotifier.new),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ]);

      expect(find.byKey(const Key('errorState')), findsWidgets);
      expect(_budgetBuildCalls, 1);

      await tester.tap(find.byKey(const Key('errorState_retry')).first);
      await tester.pumpAndSettle();

      expect(_budgetBuildCalls, greaterThanOrEqualTo(2));
      expect(find.byKey(const Key('errorState')), findsWidgets);
    });

    testWidgets('items provider lỗi → ErrorState, Thử lại gọi lại provider',
        (tester) async {
      await _pumpHome(tester, [
        itemsProvider.overrideWith(_ErrorItemsNotifier.new),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider
            .overrideWith(() => _FixedBudgetStatusNotifier(_budget())),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ]);

      expect(find.byKey(const Key('errorState')), findsWidgets);
      expect(_itemsBuildCalls, 1);

      await tester.tap(find.byKey(const Key('errorState_retry')).first);
      await tester.pumpAndSettle();

      expect(_itemsBuildCalls, 2);
      expect(find.byKey(const Key('errorState')), findsWidgets);
    });

    testWidgets('danh sách rỗng → EmptyState có CTA điều hướng tới /add',
        (tester) async {
      await _pumpHome(tester, [
        itemsProvider.overrideWith(() => _FakeItemsNotifier(const [])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider
            .overrideWith(() => _FixedBudgetStatusNotifier(_budget())),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ]);

      expect(find.byKey(const Key('emptyState')), findsOneWidget);
      expect(find.text('Thêm mặt hàng đầu tiên'), findsOneWidget);

      await tester.tap(find.byKey(const Key('emptyState_action')));
      await tester.pumpAndSettle();

      expect(find.text('ADD_SCREEN'), findsOneWidget);
    });

    testWidgets('tap item card mở ItemDetailSheet (sửa bug tap chết)',
        (tester) async {
      await _pumpHome(tester, [
        itemsProvider.overrideWith(() => _FakeItemsNotifier([_item()])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider
            .overrideWith(() => _FixedBudgetStatusNotifier(_budget())),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ]);

      await tester.tap(find.byKey(const Key('itemCard_i1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appBottomSheet_title')), findsOneWidget);
      expect(find.text('Sửa nhanh mặt hàng'), findsOneWidget);
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
      expect(find.byKey(const Key('itemDetailSheet_saveButton')), findsOneWidget);
      expect(find.byKey(const Key('itemDetailSheet_deleteButton')),
          findsOneWidget);
    });
  });
}
