import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/price_history_provider.dart';
import 'package:shopsnap/screens/home/widgets/item_detail_sheet.dart';

import 'ui/helpers.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

const _categories = [
  CategoryModel(
    id: 'cat_food',
    name: 'Ăn uống',
    icon: '🍔',
    color: '#FF6B6B',
    isDefault: true,
    sortOrder: 0,
    createdAt: 0,
  ),
  CategoryModel(
    id: 'cat_move',
    name: 'Đi lại',
    icon: '🚆',
    color: '#4B44CC',
    isDefault: true,
    sortOrder: 1,
    createdAt: 0,
  ),
];

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => _categories;
}

/// Ghi lại lời gọi updateItem/deleteItem — KHÔNG chạm DAO/API thật.
class _FakeItemsNotifier extends ItemsNotifier {
  int updateCalls = 0;
  int deleteCalls = 0;
  String? updatedName;
  int? updatedPrice;
  String? updatedCategoryId;
  String? updatedStoreName;
  Object? updateError;
  Object? deleteError;

  @override
  Future<List<ItemModel>> build() async => const [];

  @override
  Future<void> updateItem(
    String id, {
    String? name,
    int? price,
    String? categoryId,
    String? note,
    String? barcode,
    String? storeName,
  }) async {
    updateCalls++;
    updatedName = name;
    updatedPrice = price;
    updatedCategoryId = categoryId;
    updatedStoreName = storeName;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> deleteItem(String id) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ItemModel _item({int? quantity}) => ItemModel(
      id: 'item-1',
      name: 'Cà phê',
      price: 25000,
      categoryId: 'cat_food',
      categoryName: 'Ăn uống',
      categoryIcon: '🍔',
      categoryColor: '#FF6B6B',
      quantity: quantity,
      createdAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
      updatedAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required ItemModel item,
  required _FakeItemsNotifier items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => items),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        // F-#1: sheet giờ watch price history (Deal Badge) — hermetic test
        // form thì override trả null (không history → không card, AC 1.6).
        priceHistorySummaryProvider(PriceHistoryQuery(name: item.name))
            .overrideWith((ref) async => null),
      ],
      child: wrapWithAppTheme(ItemDetailSheet(item: item)),
    ),
  );
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key fieldKey) {
  final textField = tester.widget<TextField>(
    find.descendant(of: find.byKey(fieldKey), matching: find.byType(TextField)),
  );
  return textField.controller!.text;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ItemDetailSheet', () {
    testWidgets('prefills tên / giá / danh mục từ item', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
      expect(_fieldText(tester, const Key('itemDetailSheet_nameField')), 'Cà phê');
      expect(_fieldText(tester, const Key('itemDetailSheet_priceField')), '25000');
      // Danh mục đang chọn hiển thị đúng category hiện tại của item.
      expect(find.text('🍔  Ăn uống'), findsWidgets);
    });

    testWidgets('hiện số lượng khi item có quantity (chỉ xem, không sửa)', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(quantity: 3), items: items);

      expect(find.byKey(const Key('itemDetailSheet_quantity')), findsOneWidget);
      expect(find.textContaining('Số lượng: 3'), findsOneWidget);
    });

    testWidgets('Lưu thay đổi gọi itemsProvider.updateItem với giá trị mới', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_nameField')), 'Cà phê sữa');
      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_priceField')), '30000');
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(items.updateCalls, 1);
      expect(items.updatedName, 'Cà phê sữa');
      expect(items.updatedPrice, 30000);
      // Không đổi danh mục → truyền null (chỉ gửi field thay đổi).
      expect(items.updatedCategoryId, isNull);
      // Lưu xong sheet tự đóng.
      expect(find.byKey(const Key('itemDetailSheet')), findsNothing);
    });

    testWidgets('đổi danh mục rồi lưu → updateItem nhận categoryId mới', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.tap(find.byKey(const Key('itemDetailSheet_categoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🚆  Đi lại').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(items.updateCalls, 1);
      expect(items.updatedCategoryId, 'cat_move');
    });

    testWidgets('không đổi gì rồi Lưu → chỉ đóng sheet, không gọi updateItem',
        (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(items.updateCalls, 0);
      expect(find.byKey(const Key('itemDetailSheet')), findsNothing);
    });

    testWidgets('tên bỏ trống → lỗi inline, không gọi updateItem', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_nameField')), '   ');
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pump();

      expect(find.byKey(const Key('itemDetailSheet_error')), findsOneWidget);
      expect(items.updateCalls, 0);
    });

    testWidgets('Xoá mặt hàng → ConfirmDialog → xác nhận gọi deleteItem', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.tap(find.byKey(const Key('itemDetailSheet_deleteButton')));
      await tester.pumpAndSettle();
      expect(find.text('Xoá mặt hàng?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
      await tester.pumpAndSettle();

      expect(items.deleteCalls, 1);
      expect(find.byKey(const Key('itemDetailSheet')), findsNothing);
    });

    testWidgets('Huỷ ở dialog xoá → sheet giữ nguyên, không xoá', (tester) async {
      final items = _FakeItemsNotifier();
      await _pumpSheet(tester, item: _item(), items: items);

      await tester.tap(find.byKey(const Key('itemDetailSheet_deleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog_cancel')));
      await tester.pumpAndSettle();

      expect(items.deleteCalls, 0);
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
    });
  });
}
