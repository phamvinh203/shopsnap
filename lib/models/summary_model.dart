import 'item_model.dart';

class CategorySummary {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final int    totalSpent;
  final int    itemCount;

  const CategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.totalSpent,
    required this.itemCount,
  });

  factory CategorySummary.fromMap(Map<String, dynamic> m) => CategorySummary(
    categoryId:    m['category_id']   as String,
    categoryName:  m['category_name'] as String,
    categoryIcon:  m['category_icon'] as String,
    categoryColor: m['category_color'] as String,
    totalSpent:    m['total_spent']   as int,
    itemCount:     m['item_count']    as int,
  );
}

class SummaryModel {
  final DateTime            date;
  final int                 totalSpent;
  final int                 itemCount;
  final List<CategorySummary> categories;
  final List<ItemModel>     items;

  const SummaryModel({
    required this.date,
    required this.totalSpent,
    required this.itemCount,
    required this.categories,
    required this.items,
  });

  static SummaryModel empty(DateTime date) => SummaryModel(
    date: date, totalSpent: 0, itemCount: 0, categories: [], items: [],
  );

  /// Map payload `data` của GET /summary (Wave 5) sang shape cũ mà UI đang đọc:
  /// `totals` → totalSpent/itemCount, `breakdown` (group_by=category, có object
  /// `category` lồng: {id, name, color, icon}) → [CategorySummary]. API không
  /// trả items nên caller truyền items local từ ngoài (kỳ day đã sync Wave 3).
  /// Offline vẫn dùng constructor thường + `ItemDao.getSummaryFor*` như cũ.
  factory SummaryModel.fromApiJson(
    Map<String, dynamic> data, {
    required DateTime date,
    List<ItemModel> items = const [],
  }) =>
      SummaryResponse.fromJson(data).toSummaryModel(date: date, items: items);
}

// ── Shape GET /summary (Wave 5) ───────────────────────────────────────────────
// data: { period:{type,start_date,end_date,label},
//         totals:{total_spent,total_items,total_transactions,average_per_day,
//                 average_per_transaction},
//         budget:{budget_id,name,total_amount,remaining_amount,spent_percentage,
//                 status,alert_threshold,days_remaining,projected_overage}|null,
//         comparison:{previous_period_spent,change_amount,change_percentage,
//                     trend:'up'|'down'|'flat'},
//         breakdown?:[...] }  — shape phần tử breakdown theo group_by.

class SummaryPeriodInfo {
  final String type;      // day | week | month | year | custom
  final String startDate; // YYYY-MM-DD
  final String endDate;
  final String label;

  const SummaryPeriodInfo({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory SummaryPeriodInfo.fromJson(Map<String, dynamic> j) => SummaryPeriodInfo(
    type:      j['type']       as String? ?? '',
    startDate: j['start_date'] as String? ?? '',
    endDate:   j['end_date']   as String? ?? '',
    label:     j['label']      as String? ?? '',
  );
}

class SummaryTotals {
  final int totalSpent;
  final int totalItems;
  final int totalTransactions;
  final int averagePerDay;
  final int averagePerTransaction;

  const SummaryTotals({
    required this.totalSpent,
    required this.totalItems,
    required this.totalTransactions,
    required this.averagePerDay,
    required this.averagePerTransaction,
  });

  factory SummaryTotals.fromJson(Map<String, dynamic> j) => SummaryTotals(
    totalSpent:           (j['total_spent']           as num?)?.toInt() ?? 0,
    totalItems:           (j['total_items']           as num?)?.toInt() ?? 0,
    totalTransactions:    (j['total_transactions']    as num?)?.toInt() ?? 0,
    averagePerDay:        (j['average_per_day']       as num?)?.toInt() ?? 0,
    averagePerTransaction:(j['average_per_transaction'] as num?)?.toInt() ?? 0,
  );
}

/// Budget đang chạy chứa kỳ xem — null khi không có budget nào phủ kỳ.
class SummaryBudgetInfo {
  final String budgetId;
  final String name;
  final int    totalAmount;
  final int    remainingAmount;
  final double spentPercentage; // 0..1
  final String status;
  final double alertThreshold;  // 0..1
  final int    daysRemaining;
  final int?   projectedOverage;

  const SummaryBudgetInfo({
    required this.budgetId,
    required this.name,
    required this.totalAmount,
    required this.remainingAmount,
    required this.spentPercentage,
    required this.status,
    required this.alertThreshold,
    required this.daysRemaining,
    required this.projectedOverage,
  });

  factory SummaryBudgetInfo.fromJson(Map<String, dynamic> j) => SummaryBudgetInfo(
    budgetId:         j['budget_id']         as String,
    name:             j['name']              as String? ?? '',
    totalAmount:      (j['total_amount']      as num?)?.toInt() ?? 0,
    remainingAmount:  (j['remaining_amount']  as num?)?.toInt() ?? 0,
    spentPercentage:  (j['spent_percentage']  as num?)?.toDouble() ?? 0,
    status:           j['status']            as String? ?? 'active',
    alertThreshold:   (j['alert_threshold']   as num?)?.toDouble() ?? 0.8,
    daysRemaining:    (j['days_remaining']    as num?)?.toInt() ?? 0,
    projectedOverage: (j['projected_overage'] as num?)?.toInt(),
  );
}

/// So sánh với kỳ liền trước cùng độ dài. `changePercentage` null khi kỳ trước
/// chi 0đ (server không chia cho 0) → UI tự diễn giải theo trend/change_amount.
class SummaryComparison {
  final int    previousPeriodSpent;
  final int    changeAmount;
  final double? changePercentage;
  final String trend; // up | down | flat

  const SummaryComparison({
    required this.previousPeriodSpent,
    required this.changeAmount,
    required this.changePercentage,
    required this.trend,
  });

  factory SummaryComparison.fromJson(Map<String, dynamic> j) => SummaryComparison(
    previousPeriodSpent: (j['previous_period_spent'] as num?)?.toInt() ?? 0,
    changeAmount:        (j['change_amount']        as num?)?.toInt() ?? 0,
    changePercentage:    (j['change_percentage']    as num?)?.toDouble(),
    trend:               j['trend']                 as String? ?? 'flat',
  );
}

/// Một dòng breakdown — hợp nhất 4 biến thể group_by của backend:
/// - category: {category_id, category:{id,name,color,icon}, total_spent,
///              item_count, percentage_of_total, budget_allocated?,
///              budget_remaining?, budget_percentage?}
/// - day:      {date, total_spent, item_count}
/// - week:     {week_start_date, week_end_date, total_spent, item_count}
/// - store:    {store_name, total_spent, item_count}
/// (field không thuộc biến thể sẽ null.)
class SummaryBreakdownEntry {
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? date;
  final String? weekStartDate;
  final String? weekEndDate;
  final String? storeName;
  final int     totalSpent;
  final int     itemCount;
  final double? percentageOfTotal;
  final int?    budgetAllocated;
  final int?    budgetRemaining;
  final double? budgetPercentage;

  const SummaryBreakdownEntry({
    required this.totalSpent,
    required this.itemCount,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.date,
    this.weekStartDate,
    this.weekEndDate,
    this.storeName,
    this.percentageOfTotal,
    this.budgetAllocated,
    this.budgetRemaining,
    this.budgetPercentage,
  });

  factory SummaryBreakdownEntry.fromJson(Map<String, dynamic> j) {
    final cat = (j['category'] as Map?) ?? const {};
    return SummaryBreakdownEntry(
      categoryId:        j['category_id'] as String?,
      categoryName:      cat['name']      as String?,
      categoryIcon:      cat['icon']      as String?,
      categoryColor:     cat['color']     as String?,
      date:              j['date']        as String?,
      weekStartDate:     j['week_start_date'] as String?,
      weekEndDate:       j['week_end_date']   as String?,
      storeName:         j['store_name']  as String?,
      totalSpent:        (j['total_spent'] as num?)?.toInt() ?? 0,
      itemCount:         (j['item_count']  as num?)?.toInt() ?? 0,
      percentageOfTotal: (j['percentage_of_total'] as num?)?.toDouble(),
      budgetAllocated:   (j['budget_allocated']    as num?)?.toInt(),
      budgetRemaining:   (j['budget_remaining']    as num?)?.toInt(),
      budgetPercentage:  (j['budget_percentage']   as num?)?.toDouble(),
    );
  }
}

/// Response đầy đủ GET /summary (đã unwrap envelope `{success, data}`).
class SummaryResponse {
  final SummaryPeriodInfo period;
  final SummaryTotals totals;
  final SummaryBudgetInfo? budget;
  final SummaryComparison comparison;
  final List<SummaryBreakdownEntry> breakdown; // rỗng nếu không group_by

  const SummaryResponse({
    required this.period,
    required this.totals,
    required this.budget,
    required this.comparison,
    required this.breakdown,
  });

  factory SummaryResponse.fromJson(Map<String, dynamic> j) => SummaryResponse(
    period:     SummaryPeriodInfo.fromJson(Map<String, dynamic>.from((j['period']     as Map?) ?? const {})),
    totals:     SummaryTotals.fromJson(Map<String, dynamic>.from((j['totals']     as Map?) ?? const {})),
    budget:     j['budget'] is Map
        ? SummaryBudgetInfo.fromJson(Map<String, dynamic>.from(j['budget'] as Map))
        : null,
    comparison: SummaryComparison.fromJson(Map<String, dynamic>.from((j['comparison'] as Map?) ?? const {})),
    breakdown:  ((j['breakdown'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SummaryBreakdownEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  /// Sang shape [SummaryModel] mà summary_screen đang đọc (hero + pie chart):
  /// breakdown biến thể category → [CategorySummary]; các biến thể day/week/
  /// store không có category → lọc bỏ. Items không có trên API → truyền từ ngoài.
  SummaryModel toSummaryModel({required DateTime date, List<ItemModel> items = const []}) =>
      SummaryModel(
        date:       date,
        totalSpent: totals.totalSpent,
        itemCount:  totals.totalItems,
        categories: [
          for (final b in breakdown)
            if (b.categoryId != null)
              CategorySummary(
                categoryId:    b.categoryId!,
                categoryName:  b.categoryName ?? b.categoryId!,
                categoryIcon:  b.categoryIcon ?? '📦',
                categoryColor: b.categoryColor ?? '#9E9E9E',
                totalSpent:    b.totalSpent,
                itemCount:     b.itemCount,
              ),
        ],
        items: items,
      );
}
