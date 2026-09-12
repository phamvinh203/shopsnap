class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool   isDefault;
  final int    sortOrder;
  final int    createdAt;

  // ── Field chỉ có ở backend API — không lưu vào sqflite (schema giữ nguyên) ──
  final String? description;
  final String? parentId;

  // ── Stats — chỉ có khi GET /categories?include_stats=true (null nếu chưa có
  //    item nào; backend chỉ trả 2 field này cho category đang có item).
  final int? itemCount;
  final int? totalSpent;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.sortOrder,
    required this.createdAt,
    this.description,
    this.parentId,
    this.itemCount,
    this.totalSpent,
  });

  /// Parse từ row sqflite (snake_case, created_at là millisecond int).
  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
    id:        m['id'] as String,
    name:      m['name'] as String,
    icon:      m['icon'] as String,
    color:     m['color'] as String,
    isDefault: (m['is_default'] as int) == 1,
    sortOrder: m['sort_order'] as int,
    createdAt: m['created_at'] as int,
  );

  /// Parse từ JSON backend GET /categories (snake_case, created_at ISO 8601).
  ///
  /// - `updated_at`/`deleted_at` bỏ qua: sqflite không có cột tương ứng,
  ///   offline DB là nguồn truth cho chế độ offline.
  /// - `item_count`/`total_spent` chỉ xuất hiện khi include_stats=true.
  factory CategoryModel.fromApiJson(Map<String, dynamic> j) => CategoryModel(
    id:          j['id'] as String,
    name:        j['name'] as String,
    icon:        j['icon'] as String? ?? '🛍️',
    color:       j['color'] as String? ?? '#6C63FF',
    isDefault:   j['is_default'] == true || j['is_default'] == 1,
    sortOrder:   (j['sort_order'] as num?)?.toInt() ?? 0,
    createdAt:   _isoToMillis(j['created_at']),
    description: j['description'] as String?,
    parentId:    j['parent_id'] as String?,
    itemCount:   (j['item_count'] as num?)?.toInt(),
    totalSpent:  (j['total_spent'] as num?)?.toInt(),
  );

  /// ISO 8601 (hoặc millisecond int nếu có) → millisecond int cho sqflite.
  static int _isoToMillis(Object? iso) {
    if (iso is int) return iso;
    if (iso is String) return DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() => {
    'id':         id,
    'name':       name,
    'icon':       icon,
    'color':      color,
    'is_default': isDefault ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt,
  };
}
