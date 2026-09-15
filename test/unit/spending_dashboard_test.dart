import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/spending_dashboard.dart';
import 'package:shopsnap/models/summary_model.dart';

/// F-#2 Spending Intelligence Dashboard — unit test pure logic:
/// MoM (AC 2.1/2.2), breakdown sort (AC 2.3), heuristic fallback (AC 2.5,
/// 2.7, 2.8).
void main() {
  CategorySummary cat(String id, String name, int spent) => CategorySummary(
        categoryId: id,
        categoryName: name,
        categoryIcon: '🍔',
        categoryColor: '#FF6B6B',
        totalSpent: spent,
        itemCount: 1,
      );

  group('computeMomChange (AC 2.1, 2.2)', () {
    test('tăng so tháng trước → up + % dương', () {
      final m = computeMomChange(current: 110000, previous: 100000);
      expect(m.direction, MomDirection.up);
      expect(m.percent, closeTo(10.0, 0.001));
      expect(m.label, '+10% so với tháng trước');
    });

    test('giảm → down + % âm, label giữ dấu trừ', () {
      final m = computeMomChange(current: 80000, previous: 100000);
      expect(m.direction, MomDirection.down);
      expect(m.percent, closeTo(-20.0, 0.001));
      expect(m.label, '-20% so với tháng trước');
    });

    test('ngang bằng (0%) → flat, không hiện %', () {
      final m = computeMomChange(current: 100000, previous: 100000);
      expect(m.direction, MomDirection.flat);
      expect(m.label, 'Ngang bằng tháng trước');
    });

    test('AC 2.2: tháng trước = 0 → newStart, percent null (KHÔNG chia 0)', () {
      final m = computeMomChange(current: 50000, previous: 0);
      expect(m.isNewStart, isTrue);
      expect(m.direction, MomDirection.newStart);
      expect(m.percent, isNull);
      expect(m.label, 'Tháng mới bắt đầu');
    });

    test('tháng trước âm (dữ liệu bẩn) → vẫn newStart, không crash', () {
      final m = computeMomChange(current: 50000, previous: -3);
      expect(m.isNewStart, isTrue);
    });

    test('previous null (không có dữ liệu kỳ trước) → percent null', () {
      final m = computeMomChange(current: 50000, previous: null);
      expect(m.percent, isNull);
      expect(m.label, 'Ngang bằng tháng trước'); // trạng thái trung tính an toàn
    });

    test('server trend override → đồng ý tưởng với BE', () {
      final up = computeMomChange(
          current: 101000, previous: 100000, serverTrend: 'up');
      expect(up.direction, MomDirection.up);
      final down = computeMomChange(
          current: 99000, previous: 100000, serverTrend: 'down');
      expect(down.direction, MomDirection.down);
    });

    test('kỳ không phải tháng → đổi nhãn so sánh', () {
      final m = computeMomChange(
          current: 110000, previous: 100000, comparisonLabel: 'kỳ trước');
      expect(m.label, '+10% so với kỳ trước');
    });
  });

  group('sortCategoriesDesc + share (AC 2.3)', () {
    test('xếp GIẢM DẦN theo số tiền, không mutate list gốc', () {
      final original = [
        cat('c3', 'Giải trí', 20000),
        cat('c1', 'Ăn uống', 80000),
        cat('c2', 'Đi lại', 50000),
      ];
      final sorted = sortCategoriesDesc(original);

      expect(sorted.map((c) => c.categoryName).toList(),
          ['Ăn uống', 'Đi lại', 'Giải trí']);
      // List gốc nguyên vẹn.
      expect(original[0].categoryName, 'Giải trí');
    });

    test('list rỗng/1 phần tử → chạy ổn', () {
      expect(sortCategoriesDesc(const []), isEmpty);
      expect(sortCategoriesDesc([cat('c1', 'Ăn uống', 1)]).length, 1);
    });

    test('shareOfTotal + barRatio: tổng 0 → 0 (không chia 0), clamp 0..1', () {
      expect(shareOfTotal(part: 80000, total: 150000), closeTo(53.33, 0.01));
      expect(shareOfTotal(part: 10, total: 0), 0.0);
      expect(barRatio(part: 80000, total: 150000), closeTo(0.5333, 0.001));
      expect(barRatio(part: 200000, total: 150000), 1.0); // clamp
      expect(barRatio(part: 10, total: 0), 0.0);
    });
  });

  group('heuristicSpendingInsight (AC 2.5, 2.7, 2.8)', () {
    final catsDesc = [
      cat('c1', 'Ăn uống', 80000),
      cat('c2', 'Đi lại', 50000),
    ];

    test('đủ dữ liệu + tăng → theo mẫu spec (AC 2.5)', () {
      final text = heuristicSpendingInsight(
        categoriesSortedDesc: catsDesc,
        totalSpent: 150000,
        mom: computeMomChange(current: 110000, previous: 100000),
      );
      expect(
        text,
        'Ăn uống chiếm 53% chi tiêu, cao nhất tháng này, tổng chi tăng 10% so với tháng trước',
      );
    });

    test('AC 2.8: 1 category → KHÔNG có mệnh đề xếp hạng', () {
      final text = heuristicSpendingInsight(
        categoriesSortedDesc: [cat('c1', 'Ăn uống', 80000)],
        totalSpent: 80000,
        mom: computeMomChange(current: 80000, previous: 100000),
      );
      expect(text, isNot(contains('cao nhất')));
      expect(text, contains('Ăn uống chiếm 100% chi tiêu'));
    });

    test('AC 2.2: tháng trước 0 → tail "tháng này bắt đầu ghi chép"', () {
      final text = heuristicSpendingInsight(
        categoriesSortedDesc: catsDesc,
        totalSpent: 150000,
        mom: computeMomChange(current: 150000, previous: 0),
      );
      expect(text, contains('tháng này bắt đầu ghi chép'));
    });

    test('mom null (offline không có kỳ trước) → chỉ mô tả cơ cấu chi', () {
      final text = heuristicSpendingInsight(
        categoriesSortedDesc: catsDesc,
        totalSpent: 150000,
        mom: null,
      );
      expect(text, 'Ăn uống chiếm 53% chi tiêu, cao nhất tháng này');
    });

    test('AC 2.7: không có chi tiêu → câu mời nhập dữ liệu, không crash', () {
      final text = heuristicSpendingInsight(
        categoriesSortedDesc: const [],
        totalSpent: 0,
        mom: null,
      );
      expect(text, contains('Chưa đủ dữ liệu'));
    });
  });
}
