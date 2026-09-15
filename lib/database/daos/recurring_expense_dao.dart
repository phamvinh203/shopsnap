import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/price_watch.dart';
import '../../models/recurring_expense_model.dart';

const _uuid = Uuid();

/// DTO tạo khoản định kỳ mới. [name] CHƯA trim — DAO tự trim + chặn rỗng,
/// giữ list không bao giờ chứa dòng rác (cùng tinh thần AC 6.3 của F-#6).
class CreateRecurringExpenseDto {
  final String name;
  final int amount;

  /// 1..28 — caller đã validate; DAO chặn lại lần nữa (CHECK của SQLite).
  final int dueDay;

  /// 0..3 (mặc định 1 — AC 4.3).
  final int remindDaysBefore;

  const CreateRecurringExpenseDto({
    required this.name,
    required this.amount,
    required this.dueDay,
    this.remindDaysBefore = AppConstants.recurringRemindDaysBeforeDefault,
  });
}

/// DAO bảng `recurring_expenses` (M-2).
///
/// ⚠️ LOCAL-ONLY theo thiết kế (AC 4.15 [CONTRACT-PENDING]): KHÔNG method nào
/// ghi vào `sync_queue` — recurring không được gửi lên server (whitelist DTO
/// của BE chưa chứa entity này, push sẽ 400). Test
/// `test/unit/recurring_expense_dao_test.dart` khoá invariant này.
///
/// KHÔNG có xóa cứng (out of scope — tắt qua [setActive] là đủ, giữ lịch sử
/// khai báo, AC 4.5).
class RecurringExpenseDao {
  final Database db;

  RecurringExpenseDao(this.db);

  /// Thứ tự hiển thị: đang bật trước, tới hạn sớm trước, cùng hạn thì tên A→Z.
  Future<List<RecurringExpense>> getAll() async {
    final rows = await db.query(
      'recurring_expenses',
      orderBy: 'is_active DESC, due_day ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<List<RecurringExpense>> getActive() async {
    final rows = await db.query(
      'recurring_expenses',
      where: 'is_active = 1',
      orderBy: 'due_day ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<RecurringExpense?> findById(String id) async {
    final rows = await db.query(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RecurringExpense.fromMap(rows.first);
  }

  /// Thêm khoản. Trả `null` khi vi phạm validation (tên rỗng, amount ≤ 0,
  /// due_day ngoài 1..28, remind ngoài 0..3) — KHÔNG tạo dòng (AC 4.3);
  /// UI vẫn phải validate inline trước, DAO là tuyến phòng thủ cuối.
  Future<RecurringExpense?> insert(CreateRecurringExpenseDto dto) async {
    final name = dto.name.trim();
    if (name.isEmpty) return null;
    if (dto.amount <= 0) return null;
    if (dto.dueDay < AppConstants.recurringDueDayMin ||
        dto.dueDay > AppConstants.recurringDueDayMax) {
      return null;
    }
    if (dto.remindDaysBefore < AppConstants.recurringRemindDaysBeforeMin ||
        dto.remindDaysBefore > AppConstants.recurringRemindDaysBeforeMax) {
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = RecurringExpense(
      id: _uuid.v4(),
      name: name,
      matchKey: normalizeMatchKey(name),
      amount: dto.amount,
      period: 'monthly', // UI đợt này chỉ mở monthly (schema chừa yearly)
      dueDay: dto.dueDay,
      isActive: true,
      remindDaysBefore: dto.remindDaysBefore,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('recurring_expenses', entry.toMap());
    return entry;
  }

  /// Sửa tên/số tiền/ngày/nhắc — giữ nguyên `id`, chỉ `updated_at` cập nhật
  /// (AC 4.4, chuẩn bị LWW). `match_key` tự tính lại theo tên mới.
  Future<void> updateFields(
    String id, {
    String? name,
    int? amount,
    int? dueDay,
    int? remindDaysBefore,
  }) async {
    final trimmed = name?.trim();
    final changes = <String, dynamic>{
      if (trimmed != null && trimmed.isNotEmpty) ...{
        'name': trimmed,
        'match_key': normalizeMatchKey(trimmed),
      },
      if (amount != null && amount > 0) 'amount': amount,
      if (dueDay != null &&
          dueDay >= AppConstants.recurringDueDayMin &&
          dueDay <= AppConstants.recurringDueDayMax)
        'due_day': dueDay,
      if (remindDaysBefore != null &&
          remindDaysBefore >= AppConstants.recurringRemindDaysBeforeMin &&
          remindDaysBefore <= AppConstants.recurringRemindDaysBeforeMax)
        'remind_days_before': remindDaysBefore,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (changes.length == 1) return; // chỉ có updated_at → không có gì đổi
    await db.update(
      'recurring_expenses',
      changes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Bật/tắt nhắc (AC 4.5/4.6) — toggle `is_active`, KHÔNG xóa dữ liệu.
  /// Trả về trạng thái mới.
  Future<bool> setActive(String id, bool active) async {
    await db.update(
      'recurring_expenses',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final entry = await findById(id);
    return entry?.isActive ?? false;
  }

  /// Ghi chu kỳ ('yyyy-MM') vừa đặt lịch nhắc — dedup nhắc theo chu kỳ
  /// (AC 4.12, pattern AC 6.15).
  Future<void> setLastReminderCycle(String id, String cycle) async {
    await db.update(
      'recurring_expenses',
      {'last_reminder_cycle': cycle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Tập match_key của các entry ĐANG BẬT — dùng để loại nhóm đã khai báo
  /// khỏi card gợi ý (AC 4.9).
  Future<Set<String>> activeMatchKeys() async {
    final rows = await db.query(
      'recurring_expenses',
      columns: ['match_key'],
      where: 'is_active = 1',
    );
    return rows.map((r) => r['match_key'] as String).toSet();
  }
}
