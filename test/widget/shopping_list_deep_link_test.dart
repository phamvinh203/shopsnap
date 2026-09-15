import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/shopping_list_item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/shopping_list_provider.dart';
import 'package:shopsnap/screens/shopping_list/shopping_list_screen.dart';

/// F-#12 — **AC 12.5** (deep-link từ price alert): bấm notification mở
/// `/shopping-list?item=<id>` → màn list scroll tới + highlight đúng món vừa
/// được báo giá tốt, rồi tự tắt highlight sau vài giây.
///
/// Test trực tiếp prop `highlightItemId` của màn (router truyền query param
/// vào prop này — xem `app_router.dart`).
ShoppingListItem _item(String id, String name) => ShoppingListItem(
      id: id,
      name: name,
      createdAt: 0,
      updatedAt: 0,
    );

class _FakeShoppingListNotifier extends ShoppingListNotifier {
  final List<ShoppingListItem> items;

  _FakeShoppingListNotifier(this.items);

  @override
  Future<List<ShoppingListItem>> build() async => items;

  // Mở màn list → badge alert đã xem; test này không cần DB nên no-op.
  @override
  Future<void> markAlertsSeen() async {}
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [];
}

Future<void> _pump(
  WidgetTester tester,
  List<ShoppingListItem> items, {
  String? highlightItemId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shoppingListProvider
            .overrideWith(() => _FakeShoppingListNotifier(items)),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        // Không có lịch sử giá → khối intel ẩn (AC 6.10) — không liên quan test này.
        shoppingItemPriceIntelProvider.overrideWith((ref, key) async => null),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: ShoppingListScreen(highlightItemId: highlightItemId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ShoppingListScreen deep-link (AC 12.5)', () {
    testWidgets('AC 12.5 — ?item=<id> → đúng dòng được highlight, rồi tự tắt',
        (tester) async {
      await _pump(
        tester,
        [_item('sl_1', 'Sữa tươi'), _item('sl_2', 'Bánh mì')],
        highlightItemId: 'sl_2',
      );

      // Đúng món được highlight, món khác thì không.
      expect(
        find.byKey(const Key('shoppingListItem_sl_2_highlighted')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shoppingListItem_sl_1_highlighted')),
        findsNothing,
      );
      expect(find.byKey(const Key('shoppingListItem_sl_1')), findsOneWidget);

      // Highlight tạm thời → sau ~3 giây quay lại trạng thái thường.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shoppingListItem_sl_2_highlighted')),
        findsNothing,
      );
      expect(find.byKey(const Key('shoppingListItem_sl_2')), findsOneWidget);
    });

    testWidgets('AC 12.5 — item id không tồn tại (món đã xoá) → không crash, không highlight',
        (tester) async {
      await _pump(
        tester,
        [_item('sl_1', 'Sữa tươi')],
        highlightItemId: 'missing_id',
      );

      expect(find.byKey(const Key('shoppingListItem_sl_1')), findsOneWidget);
      expect(
        find.byKey(const Key('shoppingListItem_sl_1_highlighted')),
        findsNothing,
      );
    });

    testWidgets('không có deep-link (vào màn bình thường) → không dòng nào highlight',
        (tester) async {
      await _pump(tester, [_item('sl_1', 'Sữa tươi')]);

      expect(find.byKey(const Key('shoppingListItem_sl_1')), findsOneWidget);
      expect(
        find.byKey(const Key('shoppingListItem_sl_1_highlighted')),
        findsNothing,
      );
    });
  });
}