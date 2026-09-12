class ItemModel {
  final String  id;
  final String  name;
  final int     price;
  final String  categoryId;
  final String  categoryName;
  final String  categoryIcon;
  final String  categoryColor;
  final String? imagePath;
  final String? note;
  final String? barcode;
  final double? latitude;
  final double? longitude;
  final String? stickerData;
  final int     createdAt;
  final int     updatedAt;
  final String? serverId;
  final bool    isSynced;
  final bool    isDeleted;

  // ── Field chỉ có ở backend API — sqflite không có cột tương ứng nên
  //    toMap()/fromMap bỏ qua (schema giữ nguyên). Sau khi đọc lại từ DAO
  //    các field này sẽ null — consumer hiện tại không dùng đến. ────────────
  final int?    quantity;      // backend default 1
  final String? unit;          // 'hộp', 'cái', ...
  final int?    totalPrice;    // server-computed: price * quantity (BR-01)
  final String? storeName;
  final String? source;        // manual | ocr | barcode | import
  final int?    purchaseDate;  // ISO 8601 → millisecond int
  final String? imageUrl;      // URL server — KHÔNG nhét vào imagePath (Image.file sẽ lỗi)
  final String? imageThumbnailUrl;
  final double? locationAccuracy;

  const ItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.imagePath,
    this.note,
    this.barcode,
    this.latitude,
    this.longitude,
    this.stickerData,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.isSynced  = false,
    this.isDeleted = false,
    this.quantity,
    this.unit,
    this.totalPrice,
    this.storeName,
    this.source,
    this.purchaseDate,
    this.imageUrl,
    this.imageThumbnailUrl,
    this.locationAccuracy,
  });

  /// Parse từ row sqflite (snake_case, created_at là millisecond int).
  factory ItemModel.fromMap(Map<String, dynamic> m) => ItemModel(
    id:            m['id'] as String,
    name:          m['name'] as String,
    price:         m['price'] as int,
    categoryId:    m['category_id'] as String,
    categoryName:  (m['cat_name']  as String?) ?? '',
    categoryIcon:  (m['cat_icon']  as String?) ?? '📦',
    categoryColor: (m['cat_color'] as String?) ?? '#DDA0DD',
    imagePath:     m['image_path'] as String?,
    note:          m['note']       as String?,
    barcode:       m['barcode']    as String?,
    latitude:      m['latitude']   as double?,
    longitude:     m['longitude']  as double?,
    stickerData:   m['sticker_data'] as String?,
    createdAt:     m['created_at'] as int,
    updatedAt:     m['updated_at'] as int,
    serverId:      m['server_id']  as String?,
    isSynced:      (m['is_synced']  as int? ?? 0) == 1,
    isDeleted:     (m['is_deleted'] as int? ?? 0) == 1,
  );

  /// Parse từ JSON backend GET/POST /items (snake_case, category nhúng dạng
  /// `{ id, name, color, icon }`, purchase_date/created_at ISO 8601).
  ///
  /// - Category lồng → map vào 4 field phẳng (categoryId/Name/Icon/Color) vì
  ///   mọi consumer (ItemCard, history, DAO JOIN) đọc theo dạng phẳng.
  /// - `createdAt` = purchase_date (ngày mua) — home/history nhóm item theo
  ///   ngày qua `created_at` của sqflite, còn `purchaseDate` giữ nguyên vẹn
  ///   cho round-trip với API.
  /// - `image_url`/`image_thumbnail_url` là URL của server → giữ ở field riêng,
  ///   không ghi vào `imagePath` (ItemCard đọc imagePath bằng Image.file).
  factory ItemModel.fromApiJson(Map<String, dynamic> j) {
    final cat = j['category'] is Map ? j['category'] as Map : null;
    final loc = j['location']  is Map ? j['location']  as Map : null;
    final purchaseMs = _isoToMillis(j['purchase_date']);
    return ItemModel(
      id:                 j['id'] as String,
      name:               (j['name'] as String?) ?? '',
      price:              (j['price'] as num?)?.toInt() ?? 0,
      categoryId:         (j['category_id'] as String?) ?? (cat?['id'] as String? ?? ''),
      categoryName:       (cat?['name']  as String?) ?? '',
      categoryIcon:       (cat?['icon']  as String?) ?? '📦',
      categoryColor:      (cat?['color'] as String?) ?? '#DDA0DD',
      imagePath:          null, // server chỉ có URL — ảnh file local do client tự giữ
      note:               j['note'] as String?,
      barcode:            j['barcode'] as String?,
      latitude:           (loc?['latitude']  as num?)?.toDouble(),
      longitude:          (loc?['longitude'] as num?)?.toDouble(),
      stickerData:        null,
      createdAt:          purchaseMs != 0 ? purchaseMs : _isoToMillis(j['created_at']),
      updatedAt:          _isoToMillis(j['updated_at']),
      serverId:           j['id'] as String,
      isSynced:           true,
      isDeleted:          false,
      quantity:           (j['quantity'] as num?)?.toInt(),
      unit:               j['unit'] as String?,
      totalPrice:         (j['total_price'] as num?)?.toInt(),
      storeName:          j['store_name'] as String?,
      source:             j['source'] as String?,
      purchaseDate:       purchaseMs == 0 ? null : purchaseMs,
      imageUrl:           j['image_url'] as String?,
      imageThumbnailUrl:  j['image_thumbnail_url'] as String?,
      locationAccuracy:   (loc?['accuracy_meters'] as num?)?.toDouble(),
    );
  }

  /// ISO 8601 (hoặc millisecond int nếu có) → millisecond int; thiếu → 0.
  static int _isoToMillis(Object? iso) {
    if (iso is int) return iso;
    if (iso is String) return DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  /// Row sqflite — đúng bộ cột hiện có của bảng `items`, không thêm cột mới.
  Map<String, dynamic> toMap() => {
    'id':           id,
    'name':         name,
    'price':        price,
    'category_id':  categoryId,
    'image_path':   imagePath,
    'note':         note,
    'barcode':      barcode,
    'latitude':     latitude,
    'longitude':    longitude,
    'sticker_data': stickerData,
    'created_at':   createdAt,
    'updated_at':   updatedAt,
    'server_id':    serverId,
    'is_synced':    isSynced ? 1 : 0,
    'is_deleted':   isDeleted ? 1 : 0,
  };

  ItemModel copyWith({
    String? name,
    int? price,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    String? imagePath,
    String? note,
    String? barcode,
    double? latitude,
    double? longitude,
    String? stickerData,
    int? createdAt,
    int? updatedAt,
    String? serverId,
    bool? isSynced,
    bool? isDeleted,
  }) => ItemModel(
    id:            id,
    name:          name          ?? this.name,
    price:         price         ?? this.price,
    categoryId:    categoryId    ?? this.categoryId,
    categoryName:  categoryName  ?? this.categoryName,
    categoryIcon:  categoryIcon  ?? this.categoryIcon,
    categoryColor: categoryColor ?? this.categoryColor,
    imagePath:     imagePath     ?? this.imagePath,
    note:          note          ?? this.note,
    barcode:       barcode       ?? this.barcode,
    latitude:      latitude      ?? this.latitude,
    longitude:     longitude     ?? this.longitude,
    stickerData:   stickerData   ?? this.stickerData,
    createdAt:     createdAt     ?? this.createdAt,
    updatedAt:     updatedAt     ?? this.updatedAt,
    serverId:      serverId      ?? this.serverId,
    isSynced:      isSynced      ?? this.isSynced,
    isDeleted:     isDeleted     ?? this.isDeleted,
  );
}
