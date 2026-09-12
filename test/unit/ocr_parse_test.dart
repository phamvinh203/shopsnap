import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/services/ocr_service.dart';

void main() {
  group('OcrService.parsePrice', () {
    test('parses plain integer', () {
      expect(OcrService.parsePrice('25000'), 25000);
    });

    test('parses dot-separated thousands', () {
      expect(OcrService.parsePrice('25.000'), 25000);
    });

    test('parses comma-separated thousands', () {
      expect(OcrService.parsePrice('25,000'), 25000);
    });

    test('parses k suffix (lowercase)', () {
      expect(OcrService.parsePrice('25k'), 25000);
    });

    test('parses K suffix (uppercase)', () {
      expect(OcrService.parsePrice('25K'), 25000);
    });

    test('strips đ suffix', () {
      expect(OcrService.parsePrice('50000đ'), 50000);
    });

    test('returns 0 for non-numeric input', () {
      expect(OcrService.parsePrice('abc'), 0);
    });

    test('parses large price with VND', () {
      expect(OcrService.parsePrice('1.500.000 VND'), 1500000);
    });
  });

  group('OcrService.parseLines', () {
    test('returns empty list when no price lines', () {
      final items = OcrService.parseLines(['XIN CHÀO', 'CẢM ƠN QUÝ KHÁCH', '-----']);
      expect(items, isEmpty);
    });

    test('parses a single item line', () {
      final items = OcrService.parseLines(['Cà phê sữa 25000']);
      expect(items.length, 1);
      expect(items.first.name.toLowerCase(), contains('cà phê sữa'));
      expect(items.first.price, 25000);
    });

    test('skips lines matching total keywords', () {
      final items = OcrService.parseLines([
        'Bánh mì 15000',
        'Tổng cộng 15000',
      ]);
      expect(items.length, 1);
      expect(items.first.name.toLowerCase(), contains('bánh mì'));
    });

    test('parses quantity prefix "2x"', () {
      final items = OcrService.parseLines(['2x Bánh mì 30000']);
      expect(items.length, 1);
      expect(items.first.quantity, 2);
    });

    test('sets needsReview true for price above 10 million', () {
      final items = OcrService.parseLines(['Laptop 15000000']);
      expect(items.first.needsReview, isTrue);
    });

    test('skips lines with price <= 0', () {
      final items = OcrService.parseLines(['Tên sản phẩm 0']);
      expect(items, isEmpty);
    });

    test('assigns categoryId via CategoryClassifier', () {
      final items = OcrService.parseLines(['Cà phê đen 25000']);
      expect(items.first.categoryId, 'cat_food');
    });
  });

  group('OcrService.extractTotal', () {
    test('extracts total from "Tổng" line', () {
      final total = OcrService.extractTotal(['Bánh mì 15000', 'Tổng cộng: 15000']);
      expect(total, 15000);
    });

    test('extracts total from "total" (English)', () {
      final total = OcrService.extractTotal(['Item 10000', 'Total: 10000']);
      expect(total, 10000);
    });

    test('returns null when no total line', () {
      final total = OcrService.extractTotal(['Bánh mì 15000', 'Cà phê 25000']);
      expect(total, isNull);
    });
  });

  group('OcrService.assessQuality', () {
    test('returns poor when items is empty', () {
      expect(OcrService.assessQuality([], 'some text'), OcrQuality.poor);
    });

    test('returns good when 2+ items with no review flags', () {
      final items = [
        OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food'),
        OcrItem(name: 'Bánh mì', price: 15000, categoryId: 'cat_food'),
      ];
      expect(OcrService.assessQuality(items, 'text'), OcrQuality.good);
    });

    test('returns fair when any item needs review', () {
      final items = [
        OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food'),
        OcrItem(name: 'X', price: 20000000, categoryId: 'cat_other', needsReview: true),
      ];
      expect(OcrService.assessQuality(items, 'text'), OcrQuality.fair);
    });

    test('returns fair for single item without review flag', () {
      final items = [OcrItem(name: 'Cà phê', price: 25000, categoryId: 'cat_food')];
      expect(OcrService.assessQuality(items, 'text'), OcrQuality.fair);
    });
  });
}
