import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme light: tap item 2 → onTap nhận đúng index',
      (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(wrapWithAppTheme(AppBottomNav(
      key: const Key('nav_test'),
      currentIndex: 0,
      onTap: (i) => tappedIndex = i,
    )));

    await tester.tap(find.byKey(const Key('appBottomNav_item_2')));
    await tester.pump();
    expect(tappedIndex, 2);
  });

  testWidgets('bare MaterialApp: đủ 4 item, tap Cài đặt (index 3)',
      (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(wrapBare(AppBottomNav(
      key: const Key('nav_test'),
      currentIndex: 3,
      onTap: (i) => tappedIndex = i,
    )));

    expect(find.byKey(const Key('appBottomNav_item_0')), findsOneWidget);
    expect(find.byKey(const Key('appBottomNav_item_1')), findsOneWidget);
    expect(find.byKey(const Key('appBottomNav_item_2')), findsOneWidget);
    expect(find.byKey(const Key('appBottomNav_item_3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('appBottomNav_item_3')));
    await tester.pump();
    expect(tappedIndex, 3);
  });

  testWidgets('dark theme: selected item nhận tap không crash', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(wrapWithDarkTheme(AppBottomNav(
      key: const Key('nav_test'),
      currentIndex: 1,
      onTap: (i) => tappedIndex = i,
    )));

    await tester.tap(find.byKey(const Key('appBottomNav_item_1')));
    await tester.pump();
    expect(tappedIndex, 1);
  });
}
