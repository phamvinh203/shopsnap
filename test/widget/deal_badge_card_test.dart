import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/deal_badge.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/price_history_model.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/price_history_provider.dart';
import 'package:shopsnap/screens/home/widgets/deal_badge_card.dart';
import 'package:shopsnap/screens/home/widgets/item_detail_sheet.dart';

import 'ui/helpers.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

PriceHistorySummary _summary({
  required int latest,
  required int avg,
  int? previous = 40000,
  int min = 38000,
  int records = 3,
  double? threshold,
}) {
  return PriceHistorySummary(
    itemName: 'Cà phê',
    latestPrice: latest,
    previousPrice: records > 1 ? previous : null,
    minPrice: min,
    maxPrice: latest,
    avgPrice: avg,
    trend: PriceTrend.stable,
    totalRecords: records,
    points: [
      for (var i = 0; i < records; i++)
        PriceHistoryPoint(
          id: 'p$i',
          price: latest,
          purchasedAt: DateTime(2026, 9, i + 1),
        ),
    ],
    dealThresholdPercent: threshold,
  );
}

DealBadgeResult _badgeOf(PriceHistorySummary s) => computeDealBadge(
      current: s.latestPrice,
      avg: s.avgPrice,
      min: s.minPrice,
      previous: s.previousPrice,
      recordCount: s.totalRecords,
      thresholdPercent: resolveDealThreshold(s.dealThresholdPercent),
    );

Future<void> _pumpCard(WidgetTester tester, PriceHistorySummary summary) async {
  await tester.pumpWidget(wrapWithAppTheme(
    DealBadgeCard(summary: summary, badge: _badgeOf(summary)),
  ));
  await tester.pumpAndSettle();
}

// ── Sheet integration fixtures ────────────────────────────────────────────────

ItemModel _item() => const ItemModel(
      id: 'item-1',
      name: 'Cà phê',
      price: 25000,
      categoryId: 'cat_food',
      categoryName: 'Ăn uống',
      categoryIcon: '🍔',
      categoryColor: '#FF6B6B',
      createdAt: 0,
      updatedAt: 0,
    );

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [];
}

class _FakeItemsNotifier extends ItemsNotifier {
  @override
  Future<List<ItemModel>> build() async => const [];
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required PriceHistorySummary? summary,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => _FakeItemsNotifier()),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        priceHistorySummaryProvider(
          const PriceHistoryQuery(name: 'Cà phê'),
        ).overrideWith((ref) async => summary),
      ],
      // Sheet thật bọc content trong SingleChildScrollView (AppBottomSheet)
      // — test mô phỏng y hệt để Column nội dung không bị giới hạn chiều cao.
      child: wrapWithAppTheme(
        SingleChildScrollView(child: ItemDetailSheet(item: _item())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('DealBadgeCard — 3 mức badge', () {
    testWidgets('DEAL TỐT: chip, % lệch nổi bật, 4 mốc giá, gợi ý (AC 1.1/1.2/1.7)',
        (tester) async {
      await _pumpCard(tester, _summary(latest: 38000, avg: 41000));

      expect(find.byKey(const Key('dealBadge_card')), findsOneWidget);
      // Badge mức + màu chip lime/pine theo tokens (assert widget, không assert hex).
      expect(find.byKey(const Key('dealBadge_level')), findsOneWidget);
      expect(find.text('DEAL TỐT'), findsOneWidget);
      // % lệch 1 chữ số thập phân (AC 1.2).
      expect(
        tester.widget<Text>(find.byKey(const Key('dealBadge_deviation'))).data,
        'Rẻ hơn trung bình 7.3%',
      );
      // 4 mốc giá (AC 1.1) — format VND số nguyên qua CurrencyFormatter.
      expect(find.byKey(const Key('dealBadge_current')), findsOneWidget);
      expect(find.byKey(const Key('dealBadge_avg')), findsOneWidget);
      expect(find.byKey(const Key('dealBadge_min')), findsOneWidget);
      expect(find.byKey(const Key('dealBadge_previous')), findsOneWidget);
      expect(find.text('38.000đ'), findsWidgets); // current + min
      expect(find.text('41.000đ'), findsOneWidget); // avg
      expect(find.text('40.000đ'), findsOneWidget); // previous
      // Dòng gợi ý tự nhiên (AC 1.7).
      expect(
        find.text('Nếu bạn đang cần mua trong tuần này, đây là mức giá khá tốt.'),
        findsOneWidget,
      );
    });

    testWidgets('GIÁ CAO: chip đỏ, % lệch, gợi ý chờ/so cửa hàng (AC 1.3/1.8)',
        (tester) async {
      await _pumpCard(tester, _summary(latest: 45000, avg: 40000));

      expect(find.text('GIÁ CAO'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('dealBadge_deviation'))).data,
        'Đắt hơn trung bình 12.5%',
      );
      expect(
        find.text(
            'Giá đang cao hơn mức thường thấy — cân nhắc chờ hoặc so cửa hàng khác.'),
        findsOneWidget,
      );
    });

    testWidgets('GIÁ BÌNH THƯỜNG (đủ dữ liệu): KHÔNG có % lệch nổi bật (AC 1.4/1.9)',
        (tester) async {
      await _pumpCard(tester, _summary(latest: 40500, avg: 40000));

      expect(find.text('GIÁ BÌNH THƯỜNG'), findsOneWidget);
      // AC 1.4: mức bình thường → không hiển thị % lệch lớn nổi bật.
      expect(find.byKey(const Key('dealBadge_deviation')), findsNothing);
      expect(
        find.text('Giá ở mức tương đương trung bình các lần mua trước.'),
        findsOneWidget,
      );
    });
  });

  group('DealBadgeCard — thiếu dữ liệu', () {
    testWidgets('đúng 1 record → GIÁ BÌNH THƯỜNG + note, previous thành "—" (AC 1.5)',
        (tester) async {
      await _pumpCard(tester, _summary(latest: 25000, avg: 25000, records: 1));

      expect(find.byKey(const Key('dealBadge_card')), findsOneWidget);
      expect(find.text('GIÁ BÌNH THƯỜNG'), findsOneWidget);
      expect(find.text('Chưa đủ dữ liệu để đánh giá giá'), findsOneWidget);
      expect(find.byKey(const Key('dealBadge_deviation')), findsNothing);
      expect(find.text('—'), findsOneWidget); // không có lần mua trước
    });
  });

  group('ItemDetailSheet tích hợp Deal Badge (AC 1.6)', () {
    testWidgets('item CÓ history (≥2 records) → sheet hiển thị Deal Badge card',
        (tester) async {
      await _pumpSheet(tester, summary: _summary(latest: 38000, avg: 41000));
      expect(find.byKey(const Key('dealBadge_card')), findsOneWidget);
      expect(find.text('DEAL TỐT'), findsOneWidget);
      // Sheet vẫn render form sửa nhanh bình thường.
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
      expect(find.byKey(const Key('itemDetailSheet_saveButton')), findsOneWidget);
    });

    testWidgets('item KHÔNG có price history → KHÔNG hiển thị card (AC 1.6)',
        (tester) async {
      await _pumpSheet(tester, summary: null);
      expect(find.byKey(const Key('dealBadge_card')), findsNothing);
      expect(find.byKey(const Key('itemDetailSheet')), findsOneWidget);
    });
  });
}
