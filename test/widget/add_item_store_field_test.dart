import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/database_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/screens/add_item/add_item_screen.dart';
import 'package:shopsnap/screens/add_item/widgets/store_field.dart';
import 'package:sqflite/sqflite.dart';

/// M-3 — Field "Nơi mua" trên màn thêm item (AC 7.3, 7.4, 7.5).

class _MockDb extends Mock implements Database {}

// ── Fakes (pattern ocr_confirm_flow_test / summary_screen_test) ──────────────

class _CaptureItemsNotifier extends ItemsNotifier {
  final captured = <CreateItemDto>[];

  @override
  Future<List<ItemModel>> build() async => const [];

  @override
  Future<void> addItem(CreateItemDto dto,
      {bool force = false, String? source}) async {
    captured.add(dto);
  }
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [
        CategoryModel(
            id: 'cat_food', name: 'Ăn uống', icon: '🍜', color: '#FF6B6B',
            isDefault: true, sortOrder: 1, createdAt: 0),
      ];
}

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AddItemScreen()),
        GoRoute(
          path: '/scan',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('SCAN_STUB'))),
        ),
      ],
    );

Future<void> _pumpField(
  WidgetTester tester, {
  List<String> suggestions = const [],
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: StoreFieldSuggestions(
        controller: controller,
        suggestions: suggestions,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('StoreFieldSuggestions — chips gợi ý theo tần suất (AC 7.4/7.5)', () {
    testWidgets('Chips render ĐÚNG THỨ TỰ tần suất giảm dần (nguyên văn)',
        (tester) async {
      await _pumpField(tester, suggestions: const [
        'CoopMart',
        'coop mart',
        'Bách Hóa Xanh',
      ]);

      // Wrap xếp trái → phải theo thứ tự input (đã sắp tần suất giảm dần).
      double dxOf(String label) => tester.getTopLeft(find.text(label)).dx;
      expect(dxOf('CoopMart') < dxOf('coop mart'), isTrue);
      expect(dxOf('coop mart') < dxOf('Bách Hóa Xanh'), isTrue);
    });

    testWidgets('Tap chip → field điền ĐÚNG NGUYÊN VĂN giá trị đó (AC 7.5)',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StoreFieldSuggestions(
            controller: controller,
            suggestions: const ['CoopMart', 'coop mart'],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addItem_storeChip_0')));
      await tester.pump();

      expect(controller.text, 'CoopMart');
      // Con trỏ ở cuối — user gõ tiếp được ngay.
      expect(controller.selection.baseOffset, 'CoopMart'.length);
    });

    testWidgets('Không có gợi ý → không render vùng chips, field vẫn nhập tự do',
        (tester) async {
      await _pumpField(tester);

      expect(find.byKey(const Key('addItem_storeSuggestions')), findsNothing);
      expect(find.byKey(const Key('addItem_storeField')), findsOneWidget);
    });
  });

  // ── Tích hợp màn Thêm mặt hàng (AC 7.3) ─────────────────────────────────────

  group('AddItemScreen — field "Nơi mua" persist qua đường lưu', () {
    late _CaptureItemsNotifier notifier;
    late _MockDb db;

    /// Surface CAO để ListView build hết form (field Nơi mua nằm dưới màn hình
    /// ở viewport test mặc định 800×600 — ListView lazy-build theo viewport).
    Future<void> pumpScreen(
      WidgetTester tester, {
      List<String> suggestions = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
          storeSuggestionsProvider
              .overrideWith((ref) => Future.value(suggestions)),
          itemsProvider.overrideWith(() => notifier),
          // _onNameChanged tra price hint qua SQLite → mock DB (offline-safe).
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: MaterialApp.router(
            theme: buildAppTheme(), routerConfig: _router()),
      ));
      await tester.pumpAndSettle();
    }

    setUp(() {
      notifier = _CaptureItemsNotifier();
      db = _MockDb();
      when(() => db.rawQuery(any(), any()))
          .thenAnswer((_) async => <Map<String, Object?>>[]);
    });

    testWidgets('Field "Nơi mua" + chips từ dữ liệu local hiển thị',
        (tester) async {
      await pumpScreen(tester, suggestions: const ['CoopMart', 'WinMart']);

      expect(find.byKey(const Key('addItem_storeField')), findsOneWidget);
      expect(find.text('CoopMart'), findsOneWidget);
      expect(find.text('WinMart'), findsOneWidget);
    });

    testWidgets('Nhập nơi mua + lưu → dto mang store_name nguyên văn đã trim',
        (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
          find.byKey(const Key('addItem_nameField')), 'Sữa tươi');
      await tester.enterText(
          find.byKey(const Key('addItem_priceField')), '25000');
      await tester.enterText(
          find.byKey(const Key('addItem_storeField')), '  CoopMart  ');
      await tester.tap(find.byKey(const Key('addItem_saveButton')));
      await tester.pumpAndSettle();

      expect(notifier.captured.length, 1);
      expect(notifier.captured.single.storeName, 'CoopMart'); // đã trim (AC 7.5)
    });

    testWidgets('Bỏ trống nơi mua + lưu → dto storeName NULL (AC 7.3)',
        (tester) async {
      await pumpScreen(tester, suggestions: const ['CoopMart']);

      await tester.enterText(
          find.byKey(const Key('addItem_nameField')), 'Sữa tươi');
      await tester.enterText(
          find.byKey(const Key('addItem_priceField')), '25000');
      // KHÔNG đụng field nơi mua.
      await tester.tap(find.byKey(const Key('addItem_saveButton')));
      await tester.pumpAndSettle();

      expect(notifier.captured.length, 1);
      expect(notifier.captured.single.storeName, isNull);
    });
  });
}
