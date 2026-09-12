import '../core/network/api_client.dart';
import '../models/budget_model.dart';

/// Chu kỳ hợp lệ của backend (`BUDGET_PERIOD_TYPES`).
const budgetPeriodTypes = <String>['day', 'week', 'month', 'custom'];

/// Trạng thái hợp lệ của backend (`BUDGET_STATUSES`).
const budgetStatuses = <String>['active', 'exceeded', 'completed', 'paused'];

/// Dòng phân bổ theo danh mục trong body create/update — khớp
/// `CategoryBudgetDto` backend (allocated_amount phải > 0, không trùng category).
class CategoryBudgetPayload {
  final String categoryId;
  final int allocatedAmount;

  const CategoryBudgetPayload({required this.categoryId, required this.allocatedAmount});

  Map<String, dynamic> toJson() => {
    'category_id':      categoryId,
    'allocated_amount': allocatedAmount,
  };
}

/// Payload tạo budget — khớp `CreateBudgetDto` backend (snake_case khi toJson).
///
/// `startDate`/`endDate` gửi chuỗi 'YYYY-MM-DD'; server tự căn lại theo kỳ
/// (week → thứ 2–CN, month → đầu–cuối tháng, day → start == end) nên UI chỉ
/// cần gửi ngày người dùng chọn, lấy ngày đã căn từ response để lưu local.
class BudgetPayload {
  final String name;
  final String periodType; // một giá trị trong [budgetPeriodTypes]
  final String startDate;
  final String endDate;
  final int totalAmount;
  final double? alertThreshold;
  final bool? isRecurring;
  final List<CategoryBudgetPayload>? categoryBudgets;

  const BudgetPayload({
    required this.name,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    this.alertThreshold,
    this.isRecurring,
    this.categoryBudgets,
  });

  Map<String, dynamic> toJson() => {
    'name':        name,
    'period_type': periodType,
    'start_date':  startDate,
    'end_date':    endDate,
    'total_amount': totalAmount,
    if (alertThreshold   != null) 'alert_threshold':   alertThreshold,
    if (isRecurring      != null) 'is_recurring':      isRecurring,
    if (categoryBudgets  != null)
      'category_budgets': categoryBudgets!.map((e) => e.toJson()).toList(),
  };
}

/// Một alert của budget — shape backend GET /budgets/:id/alerts (BL #1).
class BudgetAlert {
  final String id;
  final String budgetId;

  /// threshold_reached | budget_exceeded | category_threshold_reached | category_exceeded
  final String type;
  final double thresholdPercentage;
  final int spentAmount;
  final int totalAmount;
  final String? categoryId;
  final String triggeredAt;     // ISO 8601
  final String? acknowledgedAt; // ISO 8601, null nếu chưa đọc

  const BudgetAlert({
    required this.id,
    required this.budgetId,
    required this.type,
    required this.thresholdPercentage,
    required this.spentAmount,
    required this.totalAmount,
    this.categoryId,
    required this.triggeredAt,
    this.acknowledgedAt,
  });

  factory BudgetAlert.fromJson(Map<String, dynamic> j) => BudgetAlert(
    id:                  j['id'] as String,
    budgetId:            j['budget_id'] as String,
    type:                j['type'] as String? ?? '',
    thresholdPercentage: (j['threshold_percentage'] as num?)?.toDouble() ?? 0,
    spentAmount:         (j['spent_amount'] as num?)?.toInt() ?? 0,
    totalAmount:         (j['total_amount'] as num?)?.toInt() ?? 0,
    categoryId:          j['category_id'] as String?,
    triggeredAt:         j['triggered_at'] as String? ?? '',
    acknowledgedAt:      j['acknowledged_at'] as String?,
  );
}

/// Gọi các endpoint /budgets/* qua [ApiClient].
///
/// Backend domain-API dùng snake_case → mapping sang [BudgetModel] nằm ở
/// `BudgetModel.fromApiJson`. Mọi endpoint đều cần Bearer token (JwtAuthGuard)
/// → `auth: true` để được 401-refresh-retry của ApiClient.
class BudgetApiService {
  final ApiClient _client;

  const BudgetApiService(this._client);

  /// GET /budgets — danh sách budget kèm computed fields (spent/remaining/%).
  ///
  /// - [status] một giá trị trong [budgetStatuses]; [periodType] trong
  ///   [budgetPeriodTypes]; [date] 'YYYY-MM-DD' → budget đang chạy ngày đó.
  /// - Meta phân trang của response bỏ qua: app load trọn bộ budget của user
  ///   (limit mặc định 20 là đủ cho nhu cầu hiện tại).
  /// - Lỗi → ném [ApiException] (caller tự quyết fallback local).
  Future<List<BudgetModel>> list({
    String? status,
    String? periodType,
    String? date,
    bool includeDeleted = false,
  }) async {
    final data = await _client.get('/budgets', auth: true, query: {
      if (status     != null) 'status':      status,
      if (periodType != null) 'period_type': periodType,
      if (date       != null) 'date':        date,
      'include_deleted': includeDeleted ? 'true' : 'false',
    });
    final items = ((data as Map)['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((j) => BudgetModel.fromApiJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /budgets/current — budget đang chạy hôm nay (kèm days_remaining +
  /// projected_overage, loại cả budget paused).
  Future<List<BudgetModel>> current() async {
    final data = await _client.get('/budgets/current', auth: true);
    return (data as List)
        .whereType<Map>()
        .map((j) => BudgetModel.fromApiJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /budgets/:id → 404 BUDGET_NOT_FOUND nếu không tồn tại/đã soft-delete.
  Future<BudgetModel> getById(String id) async {
    final data = await _client.get('/budgets/$id', auth: true);
    return BudgetModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// POST /budgets → 201 budget mới. Server căn lại ngày theo kỳ và trả về
  /// ngày đã căn — caller nên lưu lại response thay vì ngày gửi đi.
  ///
  /// Lỗi hay gặp: 409 BUDGET_OVERLAP (trùng kỳ khác), 422 BUDGET_DATE_INVALID,
  /// 400 BUDGET_ALLOCATED_EXCEEDS_TOTAL / BUDGET_NEGATIVE_AMOUNT,
  /// 409 BUDGET_CATEGORY_CONFLICT.
  Future<BudgetModel> create(BudgetPayload payload) async {
    final data = await _client.post('/budgets', auth: true, body: payload.toJson());
    return BudgetModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// PATCH /budgets/:id — cập nhật một phần (ưu tiên hơn PUT vì không cần gửi
  /// đủ field). [status] hỗ trợ paused / re-activate (kèm các field khác).
  /// Server vẫn overlap-check khi đổi ngày → 409 BUDGET_OVERLAP.
  Future<BudgetModel> update(
    String id, {
    String? name,
    String? periodType,
    String? startDate,
    String? endDate,
    int? totalAmount,
    double? alertThreshold,
    bool? isRecurring,
    String? status,
    List<CategoryBudgetPayload>? categoryBudgets,
  }) async {
    final data = await _client.patch('/budgets/$id', auth: true, body: {
      if (name           != null) 'name':            name,
      if (periodType     != null) 'period_type':     periodType,
      if (startDate      != null) 'start_date':      startDate,
      if (endDate        != null) 'end_date':        endDate,
      if (totalAmount    != null) 'total_amount':    totalAmount,
      if (alertThreshold != null) 'alert_threshold': alertThreshold,
      if (isRecurring    != null) 'is_recurring':    isRecurring,
      if (status         != null) 'status':          status,
      if (categoryBudgets != null)
        'category_budgets': categoryBudgets.map((e) => e.toJson()).toList(),
    });
    return BudgetModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// DELETE /budgets/:id → 204 (soft delete, body rỗng).
  Future<void> delete(String id) async {
    await _client.delete('/budgets/$id', auth: true);
  }

  /// GET /budgets/:id/alerts — lịch sử alert (mới nhất trước).
  Future<List<BudgetAlert>> alerts(String id) async {
    final data = await _client.get('/budgets/$id/alerts', auth: true);
    return (data as List)
        .whereType<Map>()
        .map((j) => BudgetAlert.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }
}
