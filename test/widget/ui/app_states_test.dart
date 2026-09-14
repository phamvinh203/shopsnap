import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('app theme: title/message render, không có action khi không truyền',
        (tester) async {
      await tester.pumpWidget(wrapWithAppTheme(const EmptyState(
        key: Key('empty_test'),
        icon: Icons.shopping_bag_outlined,
        title: 'Chưa có gì hôm nay',
        message: 'Nhấn + để thêm vật phẩm đầu tiên',
      )));

      expect(find.byKey(const Key('emptyState_title')), findsOneWidget);
      expect(find.byKey(const Key('emptyState_message')), findsOneWidget);
      expect(find.byKey(const Key('emptyState_action')), findsNothing);
    });

    testWidgets('bare MaterialApp: action tuỳ chọn gọi onAction khi tap',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapBare(EmptyState(
        key: const Key('empty_test'),
        icon: Icons.shopping_bag_outlined,
        title: 'Chưa có gì hôm nay',
        actionLabel: 'Thêm ngay',
        onAction: () => pressed++,
      )));

      await tester.tap(find.byKey(const Key('emptyState_action')));
      await tester.pump();
      expect(pressed, 1);
    });
  });

  group('ErrorState', () {
    testWidgets('app theme: nút "Thử lại" gọi onRetry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(wrapWithAppTheme(ErrorState(
        key: const Key('error_test'),
        message: 'Không tải được danh sách',
        onRetry: () => retried++,
      )));

      expect(find.byKey(const Key('errorState_message')), findsOneWidget);
      await tester.tap(find.byKey(const Key('errorState_retry')));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('bare MaterialApp (fallback SnapColors): nút Thử lại vẫn tap được',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(wrapBare(ErrorState(
        key: const Key('error_test'),
        onRetry: () => retried++,
      )));

      await tester.tap(find.byKey(const Key('errorState_retry')));
      await tester.pump();
      expect(retried, 1);
    });
  });
}
