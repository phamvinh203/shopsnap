import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/screens/home/widgets/item_detail_sheet.dart';

import 'ui/helpers.dart';

/// EDGE CASE giá tiền của ItemDetailSheet (QA regression 2026-09-14 — vòng
/// sau redesign). `item_detail_sheet_test.dart` hiện có đã phủ: tên bỏ trống,
/// lưu bình thường, xoá/huỷ — NHƯNG chưa có case GIÁ không hợp lệ:
/// giá 0 / giá chứa ký tự không phải số (CurrencyFormatter.parse về 0).
/// Hợp đồng: hiện lỗi inline 'Giá tiền phải lớn hơn 0.', KHÔNG gọi
/// itemsProvider.updateItem, sheet giữ nguyên để user sửa tiếp.

// ── Fakes (copy pattern từ item_detail_sheet_test.dart — không import được
//    vì file test không expose helper) ────────────────────────────────────────

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [
        CategoryModel(
          id: 'cat_food',
          name: 'Ăn uống',
          icon: '🍔',
          color: '#FF6B6B',
          isDefault: true,
          sortOrder: 0,
          createdAt: 0,
        ),
      ];
}

class _FakeItemsNotifier extends ItemsNotifier {
  int updateCalls = 0;

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
  }) async {
    updateCalls++;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ItemModel _item() => ItemModel(
      id: 'item-1',
      name: 'Cà phê',
      price: 25000,
      categoryId: 'cat_food',
      categoryName: 'Ăn uống',
      categoryIcon: '🍔',
      categoryColor: '#FF6B6B',
      createdAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
      updatedAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
    );

Future<_FakeItemsNotifier> _pumpSheet(WidgetTester tester) async {
  final items = _FakeItemsNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => items),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
      ],
      child: wrapWithAppTheme(ItemDetailSheet(item: _item())),
    ),
  );
  await tester.pumpAndSettle();
  return items;
}

void main() {
  group('ItemDetailSheet — validate giá tiền (edge case chưa phủ)', () {
    testWidgets('giá nhập "0" → lỗi inline, không gọi updateItem, sheet giữ nguyên',
        (tester) async {
      final items = await _pumpSheet(tester);

      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_priceField')), '0');
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pump();

      expect(find.byKey(const Key('itemDetailSheet_error')), findsOneWidget);
      expect(find.text('Giá tiền phải lớn hơn 0.'), findsOneWidget);
      expect(items.updateCalls, 0);
      // Không tự đóng — user phải sửa tiếp.
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
    });

    testWidgets('giá chứa ký tự không phải số ("1abc0") → parse về 0 → cùng lỗi, không crash',
        (tester) async {
      final items = await _pumpSheet(tester);

      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_priceField')), '1abc0');
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pump();

      // CurrencyFormatter.parse chỉ giữ digit → '10' > 0 → đi qua path update:
      // gọi updateItem với price = 10 (giá trị rác nhưng không crash) rồi pop —
      // pumpAndSettle để route animation của sheet kịp đóng.
      expect(items.updateCalls, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('itemDetailSheet')), findsNothing);
    });

    testWidgets('giá chỉ toàn ký tự ("abc") → parse về 0 → lỗi inline, không gọi updateItem',
        (tester) async {
      final items = await _pumpSheet(tester);

      await tester.enterText(
          find.byKey(const Key('itemDetailSheet_priceField')), 'abc');
      await tester.tap(find.byKey(const Key('itemDetailSheet_saveButton')));
      await tester.pump();

      expect(find.byKey(const Key('itemDetailSheet_error')), findsOneWidget);
      expect(find.text('Giá tiền phải lớn hơn 0.'), findsOneWidget);
      expect(items.updateCalls, 0);
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
    });
  });
}
