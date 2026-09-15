import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/deal_badge.dart';
import 'package:shopsnap/models/price_history_model.dart';
import 'package:shopsnap/providers/price_history_provider.dart';

/// F-#1 Deal Badge — unit test pure logic + parse model + provider wiring.
/// Phủ ranh giới AC 1.2–1.5, 1.11, 1.12.
void main() {
  // ── resolveDealThreshold (AC 1.11 — fallback default) ──────────────────────
  group('resolveDealThreshold', () {
    test('thiếu field → default 5%', () {
      expect(resolveDealThreshold(null), kDefaultDealThresholdPercent);
      expect(kDefaultDealThresholdPercent, 5.0);
    });

    test('invalid (0 / âm / NaN) → default 5%', () {
      expect(resolveDealThreshold(0), 5.0);
      expect(resolveDealThreshold(-3), 5.0);
      expect(resolveDealThreshold(double.nan), 5.0);
    });

    test('config hợp lệ → dùng nguyên giá trị BE trả (vd 10%)', () {
      expect(resolveDealThreshold(10), 10.0);
      expect(resolveDealThreshold(7.5), 7.5);
    });
  });

  // ── computeDealBadge — ranh giới theo spec (AC 1.2–1.4) ────────────────────
  group('computeDealBadge ranh giới (threshold 5%, avg 100.000 → delta 5.000)', () {
    DealBadgeResult badge(int current, {int avg = 100000, double? threshold}) =>
        computeDealBadge(
          current: current,
          avg: avg,
          min: 90000,
          previous: 98000,
          recordCount: 3,
          thresholdPercent: threshold ?? 5.0,
        );

    test('current == avg → GIÁ BÌNH THƯỜNG, deviation 0.0', () {
      final b = badge(100000);
      expect(b.level, DealBadgeLevel.normal);
      expect(b.label, 'GIÁ BÌNH THƯỜNG');
      expect(b.deviationPercent, 0.0);
      expect(b.hasEnoughData, isTrue);
      expect(b.insufficientNote, isNull);
    });

    test('current == avg − threshold (biên) → GIÁ BÌNH THƯỜNG (strictly less mới là deal)', () {
      expect(badge(95000).level, DealBadgeLevel.normal);
    });

    test('current < avg − threshold → DEAL TỐT (AC 1.2)', () {
      final b = badge(94999);
      expect(b.level, DealBadgeLevel.goodDeal);
      expect(b.label, 'DEAL TỐT');
    });

    test('current == avg + threshold (biên) → GIÁ BÌNH THƯỜNG', () {
      expect(badge(105000).level, DealBadgeLevel.normal);
    });

    test('current > avg + threshold → GIÁ CAO (AC 1.3)', () {
      final b = badge(105001);
      expect(b.level, DealBadgeLevel.highPrice);
      expect(b.label, 'GIÁ CAO');
    });
  });

  // ── % lệch 1 chữ số thập phân + dòng text (AC 1.2/1.3 format) ──────────────
  group('deviation percent + label + suggestion', () {
    test('4500 so avg 4100 → đắt hơn 9.8% (làm tròn 1 chữ số)', () {
      final b = computeDealBadge(
          current: 4500, avg: 4100, recordCount: 2, thresholdPercent: 5.0);
      expect(b.deviationPercent, 9.8);
      expect(b.deviationLabel, 'Đắt hơn trung bình 9.8%');
    });

    test('3800 so avg 4100 → rẻ hơn 7.3%', () {
      final b = computeDealBadge(
          current: 3800, avg: 4100, recordCount: 2, thresholdPercent: 5.0);
      expect(b.deviationPercent, -7.3);
      expect(b.deviationLabel, 'Rẻ hơn trung bình 7.3%');
    });

    test('== avg → label trung tính', () {
      final b = computeDealBadge(
          current: 4100, avg: 4100, recordCount: 2, thresholdPercent: 5.0);
      expect(b.deviationLabel, 'Giá bằng trung bình các lần mua');
    });

    test('suggestion DEAL TỐT đúng chữ spec (AC 1.7)', () {
      final b = computeDealBadge(
          current: 90000, avg: 100000, recordCount: 2, thresholdPercent: 5.0);
      expect(
        b.suggestion,
        'Nếu bạn đang cần mua trong tuần này, đây là mức giá khá tốt.',
      );
    });

    test('suggestion GIÁ CAO đúng chữ spec (AC 1.8)', () {
      final b = computeDealBadge(
          current: 110000, avg: 100000, recordCount: 2, thresholdPercent: 5.0);
      expect(
        b.suggestion,
        'Giá đang cao hơn mức thường thấy — cân nhắc chờ hoặc so cửa hàng khác.',
      );
    });

    test('suggestion GIÁ BÌNH THƯỜNG (đủ dữ liệu) đúng chữ spec (AC 1.9)', () {
      final b = computeDealBadge(
          current: 101000, avg: 100000, recordCount: 2, thresholdPercent: 5.0);
      expect(
        b.suggestion,
        'Giá ở mức tương đương trung bình các lần mua trước.',
      );
    });
  });

  // ── Edge: 1 record / 0 record / avg suy biến ───────────────────────────────
  group('computeDealBadge edge cases', () {
    test('đúng 1 record → GIÁ BÌNH THƯỜNG + note "Chưa đủ dữ liệu để đánh giá giá" (AC 1.5)', () {
      final b = computeDealBadge(
          current: 50000, avg: 50000, recordCount: 1, thresholdPercent: 5.0);
      expect(b.level, DealBadgeLevel.normal);
      expect(b.hasEnoughData, isFalse);
      expect(b.insufficientNote, 'Chưa đủ dữ liệu để đánh giá giá');
    });

    test('0 record → rơi vào nhánh thiếu dữ liệu (UI sẽ ẩn card — AC 1.6)', () {
      final b = computeDealBadge(
          current: 50000, avg: 50000, recordCount: 0, thresholdPercent: 5.0);
      expect(b.level, DealBadgeLevel.normal);
      expect(b.hasEnoughData, isFalse);
      expect(b.insufficientNote, isNotNull);
    });

    test('avg <= 0 (dữ liệu suy biến) → không chia 0, deviation 0, badge normal', () {
      final b = computeDealBadge(
          current: 50000, avg: 0, recordCount: 2, thresholdPercent: 5.0);
      expect(b.deviationPercent, 0.0);
      expect(b.level, DealBadgeLevel.normal);
    });
  });

  // ── AC 1.11 — đổi threshold config → badge đổi theo ────────────────────────
  group('threshold configurable (AC 1.11)', () {
    test('lệch +8%: threshold 5% → GIÁ CAO; threshold 10% → BÌNH THƯỜNG', () {
      final withDefault = computeDealBadge(
          current: 108000, avg: 100000, recordCount: 2, thresholdPercent: 5.0);
      final withConfig = computeDealBadge(
          current: 108000, avg: 100000, recordCount: 2, thresholdPercent: 10.0);
      expect(withDefault.level, DealBadgeLevel.highPrice);
      expect(withConfig.level, DealBadgeLevel.normal);
    });

    test('threshold 10%: −8% → BÌNH THƯỜNG (trong dải); −12% → DEAL TỐT', () {
      final inside = computeDealBadge(
          current: 92000, avg: 100000, recordCount: 2, thresholdPercent: 10.0);
      final outside = computeDealBadge(
          current: 88000, avg: 100000, recordCount: 2, thresholdPercent: 10.0);
      expect(inside.level, DealBadgeLevel.normal);
      expect(outside.level, DealBadgeLevel.goodDeal);
    });
  });

  // ── AC 1.12 — parse số lẻ làm tròn nguyên VND + wire threshold (AC 1.11) ───
  group('PriceHistorySummary.fromJson', () {
    test('giá số lẻ làm tròn về số nguyên VND (AC 1.12)', () {
      final s = PriceHistorySummary.fromJson({
        'item_name': 'nước mắm',
        'latest_price': 43210.87,
        'previous_price': 40000.4,
        'min_price': 39999.5,
        'max_price': 45000.0,
        'avg_price': 12345.67,
        'trend': 'stable',
        'points': [],
      });
      expect(s.latestPrice, 43211); // .87 → làm tròn lên
      expect(s.previousPrice, 40000); // .4 → làm tròn xuống
      expect(s.minPrice, 40000); // .5 → làm tròn lên
      expect(s.maxPrice, 45000);
      expect(s.avgPrice, 12346); // 12.345,67 → 12.346
    });

    test('đọc deal_threshold_percent từ BE; thiếu → null (client fallback)', () {
      final withField = PriceHistorySummary.fromJson({
        'item_name': 'a',
        'deal_threshold_percent': 7.5,
        'points': [],
      });
      final withoutField = PriceHistorySummary.fromJson({
        'item_name': 'a',
        'points': [],
      });
      expect(withField.dealThresholdPercent, 7.5);
      expect(withoutField.dealThresholdPercent, isNull);
    });
  });

  // ── dealBadgeProvider — wire parse API → provider ──────────────────────────
  group('dealBadgeProvider', () {
    const query = PriceHistoryQuery(name: 'cà phê');

    Future<DealBadgeResult?> readBadge(PriceHistorySummary? summary) async {
      final container = ProviderContainer(overrides: [
        priceHistorySummaryProvider(query)
            .overrideWith((ref) async => summary),
      ]);
      addTearDown(container.dispose);

      await container.read(priceHistorySummaryProvider(query).future);
      return container.read(dealBadgeProvider(query));
    }

    test('summary null (không có history) → badge null → UI ẩn card (AC 1.6)',
        () async {
      expect(await readBadge(null), isNull);
    });

    test('threshold từ BE đúc vào kết quả — config 10% mở rộng vùng bình thường (AC 1.11)',
        () async {
      final badge = await readBadge(PriceHistorySummary.fromJson({
        'item_name': 'cà phê',
        'latest_price': 108000,
        'avg_price': 100000,
        'min_price': 90000,
        'deal_threshold_percent': 10,
        'total_records': 3,
        'points': [
          {'id': 'p1', 'price': 90000, 'purchased_at': '2026-08-01T00:00:00.000Z'},
          {'id': 'p2', 'price': 100000, 'purchased_at': '2026-08-15T00:00:00.000Z'},
          {'id': 'p3', 'price': 108000, 'purchased_at': '2026-09-01T00:00:00.000Z'},
        ],
      }));
      expect(badge, isNotNull);
      expect(badge!.level, DealBadgeLevel.normal); // 8% < 10% → bình thường
      expect(badge.thresholdPercent, 10.0);
    });

    test('thiếu deal_threshold_percent → fallback 5%, 2 records → đủ dữ liệu',
        () async {
      final badge = await readBadge(PriceHistorySummary.fromJson({
        'item_name': 'cà phê',
        'latest_price': 38000,
        'previous_price': 40000,
        'avg_price': 41000,
        'min_price': 38000,
        'total_records': 2,
        'points': [
          {'id': 'p1', 'price': 40000, 'purchased_at': '2026-08-01T00:00:00.000Z'},
          {'id': 'p2', 'price': 38000, 'purchased_at': '2026-09-01T00:00:00.000Z'},
        ],
      }));
      expect(badge, isNotNull);
      expect(badge!.hasEnoughData, isTrue);
      expect(badge.thresholdPercent, 5.0);
      expect(badge.level, DealBadgeLevel.goodDeal); // −7.3% < −5%
    });
  });
}
