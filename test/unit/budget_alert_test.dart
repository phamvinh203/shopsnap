import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/core/utils/budget_alert.dart';
import 'package:shopsnap/services/budget_alert_service.dart';

/// F-#12 — pure logic budget alert: ranh giới ngưỡng 80%/100% (AC 12.1/12.2),
/// dedup mỗi ngưỡng tối đa 1 lần mỗi kỳ (AC 12.3), không ném lỗi.
void main() {
  group('evaluateBudgetThresholdCrossings (ranh giới ngưỡng)', () {
    test('budget 100.000 — chưa tới 80% → không ngưỡng nào', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 0, spentAfter: 79999, budget: 100000),
        isEmpty,
      );
    });

    test('AC 12.1 — chạm ĐÚNG 80% (80.000) → vừa vượt ngưỡng warning', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 79999, spentAfter: 80000, budget: 100000),
        [BudgetAlertThreshold.warning],
      );
    });

    test('đã ở trên 80% từ trước, thêm item không qua 100% → rỗng', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 85000, spentAfter: 90000, budget: 100000),
        isEmpty,
      );
    });

    test('AC 12.2 — chạm ĐÚNG 100% → vừa vượt ngưỡng exceeded', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 99999, spentAfter: 100000, budget: 100000),
        [BudgetAlertThreshold.exceeded],
      );
    });

    test('AC 12.14 — nhảy cóc từ dưới 80% lên trên 100% → CHỈ ngưỡng 100%', () {
      // 1 lần lưu item = 1 sự kiện = 1 notification (không bắn thêm 80% "trễ").
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 50000, spentAfter: 150000, budget: 100000),
        [BudgetAlertThreshold.exceeded],
      );
      // Đúng biên 100% cũng vậy.
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 10000, spentAfter: 100000, budget: 100000),
        [BudgetAlertThreshold.exceeded],
      );
    });

    test('vượt lại 100% từ mốc đã trên 80% → chỉ exceeded (AC 12.14)', () {
      // Đã từng vượt (ngoài tầm nhìn của hàm — dedup lo phần này); bước này
      // chỉ vượt 100%, không "vượt lại" 80% vì spentBefore > mark 80%.
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 90000, spentAfter: 120000, budget: 100000),
        [BudgetAlertThreshold.exceeded],
      );
      // Ngay cả khi bước vượt này băng qua CẢ 80% lẫn 100% → vẫn chỉ 100%.
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 70000, spentAfter: 120000, budget: 100000),
        [BudgetAlertThreshold.exceeded],
      );
    });

    test('spent không đổi hoặc giảm → không bao giờ có ngưỡng', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 90000, spentAfter: 90000, budget: 100000),
        isEmpty,
      );
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 90000, spentAfter: 50000, budget: 100000),
        isEmpty,
      );
    });

    test('budget <= 0 → rỗng, không chia 0 không crash', () {
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 0, spentAfter: 1000, budget: 0),
        isEmpty,
      );
      expect(
        evaluateBudgetThresholdCrossings(
            spentBefore: 0, spentAfter: 1000, budget: -5),
        isEmpty,
      );
    });

    test('ngưỡng lấy từ AppConstants (80%/100% — khớp hành vi BE)', () {
      expect(BudgetAlertThreshold.warning.ratio, AppConstants.budgetWarnRatio);
      expect(BudgetAlertThreshold.exceeded.ratio, AppConstants.budgetDangerRatio);
    });
  });

  group('budgetAlertDedupKey (AC 12.3 — key theo kỳ)', () {
    test('cùng budget + kỳ + ngưỡng → cùng key', () {
      final a = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        threshold: BudgetAlertThreshold.warning,
      );
      final b = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        threshold: BudgetAlertThreshold.warning,
      );
      expect(a, b);
    });

    test('kỳ mới (start/end khác) → key khác → được alert lại đúng 1 lần', () {
      final september = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        threshold: BudgetAlertThreshold.warning,
      );
      final october = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-10-01',
        periodEnd: '2026-10-31',
        threshold: BudgetAlertThreshold.warning,
      );
      expect(september, isNot(october));
    });

    test('ngưỡng khác → key khác (80% và 100% dedup độc lập)', () {
      final warn = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        threshold: BudgetAlertThreshold.warning,
      );
      final exceeded = budgetAlertDedupKey(
        budgetId: 'b1',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        threshold: BudgetAlertThreshold.exceeded,
      );
      expect(warn, isNot(exceeded));
    });
  });

  group('BudgetAlertService (dedup + an toàn lỗi)', () {
    late Set<String> firedKeys;
    late List<BudgetAlertThreshold> notified;
    late int persistCalls;

    BudgetAlertService build({
      Object? throwOnLoad,
      Object? throwOnPersist,
      Object? throwOnNotify,
    }) {
      return BudgetAlertService(
        loadFiredKeys: () async {
          if (throwOnLoad != null) throw throwOnLoad;
          return firedKeys;
        },
        persistFiredKey: (key) async {
          if (throwOnPersist != null) throw throwOnPersist;
          persistCalls++;
          firedKeys.add(key);
        },
        notify: (threshold) async {
          if (throwOnNotify != null) throw throwOnNotify;
          notified.add(threshold);
        },
      );
    }

    Future<int> run(BudgetAlertService svc,
            {int before = 50000, int after = 150000, int budget = 100000}) =>
        svc.checkAfterSpendChange(
          spentBefore: before,
          spentAfter: after,
          budgetAmount: budget,
          budgetId: 'b1',
          periodStart: '2026-09-01',
          periodEnd: '2026-09-30',
        );

    setUp(() {
      firedKeys = {};
      notified = [];
      persistCalls = 0;
    });

    test('AC 12.14 — nhảy cóc vượt 2 ngưỡng trong 1 lần lưu → bắn ĐÚNG 1 alert (100%)',
        () async {
      final fired = await run(build());

      expect(fired, 1);
      expect(notified, [BudgetAlertThreshold.exceeded]);
      expect(firedKeys.length, 1);
      expect(persistCalls, 1);
    });

    test('AC 12.3 — cùng kỳ bắn rồi → thêm chi nữa KHÔNG bắn lại', () async {
      final svc = build();
      await run(svc, before: 50000, after: 150000);
      notified.clear();

      final firedAgain = await run(svc, before: 150000, after: 180000);
      expect(firedAgain, 0);
      expect(notified, isEmpty);
    });

    test('AC 12.3 — 80% đã alert trong kỳ, chạm 100% → chỉ alert ngưỡng 100%', () async {
      final svc = build();
      await run(svc, before: 79999, after: 80000); // chỉ 80%
      notified.clear();

      final fired = await run(svc, before: 80000, after: 100000);
      expect(fired, 1);
      expect(notified, [BudgetAlertThreshold.exceeded]);
    });

    test('AC 12.2 — kỳ mới (key khác) → ngưỡng được alert lại', () async {
      final svc = build();
      await run(svc, before: 50000, after: 150000);
      notified.clear();

      final firedNewPeriod = await svc.checkAfterSpendChange(
        spentBefore: 0,
        spentAfter: 150000,
        budgetAmount: 100000,
        budgetId: 'b1',
        periodStart: '2026-10-01', // kỳ mới
        periodEnd: '2026-10-31',
      );
      expect(firedNewPeriod, 1);
    });

    test('budget không đổi (chi cùng mốc cũ) → 0 alert', () async {
      final fired = await run(build(), before: 50000, after: 50000);
      expect(fired, 0);
      expect(firedKeys, isEmpty);
    });

    test('notify ném lỗi → nuốt, vẫn persist, không vỡ caller (không crash AC 12.13)', () async {
      final fired = await run(build(throwOnNotify: StateError('plugin missing')));

      expect(fired, 1); // vẫn tính là đã xử lý — key đã persist
      expect(persistCalls, 1);
    });

    test('persist ném lỗi → không notify ngưỡng đó, không ném lên caller', () async {
      final fired = await run(build(throwOnPersist: StateError('disk full')));

      expect(fired, 0);
      expect(notified, isEmpty);
    });

    test('loadFiredKeys ném lỗi → 0 alert, không ném lên caller', () async {
      final fired =
          await run(build(throwOnLoad: StateError('prefs broken')));

      expect(fired, 0);
      expect(notified, isEmpty);
    });
  });
}
