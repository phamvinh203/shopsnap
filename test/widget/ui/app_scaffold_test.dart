import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: có title → có AppBar; action theo key nhận tap',
      (tester) async {
    var actionPressed = 0;
    await tester.pumpWidget(wrapWithAppTheme(AppScaffold(
      key: const Key('scaffold_test'),
      title: 'Lịch sử',
      actions: [
        IconButton(
          key: const Key('scaffold_action'),
          icon: const Icon(Icons.search),
          onPressed: () => actionPressed++,
        ),
      ],
      body: const SizedBox(),
    )));

    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.byKey(const Key('scaffold_action')));
    await tester.pump();
    expect(actionPressed, 1);
  });

  testWidgets('không title/actions → không AppBar; SafeArea mặc định bật',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const AppScaffold(
      key: Key('scaffold_test'),
      body: Text('Body'),
    )));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.text('Body'), findsOneWidget); // text data — được phép
  });

  testWidgets('bare MaterialApp: safeArea = false → không SafeArea',
      (tester) async {
    await tester.pumpWidget(wrapBare(const AppScaffold(
      key: Key('scaffold_test'),
      body: Text('Body'),
      safeArea: false,
    )));

    expect(find.byType(SafeArea), findsNothing);
  });
}
