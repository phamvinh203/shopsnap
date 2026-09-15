import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/core/utils/budget_alert.dart';
import 'package:shopsnap/core/utils/price_watch.dart';
import 'package:shopsnap/database/daos/shopping_list_dao.dart';
import 'package:shopsnap/models/price_history_model.dart';
import 'package:shopsnap/services/budget_alert_service.dart';
import 'package:sqflite/sqflite.dart';

/// Phase 2 (draft IT-DEPT) — các AC bổ sung sau review 4 chiều:
/// - **AC 12.15**: reconcile 2 nguồn notification (local ↔ record BE) — skip
///   local khi record BE cùng budget/ngưỡng/kỳ đã tồn tại.
/// - **AC 12.5**: payload deep-link price alert mang item id (mở đúng món).
/// - **AC 6.18/6.19**: edge case giá (equality biên, giá cũ = 0).
/// - **AC 6.20**: xoá dòng watched dọn luôn watch state (local-only).
/// - **AC 6.9**: cửa sổ 90 ngày của price intelligence.
class _MockDatabase extends Mock implements Database {}

PriceHistoryPoint _p(int price, int daysAgo) => PriceHistoryPoint(
      id: 'p$price-$daysAgo',
      price: price,
      purchasedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );

void main() {
  // ── AC 12.15 — reconcile 2 nguồn notification ──────────────────────────────
  group('AC 12.15 — serverAlertedThresholds (record BE vs local)', () {
    final periodStart = DateTime(2026, 9, 1);
    final periodEnd = DateTime(2026, 9, 30);

    Set<BudgetAlertThreshold> call(List<ServerBudgetAlertRecord> records,
            {String budgetId = 'b1'}) =>
        serverAlertedThresholds(
          records: records,
          budgetId: budgetId,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );

    test('record budget_alert cùng budget + ngưỡng TRONG kỳ → skip ngưỡng đó', () {
      final hit = call([
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': 1.0},
          createdAt: DateTime(2026, 9, 15, 10),
        ),
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': 0.8},
          createdAt: DateTime(2026, 9, 15, 9),
        ),
      ]);

      expect(hit, {BudgetAlertThreshold.warning, BudgetAlertThreshold.exceeded});
    });

    test('khác budget / khác type / NGOÀI kỳ → không skip (local vẫn bắn)', () {
      final hit = call([
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'budget_khac', 'threshold_percentage': 1.0},
          createdAt: DateTime(2026, 9, 15),
        ),
        (
          type: 'price_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': 1.0},
          createdAt: DateTime(2026, 9, 15),
        ),
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': 1.0},
          createdAt: DateTime(2026, 8, 20), // kỳ trước
        ),
      ]);

      expect(hit, isEmpty);
    });

    test('biên ngày cuối kỳ vẫn tính; payload thiếu threshold_percentage → bỏ qua an toàn', () {
      final lastDay = call([
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': 1.0},
          createdAt: DateTime(2026, 9, 30, 23, 59), // hết ngày cuối kỳ
        ),
      ]);
      expect(lastDay, {BudgetAlertThreshold.exceeded});

      final malformed = call([
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1'}, // thiếu threshold_percentage
          createdAt: DateTime(2026, 9, 20),
        ),
        (
          type: 'budget_alert',
          payload: const {'budget_id': 'b1', 'threshold_percentage': '1.0'}, // sai kiểu
          createdAt: DateTime(2026, 9, 20),
        ),
      ]);
      expect(malformed, isEmpty);
    });

    test('danh sách rỗng / payload rỗng → không skip', () {
      expect(call(const []), isEmpty);
      expect(
        call([
          (
            type: 'budget_alert',
            payload: const {},
            createdAt: DateTime(2026, 9, 20),
          ),
        ]),
        isEmpty,
      );
    });
  });

  group('AC 12.15 — BudgetAlertService skip local khi record BE đã có', () {
    late Set<String> firedKeys;
    late List<BudgetAlertThreshold> notified;

    BudgetAlertService build(
        {Set<BudgetAlertThreshold> serverAlerted = const {}}) {
      firedKeys = {};
      notified = [];
      return BudgetAlertService(
        loadFiredKeys: () async => firedKeys,
        persistFiredKey: (key) async => firedKeys.add(key),
        notify: (threshold) async => notified.add(threshold),
        serverAlertedThresholds: serverAlerted,
      );
    }

    Future<int> run(BudgetAlertService svc,
            {int before = 50000, int after = 150000}) =>
        svc.checkAfterSpendChange(
          spentBefore: before,
          spentAfter: after,
          budgetAmount: 100000,
          budgetId: 'b1',
          periodStart: '2026-09-01',
          periodEnd: '2026-09-30',
        );

    test('ngưỡng đã có record BE → KHÔNG bắn local, nhưng VẪN persist dedup key', () async {
      final svc = build(serverAlerted: {BudgetAlertThreshold.exceeded});

      final fired = await run(svc);

      expect(fired, 0);
      expect(notified, isEmpty);
      expect(firedKeys.length, 1, reason: 'key đã persist để lần sau bỏ qua ngay');
    });

    test('không có record BE → bắn local như bình thường', () async {
      final svc = build();

      expect(await run(svc), 1);
      expect(notified, [BudgetAlertThreshold.exceeded]);
    });
  });

  // ── AC 12.5 — payload deep-link mang item id ──────────────────────────────
  group('AC 12.5 — payload price alert kèm item id', () {
    test('có item id → payload chứa item; parse ra đúng id', () {
      final payload = priceAlertPayloadFor('sl_abc');
      expect(parseNotificationRoute(payload), '/shopping-list');
      expect(parseNotificationItemId(payload), 'sl_abc');
    });

    test('không có item id → payload route-only (màn đích không scroll-to)', () {
      expect(priceAlertPayloadFor(null), priceAlertPayload);
      expect(priceAlertPayloadFor('   '), priceAlertPayload);
      expect(parseNotificationItemId(priceAlertPayload), isNull);
    });

    test('payload hỏng/rỗng → null, không crash', () {
      expect(parseNotificationItemId(null), isNull);
      expect(parseNotificationItemId('not json'), isNull);
      expect(parseNotificationItemId('{"item":""}'), isNull);
    });

    test('budget alert payload KHÔNG chứa item (chỉ price alert mới có)', () {
      expect(parseNotificationItemId(budgetAlertPayload), isNull);
    });
  });

  // ── AC 6.18/6.19 — edge case giá khi quyết định alert ─────────────────────
  group('AC 6.18/6.19 — edge case price watch', () {
    const watched = true;

    test('AC 6.18 — giá mới BẰNG mức thấp nhất đã biết → KHÔNG alert', () {
      final e = evaluatePriceWatch(
        watched: watched,
        newPrice: 30000, // == min đã biết (equality biên)
        knownMinPrice: 30000,
        lastPurchasePrice: 31000, // giảm 3.2% < 10% → không đủ ngưỡng
        lastAlertedPrice: null,
      );

      expect(e.shouldAlert, isFalse);
      expect(e.reason, isNull);
    });

    test('AC 6.19 — giá cũ = 0: không chia 0, chỉ so mức thấp nhất', () {
      final notLower = evaluatePriceWatch(
        watched: watched,
        newPrice: 25000,
        knownMinPrice: 20000,
        lastPurchasePrice: 0,
        lastAlertedPrice: null,
      );
      expect(notLower.shouldAlert, isFalse);
      expect(notLower.dropPercent, 0);

      final lower = evaluatePriceWatch(
        watched: watched,
        newPrice: 15000,
        knownMinPrice: 20000,
        lastPurchasePrice: 0,
        lastAlertedPrice: null,
      );
      expect(lower.shouldAlert, isTrue);
      expect(lower.reason, PriceWatchReason.newLowest);
    });
  });

  // ── AC 6.20 — xoá dòng watched dọn luôn watch state ───────────────────────
  group('AC 6.20 — xoá dòng watched (local-only)', () {
    late _MockDatabase db;
    late ShoppingListItemDao dao;

    setUp(() {
      db = _MockDatabase();
      dao = ShoppingListItemDao(db);
      when(() => db.delete(any(),
              where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => 1);
      when(() => db.query(any(),
          distinct: any(named: 'distinct'),
          columns: any(named: 'columns'),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          groupBy: any(named: 'groupBy'),
          having: any(named: 'having'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'))).thenAnswer((_) async => []);
    });

    test('xoá là XOÁ CỨNG row — watch state nằm trong row, không bảng watch riêng', () async {
      await dao.delete('sl_watched');

      verify(() => db.delete('shopping_list_items',
          where: 'id = ?', whereArgs: ['sl_watched'])).called(1);
      // Sau khi xoá, không còn dòng watched nào treo lại (watched +
      // last_alert_price + has_unseen_alert đều đi theo row).
      expect(await dao.getWatched(), isEmpty);
    });

    test('xoá row KHÔNG tạo change sync / không đụng bảng khác (AC 6.17 + 6.20)', () async {
      await dao.delete('sl_watched');

      verifyNever(() => db.insert(any(), any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
      verifyNever(() => db.execute(any(), any()));
    });
  });

  // ── AC 12.8 — nhãn badge bell ─────────────────────────────────────────────
  group('AC 12.8 — notificationBadgeLabel', () {
    test('0..99 → hiện đúng số', () {
      expect(notificationBadgeLabel(0), '0');
      expect(notificationBadgeLabel(1), '1');
      expect(notificationBadgeLabel(99), '99');
    });

    test('quá 99 → "99+" (badge không phình)', () {
      expect(notificationBadgeLabel(100), '99+');
      expect(notificationBadgeLabel(1234), '99+');
    });
  });

  // ── AC 6.9 — cửa sổ 90 ngày cho price intelligence ────────────────────────
  group('AC 6.9 — cửa sổ 90 ngày', () {
    test('điểm CŨ HƠN 90 ngày bị loại khỏi "giá tốt nhất trong 90 ngày"', () {
      final best = bestPriceWithinDays([
        _p(20000, 120), // ngoài cửa sổ → phải bị bỏ dù rẻ nhất
        _p(26000, 30),
        _p(28000, 2),
      ]);

      expect(best?.price, 26000);
    });
  });
}
