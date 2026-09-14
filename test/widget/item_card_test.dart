import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/screens/home/widgets/item_card.dart';

ItemModel _item({String name = 'Cà phê', int price = 25000}) => ItemModel(
  id: 'item-1',
  name: name,
  price: price,
  categoryId: 'cat_food',
  categoryName: 'Ăn uống',
  categoryIcon: '🍔',
  categoryColor: '#FF6B6B',
  createdAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
  updatedAt: DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ItemCard', () {
    testWidgets('displays item name and price', (tester) async {
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(),
        onDelete: () {},
        onTap: () {},
      )));
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.textContaining('25.000'), findsOneWidget);
    });

    testWidgets('shows category icon and name', (tester) async {
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(),
        onDelete: () {},
        onTap: () {},
      )));
      expect(find.text('🍔'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(),
        onDelete: () {},
        onTap: () => tapped = true,
      )));
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });

    testWidgets('exposes itemCard_<id> key and opens detail on tap (P3a)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ItemCard(
        key: const Key('itemCard_item-1'),
        item: _item(),
        onDelete: () {},
        onTap: () => tapped = true,
      )));
      // Key convention P2/P3a: Home truyền Key('itemCard_<id>') — tap theo key.
      await tester.tap(find.byKey(const Key('itemCard_item-1')));
      expect(tapped, isTrue);
    });

    testWidgets('shows default icon when imagePath is null', (tester) async {
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(),
        onDelete: () {},
        onTap: () {},
      )));
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    });

    testWidgets('shows confirm dialog on swipe-to-delete', (tester) async {
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(name: 'Bánh mì'),
        onDelete: () {},
        onTap: () {},
      )));
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Xóa vật phẩm?'), findsOneWidget);
      // Dialog content should mention the item name
      expect(find.textContaining('Bánh mì'), findsWidgets);
    });

    testWidgets('cancels delete when Huỷ is pressed', (tester) async {
      await tester.pumpWidget(_wrap(ItemCard(
        item: _item(),
        onDelete: () {},
        onTap: () {},
      )));
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      // Card should still be visible
      expect(find.text('Cà phê'), findsOneWidget);
    });
  });
}
