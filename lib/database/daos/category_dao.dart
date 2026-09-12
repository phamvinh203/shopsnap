import 'package:sqflite/sqflite.dart';
import '../../models/category_model.dart';

class CategoryDao {
  final Database db;
  CategoryDao(this.db);

  Future<List<CategoryModel>> findAll() async {
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel?> findById(String id) async {
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CategoryModel.fromMap(rows.first);
  }

  Future<void> insert(CategoryModel cat) async {
    await db.insert('categories', cat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Upsert hàng loạt khi sync từ API (Wave 2) — 1 transaction cho nhanh.
  /// Row trùng id bị đè (server category trùng slug default seed local).
  Future<void> upsertAll(List<CategoryModel> cats) async {
    if (cats.isEmpty) return;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert('categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(CategoryModel cat) async {
    await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<void> delete(String id) async {
    await db.delete('categories', where: 'id = ? AND is_default = 0', whereArgs: [id]);
  }
}
