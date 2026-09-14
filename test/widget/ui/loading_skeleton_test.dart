import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: skeleton render (KHÔNG pumpAndSettle — animation lặp vô hạn)',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(
        const LoadingSkeleton(key: Key('skeleton_test'), height: 48)));

    // pump 1 frame là đủ; shimmer repeat(reverse) không bao giờ settle.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('skeleton_test')), findsOneWidget);
  });

  testWidgets('bare MaterialApp: skeleton render', (tester) async {
    await tester.pumpWidget(
        wrapBare(const LoadingSkeleton(key: Key('skeleton_test'))));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('skeleton_test')), findsOneWidget);
  });

  testWidgets('SkeletonList: đúng số item theo key', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const SkeletonList(
      key: Key('skeleton_list_test'),
      itemCount: 3,
      itemHeight: 72,
    )));

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('skeleton_list_test')), findsOneWidget);
    expect(find.byKey(const Key('skeletonList_item_0')), findsOneWidget);
    expect(find.byKey(const Key('skeletonList_item_1')), findsOneWidget);
    expect(find.byKey(const Key('skeletonList_item_2')), findsOneWidget);
  });
}
