import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: handle + title render; nội dung pop với result',
      (tester) async {
    Future<String?>? resultFuture;
    await tester.pumpWidget(wrapWithAppTheme(Builder(
      builder: (context) {
        return IconButton(
          key: const Key('open_sheet'),
          icon: const Icon(Icons.add),
          onPressed: () {
            resultFuture = AppBottomSheet.show<String>(
              context: context,
              title: 'Chọn danh mục',
              builder: (sheetContext) => GhostButton(
                key: const Key('sheet_action'),
                label: 'Xong',
                onPressed: () => Navigator.pop(sheetContext, 'done'),
              ),
            );
          },
        );
      },
    )));

    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appBottomSheet_handle')), findsOneWidget);
    expect(find.byKey(const Key('appBottomSheet_title')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet_action')));
    await tester.pumpAndSettle();
    expect(await resultFuture!, 'done');
  });

  testWidgets('bare MaterialApp: nội dung trong sheet render, không crash',
      (tester) async {
    await tester.pumpWidget(wrapBare(Builder(
      builder: (context) {
        return IconButton(
          key: const Key('open_sheet'),
          icon: const Icon(Icons.add),
          onPressed: () => AppBottomSheet.show<void>(
            context: context,
            builder: (_) => const GhostButton(
              key: Key('sheet_action'),
              label: 'Đóng',
            ),
          ),
        );
      },
    )));

    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet_action')), findsOneWidget);
  });
}
