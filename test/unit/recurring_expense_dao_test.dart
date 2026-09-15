import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/database/daos/recurring_expense_dao.dart';
import 'package:sqflite/sqflite.dart';

/// M-2 — DAO `recurring_expenses` là LOCAL-ONLY (AC 4.7/4.15):
/// mọi thao tác CRUD chỉ chạm bảng `recurring_expenses`, KHÔNG bao giờ enqueue
/// `sync_queue` (không phát sinh request sync — whitelist `@IsIn` của BE chưa
/// chứa entity này, push sẽ 400). Khoá invariant như
/// `shopping_list_no_sync_test.dart` của F-#6.
class MockDatabase extends Mock implements Database {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  late MockDatabase db;
  late RecurringExpenseDao dao;

  setUp(() {
    db = MockDatabase();
    dao = RecurringExpenseDao(db);

    when(() => db.insert(any(), any(),
        nullColumnHack: any(named: 'nullColumnHack'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
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
    when(() => db.update(any(), any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
        .thenAnswer((_) async => 1);
    when(() => db.execute(any(), any())).thenAnswer((_) async {});
  });

  void verifyNeverEnqueuedSync() {
    verifyNever(() => db.insert('sync_queue', any(),
        nullColumnHack: any(named: 'nullColumnHack'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')));
    // Không thao tác DAO nào ghi ra bảng ngoài recurring_expenses.
    verifyNever(() => db.insert('items', any(),
        nullColumnHack: any(named: 'nullColumnHack'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')));
  }

  group('insert (AC 4.3)', () {
    test('hợp lệ → ghi đúng bảng, match_key tự normalize, mặc định monthly/active',
        () async {
      final created = await dao.insert(const CreateRecurringExpenseDto(
        name: '  Tiền Mạng  ',
        amount: 200000,
        dueDay: 5,
      ));

      expect(created, isNotNull);
      expect(created!.name, 'Tiền Mạng'); // đã trim
      expect(created.matchKey, 'tiền mạng'); // normalizeMatchKey
      expect(created.period, 'monthly');
      expect(created.isActive, isTrue);
      expect(created.remindDaysBefore, 1); // mặc định AC 4.3
      expect(created.serverId, isNull); // [CONTRACT-PENDING]
      expect(created.dueDay, 5);

      final row = verify(() => db.insert('recurring_expenses', captureAny(),
              nullColumnHack: any(named: 'nullColumnHack'),
              conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .captured
          .cast<Map<String, dynamic>>()
          .single;
      expect(row['amount'], 200000);
      expect(row['is_active'], 1);
      expect(row['last_reminder_cycle'], isNull);
      verifyNeverEnqueuedSync();
    });

    test('vi phạm validation → trả null, KHÔNG ghi gì (tên rỗng / tiền ≤ 0 / ngày ngoài 1..28)',
        () async {
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: '   ', amount: 100, dueDay: 5)),
          isNull);
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: 'Netflix', amount: 0, dueDay: 5)),
          isNull);
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: 'Netflix', amount: -1, dueDay: 5)),
          isNull);
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: 'Netflix', amount: 200000, dueDay: 0)),
          isNull);
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: 'Netflix', amount: 200000, dueDay: 29)),
          isNull);
      expect(
          await dao.insert(const CreateRecurringExpenseDto(
              name: 'Netflix', amount: 200000, dueDay: 5, remindDaysBefore: 4)),
          isNull);

      verifyNever(() => db.insert(any(), any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
    });
  });

  group('updateFields (AC 4.4)', () {
    test('đổi tên → name + match_key + updated_at đổi, id giữ nguyên', () async {
      await dao.updateFields('e1', name: 'Netflix Premium', amount: 260000);

      final changes = verify(() => db.update('recurring_expenses', captureAny(),
              where: captureAny(named: 'where'),
              whereArgs: captureAny(named: 'whereArgs')))
          .captured;
      final row = changes[0] as Map<String, dynamic>;
      expect(row['name'], 'Netflix Premium');
      expect(row['match_key'], 'netflix premium');
      expect(row['amount'], 260000);
      expect(changes[1] as String, 'id = ?');
      expect(changes[2] as List, ['e1']);
      verifyNeverEnqueuedSync();
    });

    test('không có gì đổi → không phát sinh UPDATE', () async {
      await dao.updateFields('e1', name: '   ');
      verifyNever(() => db.update(any(), any(),
          where: any(named: 'where'), whereArgs: any(named: 'whereArgs')));
    });

    test('giá trị ngoài miền bị bỏ qua hết (due_day 29, remind 4, amount 0) → '
        'chỉ còn updated_at → KHÔNG phát sinh UPDATE', () async {
      await dao.updateFields('e1', dueDay: 29, remindDaysBefore: 4, amount: 0);
      verifyNever(() => db.update(any(), any(),
          where: any(named: 'where'), whereArgs: any(named: 'whereArgs')));
    });
  });

  group('setActive (AC 4.5/4.6)', () {
    test('ghi is_active + updated_at, trả trạng thái mới', () async {
      when(() => db.query('recurring_expenses',
          distinct: any(named: 'distinct'),
          columns: any(named: 'columns'),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          groupBy: any(named: 'groupBy'),
          having: any(named: 'having'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'))).thenAnswer((_) async => [
            {
              'id': 'e1',
              'name': 'Netflix',
              'match_key': 'netflix',
              'amount': 200000,
              'period': 'monthly',
              'due_day': 5,
              'is_active': 0,
              'remind_days_before': 1,
              'last_reminder_cycle': null,
              'server_id': null,
              'created_at': 1000,
              'updated_at': 2000,
            }
          ]);

      final newState = await dao.setActive('e1', false);

      expect(newState, isFalse);
      final changes = verify(() => db.update('recurring_expenses', captureAny(),
              where: captureAny(named: 'where'),
              whereArgs: captureAny(named: 'whereArgs')))
          .captured;
      final row = changes[0] as Map<String, dynamic>;
      expect(row['is_active'], 0); // tắt KHÔNG xóa dữ liệu (AC 4.5)
      expect(changes[2] as List, ['e1']);
      verifyNeverEnqueuedSync();
    });
  });

  test('setLastReminderCycle — ghi chu kỳ dedup (AC 4.12)', () async {
    await dao.setLastReminderCycle('e1', '2026-09');
    final changes = verify(() => db.update('recurring_expenses', captureAny(),
            where: captureAny(named: 'where'),
            whereArgs: captureAny(named: 'whereArgs')))
        .captured;
    expect((changes[0] as Map<String, dynamic>)['last_reminder_cycle'],
        '2026-09');
  });

  test('activeMatchKeys — tập match_key của entry đang bật (AC 4.9)', () async {
    when(() => db.query('recurring_expenses',
        distinct: any(named: 'distinct'),
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        groupBy: any(named: 'groupBy'),
        having: any(named: 'having'),
        orderBy: any(named: 'orderBy'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'))).thenAnswer((_) async => [
          {'match_key': 'netflix'},
          {'match_key': 'tiền mạng'},
        ]);

    final keys = await dao.activeMatchKeys();

    expect(keys, {'netflix', 'tiền mạng'});
    final args = verify(() => db.query('recurring_expenses',
            distinct: any(named: 'distinct'),
            columns: captureAny(named: 'columns'),
            where: captureAny(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            groupBy: any(named: 'groupBy'),
            having: any(named: 'having'),
            orderBy: any(named: 'orderBy'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset')))
        .captured;
    expect(args[0], ['match_key']);
    expect(args[1], 'is_active = 1');
  });

  test('getAll / getActive — chỉ đọc recurring_expenses, không sync (AC 4.7)',
      () async {
    await dao.getAll();
    await dao.getActive();
    verifyNeverEnqueuedSync();
  });
}
