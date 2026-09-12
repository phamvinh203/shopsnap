import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/category_dao.dart';
import '../models/category_model.dart';
import 'database_provider.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CategoryDao(db).findAll();
});
