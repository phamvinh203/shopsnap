import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

/// Finder: Text bên trong MoneyText (key nội bộ `moneyText_text`), để đọc
/// style/fontFeatures — pure byKey theo quy ước test mới.
Finder moneyInnerText(Finder moneyText) => find.descendant(
      of: moneyText,
      matching: find.byKey(const Key('moneyText_text')),
    );

void main() {
  testWidgets('format qua CurrencyFormatter và LUÔN tabular figures (light)',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(
        const MoneyText(key: Key('money_test'), amount: 25000)));

    final text = tester.widget<Text>(moneyInnerText(
      find.byKey(const Key('money_test')),
    ));
    // CurrencyFormatter: 25.000đ (không assert wording mới — format hiện có).
    expect(text.data, '25.000đ');
    expect(text.style?.fontFeatures, isNotNull);
    expect(
      text.style!.fontFeatures!.contains(const FontFeature.tabularFigures()),
      isTrue,
    );
  });

  testWidgets('bare MaterialApp: vẫn tabular figures (fallback SnapColors)',
      (tester) async {
    await tester.pumpWidget(
        wrapBare(const MoneyText(key: Key('money_test'), amount: 1500000)));

    final text = tester.widget<Text>(moneyInnerText(
      find.byKey(const Key('money_test')),
    ));
    expect(text.data, '1.500.000đ');
    expect(
      text.style!.fontFeatures!.contains(const FontFeature.tabularFigures()),
      isTrue,
    );
  });

  testWidgets('merge style giữ lại tabular figures', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const MoneyText(
      key: Key('money_test'),
      amount: 1000,
      style: TextStyle(fontSize: 20, color: Colors.red),
    )));

    final text = tester.widget<Text>(moneyInnerText(
      find.byKey(const Key('money_test')),
    ));
    expect(text.style!.fontSize, 20);
    expect(
      text.style!.fontFeatures!.contains(const FontFeature.tabularFigures()),
      isTrue,
    );
  });
}
