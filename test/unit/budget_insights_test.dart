import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/budget_insights.dart';

/// F-#3 Smart Budget — unit test pure math, đủ ranh giới AC 3.1–3.10.
///
/// Kỳ mẫu: tháng 9/2026 (30 ngày), giờ local — KHÔNG phụ thuộc đồng hồ thật
/// (`now` được inject).
void main() {
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 9, 30);

  BudgetInsights insights({
    required int spent,
    required int budget,
    required DateTime now,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) =>
      computeBudgetInsights(
        spent: spent,
        budget: budget,
        periodStart: periodStart ?? start,
        periodEnd: periodEnd ?? end,
        now: now,
      );

  group('Công thức cơ bản (AC 3.1, 3.10)', () {
    final r = insights(
      spent: 300000,
      budget: 600000,
      now: DateTime(2026, 9, 10, 15, 30), // giữa tháng, giữa ngày
    );

    test('ngày 10/30 → daysElapsed = 10, daysRemaining = 20', () {
      expect(r.totalDays, 30);
      expect(r.daysElapsed, 10);
      expect(r.daysRemaining, 20);
    });

    test('burn rate = spent / ngày đã qua = 30.000đ/ngày', () {
      expect(r.burnRate, 30000.0);
      expect(r.burnRateLabel, '30000.0'); // 1 chữ số thập phân (AC 3.10)
    });

    test('safe daily = (budget − spent) / ngày còn lại = 15.000đ', () {
      expect(r.safeDaily, 15000);
    });

    test('forecast = burn rate × tổng ngày kỳ = 900.000đ (làm tròn nguyên)', () {
      expect(r.forecast, 900000.0);
      expect(r.forecastVnd, 900000);
    });

    test('giờ trong ngày KHÔNG làm tròn xuống ngày (local, so sánh theo ngày)', () {
      final morning = insights(
        spent: 300000,
        budget: 600000,
        now: DateTime(2026, 9, 10, 0, 5),
      );
      expect(morning.daysElapsed, 10);
    });

    test('burn rate số lẻ → label 1 chữ số thập phân (AC 3.10)', () {
      final r = insights(
        spent: 100000,
        budget: 600000,
        now: DateTime(2026, 9, 3), // 100.000 / 3 = 33.333,33
      );
      expect(r.burnRateLabel, '33333.3');
      expect(r.forecastVnd, 1000000); // forecast làm tròn nguyên VND
    });
  });

  group('Safe daily (AC 3.2, 3.3)', () {
    test('còn tiền + còn ≥ 1 ngày → "Có thể chi ~X đ/ngày", X nguyên VND', () {
      final r = insights(
        spent: 150000,
        budget: 1000000,
        now: DateTime(2026, 9, 10), // ngày 10/30 → còn 20 ngày, còn 850.000
      );
      expect(r.safeDaily, isNotNull);
      // 850.000 / 20 = 42.500
      expect(r.safeDaily, 42500);
    });

    test('spent > budget → KHÔNG bao giờ có safe daily âm (AC 3.3)', () {
      final r = insights(
        spent: 700000,
        budget: 600000,
        now: DateTime(2026, 9, 10),
      );
      expect(r.safeDaily, isNull);
      expect(r.isOverBudget, isTrue);
      expect(r.overAmount, 100000);
    });

    test('spent == budget → safe daily null (không còn tiền để chi)', () {
      final r = insights(
        spent: 600000,
        budget: 600000,
        now: DateTime(2026, 9, 10),
      );
      expect(r.safeDaily, isNull);
      expect(r.isOverBudget, isFalse); // == không tính là VƯỢT
    });
  });

  group('Cảnh báo forecast (AC 3.4, 3.5)', () {
    test('forecast > budget → cờ vàng + projected overage nguyên VND (AC 3.4)', () {
      final r = insights(
        spent: 300000,
        budget: 600000,
        now: DateTime(2026, 9, 10), // forecast 900.000 > 600.000 → vượt 300.000
      );
      expect(r.isForecastOver, isTrue);
      expect(r.projectedOverage, 300000);
    });

    test('forecast ≤ budget → KHÔNG cảnh báo vàng, có dòng tích cực (AC 3.5)', () {
      final r = insights(
        spent: 100000,
        budget: 600000,
        now: DateTime(2026, 9, 10), // forecast 300.000 ≤ 600.000
      );
      expect(r.isForecastOver, isFalse);
      expect(r.projectedOverage, 0);
      expect(r.showPositive, isTrue);
    });

    test('đã vượt budget (đỏ) → không hiện thêm vàng (đỏ ưu tiên)', () {
      final r = insights(
        spent: 700000,
        budget: 600000,
        now: DateTime(2026, 9, 10),
      );
      expect(r.isOverBudget, isTrue);
      // forecast = 700.000/10 × 30 = 2.100.000 > budget nhưng đỏ đã đủ.
      expect(r.isForecastOver, isTrue);
    });
  });

  group('Đầu kỳ / ngày cuối kỳ (AC 3.6, 3.7)', () {
    test('ngày đầu kỳ chưa chi gì: burn 0, forecast 0, KHÔNG warning nào (AC 3.6)', () {
      final r = insights(
        spent: 0,
        budget: 600000,
        now: DateTime(2026, 9, 1, 8, 0),
      );
      expect(r.daysElapsed, 1);
      expect(r.burnRate, 0.0);
      expect(r.forecast, 0.0);
      expect(r.forecastVnd, 0);
      expect(r.isForecastOver, isFalse);
      expect(r.isOverBudget, isFalse);
      expect(r.showPositive, isFalse); // giữ yên tắng đầu tháng
      expect(r.safeDaily, isNotNull); // vẫn gợi ý mức chi an toàn
    });

    test('ngày CUỐI kỳ: daysRemaining 0 → ẩn insights, KHÔNG chia 0 (AC 3.7)', () {
      final r = insights(
        spent: 500000,
        budget: 600000,
        now: DateTime(2026, 9, 30, 23, 59),
      );
      expect(r.daysRemaining, 0);
      expect(r.showInsights, isFalse);
      expect(r.safeDaily, isNull); // ẩn safe daily
      expect(r.isForecastOver, isFalse); // ẩn forecast warning
      expect(r.showPositive, isFalse);
    });

    test('ngày cuối kỳ đã vượt → vẫn giữ trạng thái vượt để hiển thị', () {
      final r = insights(
        spent: 700000,
        budget: 600000,
        now: DateTime(2026, 9, 30),
      );
      expect(r.showInsights, isFalse);
      expect(r.isOverBudget, isTrue);
      expect(r.overAmount, 100000);
    });

    test('qua kỳ (now > end) → clamp về ngày cuối, không âm', () {
      final r = insights(
        spent: 500000,
        budget: 600000,
        now: DateTime(2026, 10, 5),
      );
      expect(r.daysElapsed, 30);
      expect(r.daysRemaining, 0);
      expect(r.showInsights, isFalse);
    });

    test('trước kỳ (now < start) → 0 ngày đã qua, burn 0, forecast 0', () {
      final r = insights(
        spent: 0,
        budget: 600000,
        now: DateTime(2026, 8, 20),
      );
      expect(r.daysElapsed, 0);
      expect(r.burnRate, 0.0);
      expect(r.forecast, 0.0);
      expect(r.isForecastOver, isFalse);
    });
  });

  group('Budget sửa giữa kỳ (AC 3.8) + dữ liệu bẩn', () {
    test('cùng spent/ngày, budget ĐỔI → mọi chỉ số dùng budget MỚI', () {
      final oldBudget = insights(
        spent: 300000,
        budget: 600000,
        now: DateTime(2026, 9, 10),
      );
      final newBudget = insights(
        spent: 300000, // spent giữ nguyên (không retroactive)
        budget: 900000, // user tăng budget giữa kỳ
        now: DateTime(2026, 9, 10),
      );
      expect(newBudget.safeDaily, 30000); // (900k − 300k)/20
      expect(newBudget.isForecastOver, isFalse); // 900k forecast ≤ 900k budget
      expect(newBudget.forecastVnd, oldBudget.forecastVnd); // forecast không đổi
    });

    test('kỳ rác (start > end) → không crash, totalDays tối thiểu 1', () {
      final r = computeBudgetInsights(
        spent: 100000,
        budget: 600000,
        periodStart: DateTime(2026, 9, 10),
        periodEnd: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 10),
      );
      expect(r.totalDays, 1);
      expect(r.daysElapsed, 1);
    });

    test('budget = 0 → safe daily null, không warning vàng khi chưa chi', () {
      final r = insights(
        spent: 0,
        budget: 0,
        now: DateTime(2026, 9, 10),
      );
      expect(r.safeDaily, isNull);
      expect(r.isForecastOver, isFalse);
    });
  });

  group('tryParseBudgetDate', () {
    test('parse YYYY-MM-DD hợp lệ, lỗi/rỗng → null (UI ẩn insights)', () {
      expect(tryParseBudgetDate('2026-09-01'), DateTime(2026, 9, 1));
      expect(tryParseBudgetDate(''), isNull);
      expect(tryParseBudgetDate('garbage'), isNull);
      expect(tryParseBudgetDate(null), isNull);
    });
  });
}
