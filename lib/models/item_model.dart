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
  });

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
}
