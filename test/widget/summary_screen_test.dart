import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        summaryProvider.overrideWith((ref, params) => scenario()),
      ],
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
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
}
