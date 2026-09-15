import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/merchant_insights.dart';

/// M-3 — Pure function phân tích nơi mua (AC 7.8, 7.11, 7.12, 7.13).
/// Không chạm DB/Flutter — input là danh sách lượt mua `{name, storeName, price}`.
MerchantPurchase p(String name, String? store, int price) =>
    MerchantPurchase(name: name, storeName: store, price: price);

void main() {
  group('AC 7.8 — topStoresBySpend: top 5 theo tổng chi giảm dần', () {
    test('Xếp GIẢM DẦN theo tổng chi + đúng số lần mua từng nơi', () {
      final top = topStoresBySpend([
        p('Sữa', 'CoopMart', 30000),
        p('Trứng', 'CoopMart', 20000),
        p('Bánh', 'Bách Hóa Xanh', 90000),
        p('Gạo', 'CoopMart', 10000),
        p('Cà phê', 'Highlands', 25000),
      ]);

      expect(top.length, 3);
      expect(top[0].storeName, 'Bách Hóa Xanh'); // 90.000
      expect(top[0].totalSpent, 90000);
      expect(top[0].purchaseCount, 1);
      expect(top[1].storeName, 'CoopMart'); // 60.000
      expect(top[1].totalSpent, 60000);
      expect(top[1].purchaseCount, 3); // nhiều lần mua vẫn gộp đúng nơi
      expect(top[2].storeName, 'Highlands');
    });

    test('Chỉ lấy đúng 5 nơi (không gộp "còn lại")', () {
      final top = topStoresBySpend([
        p('a', 'S1', 1000), p('b', 'S2', 2000), p('c', 'S3', 3000),
        p('d', 'S4', 4000), p('e', 'S5', 5000), p('f', 'S6', 6000),
      ], limit: 5);

      expect(top.length, 5);
      expect(top.map((t) => t.storeName), ['S6', 'S5', 'S4', 'S3', 'S2']);
    });

    test('Lượt mua KHÔNG có nơi mua (null/rỗng/chỉ khoảng trắng) bị bỏ qua',
        () {
      final top = topStoresBySpend([
        p('Sữa', null, 30000),
        p('Trứng', '', 20000),
        p('Bánh', '   ', 10000),
        p('Gạo', 'CoopMart', 5000),
      ]);

      expect(top.length, 1);
      expect(top.single.storeName, 'CoopMart');
    });

    test('AC 7.13 — "CoopMart" và "coop mart" là 2 nơi RIÊNG BIỆT (nguyên văn)',
        () {
      final top = topStoresBySpend([
        p('Sữa', 'CoopMart', 10000),
        p('Bánh', 'coop mart', 20000),
        p('Trứng', 'CoopMart', 5000),
      ]);

      expect(top.length, 2);
      expect(top[0].storeName, 'coop mart'); // 20.000 xếp trước
      expect(top[1].storeName, 'CoopMart');
      expect(top[1].purchaseCount, 2); // đếm riêng, không merge
    });

    test('Danh sách rỗng / toàn lượt không nơi mua → rỗng (AC 7.10)', () {
      expect(topStoresBySpend(const []), isEmpty);
      expect(topStoresBySpend([p('Sữa', null, 1000)]), isEmpty);
    });
  });

  group('AC 7.11 — merchantPriceInsights: đủ dữ liệu + công thức Y', () {
    test('Ví dụ spec: avg 30.000 vs 24.000 (mỗi nơi 2 lần) → Y = 11', () {
      final insights = merchantPriceInsights([
        p('Sữa Vinamilk', 'CoopMart', 31000),
        p('Sữa Vinamilk', 'CoopMart', 29000), // avg 30.000
        p('Sữa Vinamilk', 'chợ', 25000),
        p('Sữa Vinamilk', 'chợ', 23000), // avg 24.000
      ]);

      expect(insights.length, 1);
      final i = insights.single;
      expect(i.cheapestStore, 'chợ');
      expect(i.percentSaved, 11); // round((27000−24000)/27000×100)
      expect(i.cheapestAvgPrice, 24000);
      expect(i.baselineAvgPrice, 27000);
    });

    test('Cùng món được nhóm qua normalizeMatchKey (sai lệch nhẹ về 1 nhóm)',
        () {
      final insights = merchantPriceInsights([
        p('Sữa   Vinamilk', 'A', 20000),
        p('sữa vinamilk', 'A', 22000),
        p('Sữa Vinamilk ', 'B', 15000),
        p('SỮA VINAMILK', 'B', 17000),
      ]);

      expect(insights.length, 1);
      expect(insights.single.itemName, 'Sữa   Vinamilk'); // biến thể đầu tiên
      expect(insights.single.cheapestStore, 'B');
    });

    test('Tối đa 3 insight, sắp theo Y GIẢM DẦN', () {
      MerchantPurchase buy(String name, String store, int price) =>
          p(name, store, price);

      // Món 1: baseline 100 vs 50 → Y = 50. Món 2: baseline 100 vs 80 → Y = 20.
      // Món 3: baseline 100 vs 90 → Y = 10. Món 4: baseline 100 vs 95 → Y = 5.
      final insights = merchantPriceInsights([
        for (final (name, low) in [
          ('Món A', 50), ('Món B', 80), ('Món C', 90), ('Món D', 95),
        ]) ...[
          buy(name, 'Đắt', 100),
          buy(name, 'Đắt', 100),
          buy(name, 'Rẻ', low),
          buy(name, 'Rẻ', low),
        ],
      ]);

      expect(insights.length, 3); // max 3 dòng
      expect(insights.map((i) => i.itemName).toList(),
          ['Món A', 'Món B', 'Món C']); // Y giảm dần 50 → 20 → 10
    });
  });

  group('AC 7.12 — edge: thiếu dữ liệu / Y ≤ 0 / giá 0 / baseline 0', () {
    test('Chỉ 1 nơi mua (dù nhiều lần) → không insight', () {
      expect(
        merchantPriceInsights([
          p('Sữa', 'CoopMart', 20000),
          p('Sữa', 'CoopMart', 21000),
          p('Sữa', 'CoopMart', 22000),
        ]),
        isEmpty,
      );
    });

    test('2 nơi nhưng một nơi chỉ mua 1 lần → không insight cho món đó', () {
      expect(
        merchantPriceInsights([
          p('Sữa', 'CoopMart', 20000),
          p('Sữa', 'CoopMart', 21000),
          p('Sữa', 'chợ', 15000), // chỉ 1 lần → nơi này bị loại
        ]),
        isEmpty,
      );
    });

    test('Nơi rẻ nhất ngang baseline (Y = 0) → không insight (không chia 0 ý nghĩa)',
        () {
      expect(
        merchantPriceInsights([
          p('Sữa', 'A', 20000),
          p('Sữa', 'A', 20000),
          p('Sữa', 'B', 20000),
          p('Sữa', 'B', 20000),
        ]),
        isEmpty,
      );
    });

    test('Giá 0 KHÔNG tính vào avg và không làm baseline', () {
      final insights = merchantPriceInsights([
        p('Sữa', 'A', 0), // bị loại khỏi avg/baseline
        p('Sữa', 'A', 30000),
        p('Sữa', 'A', 30000), // A vẫn đủ 2 lần hợp lệ
        p('Sữa', 'B', 0), // bị loại
        p('Sữa', 'B', 24000),
        p('Sữa', 'B', 24000), // B vẫn đủ 2 lần hợp lệ
      ]);

      expect(insights.length, 1);
      // avg A = 30.000, avg B = 24.000, baseline = 27.000 → Y = 11 (không lệch bởi 0)
      expect(insights.single.percentSaved, 11);
      expect(insights.single.baselineAvgPrice, 27000);
    });

    test('Toàn bộ giá 0 → baseline 0 → không insight (không chia 0)', () {
      expect(
        merchantPriceInsights([
          p('Sữa', 'A', 0),
          p('Sữa', 'A', 0),
          p('Sữa', 'B', 0),
          p('Sữa', 'B', 0),
        ]),
        isEmpty,
      );
    });

    test('Món thiếu dữ liệu không chặn món khác — phần còn lại vẫn insight',
        () {
      final insights = merchantPriceInsights([
        // Món X: 1 nơi → không insight.
        p('Món X', 'A', 10000),
        p('Món X', 'A', 10000),
        // Món Y: đủ 2 nơi × 2 lần → có insight.
        p('Món Y', 'A', 40000),
        p('Món Y', 'A', 40000),
        p('Món Y', 'B', 20000),
        p('Món Y', 'B', 20000),
      ]);

      expect(insights.length, 1);
      expect(insights.single.itemName, 'Món Y');
      expect(insights.single.cheapestStore, 'B');
    });

    test('Lượt mua không có nơi mua bị loại khỏi phân tích insight', () {
      expect(
        merchantPriceInsights([
          p('Sữa', null, 10000),
          p('Sữa', '   ', 10000),
          p('Sữa', 'A', 20000),
        ]),
        isEmpty,
      );
    });
  });

  group('buildMerchantSummary — gộp top-5 + insight cho card Summary', () {
    test('Cả 2 phần tính từ cùng input; isEmpty theo topStores', () {
      final data = buildMerchantSummary([
        p('Sữa', 'CoopMart', 30000),
        p('Sữa', 'CoopMart', 30000),
        p('Sữa', 'chợ', 24000),
        p('Sữa', 'chợ', 24000),
      ]);

      expect(data.isEmpty, isFalse);
      expect(data.topStores.map((t) => t.storeName).toList(),
          ['CoopMart', 'chợ']); // xếp giảm dần theo tổng chi (60k > 48k)
      expect(data.insights.single.percentSaved, 11);
    });

    test('Không có dữ liệu nơi mua → isEmpty true (AC 7.10)', () {
      expect(buildMerchantSummary(const []).isEmpty, isTrue);
      expect(buildMerchantSummary([p('Sữa', null, 1000)]).isEmpty, isTrue);
    });
  });
}
