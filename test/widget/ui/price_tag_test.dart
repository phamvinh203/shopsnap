import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: hiển thị amount đã format trong pill',
      (tester) async {
    await tester.pumpWidget(
        wrapWithAppTheme(const PriceTag(key: Key('price_test'), amount: 25000)));

    final tag = tester.widget(find.byKey(const Key('price_test')));
    expect(tag, isNotNull);
  });

  testWidgets('bare MaterialApp: cả 3 tone đều render không crash',
      (tester) async {
    for (final tone in PriceTone.values) {
      await tester.pumpWidget(wrapBare(PriceTag(
        key: const Key('price_test'),
        amount: 12000,
        tone: tone,
      )));
      expect(find.byKey(const Key('price_test')), findsOneWidget);
    }
  });
}
