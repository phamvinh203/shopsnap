/// Dữ liệu phản hồi từ GET /api/v1/summary/ai-assistant
class AiAssistantResponse {
  final String periodLabel;
  final String queryDate;
  final SpendingPrediction prediction;
  final List<AiTopCategory> topCategories;
  final AiAdvice aiAdvice;
  final String source; // 'gemini' | 'smart_heuristic'

  const AiAssistantResponse({
    required this.periodLabel,
    required this.queryDate,
    required this.prediction,
    required this.topCategories,
    required this.aiAdvice,
    required this.source,
  });

  factory AiAssistantResponse.fromJson(Map<String, dynamic> j) {
    final rawCats = (j['top_categories'] as List<dynamic>?)
            ?.map((c) => AiTopCategory.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return AiAssistantResponse(
      periodLabel: j['period_label'] as String? ?? '',
      queryDate: j['query_date'] as String? ?? '',
      prediction: SpendingPrediction.fromJson(
        (j['prediction'] as Map<String, dynamic>?) ?? {},
      ),
      topCategories: rawCats,
      aiAdvice: AiAdvice.fromJson(
        (j['ai_advice'] as Map<String, dynamic>?) ?? {},
      ),
      source: j['source'] as String? ?? 'smart_heuristic',
    );
  }
}

/// Số liệu dự phóng tài chính cá nhân (Burn-Rate & Prediction)
class SpendingPrediction {
  final int currentSpent;
  final int projectedSpent;
  final int? budgetAmount;
  final bool isOverBudgetProjected;
  final int projectedOverAmount;
  final int burnRatePerDay;
  final int safeDailyBudget;
  final int daysElapsed;
  final int daysRemaining;
  final int totalDays;
  final int? projectedExhaustDay;
  final String riskLevel; // 'low' | 'medium' | 'high'

  const SpendingPrediction({
    required this.currentSpent,
    required this.projectedSpent,
    this.budgetAmount,
    required this.isOverBudgetProjected,
    required this.projectedOverAmount,
    required this.burnRatePerDay,
    required this.safeDailyBudget,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.totalDays,
    this.projectedExhaustDay,
    required this.riskLevel,
  });

  factory SpendingPrediction.fromJson(Map<String, dynamic> j) => SpendingPrediction(
    currentSpent: (j['current_spent'] as num?)?.toInt() ?? 0,
    projectedSpent: (j['projected_spent'] as num?)?.toInt() ?? 0,
    budgetAmount: (j['budget_amount'] as num?)?.toInt(),
    isOverBudgetProjected: j['is_over_budget_projected'] as bool? ?? false,
    projectedOverAmount: (j['projected_over_amount'] as num?)?.toInt() ?? 0,
    burnRatePerDay: (j['burn_rate_per_day'] as num?)?.toInt() ?? 0,
    safeDailyBudget: (j['safe_daily_budget'] as num?)?.toInt() ?? 0,
    daysElapsed: (j['days_elapsed'] as num?)?.toInt() ?? 1,
    daysRemaining: (j['days_remaining'] as num?)?.toInt() ?? 0,
    totalDays: (j['total_days'] as num?)?.toInt() ?? 30,
    projectedExhaustDay: (j['projected_exhaust_day'] as num?)?.toInt(),
    riskLevel: j['risk_level'] as String? ?? 'low',
  );

  bool get isHighRisk => riskLevel == 'high';
  bool get isMediumRisk => riskLevel == 'medium';
  bool get isSafe => riskLevel == 'low';
}

/// Danh mục chi tiêu đóng góp nhiều nhất
class AiTopCategory {
  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final int total;
  final double percentage;

  const AiTopCategory({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
    required this.percentage,
  });

  factory AiTopCategory.fromJson(Map<String, dynamic> j) => AiTopCategory(
    categoryId: j['category_id'] as String? ?? '',
    name: j['name'] as String? ?? 'Khác',
    icon: j['icon'] as String? ?? '📦',
    color: j['color'] as String? ?? '#DDA0DD',
    total: (j['total'] as num?)?.toInt() ?? 0,
    percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Nhận định và mẹo tiết kiệm từ AI
class AiAdvice {
  final String summary;
  final String? warning;
  final List<String> tips;

  const AiAdvice({
    required this.summary,
    this.warning,
    required this.tips,
  });

  factory AiAdvice.fromJson(Map<String, dynamic> j) {
    final rawTips = (j['tips'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    return AiAdvice(
      summary: j['summary'] as String? ?? '',
      warning: j['warning'] as String?,
      tips: rawTips,
    );
  }
}
