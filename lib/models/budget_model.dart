/// Chu kỳ ngân sách — `day`/`week`/`month` khớp CHECK constraint của sqflite;
/// `custom` chỉ tồn tại ở server (tạo từ client khác) → không persist được,
/// chỉ dùng in-memory trong phiên (xem `BudgetDao.upsertSynced`).
enum BudgetPeriod { day, week, month, custom }

/// Một dòng phân bổ ngân sách theo danh mục — shape `category_budgets` của
/// backend (chỉ có ở API, không lưu vào sqflite).
class CategoryBudgetLine {
  final String id;
  final String budgetId;
  final String categoryId;

  /// Thông tin category nhúng trong response (server include category).
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  final int allocatedAmount;

  // Computed fields của server (BR-16: spent theo purchase_date).
  final int? spentAmount;
  final int? remainingAmount;
  final double? spentPercentage;

  const CategoryBudgetLine({
    required this.id,
    required this.budgetId,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.allocatedAmount,
    this.spentAmount,
    this.remainingAmount,
    this.spentPercentage,
  });

  factory CategoryBudgetLine.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    return CategoryBudgetLine(
      id:               j['id'] as String? ?? '',
      budgetId:         j['budget_id'] as String? ?? '',
      categoryId:       j['category_id'] as String? ?? '',
      categoryName:     cat is Map ? cat['name'] as String? : null,
      categoryIcon:     cat is Map ? cat['icon'] as String? : null,
      categoryColor:    cat is Map ? cat['color'] as String? : null,
      allocatedAmount:  (j['allocated_amount'] as num?)?.toInt() ?? 0,
      spentAmount:      (j['spent_amount'] as num?)?.toInt(),
      remainingAmount:  (j['remaining_amount'] as num?)?.toInt(),
      spentPercentage:  (j['spent_percentage'] as num?)?.toDouble(),
    );
  }
}

class BudgetModel {
  final String      id;
  final int         amount;
  final BudgetPeriod period;

  /// `null` = ngân sách tổng (tất cả danh mục). Server budget có đúng 1 dòng
  /// category_budgets → map về categoryId để tái dùng UI cũ; 0 hoặc >1 dòng
  /// → coi như ngân sách tổng (schema sqflite chỉ chứa 1 category/budget).
  final String?     categoryId;
  final String      startDate;
  final String      endDate;
  final bool        isActive;
  final int         createdAt;

  // ── Field chỉ có ở backend API — không lưu vào sqflite (schema giữ nguyên) ──
  final String?     name;
  final double?     alertThreshold;
  final bool?       isRecurring;

  /// Computed fields của server (spent tính theo purchase_date, khác cách
  /// tính created_at của sqflite) — null khi model đến từ DB local.
  final int?        spentAmount;
  final int?        remainingAmount;
  final double?     spentPercentage;
  final int?        daysRemaining;      // chỉ có ở GET /budgets/current
  final int?        projectedOverage;   // chỉ có ở GET /budgets/current
  final List<CategoryBudgetLine> categoryBudgets;

  const BudgetModel({
    required this.id,
    required this.amount,
    required this.period,
    this.categoryId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    this.name,
    this.alertThreshold,
    this.isRecurring,
    this.spentAmount,
    this.remainingAmount,
    this.spentPercentage,
    this.daysRemaining,
    this.projectedOverage,
    this.categoryBudgets = const [],
  });

  /// Parse từ row sqflite (snake_case, created_at là millisecond int).
  /// Các field API-only giữ null — nguồn truth offline vẫn là tính toán local.
  factory BudgetModel.fromMap(Map<String, dynamic> m) => BudgetModel(
    id:         m['id'] as String,
    amount:     m['amount'] as int,
    period:     BudgetPeriod.values.firstWhere((e) => e.name == m['period']),
    categoryId: m['category_id'] as String?,
    startDate:  m['start_date'] as String,
    endDate:    m['end_date'] as String,
    isActive:   (m['is_active'] as int) == 1,
    createdAt:  m['created_at'] as int,
  );

  /// Parse từ JSON backend GET/POST/PATCH /budgets (snake_case, đã verify bằng curl):
  /// `start_date`/`end_date` là 'YYYY-MM-DD', `created_at` ISO 8601,
  /// `spent_percentage` là tỉ lệ 0..1 (vd. 0.0208 = 2.08%).
  factory BudgetModel.fromApiJson(Map<String, dynamic> j) {
    final status = j['status'] as String?;
    return BudgetModel(
      id:         j['id'] as String,
      name:       j['name'] as String?,
      amount:     (j['total_amount'] as num?)?.toInt() ?? 0,
      period:     BudgetPeriod.values.firstWhere(
                    (e) => e.name == j['period_type'],
                    orElse: () => BudgetPeriod.custom,
                  ),
      categoryId: _singleCategoryId(j['category_budgets']),
      startDate:  j['start_date'] as String? ?? '',
      endDate:    j['end_date'] as String? ?? '',
      // paused/deleted → isActive=false để DAO lọc khỏi danh sách đang chạy
      isActive:   status != 'paused' && j['deleted_at'] == null,
      createdAt:  _isoToMillis(j['created_at']),
      alertThreshold:   (j['alert_threshold'] as num?)?.toDouble(),
      isRecurring:      j['is_recurring'] == true,
      spentAmount:      (j['spent_amount'] as num?)?.toInt(),
      remainingAmount:  (j['remaining_amount'] as num?)?.toInt(),
      spentPercentage:  (j['spent_percentage'] as num?)?.toDouble(),
      daysRemaining:    (j['days_remaining'] as num?)?.toInt(),
      projectedOverage: (j['projected_overage'] as num?)?.toInt(),
      categoryBudgets: ((j['category_budgets'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CategoryBudgetLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Server budget nhiều dòng category_budgets → sqflite chỉ chứa được 1
  /// category/budget: 1 dòng → giữ id đó; 0 hoặc >1 dòng → ngân sách tổng.
  static String? _singleCategoryId(List? lines) {
    if (lines == null || lines.length != 1) return null;
    final first = lines.first;
    return first is Map ? first['category_id'] as String? : null;
  }

  /// ISO 8601 (hoặc millisecond int nếu có) → millisecond int cho sqflite.
  static int _isoToMillis(Object? iso) {
    if (iso is int) return iso;
    if (iso is String) return DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() => {
    'id':          id,
    'amount':      amount,
    'period':      period.name,
    'category_id': categoryId,
    'start_date':  startDate,
    'end_date':    endDate,
    'is_active':   isActive ? 1 : 0,
    'created_at':  createdAt,
  };
}

class BudgetStatus {
  final BudgetModel budget;
  final int         spent;

  const BudgetStatus({required this.budget, required this.spent});

  /// Ưu tiên giá trị server tính sẵn (khi model đến từ API) — offline thì
  /// fallback công thức local giống hệt (amount - spent).
  int  get remaining   => budget.remainingAmount ?? (budget.amount - spent);
  double get usageRatio =>
      budget.spentPercentage ?? (budget.amount > 0 ? spent / budget.amount : 0);
  bool get isWarning   => usageRatio >= 0.80 && usageRatio < 1.0;
  bool get isDanger    => usageRatio >= 1.0;
}
