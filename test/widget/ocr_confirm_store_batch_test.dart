import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/ocr_confirm_provider.dart';
import 'package:shopsnap/screens/ocr/widgets/ocr_review_confirm.dart';
import 'package:shopsnap/services/item_api_service.dart';
import 'package:shopsnap/services/ocr_service.dart';

/// M-3 (AC 7.7) — Field "Nơi mua" ÁP CHUNG CẢ BATCH trên màn confirm OCR:
/// prefill từ `OcrResult.storeName` nếu OCR trả về, bỏ trống được, submit gửi
/// đúng 1 giá trị batch-level qua `bulkAdd(storeName: ...)`.
class _FakeItemsNotifier extends ItemsNotifier {
  final calls = <String?>[];

  @override
  Future<List<ItemModel>> build() async => const [];

  @override
  Future<BulkCreateResult> bulkAdd(List<ItemPayload> items,
      {String? storeName}) async {
    calls.add(storeName);
    return const BulkCreateResult(
      created: [], failed: [], totalSubmitted: 0, totalCreated: 0, totalFailed: 0);
  }
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [
        CategoryModel(
            id: 'cat_food', name: 'Ăn uống', icon: '🍜', color: '#FF6B6B',
            isDefault: true, sortOrder: 1, createdAt: 0),
      ];
}

OcrResult _result(List<OcrItem> items, {String? storeName}) => OcrResult(
      items: items,
      rawText: '',
      quality: OcrQuality.good,
      source: OcrSource.geminiVision,
      storeName: storeName,
    );

Future<_FakeItemsNotifier> _pumpConfirm(
  WidgetTester tester, {
  required OcrResult ocrResult,
}) async {
  final fake = _FakeItemsNotifier();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      itemsProvider.overrideWith(() => fake),
      categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
      ocrRecentEntriesProvider.overrideWith((ref) => Future.value(const [])),
      ocrMatchRecordsProvider.overrideWith((ref) => Future.value(const [])),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: OcrReviewConfirm(
          result: ocrResult,
          onFinished: () {},
          onRetake: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('AC 7.7 — OCR trả storeName → field prefill đúng, submit gửi '
      'ÁP CHUNG cả batch', (tester) async {
    final fake = await _pumpConfirm(
      tester,
      ocrResult: _result(
        [
          OcrItem(name: 'Cà phê sữa', price: 25000, categoryId: 'cat_food'),
          OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
        ],
        storeName: 'CoopMart',
      ),
    );

    // Prefill từ OcrResult.storeName.
    final field = tester.widget<TextField>(find.byKey(
        const Key('ocrScreen_storeField')));
    expect(field.controller!.text, 'CoopMart');

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    expect(fake.calls.single, 'CoopMart');
  });

  testWidgets('AC 7.7 — OCR không có storeName → field rỗng (tuỳ chọn); user '
      'nhập tay thì gửi giá trị user nhập', (tester) async {
    final fake = await _pumpConfirm(
      tester,
      ocrResult: _result(
        [
          OcrItem(name: 'Cà phê sữa', price: 25000, categoryId: 'cat_food'),
        ],
      ),
    );

    final field = tester.widget<TextField>(find.byKey(
        const Key('ocrScreen_storeField')));
    expect(field.controller!.text, '');

    // Bỏ trống hẳn cũng submit được → bulkAdd nhận null.
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();
    expect(fake.calls.single, isNull);
  });

  testWidgets('AC 7.7 — user sửa field trước khi submit → gửi giá trị mới '
      '(1 field áp chung mọi dòng, không per-line)', (tester) async {
    final fake = await _pumpConfirm(
      tester,
      ocrResult: _result(
        [
          OcrItem(name: 'Cà phê sữa', price: 25000, categoryId: 'cat_food'),
        ],
        storeName: 'CoopMart',
      ),
    );

    await tester.enterText(find.byKey(const Key('ocrScreen_storeField')),
        '  Bách Hóa Xanh  ');
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    // _submit trim trước khi gửi (không gửi nguyên chuỗi có 2 đầu whitespace).
    expect(fake.calls.single, 'Bách Hóa Xanh');
  });
}
