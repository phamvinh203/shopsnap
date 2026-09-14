import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('app theme: tap gọi onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithAppTheme(PrimaryButton(
        key: const Key('btn_primary'),
        label: 'Lưu',
        onPressed: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('btn_primary')));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('bare MaterialApp (fallback SnapColors): tap gọi onPressed',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapBare(PrimaryButton(
        key: const Key('btn_primary'),
        label: 'Lưu',
        onPressed: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('btn_primary')));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('loading: hiện spinner, disable nút', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithAppTheme(PrimaryButton(
        key: const Key('btn_primary'),
        label: 'Lưu',
        loading: true,
        onPressed: () => pressed++,
      )));

      expect(find.byKey(const Key('primaryButton_loading')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_primary')));
      await tester.pump();
      expect(pressed, 0);
    });

    testWidgets('onPressed null: disable', (tester) async {
      await tester.pumpWidget(
          wrapWithAppTheme(const PrimaryButton(key: Key('btn_primary'), label: 'Lưu')));
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('btn_primary')),
          matching: find.byKey(const Key('primaryButton')),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('SecondaryButton', () {
    testWidgets('tap gọi onPressed (light)', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithAppTheme(SecondaryButton(
        key: const Key('btn_secondary'),
        label: 'Huỷ đặt chỗ',
        onPressed: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('btn_secondary')));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('danger variant vẫn nhận tap (bare MaterialApp)',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapBare(SecondaryButton(
        key: const Key('btn_secondary'),
        label: 'Xoá',
        danger: true,
        onPressed: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('btn_secondary')));
      await tester.pump();
      expect(pressed, 1);
    });
  });

  group('GhostButton', () {
    testWidgets('tap gọi onPressed; onPressed null thì disable', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithAppTheme(GhostButton(
        key: const Key('btn_ghost'),
        label: 'Huỷ',
        onPressed: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('btn_ghost')));
      await tester.pump();
      expect(pressed, 1);

      await tester.pumpWidget(wrapWithAppTheme(
          const GhostButton(key: Key('btn_ghost'), label: 'Huỷ')));
      final button = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('btn_ghost')),
          matching: find.byKey(const Key('ghostButton')),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
