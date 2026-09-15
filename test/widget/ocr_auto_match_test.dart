
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

/// M-1 — F-#5 Phase 2 Auto-Match: widget test màn CONFIRM, map 1-1 các AC
/// 5.15–5.25 (p1 đã phủ 5.1–5.14 trong ocr_confirm_flow_test.dart).

// ── Fakes (không chạm SQLite/API thật) ───────────────────────────────────────

class _FakeItemsNotifier extends ItemsNotifier {
  BulkCreateResult Function(List<ItemPayload> payloads)? script;

  /// Ném lỗi ĐÚNG 1 lần (offline — AC 5.25), các lần sau chạy [script].
  ApiException? throwOnce;

  final calls = <List<ItemPayload>>[];

  @override
  Future<List<ItemModel>> build() async => const [];

  @override
  Future<BulkCreateResult> bulkAdd(
    List<ItemPayload> items, {
    String? storeName,
  }) async {
    calls.add(items);
    if (throwOnce != null) {
      final e = throwOnce!;
      throwOnce = null;
      throw e;
    }
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

PriceHistoryMatchRecord record(
  String name,
  int price, {
  int daysAgo = 40,
  String? barcode,
}) =>
    PriceHistoryMatchRecord(
      name: name,
      price: price,
      barcode: barcode,
      purchasedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );

PrimaryButton _submitButton(WidgetTester tester) => tester.widget<PrimaryButton>(
    find.byKey(const Key('ocrConfirm_submitButton')));

ChoiceChip _modeChip(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key('ocrConfirm_mode_$key')));

Future<void> _dismissSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4, milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<_FakeItemsNotifier> _pumpConfirm(
  WidgetTester tester, {
  required OcrResult ocrResult,
  List<ReceiptHistoryEntry> entries = const [],
  List<PriceHistoryMatchRecord> matchRecords = const [],
  _FakeItemsNotifier? items,
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
        bulkMaxProvider.overrideWithValue(50),
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

final _teaLine = OcrItem(
    name: 'Trà xanh 500ml', price: 12000, categoryId: 'cat_food'); // AC 5.15
final _teaRecord =
    record('trà xanh 500ml', 12500, daysAgo: 40); // ±4%, ngoài cửa sổ trùng

void main() {
  setUp(() {
    CategoryClassifier.resetLearned();
    finishedFlag = false;
  });

  testWidgets(
      'AC 5.15 — tên + giá ±10% (40 ngày): tự tick sẵn + badge "Tự khớp: '
      '<tên record>" + đếm trong N mà user KHÔNG cần thao tác gì', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [_teaRecord],
    );

    // (b) Badge với đúng tên record khớp.
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsOneWidget);
    expect(find.text('Tự khớp: "trà xanh 500ml"'), findsOneWidget);
    // (a) Tự tick sẵn "vẫn thêm".
    final cb = tester.widget<Checkbox>(
        find.byKey(const Key('ocrConfirm_keep_line1')));
    expect(cb.value, isTrue);
    // (c) Đếm trong N, nút enable — không thao tác gì.
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
    // Không badge trùng.
    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsNothing);
  });

  testWidgets(
      'AC 5.16 — barcode inert ở UI: OcrItem chưa có barcode, record sổ giá '
      'có barcode cũng KHÔNG tạo badge nào khi tên/giá không khớp',
      (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([
        OcrItem(name: 'Mì Hảo Hảo', price: 18000, categoryId: 'cat_food'),
      ]),
      matchRecords: [
        record('mì ăn liền', 10000, daysAgo: 20, barcode: '8934567890123'),
      ],
    );

    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    expect(find.textContaining('Tự khớp'), findsNothing);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
  });

  testWidgets(
      'AC 5.17 — tên rác ≤ 2 ký tự: KHÔNG auto-match (kể cả sổ giá có record '
      'cùng key), dòng về luồng uncertain p1', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([
        OcrItem(name: 'ab', price: 12000, categoryId: 'cat_food'),
      ]),
      matchRecords: [record('ab', 12000, daysAgo: 40)],
    );

    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    // Dòng vẫn hợp lệ như dòng thường (đi luồng p1, không tick gì cả).
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
  });

  testWidgets(
      'AC 5.18 — dòng vừa khớp auto-match vừa nghi trùng ≤ 7 ngày: cảnh báo '
      'trùng THẮNG — checkbox KHÔNG tick, không badge "Tự khớp"',
      (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      entries: [recentEntry('Trà xanh 500ml', 12300)], // trùng p1 (2 ngày)
      matchRecords: [_teaRecord], // record 40 ngày đáng lẽ auto-match
    );

    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsOneWidget);
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    final cb = tester.widget<Checkbox>(
        find.byKey(const Key('ocrConfirm_keep_line1')));
    expect(cb.value, isFalse); // KHÔNG tự tick dòng nghi trùng
    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets(
      'AC 5.18 — record khớp nằm trong 7 ngày (kể cả khi item local không có): '
      'không tự tick, không badge', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [record('trà xanh 500ml', 12000, daysAgo: 3)],
    );

    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    expect(find.byKey(const Key('ocrConfirm_dupBadge_line1')), findsNothing);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget); // dòng thường
  });

  testWidgets(
      'AC 5.19 — dòng không khớp: hành vi y hệt p1, không badge, không đổi '
      'default nào', (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [record('bánh quy coco', 25000, daysAgo: 5)],
    );

    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_modeChip(tester, 'all').selected, isTrue); // mặc định "Gửi tất cả"
  });

  testWidgets(
      'AC 5.21 — bỏ tick dòng tự khớp: LOẠI khỏi batch NGAY (N giảm, nút '
      'disable), badge VẪN hiển thị, không dialog; tick lại → quay lại batch',
      (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [_teaRecord],
    );
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    // Bỏ tick → N = 0 tức thì, nút disabled, badge vẫn đó.
    await tester.tap(find.byKey(const Key('ocrConfirm_keep_line1')));
    await tester.pump();
    expect(
        tester.widget<Checkbox>(
            find.byKey(const Key('ocrConfirm_keep_line1'))).value,
        isFalse);
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsOneWidget);
    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
    expect(find.byType(AlertDialog), findsNothing); // không có dialog xác nhận

    // Tick lại → quay lại batch.
    await tester.tap(find.byKey(const Key('ocrConfirm_keep_line1')));
    await tester.pump();
    expect(
        tester.widget<Checkbox>(
            find.byKey(const Key('ocrConfirm_keep_line1'))).value,
        isTrue);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'AC 5.22 — sửa giá lệch quá ±10%: badge "Tự khớp" biến mất NGAY '
      '(recompute real-time) và thao tác sửa đánh dấu dòng "đã review"',
      (tester) async {
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [_teaRecord],
    );
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('ocrConfirm_price_line1')), '40000'); // lệch 233%
    await tester.pump();

    // Badge tắt ngay, dòng về semantics dòng thường (vẫn hợp lệ, vẫn đếm).
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsNothing);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    // Thao tác sửa đã đánh dấu "đã review" → chế độ "Chỉ dòng đã review" đếm.
    await tester.tap(find.byKey(const Key('ocrConfirm_mode_reviewed')));
    await tester.pump();
    expect(_modeChip(tester, 'reviewed').selected, isTrue);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'AC 5.23 — 2 chế độ: mặc định "Gửi tất cả" (auto-tick chưa đụng cũng '
      'gửi); "Chỉ dòng đã review" CHỈ gửi dòng user đã tương tác',
      (tester) async {
    final items = _FakeItemsNotifier()
      ..script = (payloads) => BulkCreateResult(
            created: [itemModel('Bánh mì', 15000)],
            failed: const [],
            totalSubmitted: 1,
            totalCreated: 1,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([
        _teaLine, // sẽ auto-match, KHÔNG bị đụng tới
        OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
      ]),
      matchRecords: [_teaRecord],
      items: items,
    );

    // Mặc định: "Gửi tất cả" chọn sẵn, N = 2 (1 auto + 1 thường).
    expect(_modeChip(tester, 'all').selected, isTrue);
    expect(_modeChip(tester, 'reviewed').selected, isFalse);
    expect(find.text('Xác nhận thêm 2 món'), findsOneWidget);

    // Đổi sang "Chỉ dòng đã review": dòng auto-tick chưa đụng bị loại, dòng
    // thường chưa đụng cũng chưa tính → tạm thời 0.
    await tester.tap(find.byKey(const Key('ocrConfirm_mode_reviewed')));
    await tester.pump();
    expect(_modeChip(tester, 'reviewed').selected, isTrue);
    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);

    // User tương tác dòng 2 (sửa tên) → thành "đã review" → được gửi.
    await tester.enterText(
        find.byKey(const Key('ocrConfirm_name_line2')), 'Bánh mì trứng');
    await tester.pump();
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    expect(items.calls, hasLength(1));
    final payloads = items.calls.single;
    expect(payloads, hasLength(1)); // CHỈ dòng đã review
    expect(payloads.single.name, 'Bánh mì trứng');
    expect(find.text('1 món đã ghi vào sổ giá'), findsOneWidget); // AC 5.24
    expect(finishedFlag, isTrue);
  });

  testWidgets(
      'AC 5.23 (edge) — "Chỉ dòng đã review" mà 0 dòng thỏa → nút disabled, '
      'không gửi request rỗng', (tester) async {
    final items = _FakeItemsNotifier();
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [_teaRecord],
      items: items,
    );

    await tester.tap(find.byKey(const Key('ocrConfirm_mode_reviewed')));
    await tester.pump();

    expect(find.text('Xác nhận thêm 0 món'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pump();
    expect(items.calls, isEmpty); // không gửi gì
  });

  testWidgets(
      'AC 5.24 — bulk thành công: xác nhận "N món đã ghi vào sổ giá" '
      '(N = số created; barcode/price history do BE ghi)', (tester) async {
    final items = _FakeItemsNotifier()
      ..script = (payloads) => BulkCreateResult(
            created: [
              itemModel('Trà xanh 500ml', 12000),
              itemModel('Bánh mì', 15000),
            ],
            failed: const [],
            totalSubmitted: 2,
            totalCreated: 2,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([
        _teaLine, // auto-match — "Gửi tất cả" gửi luôn không cần đụng
        OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
      ]),
      matchRecords: [_teaRecord],
      items: items,
    );

    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('2 món đã ghi vào sổ giá'), findsOneWidget);
    expect(items.calls.single, hasLength(2)); // auto line nằm trong batch
    expect(finishedFlag, isTrue);
  });

  testWidgets(
      'AC 5.25 — offline: auto-match vẫn chạy trên dữ liệu local (badge + '
      'tự tick như online); submit lỗi network thân thiện, GIỮ TOÀN trạng thái '
      'để thử lại', (tester) async {
    final items = _FakeItemsNotifier()
      ..throwOnce =
          ApiException.network('Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.')
      ..script = (payloads) => BulkCreateResult(
            created: [itemModel('Trà xanh 500ml', 12000)],
            failed: const [],
            totalSubmitted: 1,
            totalCreated: 1,
            totalFailed: 0,
          );
    await _pumpConfirm(
      tester,
      ocrResult: result([_teaLine]),
      matchRecords: [_teaRecord], // sổ giá SQLite local — không cần mạng
      items: items,
    );

    // Auto-match hoạt động như online (badge + tick sẵn).
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsOneWidget);
    expect(
        tester.widget<Checkbox>(
            find.byKey(const Key('ocrConfirm_keep_line1'))).value,
        isTrue);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    // Submit offline → lỗi thân thiện, không pop, giữ nguyên toàn bộ state.
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget);
    expect(finishedFlag, isFalse);
    expect(find.byKey(const Key('ocrConfirm_autoBadge_line1')), findsOneWidget);
    expect(
        tester.widget<Checkbox>(
            find.byKey(const Key('ocrConfirm_keep_line1'))).value,
        isTrue);
    expect(find.text('Xác nhận thêm 1 món'), findsOneWidget);

    // Có mạng lại → thử lại thành công.
    await _dismissSnackbar(tester);
    await tester.tap(find.byKey(const Key('ocrConfirm_submitButton')));
    await tester.pumpAndSettle();
    expect(items.calls, hasLength(2));
    expect(finishedFlag, isTrue);
  });
}
