import 'item_model.dart';

class CategorySummary {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final int    totalSpent;
  final int    itemCount;

  const CategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.totalSpent,
    required this.itemCount,
  });

  factory CategorySummary.fromMap(Map<String, dynamic> m) => CategorySummary(
    categoryId:    m['category_id']   as String,
    categoryName:  m['category_name'] as String,
    categoryIcon:  m['category_icon'] as String,
    categoryColor: m['category_color'] as String,
    totalSpent:    m['total_spent']   as int,
    itemCount:     m['item_count']    as int,
  );
}

class SummaryModel {
  final DateTime            date;
  final int                 totalSpent;
  final int                 itemCount;
  final List<CategorySummary> categories;
  final List<ItemModel>     items;

  const SummaryModel({
    required this.date,
    required this.totalSpent,
    required this.itemCount,
    required this.categories,
    required this.items,
  });

  static SummaryModel empty(DateTime date) => SummaryModel(
    date: date, totalSpent: 0, itemCount: 0, categories: [], items: [],
  );
}
