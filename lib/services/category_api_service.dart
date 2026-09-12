import '../core/network/api_client.dart';
import '../models/category_model.dart';

/// Một lựa chọn trong `alternatives` của suggest — shape backend:
/// `{ "category_id": ..., "confidence": ... }`.
class CategoryAlternative {
  final String categoryId;
  final double confidence;

  const CategoryAlternative({required this.categoryId, required this.confidence});
}

/// Kết quả GET /categories/suggest — khớp shape `data` của backend.
/// Không match nào → backend trả fallback `{ suggested_category_id: 'cat_other',
/// confidence: 0, alternatives: [] }` (đã verify bằng curl).
class CategorySuggestion {
  final String suggestedCategoryId;
  final double confidence;
  final List<CategoryAlternative> alternatives;

  const CategorySuggestion({
    required this.suggestedCategoryId,
    required this.confidence,
    this.alternatives = const [],
  });

  /// Fallback (confidence 0) → không đáng tin để auto chọn category cho user.
  bool get isMeaningful => confidence > 0;

  factory CategorySuggestion.fromJson(Map<String, dynamic> j) => CategorySuggestion(
    suggestedCategoryId: j['suggested_category_id'] as String? ?? 'cat_other',
    confidence:          (j['confidence'] as num?)?.toDouble() ?? 0,
    alternatives: (((j['alternatives'] as List?) ?? const [])
            .whereType<Map>()
            .map((a) => CategoryAlternative(
                  categoryId: a['category_id'] as String? ?? '',
                  confidence: (a['confidence'] as num?)?.toDouble() ?? 0,
                ))
            .toList()),
  );
}

/// Gọi các endpoint /categories/* qua [ApiClient].
///
/// Backend domain-API dùng snake_case → mapping sang [CategoryModel] nằm ở
/// `CategoryModel.fromApiJson`. Tất cả endpoint đều cần Bearer token
/// (JwtAuthGuard) → `auth: true` để được 401-refresh-retry của ApiClient.
class CategoryApiService {
  final ApiClient _client;

  const CategoryApiService(this._client);

  /// GET /categories?include_deleted=false&include_stats=... → `{ items, meta }`.
  /// `includeStats=true` chỉ thêm item_count/total_spent vào từng item.
  Future<List<CategoryModel>> fetchCategories({bool includeStats = false}) async {
    final data = await _client.get('/categories', auth: true, query: {
      'include_deleted': 'false',
      'include_stats':   includeStats ? 'true' : 'false',
    });
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((j) => CategoryModel.fromApiJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /categories/suggest?name=<tên item> → gợi ý category.
  /// Ném [ApiException] nếu lỗi (caller tự quyết định fallback local).
  Future<CategorySuggestion> suggestCategory(String name) async {
    final data = await _client.get(
      '/categories/suggest',
      auth: true,
      query: {'name': name},
    );
    return CategorySuggestion.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// POST /categories → 201 category mới (id UUID của server).
  /// 409 CATEGORY_DUPLICATE_NAME nếu tên trùng (case-insensitive).
  Future<CategoryModel> createCategory({
    required String name,
    required String color,
    required String icon,
    String? description,
    String? parentId,
    int? sortOrder,
  }) async {
    final data = await _client.post('/categories', auth: true, body: {
      'name':  name,
      'color': color,
      'icon':  icon,
      if (description != null) 'description': description,
      if (parentId != null)    'parent_id':    parentId,
      if (sortOrder != null)   'sort_order':   sortOrder,
    });
    return CategoryModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// PUT /categories/:id — mọi field tuỳ chọn (category default bị chặn 422).
  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? color,
    String? icon,
    String? description,
    String? parentId,
    int? sortOrder,
  }) async {
    final data = await _client.put('/categories/$id', auth: true, body: {
      if (name != null)        'name':        name,
      if (color != null)       'color':       color,
      if (icon != null)        'icon':        icon,
      if (description != null) 'description': description,
      if (parentId != null)    'parent_id':   parentId,
      if (sortOrder != null)   'sort_order':  sortOrder,
    });
    return CategoryModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// DELETE /categories/:id?reassign_to=<id> → 204 (body rỗng).
  ///
  /// - Category còn item mà không truyền [reassignTo] → 422 CATEGORY_HAS_ITEMS.
  /// - Category default → 422 CATEGORY_DEFAULT_IMMUTABLE.
  ///
  /// ApiClient.delete không nhận query riêng nên nhúng thẳng vào path
  /// (Uri.parse tách query chuẩn; encode để an toàn với ký tự lạ).
  Future<void> deleteCategory(String id, {String? reassignTo}) async {
    final path = reassignTo == null
        ? '/categories/$id'
        : '/categories/$id?reassign_to=${Uri.encodeQueryComponent(reassignTo)}';
    await _client.delete(path, auth: true);
  }
}
