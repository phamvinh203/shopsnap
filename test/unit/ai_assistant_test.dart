import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/models/ai_assistant_model.dart';
import 'package:shopsnap/services/summary_api_service.dart';

http.Response okJson(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> sampleAiAssistantPayload() => {
      'period_label': 'Tháng 9/2026',
      'query_date': '2026-09-13',
      'prediction': {
        'current_spent': 1300000,
        'projected_spent': 3000000,
        'budget_amount': 2500000,
        'is_over_budget_projected': true,
        'projected_over_amount': 500000,
        'burn_rate_per_day': 100000,
        'safe_daily_budget': 70588,
        'days_elapsed': 13,
        'days_remaining': 17,
        'total_days': 30,
        'projected_exhaust_day': 25,
        'risk_level': 'high',
      },
      'top_categories': [
        {
          'category_id': 'cat_food',
          'name': 'Ăn uống',
          'icon': '🍜',
          'color': '#FF6B6B',
          'total': 800000,
          'percentage': 61.5,
        }
      ],
      'ai_advice': {
        'summary': 'Tốc độ chi tiêu đang ở mức 100.000đ/ngày.',
        'warning': 'Nguy cơ cạn kiệt ngân sách vào ngày 25.',
        'tips': [
          'Hạ mức chi hàng ngày xuống 70.000đ.',
          'Giảm chi tiêu ăn ngoài.',
        ],
      },
      'source': 'gemini',
    };

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiAssistantModel Deserialization Test', () {
    test('AiAssistantResponse.fromJson parse đầy đủ', () {
      final res = AiAssistantResponse.fromJson(sampleAiAssistantPayload());

      expect(res.periodLabel, 'Tháng 9/2026');
      expect(res.queryDate, '2026-09-13');
      expect(res.source, 'gemini');

      // Prediction
      expect(res.prediction.currentSpent, 1300000);
      expect(res.prediction.projectedSpent, 3000000);
      expect(res.prediction.budgetAmount, 2500000);
      expect(res.prediction.isOverBudgetProjected, isTrue);
      expect(res.prediction.projectedOverAmount, 500000);
      expect(res.prediction.burnRatePerDay, 100000);
      expect(res.prediction.safeDailyBudget, 70588);
      expect(res.prediction.daysElapsed, 13);
      expect(res.prediction.daysRemaining, 17);
      expect(res.prediction.totalDays, 30);
      expect(res.prediction.projectedExhaustDay, 25);
      expect(res.prediction.riskLevel, 'high');
      expect(res.prediction.isHighRisk, isTrue);
      expect(res.prediction.isSafe, isFalse);

      // Top Categories
      expect(res.topCategories.length, 1);
      expect(res.topCategories.first.name, 'Ăn uống');
      expect(res.topCategories.first.percentage, 61.5);

      // AI Advice
      expect(res.aiAdvice.summary, contains('100.000đ/ngày'));
      expect(res.aiAdvice.warning, contains('ngày 25'));
      expect(res.aiAdvice.tips.length, 2);
    });
  });

  group('SummaryApiService aiAssistant Test', () {
    test('GET /summary/ai-assistant gửi query param date và parse model', () async {
      final urls = <Uri>[];

      final api = SummaryApiService(ApiClient(
        client: MockClient((req) async {
          urls.add(req.url);
          return okJson(sampleAiAssistantPayload());
        }),
      ));

      final res = await api.aiAssistant(date: '2026-09-13');

      expect(urls.first.path, '/api/v1/summary/ai-assistant');
      expect(urls.first.queryParameters['date'], '2026-09-13');
      expect(res.periodLabel, 'Tháng 9/2026');
      expect(res.prediction.burnRatePerDay, 100000);
    });
  });
}
