import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: tap chọn chip', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrapWithAppTheme(CategoryChip(
      key: const Key('chip_an_uong'),
      icon: '🍔',
      label: 'Ăn uống',
      onTap: () => tapped++,
    )));

    await tester.tap(find.byKey(const Key('chip_an_uong')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('bare MaterialApp: selected + suggested badge', (tester) async {
    await tester.pumpWidget(wrapBare(const CategoryChip(
      key: Key('chip_an_uong'),
      icon: '🍔',
      label: 'Ăn uống',
      selected: true,
      suggested: true,
    )));

    expect(find.byKey(const Key('categoryChip_suggestedBadge')),
        findsOneWidget);
  });

  testWidgets('không suggested: không có badge', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const CategoryChip(
      key: Key('chip_di_chuyen'),
      icon: '🚌',
      label: 'Di chuyển',
    )));

    expect(find.byKey(const Key('categoryChip_suggestedBadge')), findsNothing);
  });
}
