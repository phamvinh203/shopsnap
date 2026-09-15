import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/merchant_insights.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/summary_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/summary_provider.dart';
import 'package:shopsnap/screens/summary/summary_screen.dart';

/// M-3 — Tích hợp section "Chi tiêu theo nơi mua" trên SummaryScreen (AC 7.8,
/// 7.10): override merchantSummaryProvider (local-only trong app thật) để không
/// chạm SQLite; các provider khác giữ pattern summary_screen_test.dart.
MerchantPurchase p(String name, String? store, int price) =>
    MerchantPurchase(name: name, storeName: store, price: price);

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

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SummaryScreen()),
        GoRoute(
          path: '/add',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('ADD_STUB'))),
        ),
      ],
    );

Future<void> _pumpSummary(
  WidgetTester tester, {
  required MerchantSummary merchant,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      summaryProvider.overrideWith((ref, params) => _summary()),
      aiAssistantProvider.overrideWith((ref, dateStr) async => null),
      merchantSummaryProvider.overrideWith((ref, params) => merchant),
    ],
    child:
        MaterialApp.router(theme: buildAppTheme(), routerConfig: _router()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('AC 7.8 — kỳ có dữ liệu nơi mua → card hiển thị dưới breakdown',
      (tester) async {
    await _pumpSummary(
      tester,
      merchant: buildMerchantSummary([
        p('Cà phê', 'Highlands', 90000),
        p('Sữa', 'CoopMart', 60000),
        p('Sữa', 'CoopMart', 60000),
        p('Bánh', 'CoopMart', 30000),
        p('Sữa', 'chợ', 24000),
        p('Sữa', 'chợ', 24000),
      ]),
    );

    // Card nằm dưới hero/AI/pie → CustomScrollView build lazy, cuộn tới trước.
    await tester.scrollUntilVisible(
      find.byKey(const Key('summaryMerchant_card')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summaryMerchant_card')), findsOneWidget);
    // SectionHeader render chữ HOA (overline). Widget dùng đúng chữ
    // "Chi tiêu" (spending) — bản cũ của test ghi nhầm "CHI TIẾU" (detail).
    expect(find.text('CHI TIÊU THEO NƠI MUA'), findsOneWidget);
    // Insight theo dữ liệu mẫu (spec AC 7.11: so sánh CÙNG MÓN, baseline =
    // trung bình TẤT CẢ lần mua của các nơi đủ điều kiện): chỉ "Sữa" đủ
    // (CoopMart 60k ×2, chợ 24k ×2) → baseline 42.000 → Y = round(18000/42000×100) = 43.
    // (Bản cũ của test gộp nhầm Bánh vào Sữa và lấy baseline = avg nơi đắt → 39.)
    expect(find.textContaining('rẻ hơn ~43% ở chợ'), findsOneWidget);
  });

  testWidgets('AC 7.10 — kỳ không có item nào có nơi mua → KHÔNG render card',
      (tester) async {
    await _pumpSummary(tester, merchant: buildMerchantSummary(const []));

    expect(find.byKey(const Key('summaryMerchant_card')), findsNothing);
    expect(find.text('CHI TIẾU THEO NƠI MUA'), findsNothing);
    // Phần còn lại của dashboard vẫn hiển thị bình thường.
    expect(find.byKey(const Key('summaryScreen_heroCard')), findsOneWidget);
  });
}
