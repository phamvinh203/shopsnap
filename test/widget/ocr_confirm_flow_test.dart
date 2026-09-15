import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/receipt_auto_match.dart';
import 'package:shopsnap/core/utils/receipt_duplicate.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/ocr_confirm_provider.dart';
import 'package:shopsnap/screens/ocr/widgets/ocr_review_confirm.dart';
import 'package:shopsnap/services/category_classifier.dart';
import 'package:shopsnap/services/item_api_service.dart';
import 'package:shopsnap/services/ocr_service.dart';
import 'package:shopsnap/widgets/ui/app_button.dart';

/// F-#5 Phase 1 — widget test màn CONFIRM từng dòng, map 1-1 các AC.
/// (AC 5.11 do BE bảo đảm — bên mobile chỉ assert mọi item đi qua bulk API
/// với payload đầy đủ source/category/price, xem test AC 5.6.)

// ── Fakes (không chạm SQLite/API thật) ───────────────────────────────────────

class _FakeItemsNotifier extends ItemsNotifier {
  BulkCreateResult Function(List<ItemPayload> payloads)? script;

  /// Ném lỗi ĐÚNG 1 lần (429/offline), các lần sau chạy [script].
  ApiException? throwOnce;

  /// Giữ request treo để assert loading (AC 5.6).
  Completer<BulkCreateResult>? hold;

  final calls = <List<ItemPayload>>[];
  final storeNames = <String?>[];

  @override
  Future<List<ItemModel>> build() async => const [];

  @override
  Future<BulkCreateResult> bulkAdd(
    List<ItemPayload> items, {
    String? storeName,
  }) async {
    calls.add(items);
    storeNames.add(storeName);
    if (throwOnce != null) {
      final e = throwOnce!;
      throwOnce = null;
      throw e;
    }
    if (hold != null) return hold!.future;
    return script!(items);
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
            createdAt: 0),
        CategoryModel(
            id: 'cat_personal',
            name: 'Chăm sóc cá nhân',
            icon: '🧴',
            color: '#FFEAA7',
            isDefault: true,
            sortOrder: 5,
            createdAt: 0),
        CategoryModel(
            id: 'cat_other',
            name: 'Khác',
            icon: '📦',
            color: '#DDA0DD',
            isDefault: true,
            sortOrder: 6,
            createdAt: 0),
      ];
}

ItemModel itemModel(String name, int price) {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return ItemModel(
    id: 'srv-$name',
    name: name,
    price: price,
    categoryId: 'cat_food',
    categoryName: 'Ăn uống',
    categoryIcon: '🍜',
    categoryColor: '#FF6B6B',
    createdAt: ms,
    updatedAt: ms,
    serverId: 'srv-$name',
    isSynced: true,
  );
}

OcrResult result(List<OcrItem> items) => OcrResult(
      items: items,
      rawText: '',
      quality: OcrQuality.good,
      source: OcrSource.geminiVision,
    );

ReceiptHistoryEntry recentEntry(String name, int price, {int daysAgo = 2}) =>
    ReceiptHistoryEntry(
      name: name,
      price: price,
      purchasedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );

final _line1 = OcrItem(name: 'Cà phê sữa', price: 25000, categoryId: 'cat_food');
final _line2 = OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food');

PrimaryButton _submitButton(WidgetTester tester) => tester.widget<PrimaryButton>(
    find.byKey(const Key('ocrConfirm_submitButton')));

// DropdownButtonFormField (Flutter 3.22) không expose widget DropdownButton
// con → đọc label đang hiển thị (child của item được chọn).
String? _dropdownLabel(WidgetTester tester, Key key) {
  final texts = find.descendant(of: find.byKey(key), matching: find.byType(Text));
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}

/// Snackbar nổi che nút xác nhận ở đáy → đẩy thời gian cho nó ẩn hẳn trước
/// khi bấm lần nữa.
Future<void> _dismissSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4, milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<_FakeItemsNotifier> _pumpConfirm(
  WidgetTester tester, {
  required OcrResult ocrResult,
  List<ReceiptHistoryEntry> entries = const [],

  /// M-1 — sổ giá local cho auto-match; mặc định rỗng để giữ hành vi p1.
  List<PriceHistoryMatchRecord> matchRecords = const [],
  _FakeItemsNotifier? items,
  int bulkMax = 50,
}) async {
  final fake = items ?? _FakeItemsNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => fake),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        ocrRecentEntriesProvider.overrideWith((ref) => Future.value(entries)),
        ocrMatchRecordsProvider
            .overrideWith((ref) => Future.value(matchRecords)),
        bulkMaxProvider.overrideWithValue(bulkMax),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: OcrReviewConfirm(
            result: ocrResult,
            onFinished: () => finishedFlag = true,
            onRetake: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

bool finishedFlag = false;

void main() {
  setUp(() {
    CategoryClassifier.resetLearned();
    finishedFlag = false;
  });

  // ── Tests ──────────────────────────────────────────────────────────────────

  testWidgets(
      'AC 5.1 — mỗi dòng đủ 3 thành phần: tên editable + giá numeric + '
      'dropdown category mặc định = gợi ý classifier', (tester) async {
    await _pumpConfirm(tester, ocrResult: result([_line1]));

    final name = tester.widget<TextField>(
        find.byKey(const Key('ocrConfirm_name_line1')));
    final price = tester.widget<TextField>(
        find.byKey(const Key('ocrConfirm_price_line1')));
    expect(name.controller!.text, 'Cà phê sữa');
    expect(price.controller!.text, '25000');
    expect(price.keyboardType, TextInputType.number);

    // 'Cà phê sữa' khớp rule 'cà phê' → cat_food (gợi ý tự động).
    expect(_dropdownLabel(tester, const Key('ocrConfirm_category_line1')),
        '🍜  Ăn uống'); // gợi ý cat_food của classifier

    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'AC 5.2 — đổi category cho tên X → dòng cùng tên sau đó được gợi ý '
      'lại category user đã chọn', (tester) async {
    await _pumpConfirm(tester, ocrResult: result([_line1]));

    // User chủ động chọn "Chăm sóc cá nhân" cho 'Cà phê sữa'.
    await tester.tap(find.byKey(const Key('ocrConfirm_category_line1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🧴  Chăm sóc cá nhân').last);
    await tester.pumpAndSettle();

    expect(_dropdownLabel(tester, const Key('ocrConfirm_category_line1')),
        '🧴  Chăm sóc cá nhân');

    // Thêm dòng mới cùng tên → gợi ý theo lựa chọn vừa học (không phải cat_food).
    await tester.tap(find.byKey(const Key('ocrResultList_addButton')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('ocrConfirm_name_line2')), 'Cà phê sữa');
    await tester.pump();

    expect(_dropdownLabel(tester, const Key('ocrConfirm_category_line2')),
        '🧴  Chăm sóc cá nhân'); // đã học từ lựa chọn của user (AC 5.2)
  });

  testWidgets(
      'AC 5.3 — trùng item ≤ 7 ngày + giá ±10%: badge "Có thể trùng với '
      '<tên> ngày X" + checkbox mặc định KHÔNG tick', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_line1]),
      entries: [recentEntry('Cà phê sữa', 26000)], // lệch ~3.8% — trong ngưỡng
    );

    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsOneWidget);
    expect(find.textContaining('Có thể trùng với "Cà phê sữa"'), findsOneWidget);
    final cb = tester.widget<Checkbox>(
        find.byKey(const Key('ocrConfirm_keep_line1')));
    expect(cb.value, isFalse);
  });

  testWidgets(
      'AC 5.4 — không tick "vẫn thêm" → dòng LOẠI khỏi batch (N = 0, nút '
      'disabled); tick → quay lại batch (N = 1, enable)', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_line1]),
      entries: [recentEntry('Cà phê sữa', 26000)],
    );

    // Mặc định: không tick → không đếm → nút disabled.
    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('ocrConfirm_keep_line1')));
    await tester.pump();

    final cb = tester.widget<Checkbox>(
        find.byKey(const Key('ocrConfirm_keep_line1')));
    expect(cb.value, isTrue);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'AC 5.5 — sửa tên/giá khiến điều kiện trùng hết → badge TỰ BIẾN NGAY '
      '(recompute real-time)', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_line1]),
      entries: [recentEntry('Cà phê sữa', 25000)],
    );
    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsOneWidget);

    // Sửa giá ra ngoài ±10% → badge biến mất, dòng đếm lại.
    await tester.enterText(
        find.byKey(const Key('ocrConfirm_price_line1')), '40000'); // lệch 60%
    await tester.pump();
    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsNothing);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    // Sửa tiếp tên → category recompute theo tên mới, vẫn không còn badge.
    await tester.enterText(
        find.byKey(const Key('ocrConfirm_name_line1')), 'Nước rửa tay');
    await tester.pump();
    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsNothing);
  });

  testWidgets(
      'AC 5.6 — bấm xác nhận: loading trong lúc gọi, bulk nhận đúng N dòng '
      'source=ocr + category đã chọn (AC 5.11: BE bulk tự ghi price history '
      '— mobile chỉ bảo đảm mọi item đi qua bulk)', (tester) async {
    final items = _FakeItemsNotifier()
      ..hold = Completer<BulkCreateResult>()
      ..script = (payloads) => BulkCreateResult(
            created: [itemModel('Sữa tươi', 25000), itemModel('Bánh mì', 15000)],
            failed: const [],
            totalSubmitted: 2,
            totalCreated: 2,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([_line1, _line2]),
      items: items,
    );

    await tester.enterText(
        find.byKey(const Key('ocrConfirm_name_line1')), '  Sữa tươi  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pump();

    // Loading trong lúc gọi API (spinner thay label — AC 5.6).
    expect(find.byKey(const Key('primaryButton_loading')), findsOneWidget);

    items.hold!.complete(BulkCreateResult(
      created: [itemModel('Sữa tươi', 25000), itemModel('Bánh mì', 15000)],
      failed: const [],
      totalSubmitted: 2,
      totalCreated: 2,
      totalFailed: 0,
    ));
    await tester.pumpAndSettle();

    expect(items.calls, hasLength(1));
    final payloads = items.calls.single;
    expect(payloads, hasLength(2));
    expect(payloads[0].name, 'Sữa tươi'); // đã trim
    expect(payloads[0].price, 25000);
    expect(payloads[0].source, 'ocr');
    expect(payloads[0].categoryId, 'cat_food');
    expect(payloads[1].source, 'ocr');
    expect(items.storeNames.single, isNull); // không nhập store → không gửi

    // AC 5.24 (M-1) — xác nhận sau bulk theo spec mới.
    expect(find.text('2 món đã ghi vào sổ giá'), findsOneWidget);
    expect(find.byKey(const Key('primaryButton_loading')), findsNothing);
    expect(finishedFlag, isTrue); // hết dòng phải sửa → pop về màn trước
  });

  testWidgets(
      'AC 5.7 — partial failure: hiển thị số món thành công + từng dòng fail '
      'kèm lý do; thử lại CHỈ các dòng fail, không tạo trùng dòng đã xong',
      (tester) async {
    var callCount = 0;
    final items = _FakeItemsNotifier()
      ..script = (payloads) {
        callCount++;
        if (callCount == 1) {
          return BulkCreateResult(
            created: [itemModel('Sữa tươi', 25000)],
            failed: const [
              BulkItemFailure(
                index: 1,
                code: 'ITEM_INVALID_CATEGORY',
                message: 'Danh mục không tồn tại',
              ),
            ],
            totalSubmitted: 2,
            totalCreated: 1,
            totalFailed: 1,
          );
        }
        return BulkCreateResult(
          created: [itemModel('Bánh mì', 15000)],
          failed: const [],
          totalSubmitted: 1,
          totalCreated: 1,
          totalFailed: 0,
        );
      };

    await _pumpConfirm(
      tester,
      ocrResult: result([_line1, _line2]),
      items: items,
    );

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    // Số món thành công + dòng thất bại kèm lý do.
    expect(find.textContaining('Đã thêm 1/2 món'), findsOneWidget);
    expect(find.byKey(const Key('ocrConfirm_failBadge_line2')), findsOneWidget);
    expect(find.textContaining('Chưa lưu được'), findsOneWidget);
    // Dòng đã thành công bị loại khỏi editor.
    expect(find.byKey(const Key('ocrConfirm_name_line1')), findsNothing);
    expect(finishedFlag, isFalse); // còn dòng lỗi → chưa pop

    // Thử lại → CHỈ gửi dòng fail.
    await _dismissSnackbar(tester);
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    expect(items.calls, hasLength(2));
    expect(items.calls.last, hasLength(1));
    expect(items.calls.last.single.name, 'Bánh mì');
    expect(find.text('1 món đã ghi vào sổ giá'), findsOneWidget); // AC 5.24
    expect(finishedFlag, isTrue);
  });

  testWidgets(
      'AC 5.8 — batch > BULK_MAX: chặn TRƯỚC khi gọi API với thông báo rõ',
      (tester) async {
    final items = _FakeItemsNotifier()
      ..script = (payloads) => const BulkCreateResult(
            created: [],
            failed: [],
            totalSubmitted: 3,
            totalCreated: 3,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([
        OcrItem(name: 'Món 1', price: 1000, categoryId: 'cat_other'),
        OcrItem(name: 'Món 2', price: 2000, categoryId: 'cat_other'),
        OcrItem(name: 'Món 3', price: 3000, categoryId: 'cat_other'),
      ]),
      items: items,
      // App thật luôn dùng BULK_MAX = 50 (unit test chốt message); override 2
      // ở đây chỉ để test được NHÁNH chặn mà không pump 51 dòng.
      bulkMax: 2,
    );

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pump();

    expect(find.text('Tối đa 2 món mỗi lần thêm'), findsOneWidget);
    expect(items.calls, isEmpty); // KHÔNG gọi API
    expect(finishedFlag, isFalse);
  });

  testWidgets(
      'AC 5.9 — 429 throttle: message thân thiện, giữ nguyên màn, không crash, '
      'thử lại được', (tester) async {
    final items = _FakeItemsNotifier()
      ..throwOnce = const ApiException(
          code: 'RATE_LIMITED', message: 'Too many requests', statusCode: 429)
      ..script = (payloads) => BulkCreateResult(
            created: [itemModel('Sữa tươi', 25000)],
            failed: const [],
            totalSubmitted: 1,
            totalCreated: 1,
            totalFailed: 0,
          );
    await _pumpConfirm(tester, ocrResult: result([_line1]), items: items);

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn đang thao tác quá nhanh, thử lại sau ít phút'),
        findsOneWidget);
    // Màn giữ nguyên — dòng vẫn đó, có thể thử lại.
    expect(find.byKey(const Key('ocrConfirm_name_line1')), findsOneWidget);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(finishedFlag, isFalse);

    await _dismissSnackbar(tester);
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();
    expect(items.calls, hasLength(2));
    expect(finishedFlag, isTrue);
  });

  testWidgets(
      'AC 5.10 — offline: lỗi network rõ ràng, TOÀN BỘ state confirm '
      '(tên/giá/category/checkbox) giữ nguyên để thử lại', (tester) async {
    final items = _FakeItemsNotifier()
      ..throwOnce = ApiException.network(
          'Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.')
      ..script = (payloads) => const BulkCreateResult(
            created: [],
            failed: [],
            totalSubmitted: 2,
            totalCreated: 2,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([_line1, _line2]),
      items: items,
      entries: [recentEntry('Bánh mì', 15500)], // dòng 2 trùng (lệch ~3%)
    );

    // Sửa tên dòng 1 + tick "vẫn thêm" cho dòng trùng trước khi submit.
    await tester.enterText(
        find.byKey(const Key('ocrConfirm_name_line1')), 'Sữa tươi mới');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ocrConfirm_keep_line2')));
    await tester.pump();
    expect(find.text('Xác nhận thêm 2 món'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    // Lỗi network rõ ràng, không pop.
    expect(find.text('Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget);
    expect(finishedFlag, isFalse);

    // TOÀN BỘ state giữ nguyên: tên đã sửa, checkbox đã tick, N không đổi.
    final name = tester.widget<TextField>(
        find.byKey(const Key('ocrConfirm_name_line1')));
    expect(name.controller!.text, 'Sữa tươi mới');
    final cb = tester.widget<Checkbox>(
        find.byKey(const Key('ocrConfirm_keep_line2')));
    expect(cb.value, isTrue);
    expect(find.text('Xác nhận thêm 2 món'), findsOneWidget);

    // Có mạng lại → bấm lại chạy bình thường (retry).
    await _dismissSnackbar(tester);
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();
    expect(items.calls, hasLength(2));
  });

  testWidgets(
      'AC 5.12 — bỏ/hủy hết dòng hợp lệ: nút xác nhận disabled, không gửi '
      'request rỗng', (tester) async {
    final items = _FakeItemsNotifier()
      ..script = (payloads) => const BulkCreateResult(
            created: [],
            failed: [],
            totalSubmitted: 0,
            totalCreated: 0,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([
        OcrItem(
            name: 'X', price: 20000000, categoryId: 'cat_other', needsReview: true),
      ]),
      items: items,
    );

    // Xoá sạch tên dòng → 0 dòng hợp lệ.
    await tester.enterText(find.byKey(const Key('ocrConfirm_name_line1')), '');
    await tester.pump();

    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull); // disabled
  });
}
