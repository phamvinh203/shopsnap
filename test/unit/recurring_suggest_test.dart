import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/recurring_suggest.dart';

/// AC 4.8/4.9 — Pure function phát hiện "có vẻ là khoản định kỳ".
/// Ranh giới đều được test qua tham số `now` (không phụ thuộc đồng hồ thật).
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  RecurringScanEntry e(String name, int price, DateTime at) =>
      RecurringScanEntry(name: name, price: price, purchasedAt: at);

  group('AC 4.8 — điều kiện nhận diện (ĐỒNG THỜI)', () {
    test('Ví dụ spec: Netflix 200.000đ 01/01, 31/01, 02/03 (gaps 30 + 30) → gợi ý',
        () {
      final now = d(2026, 4, 1);
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 1, 1)),
          e('Netflix', 200000, d(2026, 1, 31)),
          e('Netflix', 200000, d(2026, 3, 2)),
        ],
        now: now,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Netflix');
      expect(result.single.amount, 200000);
      expect(result.single.occurrences, 3);
      expect(result.single.matchKey, 'netflix');
      expect(result.single.lastPurchasedAt, d(2026, 3, 2));
    });

    test('CHỈ 2 lần mua → KHÔNG gợi ý (≥ 3 lần)', () {
      final now = d(2026, 4, 1);
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 2, 1)),
          e('Netflix', 200000, d(2026, 3, 3)),
        ],
        now: now,
      );
      expect(result, isEmpty);
    });

    test('median gap ngoài [25, 35] → KHÔNG gợi ý', () {
      final now = d(2026, 4, 1);
      // Gap đều ~7 ngày (mua tuần 1 lần) — median 7.
      final weekly = detectRecurringSuggestions(
        entries: [
          e('Cà phê', 25000, d(2026, 3, 2)),
          e('Cà phê', 25000, d(2026, 3, 9)),
          e('Cà phê', 25000, d(2026, 3, 16)),
        ],
        now: now,
      );
      expect(weekly, isEmpty, reason: 'gap tuần lễ không phải monthly');

      // Gap ~90 ngày — quarterly, median 90.
      final quarterly = detectRecurringSuggestions(
        entries: [
          e('Bảo hiểm', 1200000, d(2025, 12, 5)),
          e('Bảo hiểm', 1200000, d(2026, 3, 5)),
          e('Bảo hiểm', 1200000, d(2026, 6, 3)),
        ],
        now: d(2026, 6, 10),
      );
      expect(quarterly, isEmpty);
    });

    test('Một gap > 45 ngày → KHÔNG gợi ý (chống nhiễu) dù median nằm trong dải',
        () {
      final now = d(2026, 6, 10);
      // Gaps: 30, 50 → median 40 (ngoài dải) lẫn gap>45. Sửa để median ok:
      // gaps 60, 28, 30 → median 30 nhưng có gap 60 > 45 → loại.
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 1, 5)),
          e('Netflix', 200000, d(2026, 3, 6)), // +60 ngày
          e('Netflix', 200000, d(2026, 4, 3)), // +28
          e('Netflix', 200000, d(2026, 5, 3)), // +30
        ],
        now: now,
      );
      expect(result, isEmpty);
    });

    test('Gap đúng 45 ngày + median trong dải → VẪN gợi ý (45 inclusive)', () {
      // 3 lần, gaps [45, 25] → median 35.0 (chạm biên trên, inclusive),
      // không gap nào > 45 → vẫn gợi ý.
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 4, 2)),
          e('Netflix', 200000, d(2026, 5, 17)), // +45
          e('Netflix', 200000, d(2026, 6, 11)), // +25
        ],
        now: d(2026, 6, 30),
      );
      expect(result, hasLength(1));
      expect(result.single.occurrences, 3);
    });
  });

  group('AC 4.9 — edge suggest', () {
    test('Một lần giá khác 1 đồng (199.999 thay 200.000) → KHÔNG gợi ý (±0%)',
        () {
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 1, 1)),
          e('Netflix', 200000, d(2026, 1, 31)),
          e('Netflix', 199999, d(2026, 3, 2)), // lệch đúng 1 đồng
        ],
        now: d(2026, 4, 1),
      );
      expect(result, isEmpty);
    });

    test('Cùng tên khác giá → 2 nhóm riêng, nhóm nào không đủ ≥3 thì rơi hết',
        () {
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 1, 1)),
          e('Netflix', 200000, d(2026, 1, 31)),
          e('Netflix', 250000, d(2026, 3, 2)),
          e('Netflix', 250000, d(2026, 4, 1)),
        ],
        now: d(2026, 5, 1),
      );
      expect(result, isEmpty);
    });

    test('Entry đang bật cùng match_key → không gợi ý lần nữa', () {
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2026, 1, 1)),
          e('Netflix', 200000, d(2026, 1, 31)),
          e('Netflix', 200000, d(2026, 3, 2)),
        ],
        activeMatchKeys: {'netflix'},
        now: d(2026, 4, 1),
      );
      expect(result, isEmpty);
    });

    test('amount ≤ 0 hoặc tên rỗng → loại khỏi phép quét', () {
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 0, d(2026, 1, 1)),
          e('Netflix', -200000, d(2026, 1, 31)),
          e('   ', 200000, d(2026, 1, 31)),
          e('Netflix', 200000, d(2026, 3, 2)),
        ],
        now: d(2026, 4, 1),
      );
      expect(result, isEmpty);
    });

    test('Ngoài 90 ngày → không tính; ranh giới đúng ngày thứ 90 thì tính',
        () {
      final now = d(2026, 4, 1);
      // Ngày 91 (02/01 là 89 ngày trước 01/04? tính: 01/04 - 90 ngày = 01/01).
      // cutoff = 01/01/2026 (đầu ngày). Entry 01/01 → TÍNH; 31/12/2025 → loại.
      final result = detectRecurringSuggestions(
        entries: [
          e('Netflix', 200000, d(2025, 12, 31)), // ngoài cửa sổ
          e('Netflix', 200000, d(2026, 1, 1)), // đúng mốc cutoff → tính
          e('Netflix', 200000, d(2026, 1, 31)),
          e('Netflix', 200000, d(2026, 3, 2)),
        ],
        now: now,
      );
      expect(result, hasLength(1));
      expect(result.single.occurrences, 3); // bản 31/12 không được đếm
    });

    test('Tên normalize gộp nhóm ("Netflix " = "netflix"), tên hiển thị = lần GẦN NHẤT',
        () {
      final result = detectRecurringSuggestions(
        entries: [
          e('netflix  ', 200000, d(2026, 1, 1)),
          e('Netflix', 200000, d(2026, 1, 31)),
          e(' NETFLIX', 200000, d(2026, 3, 2)),
        ],
        now: d(2026, 4, 1),
      );
      expect(result, hasLength(1));
      expect(result.single.name, 'NETFLIX'); // nguyên văn lần gần nhất
      expect(result.single.matchKey, 'netflix');
    });
  });

  test('Nhiều gợi ý → sắp theo occurrences giảm dần (deterministic)', () {
    final result = detectRecurringSuggestions(
      entries: [
        // 3 lần — 30 ngày/lần
        e('Netflix', 200000, d(2026, 1, 1)),
        e('Netflix', 200000, d(2026, 1, 31)),
        e('Netflix', 200000, d(2026, 3, 2)),
        // 4 lần — 28 ngày/lần
        e('Tiền mạng', 220000, d(2026, 1, 1)),
        e('Tiền mạng', 220000, d(2026, 1, 29)),
        e('Tiền mạng', 220000, d(2026, 2, 26)),
        e('Tiền mạng', 220000, d(2026, 3, 26)),
      ],
      // Cutoff (01/01) không loại lần mua nào của cả 2 nhóm.
      now: d(2026, 4, 1),
    );

    expect(result.map((s) => s.name).toList(), ['Tiền mạng', 'Netflix']);
  });

  test('Danh sách rỗng → rỗng, không crash', () {
    expect(
      detectRecurringSuggestions(entries: const [], now: d(2026, 4, 1)),
      isEmpty,
    );
  });
}
