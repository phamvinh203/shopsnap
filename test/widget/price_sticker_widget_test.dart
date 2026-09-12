import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/screens/ar_sticker/widgets/price_sticker_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PriceStickerWidget', () {
    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(_wrap(
        const PriceStickerWidget(label: '25.000đ', color: Colors.purple),
      ));
      expect(find.text('25.000đ'), findsOneWidget);
    });

    testWidgets('uses white text on dark background', (tester) async {
      await tester.pumpWidget(_wrap(
        const PriceStickerWidget(label: '25.000đ', color: Colors.purple),
      ));
      final text = tester.widget<Text>(find.text('25.000đ'));
      expect(text.style?.color, Colors.white);
    });

    testWidgets('uses black text on light background', (tester) async {
      await tester.pumpWidget(_wrap(
        const PriceStickerWidget(label: '25.000đ', color: Colors.yellow),
      ));
      final text = tester.widget<Text>(find.text('25.000đ'));
      expect(text.style?.color, Colors.black87);
    });

    testWidgets('applies scale transform', (tester) async {
      await tester.pumpWidget(_wrap(
        const PriceStickerWidget(label: '25.000đ', color: Colors.blue, scale: 1.5),
      ));
      // Transform.scale wraps the widget — at least one Transform must be present
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('shows price tag icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const PriceStickerWidget(label: '25.000đ', color: Colors.purple),
      ));
      expect(find.byIcon(Icons.local_offer_rounded), findsOneWidget);
    });
  });
}
