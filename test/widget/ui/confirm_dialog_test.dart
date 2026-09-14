import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: confirm → true; cancel → false', (tester) async {
    Future<bool>? resultFuture;
    await tester.pumpWidget(wrapWithAppTheme(Builder(
      key: const Key('opener'),
      builder: (context) {
        return IconButton(
          key: const Key('open_dialog'),
          icon: const Icon(Icons.delete),
          onPressed: () {
            resultFuture = ConfirmDialog.show(
              context: context,
              title: 'Xóa vật phẩm?',
              message: 'Vật phẩm sẽ bị xoá khỏi danh sách hôm nay.',
              confirmLabel: 'Xóa',
            );
          },
        );
      },
    )));

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirmDialog_confirm')), findsOneWidget);
    expect(find.byKey(const Key('confirmDialog_cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmDialog_cancel')));
    await tester.pumpAndSettle();
    expect(await resultFuture!, isFalse);

    // Mở lại và confirm.
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
    await tester.pumpAndSettle();
    expect(await resultFuture!, isTrue);
  });

  testWidgets('bare MaterialApp: destructive variant nhận tap và trả true',
      (tester) async {
    Future<bool>? resultFuture;
    await tester.pumpWidget(wrapBare(Builder(
      builder: (context) {
        return IconButton(
          key: const Key('open_dialog'),
          icon: const Icon(Icons.logout),
          onPressed: () {
            resultFuture = ConfirmDialog.show(
              context: context,
              title: 'Đăng xuất',
              message: 'Bạn chắc chắn muốn đăng xuất khỏi ShopSnap?',
              confirmLabel: 'Đăng xuất',
              destructive: true,
            );
          },
        );
      },
    )));

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
    await tester.pumpAndSettle();

    expect(await resultFuture!, isTrue);
  });
}
