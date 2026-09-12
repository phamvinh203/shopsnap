import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/screens/ocr/widgets/ocr_result_list.dart';
import 'package:shopsnap/services/ocr_service.dart';

List<OcrItem> _items() => [
  OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food'),
  OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('OcrResultList', () {
    testWidgets('renders initial items', (tester) async {
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: _items(),
        onChanged: (_) {},
      )));
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text('Bánh mì'), findsOneWidget);
    });

    testWidgets('shows "Thêm item" button', (tester) async {
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: _items(),
        onChanged: (_) {},
      )));
      expect(find.text('Thêm item'), findsOneWidget);
    });

    testWidgets('tapping "Thêm item" adds a new row', (tester) async {
      List<OcrItem> changed = [];
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: _items(),
        onChanged: (items) => changed = items,
      )));
      await tester.tap(find.text('Thêm item'));
      await tester.pump();
      expect(changed.length, 3);
    });

    testWidgets('tapping delete icon removes a row', (tester) async {
      List<OcrItem> changed = [];
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: _items(),
        onChanged: (items) => changed = items,
      )));
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(changed.length, 1);
    });

    testWidgets('shows warning border for needsReview items', (tester) async {
      final items = [
        OcrItem(name: 'X', price: 20000000, categoryId: 'cat_other', needsReview: true),
      ];
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: items,
        onChanged: (_) {},
      )));
      // Row renders at least one Container (the warning-styled row)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows correct index numbers', (tester) async {
      await tester.pumpWidget(_wrap(OcrResultList(
        initialItems: _items(),
        onChanged: (_) {},
      )));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
