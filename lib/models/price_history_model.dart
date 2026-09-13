class PriceHistoryPoint {
  final String id;
  final int price;
  final DateTime purchasedAt;
  final String? storeName;

  const PriceHistoryPoint({
    required this.id,
    required this.price,
    required this.purchasedAt,
    this.storeName,
  });

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      id: json['id'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      purchasedAt: json['purchased_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['purchased_at'] as int)
          : DateTime.parse(json['purchased_at'] as String),
      storeName: json['store_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'price': price,
    'purchased_at': purchasedAt.toIso8601String(),
    'store_name': storeName,
  };
}

enum PriceTrend { up, down, stable }

class PriceHistorySummary {
  final String itemName;
  final String? barcode;
  final int latestPrice;
  final int? previousPrice;
  final int minPrice;
  final int maxPrice;
  final int avgPrice;
  final double? priceChangePercent;
  final PriceTrend trend;
  final int totalRecords;
  final List<PriceHistoryPoint> points;

  const PriceHistorySummary({
    required this.itemName,
    this.barcode,
    required this.latestPrice,
    this.previousPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.avgPrice,
    this.priceChangePercent,
    required this.trend,
    required this.totalRecords,
    required this.points,
  });

  factory PriceHistorySummary.fromJson(Map<String, dynamic> json) {
    final rawTrend = json['trend'] as String? ?? 'stable';
    final trend = rawTrend == 'up'
        ? PriceTrend.up
        : rawTrend == 'down'
            ? PriceTrend.down
            : PriceTrend.stable;

    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints
        .map((p) => PriceHistoryPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    return PriceHistorySummary(
      itemName: json['item_name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      latestPrice: (json['latest_price'] as num?)?.toInt() ?? 0,
      previousPrice: (json['previous_price'] as num?)?.toInt(),
      minPrice: (json['min_price'] as num?)?.toInt() ?? 0,
      maxPrice: (json['max_price'] as num?)?.toInt() ?? 0,
      avgPrice: (json['avg_price'] as num?)?.toInt() ?? 0,
      priceChangePercent: (json['price_change_percent'] as num?)?.toDouble(),
      trend: trend,
      totalRecords: (json['total_records'] as num?)?.toInt() ?? points.length,
      points: points,
    );
  }
}

class FrequentTrackedItem {
  final String itemName;
  final String? barcode;
  final int purchaseCount;
  final int latestPrice;
  final DateTime lastPurchasedAt;

  const FrequentTrackedItem({
    required this.itemName,
    this.barcode,
    required this.purchaseCount,
    required this.latestPrice,
    required this.lastPurchasedAt,
  });

  factory FrequentTrackedItem.fromJson(Map<String, dynamic> json) {
    return FrequentTrackedItem(
      itemName: json['item_name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      purchaseCount: (json['purchase_count'] as num?)?.toInt() ?? 1,
      latestPrice: (json['latest_price'] as num?)?.toInt() ?? 0,
      lastPurchasedAt: json['last_purchased_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['last_purchased_at'] as int)
          : DateTime.parse(json['last_purchased_at'] as String),
    );
  }
}
