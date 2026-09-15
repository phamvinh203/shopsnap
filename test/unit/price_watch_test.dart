import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/core/utils/price_watch.dart';
import 'package:shopsnap/models/price_history_model.dart';

PriceHistoryPoint _p(int price, DateTime at) =>
    PriceHistoryPoint(id: 'p$price-${at.millisecondsSinceEpoch}', price: price, purchasedAt: at);

void main() {
  group('normalizeMatchKey (AC 6.9/6.13 — match tên normalize)', () {
    test('lowercase + trim + gộp khoảng trắng', () {
      expect(normalizeMatchKey('  Sữa   Tươi  VINAMILK '), 'sữa tươi vinamilk');
      expect(normalizeMatchKey('SỮA TƯƠI VINAMILK'), 'sữa tươi vinamilk');
      expect(normalizeMatchKey('\tBánh  mì\n'), 'bánh mì');
    });
  });

  group('matchesProductKey (barcode ưu tiên, fallback tên)', () {
    test('cả hai có barcode → so barcode, bỏ qua tên lệch', () {
      expect(
        matchesProductKey(
          aBarcode: '8934567890', aName: 'Sữa tươi',
          bBarcode: '8934567890', bName: 'Tên khác hẳn',
        ),
        isTrue,
      );
      expect(
        matchesProductKey(
          aBarcode: '8934567890', aName: 'cùng tên',
          bBarcode: '1111', bName: 'cùng tên',
        ),
        isFalse, // barcode lệch → khác sản phẩm dù tên giống
      );
    });

    test('một bên không có barcode → fallback tên normalize', () {
      expect(
        matchesProductKey(
          aBarcode: null, aName: ' Sữa   tươi VINAMILK ',
          bBarcode: '8934567890', bName: 'sữa tươi vinamilk',
        ),
        isTrue,
      );
      expect(
        matchesProductKey(aBarcode: null, aName: 'bánh', bBarcode: null, bName: 'bánh mì'),
        isFalse, // exact match, không fuzzy prefix
      );
    });
  });

  group('evaluatePriceWatch (AC 6.13/6.14/6.15/6.16)', () {
    const watched = true;
    const baseline = (minPrice: 30000, lastPrice: 30000);

    test('AC 6.16 — chưa có baseline (0 record history) → không alert', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 10000,
        knownMinPrice: null,
        lastPurchasePrice: null,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isFalse);
    });

    test('món không watched → không alert', () {
      final e = evaluatePriceWatch(
        watched: false,
        newPrice: 10000,
        knownMinPrice: 30000,
        lastPurchasePrice: 30000,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isFalse);
    });

    test('AC 6.13a — giá mới thấp hơn mức thấp nhất đã biết → alert newLowest', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 28000,
        knownMinPrice: baseline.minPrice,
        lastPurchasePrice: baseline.lastPrice,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isTrue);
      expect(e.reason, PriceWatchReason.newLowest);
    });

    test('AC 6.13b — giảm ≥ 10% so lần mua gần nhất (dù chưa phá min) → droppedEnough', () {
      // min đã biết 20000 (do lần khác rẻ hơn), lần gần nhất 30000 → 11.3k drop 37.8%... dùng case rõ:
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 26000, // giảm 13.3% so với 30000
        knownMinPrice: 20000,
        lastPurchasePrice: 30000,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isTrue);
      expect(e.reason, PriceWatchReason.droppedEnough);
      expect(e.dropPercent, closeTo(13.33, 0.01));
    });

    test('AC 6.14 — giảm 9.99% (< PRICE_WATCH_DROP_PERCENT) → KHÔNG alert', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 27001, // giảm 9.996% so với 30000
        knownMinPrice: 27001, // không phá min → chỉ (b) xét được
        lastPurchasePrice: 30000,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isFalse);
      expect(AppConstants.priceWatchDropPercent, 10.0); // giá trị mặc định spec
    });

    test('đúng 10% (biên ≥) → alert', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 27000, // giảm đúng 10% so với 30000
        knownMinPrice: 27000,
        lastPurchasePrice: 30000,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isTrue);
      expect(e.reason, PriceWatchReason.droppedEnough);
    });

    test('AC 6.15 — giá P đã alert rồi mà lần mua mới nhất vẫn là P → không lặp', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 28000,
        knownMinPrice: 30000,
        lastPurchasePrice: 30000,
        lastAlertedPrice: 28000, // đã từng alert đúng mức này
      );
      expect(e.shouldAlert, isFalse);
    });

    test('AC 6.15 — lần giảm MỚI thấp hơn mức đã alert → alert lại đúng 1 lần', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 25000,
        knownMinPrice: 28000,
        lastPurchasePrice: 28000,
        lastAlertedPrice: 28000,
      );
      expect(e.shouldAlert, isTrue);
      expect(e.reason, PriceWatchReason.newLowest);
    });

    test('giá tăng / bằng nhau → không alert', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 32000,
        knownMinPrice: 30000,
        lastPurchasePrice: 30000,
        lastAlertedPrice: null,
      );
      expect(e.shouldAlert, isFalse);
    });
  });

  group('baselineFromPoints', () {
    test('loại record mới nhất khi excludeLatest (flow add)', () {
      final points = [
        _p(25000, DateTime(2026, 9, 15)), // vừa thêm
        _p(30000, DateTime(2026, 9, 10)),
        _p(28000, DateTime(2026, 9, 1)),
      ];
      final b = baselineFromPoints(points, excludeLatestRecord: true);
      expect(b, isNotNull);
      expect(b!.minPrice, 28000);
      expect(b.lastPrice, 30000);
    });

    test('không exclude khi edit flow', () {
      final points = [
        _p(25000, DateTime(2026, 9, 15)),
        _p(30000, DateTime(2026, 9, 10)),
      ];
      final b = baselineFromPoints(points, excludeLatestRecord: false);
      expect(b!.minPrice, 25000);
      expect(b.lastPrice, 25000);
    });

    test('input không thứ tự vẫn tính đúng; rỗng → null (AC 6.16)', () {
      final b = baselineFromPoints([
        _p(30000, DateTime(2026, 9, 10)),
        _p(20000, DateTime(2026, 9, 1)),
      ], excludeLatestRecord: false);
      expect(b!.minPrice, 20000);

      expect(baselineFromPoints(const [], excludeLatestRecord: true), isNull);
    });
  });

  group('bestPriceWithinDays (AC 6.9 — "Giá tốt nhất trong 90 ngày")', () {
    final now = DateTime(2026, 9, 15, 10, 0);

    test('chọn record RẺ NHẤT trong cửa sổ 90 ngày kèm ngày', () {
      final best = bestPriceWithinDays([
        _p(32000, now.subtract(const Duration(days: 5))),
        _p(24000, now.subtract(const Duration(days: 30))),
        _p(28000, now.subtract(const Duration(days: 1))),
      ], now: now);
      expect(best, isNotNull);
      expect(best!.price, 24000);
      expect(best.date.day, now.subtract(const Duration(days: 30)).day);
    });

    test('record cũ hơn 90 ngày bị loại khỏi cửa sổ', () {
      final best = bestPriceWithinDays([
        _p(10000, now.subtract(const Duration(days: 120))), // quá cũ
        _p(29000, now.subtract(const Duration(days: 10))),
      ], now: now);
      expect(best!.price, 29000);
    });

    test('không có point nào → null (UI ẩn khối, không hiện "0 đ")', () {
      expect(bestPriceWithinDays(const [], now: now), isNull);
      // Tất cả ngoài cửa sổ → null
      expect(
        bestPriceWithinDays([_p(10000, now.subtract(const Duration(days: 91)))], now: now),
        isNull,
      );
    });
  });
}
