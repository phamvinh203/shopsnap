import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/theme/app_colors.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/ai_assistant_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/summary_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/summary_provider.dart';
import 'package:shopsnap/screens/summary/summary_screen.dart';

// ── Fakes (không chạm DAO/API thật — cùng pattern với home_screen_test) ──────

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

ItemModel _item() => const ItemModel(
      id: 'i1',
      name: 'Cà phê',
      price: 50000,
      categoryId: 'cat_food',
      categoryName: 'Ăn uống',
      categoryIcon: '🍔',
      categoryColor: '#FF6B6B',
      createdAt: 1705302600000,
      updatedAt: 1705302600000,
    );

SummaryModel _summary() => SummaryModel(
      date: DateTime(2026, 9, 14),
      totalSpent: 150000,
      itemCount: 3,
      categories: const [],
      items: [_item()],
    );

/// F-#2: summary CÓ categories — thứ tự gửi vào MỨT LOẠN để verify sort giảm dần.
SummaryModel _summaryWithCategories() => SummaryModel(
      date: DateTime(2026, 9, 14),
      totalSpent: 150000,
      itemCount: 3,
      categories: const [
        CategorySummary(
            categoryId: 'c3', categoryName: 'Giải trí', categoryIcon: '🎮',
            categoryColor: '#4B44CC', totalSpent: 20000, itemCount: 1),
        CategorySummary(
            categoryId: 'c1', categoryName: 'Ăn uống', categoryIcon: '🍔',
            categoryColor: '#FF6B6B', totalSpent: 80000, itemCount: 2),
        CategorySummary(
            categoryId: 'c2', categoryName: 'Đi lại', categoryIcon: '🚆',
            categoryColor: '#175E48', totalSpent: 50000, itemCount: 1),
      ],
      items: const [],
    );

/// F-#2: response server với comparison MoM.
SummaryResponse _serverResponse({
  required int previousSpent,
  double? changePercentage,
  String trend = 'up',
}) =>
    SummaryResponse(
      period: const SummaryPeriodInfo(
          type: 'month',
          startDate: '2026-09-01',
          endDate: '2026-09-30',
          label: 'Tháng 9'),
      totals: const SummaryTotals(
          totalSpent: 150000,
          totalItems: 3,
          totalTransactions: 3,
          averagePerDay: 5000,
          averagePerTransaction: 50000),
      budget: null,
      comparison: SummaryComparison(
        previousPeriodSpent: previousSpent,
        changeAmount: 50000,
        changePercentage: changePercentage,
        trend: trend,
      ),
      breakdown: const [],
    );

AiAssistantResponse _aiResponse() => const AiAssistantResponse(
      periodLabel: 'Tháng 9/2026',
      queryDate: '2026-09-14',
      prediction: SpendingPrediction(
        currentSpent: 150000,
        projectedSpent: 300000,
        isOverBudgetProjected: false,
        projectedOverAmount: 0,
        burnRatePerDay: 10000,
        safeDailyBudget: 25000,
        daysElapsed: 15,
        daysRemaining: 15,
        totalDays: 30,
        riskLevel: 'low',
      ),
      topCategories: [],
      aiAdvice: AiAdvice(summary: 'Chi tiêu ổn định', tips: []),
      source: 'gemini',
    );

/// Lưu ý Riverpod 2.x: `invalidate` chạy lại closure của override nên bộ đếm
/// phải nằm ngoài closure.
int _summaryBuildCalls = 0;

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SummaryScreen()),
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
      ],
    );

Future<void> _pumpSummary(
  WidgetTester tester, {
  required FutureOr<SummaryModel> Function() scenario,
}) async {
  await _pumpSummaryWithOverrides(tester, scenario: scenario);
}

/// F-#2: bản pump đầy đủ — cho phép override server comparison / tổng kỳ
/// trước local / AI provider để test từng trạng thái dashboard.
Future<void> _pumpSummaryWithOverrides(
  WidgetTester tester, {
  required FutureOr<SummaryModel> Function() scenario,
  SummaryResponse? Function()? server,
  FutureOr<int> Function()? previousLocal,
  FutureOr<AiAssistantResponse?> Function(String?)? ai,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        summaryProvider.overrideWith((ref, params) => scenario()),
        if (server != null)
          serverSummaryProvider.overrideWith((ref, params) => server()),
        if (previousLocal != null)
          previousPeriodTotalProvider
              .overrideWith((ref, params) => previousLocal()),
        if (ai != null)
          aiAssistantProvider.overrideWith((ref, dateStr) => ai(dateStr)),
      ],
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: _router()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // DateHelper dùng locale 'vi_VN'.
    await initializeDateFormatting('vi_VN', null);
  });

  setUp(() {
    _summaryBuildCalls = 0;
  });

  group('SummaryScreen (Phase 3c restyle)', () {
    testWidgets('data → hero tổng chi tiêu + danh sách vật phẩm',
        (tester) async {
      await _pumpSummary(tester, scenario: _summary);

      // Hero card: tổng 150.000đ tabular figures.
      expect(find.byKey(const Key('summaryScreen_heroCard')), findsOneWidget);
      expect(find.textContaining('150.000đ'), findsWidgets);

      // Item list kỳ day: 1 item với giá 50.000đ.
      expect(find.text('Cà phê'), findsOneWidget);
    });

    testWidgets('data rỗng → EmptyState có CTA điều hướng tới /add',
        (tester) async {
      await _pumpSummary(
        tester,
        scenario: () => SummaryModel.empty(DateTime(2026, 9, 14)),
      );

      expect(find.byKey(const Key('emptyState')), findsOneWidget);
      expect(find.text('Thêm mặt hàng'), findsOneWidget);

      await tester.tap(find.byKey(const Key('emptyState_action')));
      await tester.pumpAndSettle();

      expect(find.text('ADD_STUB'), findsOneWidget);
    });

    testWidgets('provider lỗi → ErrorState, Thử lại gọi lại provider',
        (tester) async {
      await _pumpSummary(tester, scenario: () async {
        _summaryBuildCalls++;
        throw StateError('summary down');
      });

      expect(find.byKey(const Key('errorState')), findsOneWidget);
      // Không còn render raw 'Lỗi: $e'.
      expect(find.textContaining('StateError'), findsNothing);
      expect(_summaryBuildCalls, 1);

      await tester.tap(find.byKey(const Key('errorState_retry')));
      await tester.pumpAndSettle();

      expect(_summaryBuildCalls, 2);
    });

    testWidgets('chưa đăng nhập bấm xuất CSV → snackbar mời đăng nhập có '
        'action điều hướng /login (auth gate mềm)', (tester) async {
      await _pumpSummary(tester, scenario: _summary);

      await tester.tap(find.byKey(const Key('summaryScreen_exportButton')));
      // Đợi snackbar trượt vào xong (animation) để action hit-test được.
      await tester.pumpAndSettle();

      // Snackbar chuẩn (AppSnackBar) có action Đăng nhập.
      expect(find.byKey(const Key('appSnackBar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('appSnackBar_action')));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_STUB'), findsOneWidget);
    });
  });

  group('SummaryScreen — F-#2 Spending Intelligence Dashboard', () {
    /// AC 2.1 là so sánh THÁNG → mở tab "Tháng" trước khi assert.
    Future<void> tapMonthTab(WidgetTester tester) async {
      await tester.tap(find.text('Tháng'));
      await tester.pumpAndSettle();
    }

    testWidgets('AC 2.1: header có chip MoM TĂNG — mũi tên lên + màu đỏ',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summary,
        server: () => _serverResponse(
            previousSpent: 100000, changePercentage: 50.0, trend: 'up'),
      );
      await tapMonthTab(tester);

      expect(find.byKey(const Key('summaryScreen_momChip')), findsOneWidget);
      expect(find.text('+50% so với tháng trước'), findsOneWidget);
      final icon = tester.widget<Icon>(find.descendant(
        of: find.byKey(const Key('summaryScreen_momChip')),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, Icons.trending_up);
      expect(icon.color, AppColors.danger); // tăng = ĐỎ (AC 2.1)
    });

    testWidgets('AC 2.1: MoM GIẢM → mũi tên xuống + màu xanh', (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summary,
        server: () => _serverResponse(
            previousSpent: 200000, changePercentage: -25.0, trend: 'down'),
      );
      await tapMonthTab(tester);

      expect(find.byKey(const Key('summaryScreen_momChip')), findsOneWidget);
      expect(find.text('-25% so với tháng trước'), findsOneWidget);
      final icon = tester.widget<Icon>(find.descendant(
        of: find.byKey(const Key('summaryScreen_momChip')),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, Icons.trending_down);
      expect(icon.color, AppColors.success); // giảm = XANH (AC 2.1)
    });

    testWidgets('AC 2.2: tháng trước chi 0đ → "Tháng mới bắt đầu", KHÔNG %',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summary,
        server: () => _serverResponse(
            previousSpent: 0, changePercentage: null, trend: 'up'),
      );

      expect(find.byKey(const Key('summaryScreen_momNew')), findsOneWidget);
      expect(find.text('Tháng mới bắt đầu'), findsOneWidget);
      expect(find.byKey(const Key('summaryScreen_momChip')), findsNothing);
      expect(find.textContaining('% so với tháng trước'), findsNothing);
    });

    testWidgets('AC 2.1 offline: không có server → MoM từ tổng kỳ trước local',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summary, // 150.000
        previousLocal: () => 300000, // kỳ trước 300.000 → giảm 50%
      );
      await tapMonthTab(tester);

      expect(find.byKey(const Key('summaryScreen_momChip')), findsOneWidget);
      expect(find.text('-50% so với tháng trước'), findsOneWidget);
    });

    testWidgets('AC 2.3: breakdown progress bar xếp GIẢM DẦN + % trên tổng',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summaryWithCategories, // gửi vào MỨT LOẠN
      );

      expect(find.byKey(const Key('summaryBreakdown_card')), findsOneWidget);

      // Thứ tự sau sort: Ăn uống (80k) → Đi lại (50k) → Giải trí (20k).
      double dyOf(String name) =>
          tester.getTopLeft(find.text(name)).dy;
      final dyFood = dyOf('Ăn uống');
      final dyMove = dyOf('Đi lại');
      final dyFun = dyOf('Giải trí');
      expect(dyFood < dyMove && dyMove < dyFun, isTrue,
          reason: 'breakdown phải xếp giảm dần theo số tiền');

      // % trên tổng từng dòng.
      expect(find.text('53%'), findsOneWidget); // 80k/150k
      expect(find.text('33%'), findsOneWidget); // 50k/150k
      expect(find.text('13%'), findsOneWidget); // 20k/150k

      // Bar: value tỉ lệ với tổng, dòng đầu lớn nhất.
      double valueOf(int i) => tester.widget<LinearProgressIndicator>(
          find.byKey(Key('summaryBreakdown_bar_$i'))).value!;
      expect(valueOf(0), greaterThan(valueOf(1)));
      expect(valueOf(1), greaterThan(valueOf(2)));
      expect(valueOf(0), closeTo(80000 / 150000, 0.001));
    });

    testWidgets('AC 2.5: AI call THẤT BẠI → heuristic fallback card (không bỏ trống)',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summaryWithCategories,
        ai: (date) => throw Exception('AI down'),
      );

      expect(find.byKey(const Key('aiInsight_fallback')), findsOneWidget);
      expect(
        find.text(
            'Ăn uống chiếm 53% chi tiêu, cao nhất tháng này'), // mom null (offline)
        findsOneWidget,
      );
    });

    testWidgets('AC 2.6: AI đang xử lý → skeleton RIÊNG, hero + breakdown vẫn render',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summaryWithCategories,
        ai: (date) => Completer<AiAssistantResponse?>().future, // chưa xong
        settle: false, // không settle — AI vĩnh viễn loading
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('aiInsight_loading')), findsOneWidget);
      // Các phần khác KHÔNG chờ AI.
      expect(find.byKey(const Key('summaryScreen_heroCard')), findsOneWidget);
      expect(find.byKey(const Key('summaryBreakdown_card')), findsOneWidget);
    });

    testWidgets('AI thành công → AiAssistantCard hiển thị nội dung AI',
        (tester) async {
      await _pumpSummaryWithOverrides(
        tester,
        scenario: _summary,
        ai: (date) => _aiResponse(),
      );

      expect(find.text('Trợ lý AI Tài Chính'), findsOneWidget);
      expect(find.byKey(const Key('aiInsight_fallback')), findsNothing);
    });
  });
}
