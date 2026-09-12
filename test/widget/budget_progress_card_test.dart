import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_colors.dart';
import 'package:shopsnap/screens/home/widgets/budget_progress_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('BudgetProgressCard', () {
    testWidgets('shows "Chưa đặt ngân sách" when total is 0', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 0, total: 0),
      ));
      expect(find.text('Chưa đặt ngân sách'), findsOneWidget);
    });

    testWidgets('shows spent and remaining amounts', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 40000, total: 100000),
      ));
      expect(find.textContaining('40.000'), findsOneWidget);
      expect(find.textContaining('60.000'), findsOneWidget);
    });

    testWidgets('shows percentage badge', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 50000, total: 100000),
      ));
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('progress indicator uses success color below 80%', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 50000, total: 100000),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.color, AppColors.success);
    });

    testWidgets('progress indicator uses warning color at 80%', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 80000, total: 100000),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.color, AppColors.warning);
    });

    testWidgets('progress indicator uses danger color at 100%', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 100000, total: 100000),
      ));
      await tester.pumpAndSettle();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.color, AppColors.danger);
    });

    testWidgets('shows 0% when no spending', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 0, total: 100000),
      ));
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('clamps remaining at 0 when overspent', (tester) async {
      await tester.pumpWidget(_wrap(
        const BudgetProgressCard(spent: 150000, total: 100000),
      ));
      await tester.pumpAndSettle();
      // Remaining display should show 0, not negative
      expect(find.textContaining('Còn lại: 0'), findsOneWidget);
    });
  });
}
