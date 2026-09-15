import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/utils/price_watch.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/notification_preferences_provider.dart';
import 'package:shopsnap/providers/shopping_list_provider.dart';
import 'package:shopsnap/services/notification_service.dart';

/// F-#12 — pipeline budget/price alert đến NotificationService:
/// - AC 12.7: toggle "Budget alerts"/"Price alerts" TẮT → KHÔNG local
///   notification nào được đẩy (observe số call 'show' xuống plugin channel).
/// - AC 12.1/12.2: prefs BẬT → crossing 80%/100% đẩy đủ 2 notification.
/// - spentBefore không chụp được → không bắn (tránh alert sai).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Dedup key budget alert lưu SharedPreferences → phải mock trong test,
    // nếu không getStringList ném MissingPluginException (service nuốt → 0).
    SharedPreferences.setMockInitialValues({});
  });

  final showCalls = <MethodCall>[];

  /// Mock handler plugin: 'initialize' phải trả bool (plugin cast kết quả),
  /// 'show' được ghi nhận để assert payload, còn lại trả null an toàn.
  Future<Object?> handlePluginCall(MethodCall call) async {
    switch (call.method) {
      case 'initialize':
      case 'requestNotificationsPermission':
      case 'areNotificationsEnabled':
        return true;
      case 'show':
        showCalls.add(call);
        return null;
      default:
        return null;
    }
  }

  setUp(() async {
    showCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => handlePluginCall(call),
    );
    // Plugin cần init để platform instance được gán → call 'show' đi qua mock.
    await NotificationService.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  BudgetStatus budgetStatus({int spent = 150000, int amount = 100000}) =>
      BudgetStatus(
        budget: BudgetModel(
          id: 'b1',
          amount: amount,
          period: BudgetPeriod.month,
          startDate: '2026-09-01',
          endDate: '2026-09-30',
          isActive: true,
          createdAt: 0,
        ),
        spent: spent,
      );

  ProviderContainer container(NotificationPreferences prefs) {
    final c = ProviderContainer(overrides: [
      budgetStatusProvider
          .overrideWith(() => _FixedBudgetStatusNotifier(budgetStatus())),
      notificationPreferencesProvider
          .overrideWith(() => _FixedPrefsController(prefs)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> checkAlert(ProviderContainer c, {int? spentBefore}) =>
      c.read(budgetStatusProvider.notifier).checkAndAlert(spentBefore: spentBefore);

  test('AC 12.14/12.2 — prefs bật + vượt 2 ngưỡng trong 1 lần → 1 notification generic (ngưỡng cao nhất)',
      () async {
    final c = container(const NotificationPreferences(
        budgetAlerts: true, priceAlerts: true));

    await checkAlert(c, spentBefore: 50000);

    expect(showCalls.length, 1);
    final titles = showCalls.map((c) => c.arguments['title'] as String).toSet();
    expect(titles, {'Ngân sách cần chú ý'});
    // AC 12.14: ngưỡng cao nhất (100%) → body "đã vượt", không phải "sắp chạm".
    expect(showCalls.single.arguments['body'], 'Bạn đã vượt mức chi tiêu đã đặt ra. Mở ứng dụng để xem chi tiết.');
    // AC 12.4: body không chứa số.
    for (final call in showCalls) {
      expect((call.arguments['body'] as String).contains(RegExp(r'\d')), isFalse);
    }
  });

  test('AC 12.7 — toggle "Budget alerts" TẮT → KHÔNG local notification nào',
      () async {
    final c = container(const NotificationPreferences(
        budgetAlerts: false, priceAlerts: true));

    await checkAlert(c, spentBefore: 50000);

    expect(showCalls, isEmpty);
  });

  test('spentBefore = null (không chụp được mốc) → không bắn', () async {
    final c = container(const NotificationPreferences(
        budgetAlerts: true, priceAlerts: true));

    await checkAlert(c); // spentBefore: null

    expect(showCalls, isEmpty);
  });

  test('AC 12.7 — toggle "Price alerts" TẮT → notify price watch không đẩy notification',
      () async {
    final c = container(const NotificationPreferences(
        budgetAlerts: true, priceAlerts: false));

    await c.read(priceWatchServiceProvider).notify(
          itemName: 'Sữa tươi Vinamilk',
          price: 28000,
          reason: PriceWatchReason.newLowest,
        );

    expect(showCalls, isEmpty);
  });

  test('prefs bật → notify price watch đẩy ĐÚng 1 notification generic (AC 12.4/12.6)',
      () async {
    final c = container(const NotificationPreferences(
        budgetAlerts: true, priceAlerts: true));

    await c.read(priceWatchServiceProvider).notify(
          itemName: 'Sữa tươi Vinamilk',
          price: 28000,
          reason: PriceWatchReason.newLowest,
        );

    expect(showCalls.length, 1);
    expect(showCalls.single.arguments['title'], 'Cập nhật giá đáng chú ý');
    final text =
        '${showCalls.single.arguments['title']} ${showCalls.single.arguments['body']}';
    // Tên món / giá KHÔNG xuất hiện trong notification.
    expect(text.contains('Vinamilk'), isFalse);
    expect(text.contains('28'), isFalse);
  });
}

/// Mock handler plugin: 'initialize' phải trả bool (plugin cast kết quả),
/// 'show' được ghi nhận để assert payload, còn lại trả null an toàn.
class _FixedBudgetStatusNotifier extends BudgetStatusNotifier {
  final BudgetStatus? status;
  _FixedBudgetStatusNotifier(this.status);

  @override
  Future<BudgetStatus?> build() async => status;
}

class _FixedPrefsController extends NotificationPreferencesController {
  final NotificationPreferences prefs;
  _FixedPrefsController(this.prefs);

  @override
  Future<NotificationPreferences> build() async => prefs;
}
