import '../core/network/api_client.dart';
import '../models/item_model.dart';

/// Nguồn gốc vật phẩm — whitelist `ITEM_SOURCES` của backend.
/// `source` bất biến sau khi tạo (BR-05) → update không bao giờ gửi field này.
const itemSources = <String>['manual', 'ocr', 'barcode', 'import'];

/// Trường sắp xếp hợp lệ của GET /items (`ITEM_SORT_FIELDS` backend).
const itemSortFields = <String>['purchase_date', 'price', 'name', 'created_at'];

/// Điểm toạ độ — shape `location` của backend (latitude/longitude/accuracy_meters).
class ItemLocation {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  const ItemLocation({required this.latitude, required this.longitude, this.accuracyMeters});

  Map<String, dynamic> toJson() => {
    'latitude':  latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
  };
}

/// Payload tạo item — khớp `CreateItemDto` backend (snake_case khi toJson).
///
/// `purchaseDate` không truyền → mặc định "bây giờ" (flow thêm item hiện tại
/// chưa có picker ngày). `categoryId` bỏ trống → server tự auto-classify (BR-04).
class ItemPayload {
  final String  name;
  final int     price;
  final int?    quantity;
  final String? unit;
  final String? categoryId;
  final String? imageUrl;
  final String? note;
  final String? storeName;
  final ItemLocation? location;
  final DateTime? purchaseDate;
  final String? source;   // một giá trị trong [itemSources], mặc định server tự điền 'manual'
  final String? barcode;

  const ItemPayload({
    required this.name,
    required this.price,
    this.quantity,
    this.unit,
    this.categoryId,
    this.imageUrl,
    this.note,
    this.storeName,
    this.location,
    this.purchaseDate,
    this.source,
    this.barcode,
  });

  Map<String, dynamic> toJson() => {
    'name':  name,
    'price': price,
    if (quantity   != null) 'quantity':      quantity,
    if (unit       != null) 'unit':          unit,
    if (categoryId != null) 'category_id':   categoryId,
    if (imageUrl   != null) 'image_url':     imageUrl,
    if (note       != null) 'note':          note,
    if (storeName  != null) 'store_name':    storeName,
    if (location   != null) 'location':      location!.toJson(),
    'purchase_date': (purchaseDate ?? DateTime.now()).toUtc().toIso8601String(),
    if (source     != null) 'source':        source,
    if (barcode    != null) 'barcode':       barcode,
  };
}

/// Meta phân trang — shape backend `{ total, page, limit, total_pages, has_next, has_prev }`.
class ItemsPageMeta {
  final int  total;
  final int  page;
  final int  limit;
  final int  totalPages;
  final bool hasNext;
  final bool hasPrev;

  const ItemsPageMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory ItemsPageMeta.fromJson(Map<String, dynamic> j) => ItemsPageMeta(
    total:      (j['total']       as num?)?.toInt() ?? 0,
    page:       (j['page']        as num?)?.toInt() ?? 1,
    limit:      (j['limit']       as num?)?.toInt() ?? 20,
    totalPages: (j['total_pages'] as num?)?.toInt() ?? 0,
    hasNext:    j['has_next'] == true,
    hasPrev:    j['has_prev'] == true,
  );
}

/// Một trang kết quả GET /items — shape backend `{ items, meta }`.
class ItemsPage {
  final List<ItemModel> items;
  final ItemsPageMeta meta;

  const ItemsPage({required this.items, required this.meta});

  factory ItemsPage.fromJson(Map<String, dynamic> j) => ItemsPage(
    items: ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ItemModel.fromApiJson(Map<String, dynamic>.from(e)))
        .toList(),
    meta: ItemsPageMeta.fromJson(Map<String, dynamic>.from((j['meta'] as Map?) ?? const {})),
  );
}

/// Một item fail trong bulk — shape backend `{ index, input, error: { code, message } }`.
class BulkItemFailure {
  final int index;
  final Map<String, dynamic>? input;
  final String code;
  final String message;

  const BulkItemFailure({
    required this.index,
    this.input,
    required this.code,
    required this.message,
  });
}

/// Kết quả POST /items/bulk — tạo từng item độc lập, lỗi không chặn phần tử khác.
class BulkCreateResult {
  final List<ItemModel> created;
  final List<BulkItemFailure> failed;
  final int totalSubmitted;
  final int totalCreated;
  final int totalFailed;

  const BulkCreateResult({
    required this.created,
    required this.failed,
    required this.totalSubmitted,
    required this.totalCreated,
    required this.totalFailed,
  });

  factory BulkCreateResult.fromJson(Map<String, dynamic> j) {
    final meta = (j['meta'] as Map?) ?? const {};
    return BulkCreateResult(
      created: ((j['created'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ItemModel.fromApiJson(Map<String, dynamic>.from(e)))
          .toList(),
      failed: ((j['failed'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) {
            final err = (e['error'] as Map?) ?? const {};
            return BulkItemFailure(
              index:  (e['index'] as num?)?.toInt() ?? -1,
              input:  e['input'] is Map ? Map<String, dynamic>.from(e['input'] as Map) : null,
              code:   (err['code'] as String?) ?? 'ITEM_CREATE_FAILED',
              message: (err['message'] as String?) ?? '',
            );
          })
          .toList(),
      totalSubmitted: (meta['total_submitted'] as num?)?.toInt() ?? 0,
      totalCreated:   (meta['total_created']   as num?)?.toInt() ?? 0,
      totalFailed:    (meta['total_failed']    as num?)?.toInt() ?? 0,
    );
  }
}

/// Gọi các endpoint /items/* qua [ApiClient].
///
/// Backend domain-API dùng snake_case → mapping sang [ItemModel] nằm ở
/// `ItemModel.fromApiJson`. Mọi endpoint đều cần Bearer token (JwtAuthGuard)
/// → `auth: true` để được 401-refresh-retry của ApiClient.
class ItemApiService {
  final ApiClient _client;

  const ItemApiService(this._client);

  /// GET /items — danh sách có lọc/phân trang/sort (lọc date áp lên purchase_date).
  ///
  /// - [sort] một giá trị trong [itemSortFields]; [order] 'asc' | 'desc'.
  /// - [dateFrom]/[dateTo] gửi ISO 8601 UTC (backend dùng nguyên instant khi
  ///   đầy đủ ngày giờ — tránh phụ thuộc timezone của server).
  /// - Lỗi → ném [ApiException] (caller tự quyết fallback local).
  Future<ItemsPage> fetchItems({
    int page = 1,
    int limit = 20,
    String? sort,
    String? order,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? priceMin,
    int? priceMax,
    String? storeName,
    String? source,
    String? search,
    bool includeDeleted = false,
  }) async {
    final data = await _client.get('/items', auth: true, query: {
      'page':  '$page',
      'limit': '$limit',
      if (sort != null)          'sort':            sort,
      if (order != null)         'order':           order,
      if (categoryId != null)    'category_id':     categoryId,
      if (dateFrom != null)      'date_from':       dateFrom.toUtc().toIso8601String(),
      if (dateTo != null)        'date_to':         dateTo.toUtc().toIso8601String(),
      if (priceMin != null)      'price_min':       '$priceMin',
      if (priceMax != null)      'price_max':       '$priceMax',
      if (storeName != null)     'store_name':      storeName,
      if (source != null)        'source':          source,
      if (search != null)        'search':          search,
      'include_deleted': includeDeleted ? 'true' : 'false',
    });
    return ItemsPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// GET /items/:id → 404 ITEM_NOT_FOUND nếu không tồn tại hoặc đã soft-delete.
  Future<ItemModel> getById(String id) async {
    final data = await _client.get('/items/$id', auth: true);
    return ItemModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// POST /items → 201 item mới (server tự tính `total_price` = price × quantity).
  ///
  /// - [force]=true → `?force=true` bỏ qua duplicate check (409 ITEM_DUPLICATE).
  ///   ApiClient.post không nhận query riêng nên nhúng thẳng vào path
  ///   (Uri.parse tách query chuẩn — cùng cách deleteCategory đã dùng).
  /// - 409 ITEM_DUPLICATE kèm `existing_item_id` trong details → UI hỏi lại.
  /// - 404 ITEM_INVALID_CATEGORY nếu [ItemPayload.categoryId] không tồn tại.
  Future<ItemModel> create(ItemPayload payload, {bool force = false}) async {
    final data = await _client.post(
      force ? '/items?force=true' : '/items',
      auth: true,
      body: payload.toJson(),
    );
    return ItemModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// PATCH /items/:id — cập nhật một phần (ưu tiên hơn PUT vì không cần gửi đủ field).
  ///
  /// `source` bất biến (BR-05) — cố tình không có param; gửi kèm sẽ bị
  /// backend ValidationPipe từ chối 400. Đổi `categoryId` → server ghi nhận
  /// correction để cải thiện auto-classify.
  Future<ItemModel> update(
    String id, {
    String? name,
    int? price,
    int? quantity,
    String? unit,
    String? categoryId,
    String? imageUrl,
    String? note,
    String? storeName,
    ItemLocation? location,
    DateTime? purchaseDate,
    String? barcode,
  }) async {
    final data = await _client.patch('/items/$id', auth: true, body: {
      if (name        != null) 'name':         name,
      if (price       != null) 'price':        price,
      if (quantity    != null) 'quantity':     quantity,
      if (unit        != null) 'unit':         unit,
      if (categoryId  != null) 'category_id':  categoryId,
      if (imageUrl    != null) 'image_url':    imageUrl,
      if (note        != null) 'note':         note,
      if (storeName   != null) 'store_name':   storeName,
      if (location    != null) 'location':     location.toJson(),
      if (purchaseDate != null) 'purchase_date': purchaseDate.toUtc().toIso8601String(),
      if (barcode     != null) 'barcode':      barcode,
    });
    return ItemModel.fromApiJson(Map<String, dynamic>.from(data as Map));
  }

  /// DELETE /items/:id → 204 (soft delete), body rỗng.
  Future<void> delete(String id) async {
    await _client.delete('/items/$id', auth: true);
  }

  /// POST /items/bulk — tối đa 50 item (throttle 5 req/phút ở backend).
  /// `[storeName]`/`[location]` áp chung cho item không khai báo riêng.
  Future<BulkCreateResult> bulkCreate(
    List<ItemPayload> items, {
    String? storeName,
    ItemLocation? location,
  }) async {
    final data = await _client.post('/items/bulk', auth: true, body: {
      'items': items.map((e) => e.toJson()).toList(),
      if (storeName != null) 'store_name': storeName,
      if (location  != null) 'location':   location.toJson(),
    });
    return BulkCreateResult.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
