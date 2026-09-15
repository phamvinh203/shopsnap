import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/merchant_insights.dart';
import 'package:shopsnap/screens/summary/widgets/merchant_breakdown_card.dart';

/// M-3 — Card "Chi tiêu theo nơi mua" trên Summary (AC 7.8, 7.9, 7.10, 7.11).
MerchantPurchase p(String name, String? store, int price) =>
    MerchantPurchase(name: name, storeName: store, price: price);

Future<void> _pumpCard(WidgetTester tester, MerchantSummary data) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: ListView(children: [MerchantBreakdownCard(data: data)]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AC 7.8 — top 5 nơi mua, bar ngang kèm tổng chi + số lần mua', () {
    testWidgets('Bar xếp GIẢM DẦN, ratio theo nơi lớn nhất', (tester) async {
      final data = buildMerchantSummary([
        p('Sữa', 'CoopMart', 90000),
        p('Bánh', 'Bách Hóa Xanh', 45000),
        p('Trứng', 'WinMart', 45000),
      ]);

      await _pumpCard(tester, data);

      expect(find.byKey(const Key('summaryMerchant_card')), findsOneWidget);
      expect(find.byKey(const Key('summaryMerchant_row_0')), findsOneWidget);

      // Thứ tự: CoopMart (90k) → Bách Hóa Xanh (45k, tên A→Z sau tie) → WinMart.
      double dyOf(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(dyOf('CoopMart') < dyOf('Bách Hóa Xanh'), isTrue);
      expect(dyOf('Bách Hóa Xanh') < dyOf('WinMart'), isTrue);

      // Mỗi bar: tổng chi VND + số lần mua (AC 7.8) — cả 3 nơi đều 1 lần.
      expect(find.text('1 lần'), findsNWidgets(3));
      expect(find.textContaining('90.000'), findsOneWidget);

      // Bar ratio theo max (CoopMart = 1.0, còn lại 0.5).
      double valueOf(int i) => tester.widget<LinearProgressIndicator>(
          find.byKey(Key('summaryMerchant_bar_$i'))).value!;
      expect(valueOf(0), 1.0);
      expect(valueOf(1), closeTo(0.5, 0.001));
      expect(valueOf(2), closeTo(0.5, 0.001));
    });

    testWidgets('7 nơi mua → CHỈ ĐÚNG 5 bar (không gộp "còn lại")',
        (tester) async {
      final data = buildMerchantSummary([
        for (var s = 1; s <= 7; s++) p('món$s', 'S$s', s * 10000),
      ]);

      await _pumpCard(tester, data);

      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('summaryMerchant_row_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('summaryMerchant_row_5')), findsNothing);
      expect(find.textContaining('còn lại'), findsNothing);
    });
  });

  group('AC 7.9 — caveat bắt buộc', () {
    testWidgets('Card luôn kèm ghi chú "Độ chính xác thấp"', (tester) async {
      await _pumpCard(
          tester,
          buildMerchantSummary([p('Sữa', 'CoopMart', 10000)]));

      expect(find.byKey(const Key('summaryMerchant_caveat')), findsOneWidget);
      expect(find.textContaining('Độ chính xác thấp'), findsOneWidget);
    });
  });

  group('AC 7.10 — empty state: ẨN toàn bộ section', () {
    testWidgets('Không có lượt mua nào có nơi mua → không card, không "0đ"',
        (tester) async {
      await _pumpCard(tester, buildMerchantSummary([
        p('Sữa', null, 30000),
        p('Trứng', '', 20000),
      ]));

      expect(find.byKey(const Key('summaryMerchant_card')), findsNothing);
      expect(find.textContaining('0đ'), findsNothing);
    });
  });

  group('AC 7.11/7.12 — insight dưới các bar', () {
    testWidgets('Hiển thị dòng insight đúng format với Y nguyên văn',
        (tester) async {
      final data = buildMerchantSummary([
        p('Sữa Vinamilk', 'CoopMart', 31000),
        p('Sữa Vinamilk', 'CoopMart', 29000),
        p('Sữa Vinamilk', 'chợ', 25000),
        p('Sữa Vinamilk', 'chợ', 23000),
      ]);

      await _pumpCard(tester, data);

      expect(
        find.text('Bạn thường mua Sữa Vinamilk rẻ hơn ~11% ở chợ'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('summaryMerchant_insight_0')),
          findsOneWidget);
    });

    testWidgets('Không đủ dữ liệu insight (1 nơi) → chỉ có bars + caveat',
        (tester) async {
      final data = buildMerchantSummary([
        p('Sữa', 'CoopMart', 31000),
        p('Sữa', 'CoopMart', 29000),
      ]);

      await _pumpCard(tester, data);

      expect(find.byKey(const Key('summaryMerchant_card')), findsOneWidget);
      expect(find.textContaining('rẻ hơn'), findsNothing);
    });
  });
}
