import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/services/category_classifier.dart';

void main() {
  group('CategoryClassifier.classify', () {
    test('returns cat_other for empty string', () {
      expect(CategoryClassifier.classify(''), 'cat_other');
    });

    test('returns cat_other for whitespace only', () {
      expect(CategoryClassifier.classify('   '), 'cat_other');
    });

    test('classifies cà phê as cat_food', () {
      expect(CategoryClassifier.classify('Cà Phê Sữa'), 'cat_food');
    });

    test('classifies bánh mì as cat_food (multi-word wins over bánh)', () {
      expect(CategoryClassifier.classify('Bánh Mì Thịt'), 'cat_food');
    });

    test('classifies phở as cat_food', () {
      expect(CategoryClassifier.classify('Phở Bò'), 'cat_food');
    });

    test('classifies coffee (English) as cat_food', () {
      expect(CategoryClassifier.classify('Iced Coffee Large'), 'cat_food');
    });

    test('classifies áo as cat_clothes', () {
      expect(CategoryClassifier.classify('Áo Thun Trắng'), 'cat_clothes');
    });

    test('classifies giày as cat_clothes', () {
      expect(CategoryClassifier.classify('Giày Sneaker Nike'), 'cat_clothes');
    });

    test('classifies thắt lưng as cat_clothes (multi-word)', () {
      expect(CategoryClassifier.classify('Thắt Lưng Da'), 'cat_clothes');
    });

    test('classifies điện thoại as cat_tech (multi-word)', () {
      expect(CategoryClassifier.classify('Điện Thoại iPhone 15'), 'cat_tech');
    });

    test('classifies tai nghe as cat_tech', () {
      expect(CategoryClassifier.classify('Tai Nghe AirPods'), 'cat_tech');
    });

    test('classifies laptop as cat_tech', () {
      expect(CategoryClassifier.classify('Laptop MacBook Pro'), 'cat_tech');
    });

    test('classifies móc khóa as cat_souvenir', () {
      expect(CategoryClassifier.classify('Móc Khóa Đà Lạt'), 'cat_souvenir');
    });

    test('classifies serum as cat_personal', () {
      expect(CategoryClassifier.classify('Serum Vitamin C'), 'cat_personal');
    });

    test('returns cat_other for unknown item', () {
      expect(CategoryClassifier.classify('Bàn gỗ thông'), 'cat_other');
    });

    test('matching is case-insensitive', () {
      expect(CategoryClassifier.classify('CÀ PHÊ'), 'cat_food');
    });
  });
}
