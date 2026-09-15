import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/price_watch.dart';
import 'package:shopsnap/models/shopping_list_item_model.dart';
import 'package:shopsnap/services/price_watch_service.dart';

ShoppingListItem _watched(
  String id, {
  required String name,
  String? barcode,
  int? lastAlertPrice,
}) =>
    ShoppingListItem(
      id: id,
      name: name,
      barcode: barcode,
      watched: true,
      lastAlertPrice: lastAlertPrice,
      createdAt: 0,
      updatedAt: 0,
    );

class _Recorder {
  final notified = <String>[];
  final persisted = <(String, int)>[];
}

void main() {
  late _Recorder rec;

  setUp(() => rec = _Recorder());

  PriceWatchService buildService({
    List<ShoppingListItem> watched = const [],
    WatchBaseline? Function({
      required String name,
      String? barcode,
      required bool excludeLatestRecord,
    })?
    baseline,
    Object? throwOnBaseline,
  }) {
    return PriceWatchService(
      loadWatchedItems: () async => watched,
      loadBaseline: ({required name, barcode, required excludeLatestRecord}) async {
        if (throwOnBaseline != null) throw throwOnBaseline;
        return baseline?.call(
          name: name,
          barcode: barcode,
          excludeLatestRecord: excludeLatestRecord,
        );
      },
      notify: ({required itemName, required price, required reason, String? itemId}) async {
        rec.notified.add('$itemName@$price:${reason.name}');
      },
      persistAlert: (itemId, price) async {
        rec.persisted.add((itemId, price));
      },
    );
  }

  test('AC 6.13 — giá mới phá min → bắn notification + persist alert đúng món', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'Sữa tươi Vinamilk')],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa tươi vinamilk',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 1);
    expect(rec.notified, ['Sữa tươi Vinamilk@28000:newLowest']);
    expect(rec.persisted, [('w1', 28000)]);
  });

  test('AC 6.13 — match barcode ưu tiên khi cả hai có', () async {
    final svc = buildService(
      watched: [
        _watched('w1', name: 'Tên trong list', barcode: '8934567890'),
        _watched('w2', name: '8934567890'), // tên trùng barcode — không được khớp
      ],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'Tên khác hẳn trên hóa đơn',
      barcode: '8934567890',
      price: 20000,
      excludeLatestRecord: true,
    );

    // Chỉ món watch có barcode khớp được alert; món tên trùng barcode bị bỏ qua.
    expect(rec.persisted, [('w1', 20000)]);
    expect(fired, 1);
  });

  test('AC 6.13b — trigger theo nhánh giảm ≥ 10% (reason droppedEnough)', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'bánh mì')],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 20000, lastPrice: 30000),
    );

    await svc.checkAfterItemSaved(
      name: 'Bánh mì',
      price: 26000,
      excludeLatestRecord: true,
    );

    expect(rec.notified.single, 'bánh mì@26000:droppedEnough');
  });

  test('AC 6.15 — lastAlertedPrice trùng giá mới → không alert, không persist', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa', lastAlertPrice: 28000)],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 0);
    expect(rec.notified, isEmpty);
    expect(rec.persisted, isEmpty);
  });

  test('AC 6.16 — chưa có baseline → không alert', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa')],
      baseline: ({required name, barcode, required excludeLatestRecord}) => null,
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 0);
    expect(rec.notified, isEmpty);
  });

  test('không món nào watched khớp → 0 alert', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'khác hẳn')],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa tươi',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 0);
    expect(rec.notified, isEmpty);
  });

  test('nhiều món watched cùng khớp → mỗi món alert riêng', () async {
    final svc = buildService(
      watched: [
        _watched('w1', name: 'sữa tươi'),
        _watched('w2', name: 'SỮA  TƯƠI'), // normalize khớp
      ],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa tươi',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 2);
    expect(rec.persisted.map((p) => p.$1), containsAll(['w1', 'w2']));
  });

  test('lỗi tra cứu baseline → nuốt lỗi, không ném lên caller (không vỡ flow add)', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa')],
      throwOnBaseline: StateError('db down'),
    );

    final fired = await svc.checkAfterItemSaved(
      name: 'sữa',
      price: 28000,
      excludeLatestRecord: true,
    );

    expect(fired, 0);
    expect(rec.notified, isEmpty);
  });

  test('input vô hiệu (tên rỗng / giá 0) → bỏ qua không check', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa')],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    expect(
      await svc.checkAfterItemSaved(name: '   ', price: 1000, excludeLatestRecord: true),
      0,
    );
    expect(
      await svc.checkAfterItemSaved(name: 'sữa', price: 0, excludeLatestRecord: true),
      0,
    );
    expect(rec.notified, isEmpty);
  });

  // ── F-#5 P1 (AC 5.13a/5.14) — watch check sau bulk confirm ─────────────────

  test('AC 5.13a — bulk: quét watched 1 lần cho cả batch, alert theo giá thấp nhất', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa tươi')],
      baseline: ({required name, barcode, required excludeLatestRecord}) {
        expect(excludeLatestRecord, isTrue); // record vừa ghi bị loại khỏi baseline
        return (minPrice: 30000, lastPrice: 30000);
      },
    );

    final fired = await svc.checkAfterBulkSaved(
      items: [
        (name: 'SỮA TƯỚI', barcode: null, price: 32000), // khớp sau normalize
        (name: 'sữa  tươi', barcode: null, price: 28000), // thấp nhất khớp
        (name: 'bánh mì', barcode: null, price: 15000), // không khớp watched
      ],
      excludeLatestRecord: true,
    );

    expect(fired, 1);
    expect(rec.notified.single, 'sữa tươi@28000:newLowest');
    expect(rec.persisted, [('w1', 28000)]);
  });

  test('AC 5.14 — bulk: nhiều dòng + nhiều watched khớp → TỐI ĐA 1 notification', () async {
    final svc = buildService(
      watched: [
        _watched('w1', name: 'sữa tươi'),
        _watched('w2', name: 'SỮA  TƯƠI'), // cùng normalize
        _watched('w3', name: 'bánh mì'),
      ],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    final fired = await svc.checkAfterBulkSaved(
      items: [
        (name: 'sữa tươi', barcode: null, price: 28000),
        (name: 'bánh mì', barcode: null, price: 27000),
      ],
      excludeLatestRecord: true,
    );

    expect(fired, 1); // dừng sau alert đầu tiên — không spam N notification
    expect(rec.notified.length, 1);
  });

  test('bulk: không dòng nào khớp watched / batch rỗng → 0 alert, không lỗi', () async {
    final svc = buildService(
      watched: [_watched('w1', name: 'sữa tươi')],
      baseline: ({required name, barcode, required excludeLatestRecord}) =>
          (minPrice: 30000, lastPrice: 30000),
    );

    expect(
      await svc.checkAfterBulkSaved(
        items: [(name: 'nước tương', barcode: null, price: 42000)],
        excludeLatestRecord: true,
      ),
      0,
    );
    expect(
      await svc.checkAfterBulkSaved(items: const [], excludeLatestRecord: true),
      0,
    );
    expect(
      await svc.checkAfterBulkSaved(
        items: [(name: '   ', barcode: null, price: 0)],
        excludeLatestRecord: true,
      ),
      0,
    );
    expect(rec.notified, isEmpty);
  });
}
