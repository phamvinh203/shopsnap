enum BudgetPeriod { day, week, month }

class BudgetModel {
  final String      id;
  final int         amount;
  final BudgetPeriod period;
  final String?     categoryId;
  final String      startDate;
  final String      endDate;
  final bool        isActive;
  final int         createdAt;

  const BudgetModel({
    required this.id,
    required this.amount,
    required this.period,
    this.categoryId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

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

  int  get remaining   => budget.amount - spent;
  double get usageRatio => budget.amount > 0 ? spent / budget.amount : 0;
  bool get isWarning   => usageRatio >= 0.80 && usageRatio < 1.0;
  bool get isDanger    => usageRatio >= 1.0;
}
