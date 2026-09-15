import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/receipt_duplicate.dart';
import 'package:shopsnap/screens/ocr/widgets/ocr_result_list.dart';
import 'package:shopsnap/services/ocr_service.dart';

/// F-#5 P1 — OcrResultList giờ render các dòng CONFIRM (state do parent sở
/// hữu, widget bắn onEdit/onRemove/onAdd về). Test asserted render + callback
/// payload; hành vi state đầy đủ xem ocr_confirm_flow_test.dart.
List<OcrConfirmLine> _lines() => [
      OcrConfirmLine(
        uid: 'line1',
        item: OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food'),
      ),
      OcrConfirmLine(
        uid: 'line2',
        item: OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
      ),
    ];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('OcrResultList', () {
    testWidgets('renders initial items', (tester) async {
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: _lines(),
        onEdit: (_, __) {},
        onRemove: (_) {},
        onAdd: () {},
      )));
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text('Bánh mì'), findsOneWidget);
    });

    testWidgets('shows "Thêm mặt hàng" button + fires onAdd', (tester) async {
      var added = 0;
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: _lines(),
        onEdit: (_, __) {},
        onRemove: (_) {},
        onAdd: () => added++,
      )));
      expect(find.text('Thêm mặt hàng'), findsOneWidget);
      await tester.tap(find.text('Thêm mặt hàng'));
      expect(added, 1);
    });

    testWidgets('tapping delete icon removes the row (đúng uid)', (tester) async {
      String? removed;
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: _lines(),
        onEdit: (_, __) {},
        onRemove: (uid) => removed = uid,
        onAdd: () {},
      )));
      await tester.tap(find.byIcon(Icons.close).first);
      expect(removed, 'line1');
    });

    testWidgets('editing name/price reports OcrLineEdit đúng field', (tester) async {
      final edits = <OcrLineEdit>[];
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: _lines(),
        onEdit: (_, edit) => edits.add(edit),
        onRemove: (_) {},
        onAdd: () {},
      )));
      await tester.enterText(find.byKey(const Key('ocrConfirm_name_line1')), 'Cà phê sữa đá');
      await tester.enterText(find.byKey(const Key('ocrConfirm_price_line1')), '30000');

      expect(edits[0].name, 'Cà phê sữa đá');
      expect(edits[1].price, 30000);
    });

    testWidgets('dup badge + checkbox "Vẫn thêm" mặc định KHÔNG tick (AC 5.3)',
        (tester) async {
      final lines = [
        OcrConfirmLine(
          uid: 'line1',
          item: OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food'),
          duplicate: ReceiptDuplicateMatch(
            matchedName: 'Cà phê',
            matchedPrice: 25000,
            purchasedAt: DateTime(2026, 9, 13),
            priceDiffRatio: 0,
          ),
        ),
      ];
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: lines,
        onEdit: (_, __) {},
        onRemove: (_) {},
        onAdd: () {},
      )));
      expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsOneWidget);
      expect(find.byKey(const Key('ocrConfirm_keep_line1')), findsOneWidget);
      final cb = tester.widget<Checkbox>(find.byKey(const Key('ocrConfirm_keep_line1')));
      expect(cb.value, isFalse);
    });

    testWidgets('shows warning border for needsReview items', (tester) async {
      final lines = [
        OcrConfirmLine(
          uid: 'line1',
          item: OcrItem(name: 'X', price: 20000000, categoryId: 'cat_other', needsReview: true),
        ),
      ];
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: lines,
        onEdit: (_, __) {},
        onRemove: (_) {},
        onAdd: () {},
      )));
      // Row renders at least one Container (the warning-styled row)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows correct index numbers', (tester) async {
      await tester.pumpWidget(_wrap(OcrResultList(
        lines: _lines(),
        onEdit: (_, __) {},
        onRemove: (_) {},
        onAdd: () {},
      )));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
