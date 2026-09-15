/// F-#6: dòng trong Shopping List — offline-first, local-only (sync OUT:
/// whitelist DTO của BE chưa có `shopping_list`, AC 6.17).
///
/// `updatedAt` bắt buộc giữ theo spec để dùng LWW khi sync mở khoá về sau.
class ShoppingListItem {
  final String id;
  final String name;

  /// Barcode (tuỳ chọn) — dùng match sản phẩm theo barcode khi cả hai có.
  final String? barcode;

  /// `true` = đã mua (tick) — AC 6.4.
  final bool checked;

  /// `true` = đang theo dõi giá (Price Watch) — AC 6.12.
  final bool watched;

  /// Tuỳ chọn (AC 6.6) — có thể null.
  final int? quantity;

  /// Giá dự kiến (VND, tuỳ chọn — AC 6.6).
  final int? expectedPrice;

  /// Danh mục tuỳ chọn (AC 6.6); trỏ categories.id, KHÔNG FK cứng để quick-add
  /// không bao giờ vỡ khi category chưa tồn tại local.
  final String? categoryId;

  /// Giá P của lần giảm ĐÃ alert gần nhất — dedup AC 6.15 (mỗi lần giảm chỉ
  /// alert 1 lần). `null` = chưa từng alert.
  final int? lastAlertPrice;

  /// Cờ badge trên entry Shopping List (AC 6.13) — tự clear khi user mở list.
  final bool hasUnseenAlert;

  final int createdAt;
  final int updatedAt;

  const ShoppingListItem({
    required this.id,
    required this.name,
    this.barcode,
    this.checked = false,
    this.watched = false,
    this.quantity,
    this.expectedPrice,
    this.categoryId,
    this.lastAlertPrice,
    this.hasUnseenAlert = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingListItem.fromMap(Map<String, dynamic> m) => ShoppingListItem(
        id: m['id'] as String,
        name: m['name'] as String,
        barcode: m['barcode'] as String?,
        checked: (m['checked'] as int? ?? 0) == 1,
        watched: (m['watched'] as int? ?? 0) == 1,
        quantity: (m['quantity'] as num?)?.toInt(),
        expectedPrice: (m['expected_price'] as num?)?.toInt(),
        categoryId: m['category_id'] as String?,
        lastAlertPrice: (m['last_alert_price'] as num?)?.toInt(),
        hasUnseenAlert: (m['has_unseen_alert'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'checked': checked ? 1 : 0,
        'watched': watched ? 1 : 0,
        'quantity': quantity,
        'expected_price': expectedPrice,
        'category_id': categoryId,
        'last_alert_price': lastAlertPrice,
        'has_unseen_alert': hasUnseenAlert ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  ShoppingListItem copyWith({
    String? name,
    String? barcode,
    bool? checked,
    bool? watched,
    int? quantity,
    int? expectedPrice,
    String? categoryId,
    bool clearQuantity = false,
    bool clearExpectedPrice = false,
    bool clearCategoryId = false,
    bool clearBarcode = false,
    int? lastAlertPrice,
    bool? hasUnseenAlert,
    int? updatedAt,
  }) =>
      ShoppingListItem(
        id: id,
        name: name ?? this.name,
        barcode: clearBarcode ? null : (barcode ?? this.barcode),
        checked: checked ?? this.checked,
        watched: watched ?? this.watched,
        quantity: clearQuantity ? null : (quantity ?? this.quantity),
        expectedPrice:
            clearExpectedPrice ? null : (expectedPrice ?? this.expectedPrice),
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        lastAlertPrice: lastAlertPrice ?? this.lastAlertPrice,
        hasUnseenAlert: hasUnseenAlert ?? this.hasUnseenAlert,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
