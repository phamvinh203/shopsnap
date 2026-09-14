import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('app theme: snackbar hiện với key, tự đóng hết timer',
      (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(Builder(
      builder: (context) {
        return IconButton(
          key: const Key('show_snackbar'),
          icon: const Icon(Icons.info),
          onPressed: () => AppSnackBar.show(
            context: context,
            message: 'Đã lưu vật phẩm',
            tone: AppSnackBarTone.success,
            duration: const Duration(seconds: 1),
          ),
        );
      },
    )));

    await tester.tap(find.byKey(const Key('show_snackbar')));
    await tester.pump();
    expect(find.byKey(const Key('appSnackBar')), findsOneWidget);
    expect(find.byKey(const Key('appSnackBar_message')), findsOneWidget);

    // Đẩy qua duration + animation ra vào để không só timer pending.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('appSnackBar')), findsNothing);
  });

  testWidgets('bare MaterialApp: action nhận tap', (tester) async {
    var actionPressed = 0;
    await tester.pumpWidget(wrapBare(Builder(
      builder: (context) {
        return IconButton(
          key: const Key('show_snackbar'),
          icon: const Icon(Icons.info),
          onPressed: () => AppSnackBar.show(
            context: context,
            message: 'Đồng bộ thất bại',
            tone: AppSnackBarTone.danger,
            duration: const Duration(seconds: 3),
            actionLabel: 'Thử lại',
            onAction: () => actionPressed++,
          ),
        );
      },
    )));

    await tester.tap(find.byKey(const Key('show_snackbar')));
    await tester.pump();
    // Đợi animation trượt vào xong để action nằm trong hit-test area.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('appSnackBar_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('appSnackBar_action')));
    await tester.pump();
    expect(actionPressed, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });
}
