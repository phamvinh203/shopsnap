import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme light: render child và onTap hoạt động',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrapWithAppTheme(AppCard(
      key: const Key('card_test'),
      onTap: () => tapped++,
      child: const Text('Nội dung card'),
    )));

    expect(find.byKey(const Key('card_test')), findsOneWidget);
    await tester.tap(find.byKey(const Key('card_test')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('bare MaterialApp: không crash khi thiếu SnapColors trong theme',
      (tester) async {
    await tester.pumpWidget(wrapBare(const AppCard(
      key: Key('card_test'),
      child: Text('Nội dung card'),
    )));

    expect(find.byKey(const Key('card_test')), findsOneWidget);
  });

  testWidgets('dark theme: render + tap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrapWithDarkTheme(AppCard(
      key: const Key('card_test'),
      onTap: () => tapped++,
      child: const Text('Nội dung card'),
    )));

    await tester.tap(find.byKey(const Key('card_test')));
    await tester.pump();
    expect(tapped, 1);
  });
}
