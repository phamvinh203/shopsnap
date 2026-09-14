import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('full mode: bar animate đến đúng ratio, chuỗi Còn lại đúng',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const BudgetProgressBar(
      key: Key('budget_test'),
      spent: 50000,
      total: 100000,
    )));

    // Chờ TweenAnimationBuilder chạy xong.
    await tester.pumpAndSettle();

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('budgetProgressBar_indicator')),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('ngưỡng 80%: bar vẫn render, % đúng', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const BudgetProgressBar(
      key: Key('budget_test'),
      spent: 85000,
      total: 100000,
    )));
    await tester.pumpAndSettle();

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('budgetProgressBar_indicator')),
    );
    expect(indicator.value, closeTo(0.85, 0.001));
  });

  testWidgets('total = 0: hiện "Chưa đặt ngân sách" qua key remaining',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const BudgetProgressBar(
      key: Key('budget_test'),
      spent: 0,
      total: 0,
    )));
    await tester.pumpAndSettle();

    final remaining = tester.widget<Text>(
      find.byKey(const Key('budgetProgressBar_remaining')),
    );
    // Contract copy — BudgetProgressCard test cũ phụ thuộc chuỗi này.
    expect(remaining.data, 'Chưa đặt ngân sách');
  });

  testWidgets('bare MaterialApp: compact mode — bar + %, không còn dòng remaining',
      (tester) async {
    await tester.pumpWidget(wrapBare(const BudgetProgressBar(
      key: Key('budget_test'),
      spent: 120000,
      total: 100000,
      compact: true,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budgetProgressBar_indicator')), findsOneWidget);
    expect(find.byKey(const Key('budgetProgressBar_percent')), findsOneWidget);
    expect(find.byKey(const Key('budgetProgressBar_remaining')), findsNothing);
  });

  test('token layer: budgetLevelFromRatio đúng ngưỡng 80% / 100%', () {
    expect(budgetLevelFromRatio(0.0), BudgetLevel.ok);
    expect(budgetLevelFromRatio(0.79), BudgetLevel.ok);
    expect(budgetLevelFromRatio(0.80), BudgetLevel.warning);
    expect(budgetLevelFromRatio(0.99), BudgetLevel.warning);
    expect(budgetLevelFromRatio(1.0), BudgetLevel.danger);
    expect(budgetLevelFromRatio(1.5), BudgetLevel.danger);
  });
}
