import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/providers/all_budgets_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/screens/budget_settings/budget_settings_screen.dart';
import 'package:shopsnap/screens/home/widgets/budget_progress_card.dart';

import 'ui/helpers.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _monthStart = DateTime(2026, 9, 1);
final _monthEnd = DateTime(2026, 9, 30);

Future<void> _pumpCard(
  WidgetTester tester, {
  required int spent,
  required int total,
  required DateTime? periodStart,
  required DateTime? periodEnd,
  required DateTime? now,
}) async {
  await tester.pumpWidget(wrapWithAppTheme(
    BudgetProgressCard(
      key: const Key('budgetProgressCard'),
      spent: spent,
      total: total,
      periodStart: periodStart,
      periodEnd: periodEnd,
      now: now,
    ),
  ));
  await tester.pumpAndSettle();
}

// ── AC 3.9 fixtures: BudgetSettingsScreen với 1 ngân sách category ───────────

class _FakeAllBudgetsNotifier extends AllBudgetsNotifier {
  final List<BudgetStatus> budgets;
  _FakeAllBudgetsNotifier(this.budgets);

  @override
  Future<List<BudgetStatus>> build() async => budgets;
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [];
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('BudgetProgressCard + Smart Budget (F-#3)', () {
    testWidgets('giữa tháng, trong hạn: đủ burn rate / safe daily / forecast + dòng tích cực (AC 3.1, 3.2, 3.5, 3.10)',
        (tester) async {
      // spent 100k sau 10 ngày → burn 10k/ngày, forecast 300k ≤ 600k.
      await _pumpCard(
        tester,
        spent: 100000,
        total: 600000,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 10),
      );

      expect(find.byKey(const Key('budgetInsights_strip')), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_burnRate')), findsOneWidget);
      expect(find.text('Đã chi TB 10000.0đ/ngày'), findsOneWidget); // 1 chữ số thập phân
      expect(find.byKey(const Key('budgetInsights_safeDaily')), findsOneWidget);
      expect(find.text('Có thể chi ~25.000đ/ngày'), findsOneWidget); // 500k/20 ngày
      expect(find.byKey(const Key('budgetInsights_forecast')), findsOneWidget);
      expect(find.text('Dự phóng cuối kỳ ~300.000đ'), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_okLine')), findsOneWidget);
      expect(find.text('Đang đúng tốc độ'), findsOneWidget);
      // Không có cảnh báo nào.
      expect(find.byKey(const Key('budgetInsights_overWarning')), findsNothing);
      expect(find.byKey(const Key('budgetInsights_forecastWarning')), findsNothing);
    });

    testWidgets('chi vượt budget → cảnh báo ĐỎ + số vượt, KHÔNG safe daily âm (AC 3.3)',
        (tester) async {
      await _pumpCard(
        tester,
        spent: 700000,
        total: 600000,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 10),
      );

      expect(find.byKey(const Key('budgetInsights_overWarning')), findsOneWidget);
      expect(find.text('Đã vượt ngân sách 100.000đ'), findsOneWidget);
      // Không hiện số âm — safe daily biến mất hẳn.
      expect(find.byKey(const Key('budgetInsights_safeDaily')), findsNothing);
    });

    testWidgets('forecast vượt budget → cảnh báo VÀNG "~X đ" (AC 3.4)', (tester) async {
      // spent 250k sau 10 ngày → forecast 750k > 600k → vượt ~150k.
      await _pumpCard(
        tester,
        spent: 250000,
        total: 600000,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 10),
      );
      expect(find.byKey(const Key('budgetInsights_forecastWarning')), findsOneWidget);
      expect(find.text('Dự kiến vượt ~150.000đ'), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_overWarning')), findsNothing);
    });

    testWidgets('ngày đầu kỳ chưa chi gì → forecast 0, KHÔNG bất kỳ warning nào (AC 3.6)',
        (tester) async {
      await _pumpCard(
        tester,
        spent: 0,
        total: 600000,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 1, 7, 30),
      );

      expect(find.byKey(const Key('budgetInsights_strip')), findsOneWidget);
      expect(find.text('Dự phóng cuối kỳ ~0đ'), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_overWarning')), findsNothing);
      expect(find.byKey(const Key('budgetInsights_forecastWarning')), findsNothing);
      expect(find.byKey(const Key('budgetInsights_okLine')), findsNothing);
    });

    testWidgets('ngày CUỐI kỳ → ẩn toàn bộ insights, không chia 0 (AC 3.7)',
        (tester) async {
      await _pumpCard(
        tester,
        spent: 500000,
        total: 600000,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 30, 23, 0),
      );

      expect(find.byKey(const Key('budgetInsights_strip')), findsNothing);
      // Card gốc vẫn render bình thường.
      expect(find.byKey(const Key('budgetProgressCard')), findsOneWidget);
      expect(find.textContaining('Còn lại: 100.000đ'), findsOneWidget);
    });

    testWidgets('KHÔNG truyền kỳ (caller cũ) → card giữ nguyên contract, không strip',
        (tester) async {
      await _pumpCard(
        tester,
        spent: 40000,
        total: 100000,
        periodStart: null,
        periodEnd: null,
        now: null,
      );

      expect(find.byKey(const Key('budgetProgressCard')), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_strip')), findsNothing);
      expect(find.byKey(const Key('budgetProgressCard_percent')), findsOneWidget);
    });

    testWidgets('chưa đặt ngân sách (total = 0) → không insights', (tester) async {
      await _pumpCard(
        tester,
        spent: 0,
        total: 0,
        periodStart: _monthStart,
        periodEnd: _monthEnd,
        now: DateTime(2026, 9, 10),
      );

      expect(find.text('Chưa đặt ngân sách'), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_strip')), findsNothing);
    });
  });

  group('BudgetSettingsScreen — category budget cùng bộ chỉ số (AC 3.9)', () {
    testWidgets('ngân sách monthly theo category → card hiện burn/safe/forecast',
        (tester) async {
      const categoryBudget = BudgetStatus(
        budget: BudgetModel(
          id: 'b-cat',
          amount: 600000,
          period: BudgetPeriod.month,
          categoryId: 'cat_food',
          startDate: '2026-09-01',
          endDate: '2026-09-30',
          isActive: true,
          createdAt: 0,
        ),
        spent: 300000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allBudgetsProvider.overrideWith(() => _FakeAllBudgetsNotifier([
                  categoryBudget,
                ])),
            categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
          ],
          child: wrapWithAppTheme(const BudgetSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budgetSettings_card_b-cat')), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_strip')), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_burnRate')), findsOneWidget);
      expect(find.byKey(const Key('budgetInsights_safeDaily')), findsOneWidget);
    });
  });
}
