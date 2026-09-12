import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/services/category_api_service.dart';

/// Wave 2 — mapping JSON backend (snake_case) ↔ CategoryModel + shape suggest.
void main() {
  group('CategoryModel.fromApiJson', () {
    test('parse JSON backend đầy đủ (snake_case, created_at ISO 8601, có stats)', () {
      final cat = CategoryModel.fromApiJson({
        'id': 'cat_food',
        'name': 'Ăn uống',
        'color': '#FF6B6B',
        'icon': '🍜',
        'description': null,
        'is_default': true,
        'parent_id': null,
        'sort_order': 1,
        'item_count': 1,
        'total_spent': 32000,
        'created_at': '2026-09-12T18:45:41.933Z',
        'updated_at': '2026-09-12T19:28:10.721Z',
        'deleted_at': null,
      });
      expect(cat.id, 'cat_food');
      expect(cat.name, 'Ăn uống');
      expect(cat.isDefault, isTrue);
      expect(cat.sortOrder, 1);
      expect(cat.createdAt,
          DateTime.utc(2026, 9, 12, 18, 45, 41, 933).millisecondsSinceEpoch);
      expect(cat.itemCount, 1);
      expect(cat.totalSpent, 32000);
      expect(cat.parentId, isNull);
      expect(cat.description, isNull);
    });

    test('thiếu stats/field tuỳ chọn → null + fallback an toàn', () {
      final cat = CategoryModel.fromApiJson({'id': 'x', 'name': 'X'});
      expect(cat.icon, '🛍️');
      expect(cat.color, '#6C63FF');
      expect(cat.isDefault, isFalse);
      expect(cat.sortOrder, 0);
      expect(cat.createdAt, 0);
      expect(cat.itemCount, isNull);
      expect(cat.totalSpent, isNull);
    });

    test('toMap (sqflite) vẫn đúng 7 cột gốc — không phá schema', () {
      final cat = CategoryModel.fromApiJson({
        'id': 'cat_other', 'name': 'Khác', 'icon': '📦', 'color': '#DDA0DD',
        'is_default': true, 'sort_order': 6, 'created_at': 0,
      });
      final map = cat.toMap();
      expect(map.keys.toSet(),
          {'id', 'name', 'icon', 'color', 'is_default', 'sort_order', 'created_at'});
      expect(CategoryModel.fromMap(map).id, 'cat_other');
      expect(CategoryModel.fromMap(map).isDefault, isTrue);
    });
  });

  group('CategorySuggestion.fromJson', () {
    test('shape backend có alternatives', () {
      final s = CategorySuggestion.fromJson({
        'suggested_category_id': 'cat_food',
        'confidence': 0.87,
        'alternatives': [
          {'category_id': 'cat_personal', 'confidence': 0.1},
        ],
      });
      expect(s.suggestedCategoryId, 'cat_food');
      expect(s.confidence, 0.87);
      expect(s.alternatives.single.categoryId, 'cat_personal');
      expect(s.isMeaningful, isTrue);
    });

    test('fallback backend (cat_other, confidence 0) → isMeaningful false', () {
      final s = CategorySuggestion.fromJson({
        'suggested_category_id': 'cat_other',
        'confidence': 0,
        'alternatives': [],
      });
      expect(s.suggestedCategoryId, 'cat_other');
      expect(s.isMeaningful, isFalse);
    });
  });
}
