import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: amount → MoneyText với key riêng', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const SectionHeader(
      key: Key('header_test'),
      title: 'Hôm nay · 3 items',
      amount: 123000,
    )));

    expect(find.byKey(const Key('sectionHeader_title')), findsOneWidget);
    expect(find.byKey(const Key('sectionHeader_amount')), findsOneWidget);
  });

  testWidgets('bare MaterialApp: trailing override amount', (tester) async {
    await tester.pumpWidget(wrapBare(SectionHeader(
      key: const Key('header_test'),
      title: 'Hôm nay · 3 items',
      trailing: IconButton(
        key: const Key('header_trailing'),
        icon: const Icon(Icons.refresh),
        onPressed: () {},
      ),
      amount: 123000,
    )));

    expect(find.byKey(const Key('header_trailing')), findsOneWidget);
    expect(find.byKey(const Key('sectionHeader_amount')), findsNothing);
  });

  testWidgets('dark theme: render không crash', (tester) async {
    await tester.pumpWidget(wrapWithDarkTheme(const SectionHeader(
      key: Key('header_test'),
      title: 'Hôm nay · 3 items',
      amount: 123000,
    )));

    expect(find.byKey(const Key('header_test')), findsOneWidget);
  });
}
