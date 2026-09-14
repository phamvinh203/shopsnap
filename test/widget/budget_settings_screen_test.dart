import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/providers/all_budgets_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/screens/budget_settings/budget_settings_screen.dart';

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

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => _categories;
}

BudgetStatus _status({
  String id = 'b1',
  int spent = 40000,
  int amount = 100000,
}) =>
    BudgetStatus(
      budget: BudgetModel(
        id: id,
        amount: amount,
        period: BudgetPeriod.day,
        startDate: '2026-09-14',
        endDate: '2026-09-14',
        isActive: true,
        createdAt: 0,
      ),
      spent: spent,
    );

/// Fake notifier: chỉ override `build` cho state + ghi nhận các thao tác
/// CRUD để test không chạm sqflite/API.
class _FakeAllBudgetsNotifier extends AllBudgetsNotifier {
  final List<BudgetStatus> budgets;
  _FakeAllBudgetsNotifier(this.budgets);

  int buildCalls = 0;
  int addCalls = 0;
  int? lastAddedAmount;
  int deleteCalls = 0;

  @override
  Future<List<BudgetStatus>> build() async {
    buildCalls++;
    return budgets;
  }

  @override
  Future<void> addBudget({
    required int amount,
    required BudgetPeriod period,
    String? categoryId,
  }) async {
    addCalls++;
    lastAddedAmount = amount;
  }

  @override
  Future<void> deleteBudget(String id) async {
    deleteCalls++;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeAllBudgetsNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allBudgetsProvider.overrideWith(() => notifier),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const BudgetSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('BudgetSettingsScreen (Phase 3c restyle)', () {
    testWidgets('data → budget card + progress bar semantic', (tester) async {
      final notifier = _FakeAllBudgetsNotifier([_status()]);
      await _pumpScreen(tester, notifier);

      expect(find.byKey(const Key('budgetSettings_card_b1')), findsOneWidget);
      expect(
          find.byKey(const Key('budgetSettings_progress_b1')), findsOneWidget);
      // 40.000đ / 100.000đ hiển thị qua CurrencyFormatter.
      expect(find.textContaining('40.000đ'), findsWidgets);
      expect(find.textContaining('100.000đ'), findsWidgets);
    });

    testWidgets('rỗng → EmptyState có CTA mở sheet thêm ngân sách',
        (tester) async {
      final notifier = _FakeAllBudgetsNotifier(const []);
      await _pumpScreen(tester, notifier);

      expect(
          find.byKey(const Key('budgetSettings_emptyState')), findsOneWidget);

      await tester.tap(find.byKey(const Key('emptyState_action')));
      await tester.pumpAndSettle();

      // Title của sheet là "Thêm ngân sách" — key nằm TRÊN widget Text nên
      // đọc `data` trực tiếp (text FAB cũng trùng chuỗi, không dùng find.text).
      final titleFinder = find.byKey(const Key('appBottomSheet_title'));
      expect(titleFinder, findsOneWidget);
      expect(tester.widget<Text>(titleFinder).data, 'Thêm ngân sách');
    });

    testWidgets('provider lỗi → ErrorState, Thử lại gọi lại provider',
        (tester) async {
      // Notifier luôn ném lỗi khi build.
      final errorNotifier = _ErrorAllBudgetsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allBudgetsProvider.overrideWith(() => errorNotifier),
            categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const BudgetSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('budgetSettings_errorState')), findsOneWidget);
      // Không còn render raw 'Lỗi: $e'.
      expect(find.textContaining('StateError'), findsNothing);
      expect(errorNotifier.buildCalls, 1);

      await tester.tap(find.byKey(const Key('errorState_retry')));
      await tester.pumpAndSettle();

      expect(errorNotifier.buildCalls, 2);
    });

    testWidgets('submit form amount rỗng → hiện lỗi rõ (fix bug validate '
        'im lặng), không gọi save', (tester) async {
      final notifier = _FakeAllBudgetsNotifier([_status()]);
      await _pumpScreen(tester, notifier);

      // Mở sheet qua FAB.
      await tester.tap(find.byKey(const Key('budgetSettings_fab')));
      await tester.pumpAndSettle();

      // Bấm lưu khi amount đang rỗng.
      await tester.tap(find.byKey(const Key('budgetSheet_submitButton')));
      await tester.pump();

      // Lỗi hiện dưới field + snackbar danger — KHÔNG còn im lặng.
      expect(find.text('Số tiền ngân sách phải lớn hơn 0'), findsWidgets);
      expect(find.byKey(const Key('appSnackBar')), findsOneWidget);
      // Sheet vẫn mở cho user sửa lại.
      expect(find.byKey(const Key('budgetSheet_submitButton')),
          findsOneWidget);
      // Không gọi save.
      expect(notifier.addCalls, 0);
    });

    testWidgets('submit form hợp lệ → gọi save đúng số tiền rồi đóng sheet',
        (tester) async {
      final notifier = _FakeAllBudgetsNotifier([_status()]);
      await _pumpScreen(tester, notifier);

      await tester.tap(find.byKey(const Key('budgetSettings_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('budgetSheet_amountField')), '500000');
      await tester.tap(find.byKey(const Key('budgetSheet_submitButton')));
      await tester.pumpAndSettle();

      expect(notifier.addCalls, 1);
      expect(notifier.lastAddedAmount, 500000);
      // Sheet đã đóng.
      expect(find.byKey(const Key('budgetSheet_submitButton')), findsNothing);
    });
  });
}

/// Notifier luôn lỗi — dùng cho nhánh ErrorState.
class _ErrorAllBudgetsNotifier extends AllBudgetsNotifier {
  int buildCalls = 0;

  @override
  Future<List<BudgetStatus>> build() async {
    buildCalls++;
    throw StateError('budgets down');
  }
}
