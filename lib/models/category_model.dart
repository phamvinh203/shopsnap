class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool   isDefault;
  final int    sortOrder;
  final int    createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.sortOrder,
    required this.createdAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
    id:        m['id'] as String,
    name:      m['name'] as String,
    icon:      m['icon'] as String,
    color:     m['color'] as String,
    isDefault: (m['is_default'] as int) == 1,
    sortOrder: m['sort_order'] as int,
    createdAt: m['created_at'] as int,
  );

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
