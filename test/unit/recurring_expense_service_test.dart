import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/core/utils/recurring_schedule.dart';
import 'package:shopsnap/database/daos/recurring_expense_dao.dart';
import 'package:shopsnap/models/recurring_expense_model.dart';
import 'package:shopsnap/services/recurring_expense_service.dart';

/// M-2 — RecurringExpenseService điều phối CRUD + nhắc (AC 4.5/4.6/4.11/4.12).
/// DAO mock, scheduler fake ghi nhận mọi schedule/cancel → assert "gọi đúng".
class MockDao extends Mock implements RecurringExpenseDao {}

class _FakeScheduler implements RecurringReminderScheduler {
  final scheduled = <({int id, DateTime when})>[];
  final cancelled = <int>[];
  final List<int> callOrder = []; // 0 = cancel, 1 = schedule (theo thứ tự thật)

  @override
  Future<void> Function(int, DateTime) get schedule =>
      (notificationId, when) async {
        scheduled.add((id: notificationId, when: when));
        callOrder.add(1);
      };

  @override
  Future<void> Function(int) get cancel => (notificationId) async {
        cancelled.add(notificationId);
        callOrder.add(0);
      };
}

RecurringExpense _entry({
  String id = 'e1',
  int dueDay = 15,
  int remindDaysBefore = 1,
  bool isActive = true,
}) =>
    RecurringExpense(
      id: id,
      name: 'Netflix',
      matchKey: 'netflix',
      amount: 200000,
      dueDay: dueDay,
      isActive: isActive,
      remindDaysBefore: remindDaysBefore,
      createdAt: 1000,
      updatedAt: 1000,
    );

void main() {
  late MockDao dao;
  late _FakeScheduler scheduler;
  late RecurringExpenseService service;

  // Mốc "hiện tại" cố định để assert mốc nhắc deterministic.
  final now = DateTime(2026, 9, 10, 12, 0);

  setUpAll(() {
    registerFallbackValue(
        const CreateRecurringExpenseDto(name: 'x', amount: 1, dueDay: 1));
  });

  setUp(() {
    dao = MockDao();
    scheduler = _FakeScheduler();
    service = RecurringExpenseService(
      dao: dao,
      scheduler: scheduler,
      now: () => now,
    );
    when(() => dao.insert(any())).thenAnswer((_) async => null);
    when(() => dao.updateFields(any(),
        name: any(named: 'name'),
        amount: any(named: 'amount'),
        dueDay: any(named: 'dueDay'),
        remindDaysBefore: any(named: 'remindDaysBefore')))
        .thenAnswer((_) async {});
    when(() => dao.setActive(any(), any())).thenAnswer((_) async => false);
    when(() => dao.findById(any())).thenAnswer((_) async => null);
    when(() => dao.setLastReminderCycle(any(), any())).thenAnswer((_) async {});
    when(() => dao.getActive()).thenAnswer((_) async => []);
  });

  group('create (AC 4.3 + 4.11a)', () {
    test('lưu thành công (đang bật) → schedule ĐÚNG 1 pending với id deterministic',
        () async {
      final entry = _entry();
      when(() => dao.insert(any())).thenAnswer((_) async => entry);

      final created = await service.create(
          const CreateRecurringExpenseDto(
              name: 'Netflix', amount: 200000, dueDay: 15));

      expect(created, same(entry));
      expect(scheduler.scheduled, hasLength(1));
      final call = scheduler.scheduled.single;
      expect(call.id, recurringNotificationId('e1'));
      // Hạn 15/09, nhắc trước 1 → 14/09 09:00 (chu kỳ hiện tại còn tương lai).
      expect(call.when, DateTime(2026, 9, 14, 9, 0));
      verify(() => dao.setLastReminderCycle('e1', '2026-09')).called(1);
    });

    test('insert trả null (vi phạm validation) → KHÔNG schedule gì', () async {
      final result = await service.create(
          const CreateRecurringExpenseDto(
              name: '   ', amount: 0, dueDay: 5));

      expect(result, isNull);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
    });
  });

  group('update (AC 4.4 + 4.11a)', () {
    test('entry đang bật → HỦY schedule cũ TRƯỚC rồi đặt lại (không nhân bản)',
        () async {
      when(() => dao.findById('e1')).thenAnswer((_) async => _entry());

      await service.update('e1', amount: 260000);

      verify(() => dao.updateFields('e1',
          name: null, amount: 260000, dueDay: null, remindDaysBefore: null))
          .called(1);
      expect(scheduler.cancelled, [recurringNotificationId('e1')]);
      expect(scheduler.scheduled, hasLength(1));
      // Cancel luôn diễn ra trước schedule.
      expect(scheduler.callOrder, [0, 1]);
    });

    test('entry không còn tồn tại → không đụng scheduler', () async {
      await service.update('ghost', amount: 1);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
    });

    test('entry đang TẮT → không re-arm', () async {
      when(() => dao.findById('e1'))
          .thenAnswer((_) async => _entry(isActive: false));

      await service.update('e1', amount: 1);

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
    });
  });

  group('setActive (AC 4.5/4.6)', () {
    test('tắt → pending reminder bị HỦY NGAY, không schedule mới', () async {
      when(() => dao.setActive('e1', false)).thenAnswer((_) async => false);
      when(() => dao.findById('e1'))
          .thenAnswer((_) async => _entry(isActive: false));

      final state = await service.setActive('e1', false);

      expect(state, isFalse);
      expect(scheduler.cancelled, [recurringNotificationId('e1')]);
      expect(scheduler.scheduled, isEmpty);
      verifyNever(() => dao.setLastReminderCycle(any(), any()));
    });

    test('bật lại → re-arm cho chu kỳ KẾ TIẾP (mốc cũ đã qua → tháng sau)',
        () async {
      when(() => dao.setActive('e1', true)).thenAnswer((_) async => true);
      // Hạn ngày 5, nhắc trước 1 → mốc 04/09 đã qua lúc now 10/09 → nhảy 04/10.
      when(() => dao.findById('e1'))
          .thenAnswer((_) async => _entry(dueDay: 5));

      await service.setActive('e1', true);

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.when, DateTime(2026, 10, 4, 9, 0));
      verify(() => dao.setLastReminderCycle('e1', '2026-10')).called(1);
    });
  });

  group('rearmAll (AC 4.11b + 4.12 — dedup theo chu kỳ)', () {
    test('mỗi entry bật → hủy + đặt lại ĐÚNG 1 pending; chu kỳ đã fire → K+1',
        () async {
      // Entry A: mốc chu kỳ này còn tương lai. Entry B: đã qua → K+1.
      when(() => dao.getActive()).thenAnswer((_) async => [
            _entry(id: 'a', dueDay: 15, remindDaysBefore: 1), // 14/09
            _entry(id: 'b', dueDay: 5, remindDaysBefore: 1), // 04/10 (K+1)
          ]);

      await service.rearmAll();

      expect(scheduler.scheduled, hasLength(2));
      final byId = {for (final s in scheduler.scheduled) s.id: s.when};
      expect(byId[recurringNotificationId('a')], DateTime(2026, 9, 14, 9, 0));
      expect(byId[recurringNotificationId('b')], DateTime(2026, 10, 4, 9, 0));
      // Mỗi entry đúng 1 schedule — không nhân bản, không nhắc bù chu kỳ cũ.
      expect(
        scheduler.scheduled.map((s) => s.id).toSet().length,
        scheduler.scheduled.length,
      );
      // Không có schedule nào trong quá khứ.
      for (final s in scheduler.scheduled) {
        expect(s.when.isAfter(now), isTrue);
      }
    });

    test('chạy rearmAll NHIỀU lần → luôn cancel trước schedule (tối đa 1 pending)',
        () async {
      when(() => dao.getActive())
          .thenAnswer((_) async => [_entry(id: 'a')]);

      await service.rearmAll();
      await service.rearmAll();
      await service.rearmAll();

      // Lần nào cũng cancel id cũ trước khi đặt mới → không bao giờ 2 pending.
      for (var round = 0; round < 3; round++) {
        expect(scheduler.callOrder[round * 2], 0); // cancel
        expect(scheduler.callOrder[round * 2 + 1], 1); // schedule
      }
      expect(scheduler.scheduled.where((s) => s.id == recurringNotificationId('a')),
          hasLength(3)); // 1 pending tại mọi thời điểm (mỗi lần đè lên)
    });
  });
}
