import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/price_watch.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/price_history_model.dart';
import 'package:shopsnap/models/shopping_list_item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/shopping_list_provider.dart';
import 'package:shopsnap/screens/shopping_list/shopping_list_screen.dart';
import 'package:shopsnap/screens/shopping_list/widgets/price_sparkline.dart';
import 'package:shopsnap/screens/shopping_list/widgets/shopping_list_entry_button.dart';

// ── Fakes (không chạm SQLite/API) ─────────────────────────────────────────────

ShoppingListItem _item(
  String id,
  String name, {
  bool checked = false,
  bool watched = false,
  int? quantity,
  int? expectedPrice,
}) =>
    ShoppingListItem(
      id: id,
      name: name,
      checked: checked,
      watched: watched,
      quantity: quantity,
      expectedPrice: expectedPrice,
      createdAt: 0,
      updatedAt: 0,
    );

/// Fake notifier giữ list trong bộ nhớ — mutate rồi `ref.invalidateSelf()` để
/// UI rebuild (cùng cơ chế với notifier thật sau mỗi DAO call).
class _FakeShoppingListNotifier extends ShoppingListNotifier {
  final List<ShoppingListItem> items;
  final List<String> calls = [];

  _FakeShoppingListNotifier(this.items);

  @override
  Future<List<ShoppingListItem>> build() async => items;

  @override
  Future<bool> addQuick(String rawName) async {
    final name = rawName.trim();
    calls.add('add:$name');
    if (name.isEmpty) return false;
    items.add(_item('sl_${items.length + 1}', name));
    ref.invalidateSelf();
    return true;
  }

  @override
  Future<void> toggleChecked(String id) async {
    calls.add('toggleChecked:$id');
    final i = items.indexWhere((e) => e.id == id);
    items[i] = items[i].copyWith(checked: !items[i].checked);
    ref.invalidateSelf();
  }

  @override
  Future<void> toggleWatched(String id) async {
    calls.add('toggleWatched:$id');
    final i = items.indexWhere((e) => e.id == id);
    items[i] = items[i].copyWith(watched: !items[i].watched);
    ref.invalidateSelf();
  }

  @override
  Future<void> remove(String id) async {
    calls.add('remove:$id');
    items.removeWhere((e) => e.id == id);
    ref.invalidateSelf();
  }

  @override
  Future<void> updateDetails(
    String id, {
    int? quantity,
    int? expectedPrice,
    String? categoryId,
    bool clearQuantity = false,
    bool clearExpectedPrice = false,
    bool clearCategoryId = false,
  }) async {
    calls.add('updateDetails:$id:q=$quantity:p=$expectedPrice:c=$categoryId');
    ref.invalidateSelf();
  }

  @override
  Future<void> markAlertsSeen() async {
    calls.add('markAlertsSeen');
  }
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [
        CategoryModel(
          id: 'cat_food',
          name: 'Ăn uống',
          icon: '🍜',
          color: '#FF6B6B',
          isDefault: true,
          sortOrder: 1,
          createdAt: 0,
        ),
      ];
}

/// Intel giả: 'sữa' có lịch sử giá, món khác không (AC 6.9/6.10).
final _intelOverride = shoppingItemPriceIntelProvider.overrideWith((ref, key) async {
  if (normalizeMatchKey(key.name).contains('sữa')) {
    return ShoppingItemPriceIntel(
      points: [
        PriceHistoryPoint(id: 'p1', price: 32000, purchasedAt: DateTime(2026, 9, 1)),
        PriceHistoryPoint(id: 'p2', price: 24000, purchasedAt: DateTime(2026, 8, 12)),
        PriceHistoryPoint(id: 'p3', price: 28000, purchasedAt: DateTime(2026, 9, 10)),
      ],
      bestIn90Days: BestPriceRecord(price: 24000, date: DateTime(2026, 8, 12)),
      latestPrice: 28000,
      previousPrice: 24000,
    );
  }
  return null;
});

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pumpScreen(
  WidgetTester tester,
  List<ShoppingListItem> items,
  _FakeShoppingListNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shoppingListProvider.overrideWith(() => notifier),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        _intelOverride,
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const ShoppingListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ShoppingListScreen (F-#6)', () {
    testWidgets('AC 6.1 — rỗng: empty state hướng dẫn + quick-add field sẵn sàng',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([]);
      await _pumpScreen(tester, [], notifier);

      expect(find.byKey(const Key('shoppingList_quickAddField')), findsOneWidget);
      expect(find.byKey(const Key('emptyState')), findsOneWidget);
      expect(find.text('Danh sách đang trống'), findsOneWidget);
      expect(find.textContaining('Enter'), findsOneWidget);
      expect(find.byKey(const Key('emptyState_action')), findsOneWidget);
    });

    testWidgets('AC 6.2 — Enter với tên → dòng mới chưa tick (tên đã trim) + input clear',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([]);
      await _pumpScreen(tester, [], notifier);

      await tester.enterText(
          find.byKey(const Key('shoppingList_quickAddField')), '  Sữa tươi  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('add:Sữa tươi')); // đã trim
      expect(find.byKey(const Key('shoppingListItem_sl_1')), findsOneWidget);
      expect(find.text('Sữa tươi'), findsOneWidget);

      // Chưa tick: checkbox false, tên KHÔNG gạch ngang.
      final checkbox =
          tester.widget<Checkbox>(find.byKey(const Key('shoppingItem_check_sl_1')));
      expect(checkbox.value, isFalse);
      final nameText =
          tester.widget<Text>(find.byKey(const Key('shoppingItem_name_sl_1')));
      expect(nameText.style?.decoration, isNot(TextDecoration.lineThrough));

      // Input đã clear để nhập món tiếp theo.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('shoppingList_quickAddField')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('AC 6.3 — Enter khi input rỗng/toàn space → không tạo dòng, hiện hint',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([]);
      await _pumpScreen(tester, [], notifier);

      await tester.enterText(
          find.byKey(const Key('shoppingList_quickAddField')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.calls.where((c) => c.startsWith('add:')), isEmpty);
      expect(find.byKey(const Key('shoppingList_emptyInputHint')), findsOneWidget);
      expect(find.byKey(const Key('emptyState')), findsOneWidget); // list vẫn rỗng

      // Gõ tiếp → hint biến mất.
      await tester.enterText(
          find.byKey(const Key('shoppingList_quickAddField')), 'bánh');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shoppingList_emptyInputHint')), findsNothing);
    });

    testWidgets('AC 6.4 — tick checkbox: tên gạch ngang NGAY; tick lần nữa trả lại',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([_item('sl_1', 'Sữa')]);
      await _pumpScreen(tester, [_item('sl_1', 'Sữa')], notifier);

      await tester.tap(find.byKey(const Key('shoppingItem_check_sl_1')));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('toggleChecked:sl_1'));
      final nameText =
          tester.widget<Text>(find.byKey(const Key('shoppingItem_name_sl_1')));
      expect(nameText.style?.decoration, TextDecoration.lineThrough);

      // Bỏ tick → trả về như cũ.
      await tester.tap(find.byKey(const Key('shoppingItem_check_sl_1')));
      await tester.pumpAndSettle();
      final nameText2 =
          tester.widget<Text>(find.byKey(const Key('shoppingItem_name_sl_1')));
      expect(nameText2.style?.decoration, isNull);
    });

    testWidgets('AC 6.5 — nút xoá: dòng biến mất, KHÔNG có dialog xác nhận',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([_item('sl_1', 'Sữa')]);
      await _pumpScreen(tester, [_item('sl_1', 'Sữa')], notifier);

      await tester.tap(find.byKey(const Key('shoppingItem_delete_sl_1')));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('remove:sl_1'));
      expect(find.byKey(const Key('shoppingListItem_sl_1')), findsNothing);
      expect(find.textContaining('Xoá'), findsNothing); // không dialog xác nhận
    });

    testWidgets('AC 6.6 — tap thân dòng → sheet sửa: số lượng / giá dự kiến / danh mục',
        (tester) async {
      final notifier =
          _FakeShoppingListNotifier([_item('sl_1', 'Sữa', quantity: 2)]);
      await _pumpScreen(tester, [_item('sl_1', 'Sữa', quantity: 2)], notifier);

      await tester.tap(find.text('Sữa'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shoppingItemEditSheet')), findsOneWidget);
      expect(
          find.byKey(const Key('shoppingItemEditSheet_quantityField')), findsOneWidget);
      expect(find.byKey(const Key('shoppingItemEditSheet_priceField')), findsOneWidget);
      expect(
          find.byKey(const Key('shoppingItemEditSheet_categoryField')), findsOneWidget);

      // Sửa + lưu → updateDetails nhận đúng giá trị (quantity giữ nguyên 2 vì
      // field prefill từ item; category bỏ trống = clear).
      await tester.enterText(
          find.byKey(const Key('shoppingItemEditSheet_priceField')), '30000');
      await tester.tap(find.byKey(const Key('shoppingItemEditSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(
        notifier.calls.where((c) => c.startsWith('updateDetails:sl_1')),
        contains('updateDetails:sl_1:q=2:p=30000:c=null'),
      );
      expect(find.byKey(const Key('shoppingItemEditSheet')), findsNothing);
    });

    testWidgets('AC 6.9 — món khớp sản phẩm đã mua: sparkline + "Giá tốt nhất trong 90 ngày"',
        (tester) async {
      final notifier =
          _FakeShoppingListNotifier([_item('sl_1', 'Sữa tươi'), _item('sl_2', 'Bút chì')]);
      await _pumpScreen(
          tester, [_item('sl_1', 'Sữa tươi'), _item('sl_2', 'Bút chì')], notifier);

      // Khớp: khối intel + sparkline + nhãn best 90 ngày (VND số nguyên).
      expect(find.byKey(const Key('priceIntelBlock_sl_1')), findsOneWidget);
      expect(find.byType(PriceSparkline), findsOneWidget);
      expect(
        find.textContaining('Giá tốt nhất trong 90 ngày: 24.000đ'),
        findsOneWidget,
      );
      expect(find.textContaining('(ngày 12/8)'), findsOneWidget);

      // AC 6.10 — món không khớp: KHÔNG có khối intel (không chart rỗng/0đ).
      expect(find.byKey(const Key('priceIntelBlock_sl_2')), findsNothing);
    });

    testWidgets('AC 6.12 — "Theo dõi giá" toggle watched + icon khi đang theo dõi',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([_item('sl_1', 'Sữa tươi')]);
      await _pumpScreen(tester, [_item('sl_1', 'Sữa tươi')], notifier);

      expect(find.text('Theo dõi giá'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shoppingItem_watch_sl_1')));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('toggleWatched:sl_1'));
      expect(find.text('Đang theo dõi giá'), findsOneWidget);
      // Icon "đang watch" hiển thị cạnh tên món.
      expect(find.byIcon(Icons.notifications_active_rounded), findsWidgets);

      // Bấm lần nữa → bỏ theo dõi.
      await tester.tap(find.byKey(const Key('shoppingItem_watch_sl_1')));
      await tester.pumpAndSettle();
      expect(find.text('Theo dõi giá'), findsOneWidget);
    });

    testWidgets('AC 6.13 — mở màn list đánh dấu alert đã xem (badge clear)',
        (tester) async {
      final notifier = _FakeShoppingListNotifier([]);
      await _pumpScreen(tester, [], notifier);
      expect(notifier.calls, contains('markAlertsSeen'));
    });
  });

  group('ShoppingListEntryButton (AC 6.13 — badge trên entry)', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: Center(child: ShoppingListEntryButton()),
              ),
            ),
            GoRoute(
              path: '/shopping-list',
              builder: (_, __) =>
                  const Scaffold(body: Text('SHOPPING_LIST_SCREEN')),
            ),
          ],
        );

    Future<void> pumpEntry(WidgetTester tester, int unseen) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListUnseenAlertsProvider.overrideWith((ref) => unseen),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: buildRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('badge hiện số món có alert chưa xem + điều hướng sang list',
        (tester) async {
      await pumpEntry(tester, 2);

      final badge = tester.widget<Badge>(
          find.byKey(const Key('homeScreen_shoppingListBadge')));
      expect(badge.isLabelVisible, isTrue);

      await tester.tap(find.byKey(const Key('homeScreen_shoppingListButton')));
      await tester.pumpAndSettle();
      expect(find.text('SHOPPING_LIST_SCREEN'), findsOneWidget);
    });

    testWidgets('không có alert → badge ẩn, icon bình thường', (tester) async {
      await pumpEntry(tester, 0);

      final badge = tester.widget<Badge>(
          find.byKey(const Key('homeScreen_shoppingListBadge')));
      expect(badge.isLabelVisible, isFalse);
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
    });
  });
}
