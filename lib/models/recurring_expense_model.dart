/// M-2: một khoản chi định kỳ khai báo LOCAL trong `recurring_expenses`
/// (SQLite, sync OUT — whitelist DTO của BE chưa có entity này, AC 4.15
/// [CONTRACT-PENDING]).
///
/// `updatedAt` bắt buộc giữ theo spec để dùng LWW khi sync mở khoá về sau;
/// `serverId` chừa sẵn (schema v6), đợt này luôn `null`.
class RecurringExpense {
  final String id;

  /// Tên hiển thị (đã trim).
  final String name;

  /// `normalizeMatchKey(name)` — dedup gợi ý + match về sau (AC 4.9/4.10).
  final String matchKey;

  /// Số tiền mỗi kỳ (VND nguyên, CHECK amount > 0).
  final int amount;

  /// `'monthly'` | `'yearly'` — schema chừa yearly nhưng UI đợt này chỉ mở
  /// monthly (out of scope).
  final String period;

  /// Ngày đến hạn trong tháng, 1..28 (tránh lệch tháng 30/31 — AC 4.3).
  final int dueDay;

  /// `true` = đang bật (nhắc + hiện mục danh sách chính); `false` = mục
  /// "Đã tắt" — tắt KHÔNG xóa dữ liệu (AC 4.5).
  final bool isActive;

  /// Nhắc trước bao nhiêu ngày: 0..3 (AC 4.3, mặc định 1).
  final int remindDaysBefore;

  /// Chu kỳ ('yyyy-MM' của kỳ ĐƯỢC nhắc) gần nhất đã đặt lịch nhắc —
  /// dedup nhắc theo chu kỳ (AC 4.12, pattern AC 6.15). `null` = chưa từng.
  final String? lastReminderCycle;

  /// [CONTRACT-PENDING] AC 4.15 — luôn null ở đợt local-only này.
  final String? serverId;

  final int createdAt;
  final int updatedAt;

  const RecurringExpense({
    required this.id,
    required this.name,
    required this.matchKey,
    required this.amount,
    this.period = 'monthly',
    required this.dueDay,
    this.isActive = true,
    this.remindDaysBefore = 1,
    this.lastReminderCycle,
    this.serverId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecurringExpense.fromMap(Map<String, dynamic> m) => RecurringExpense(
        id: m['id'] as String,
        name: m['name'] as String,
        matchKey: m['match_key'] as String,
        amount: (m['amount'] as num).toInt(),
        period: (m['period'] as String?) ?? 'monthly',
        dueDay: (m['due_day'] as num).toInt(),
        isActive: (m['is_active'] as int? ?? 1) == 1,
        remindDaysBefore: (m['remind_days_before'] as num?)?.toInt() ?? 1,
        lastReminderCycle: m['last_reminder_cycle'] as String?,
        serverId: m['server_id'] as String?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'match_key': matchKey,
        'amount': amount,
        'period': period,
        'due_day': dueDay,
        'is_active': isActive ? 1 : 0,
        'remind_days_before': remindDaysBefore,
        'last_reminder_cycle': lastReminderCycle,
        'server_id': serverId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Sửa giữ nguyên `id` + lịch sử, chỉ `updatedAt` đổi (chuẩn bị LWW — AC 4.4).
  RecurringExpense copyWith({
    String? name,
    String? matchKey,
    int? amount,
    int? dueDay,
    bool? isActive,
    int? remindDaysBefore,
    String? lastReminderCycle,
    bool clearLastReminderCycle = false,
    int? updatedAt,
  }) =>
      RecurringExpense(
        id: id,
        name: name ?? this.name,
        matchKey: matchKey ?? this.matchKey,
        amount: amount ?? this.amount,
        period: period,
        dueDay: dueDay ?? this.dueDay,
        isActive: isActive ?? this.isActive,
        remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
        lastReminderCycle: clearLastReminderCycle
            ? null
            : (lastReminderCycle ?? this.lastReminderCycle),
        serverId: serverId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
