import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/core/utils/receipt_duplicate.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/services/category_classifier.dart';

/// F-#5 P1 — unit test logic thuần:
/// - `findReceiptDuplicate`: ranh giới 7 ngày / ±10% / tên sai lệch nhẹ (AC 5.3).
/// - `bulkBatchLimitError`: chặn > 50 (AC 5.8).
/// - `CategoryClassifier` lớp tự học: gợi ý lại category user đã chọn (AC 5.2).
void main() {
  final now = DateTime(2026, 9, 15, 12, 0);

  ReceiptHistoryEntry entry(
    String name,
    int price, {
    int daysAgo = 1,
  }) =>
      ReceiptHistoryEntry(
        name: name,
        price: price,
        purchasedAt: now.subtract(Duration(days: daysAgo)),
      );

  group('findReceiptDuplicate — ranh giới thời gian (AC 5.3)', () {
    test('khớp tên + giá trong cửa sổ 7 ngày → match', () {
      final m = findReceiptDuplicate(
        name: 'Cà phê sữa',
        price: 25000,
        existing: [entry('Cà phê sữa', 25000, daysAgo: 3)],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.matchedName, 'Cà phê sữa');
      expect(m.matchedPrice, 25000);
    });

    test('đúng 7 ngày (ranh giới) → VẪN match (≤ 7 ngày)', () {
      final m = findReceiptDuplicate(
        name: 'Bánh mì',
        price: 15000,
        existing: [entry('Bánh mì', 15000, daysAgo: 7)],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('7 ngày + 1 phút → HẾT cửa sổ → không match', () {
      final justOver = ReceiptHistoryEntry(
        name: 'Bánh mì',
        price: 15000,
        purchasedAt: now.subtract(const Duration(days: 7, minutes: 1)),
      );
      final m = findReceiptDuplicate(
        name: 'Bánh mì',
        price: 15000,
        existing: [justOver],
        now: now,
      );
      expect(m, isNull);
    });

    test('windowDays/tolerance đọc từ AppConstants (7 ngày, 10% — tham số khung)', () {
      expect(AppConstants.receiptDuplicateWindowDays, 7);
      expect(AppConstants.receiptDuplicatePriceTolerance, 0.10);
      expect(AppConstants.receiptBulkMax, 50);
    });
  });

  group('findReceiptDuplicate — ranh giới giá ±10% (AC 5.3)', () {
    test('lệch đúng 10% (25000 → 27500) → VẪN match', () {
      final m = findReceiptDuplicate(
        name: 'Sữa',
        price: 27500,
        existing: [entry('Sữa', 25000)],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.priceDiffRatio, 0.10);
    });

    test('lệch đúng 10% chiều giảm (25000 → 22500) → VẪN match', () {
      final m = findReceiptDuplicate(
        name: 'Sữa',
        price: 22500,
        existing: [entry('Sữa', 25000)],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('lệch 11% (25000 → 27750) → không match', () {
      final m = findReceiptDuplicate(
        name: 'Sữa',
        price: 27750,
        existing: [entry('Sữa', 25000)],
        now: now,
      );
      expect(m, isNull);
    });

    test('item cũ giá 0 → không so được (tránh chia 0) → không match', () {
      final m = findReceiptDuplicate(
        name: 'Quà tặng',
        price: 50000,
        existing: [entry('Quà tặng', 0)],
        now: now,
      );
      expect(m, isNull);
    });

    test('dòng OCR giá 0 (chưa nhập giá) → không match', () {
      final m = findReceiptDuplicate(
        name: 'Sữa',
        price: 0,
        existing: [entry('Sữa', 25000)],
        now: now,
      );
      expect(m, isNull);
    });
  });

  group('findReceiptDuplicate — tên normalize (AC 5.3, cùng chuẩn F-#6)', () {
    test('sai lệch nhẹ: hoa/thường + khoảng trắng thừa → VẪN match', () {
      final m = findReceiptDuplicate(
        name: '  Cà   PHÊ sữa  ',
        price: 25000,
        existing: [entry('cà phê sữa', 25000)],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('tên khác hẳn → không match dù giá khớp', () {
      final m = findReceiptDuplicate(
        name: 'Trà chanh',
        price: 25000,
        existing: [entry('Cà phê sữa', 25000)],
        now: now,
      );
      expect(m, isNull);
    });

    test('tên chứa một phần (match một phần) → KHÔNG match (chỉ khớp chính xác)', () {
      final m = findReceiptDuplicate(
        name: 'Cà phê sữa đá',
        price: 25000,
        existing: [entry('Cà phê sữa', 25000)],
        now: now,
      );
      expect(m, isNull);
    });

    test('tên dòng OCR rỗng/toàn space → không match', () {
      final m = findReceiptDuplicate(
        name: '   ',
        price: 25000,
        existing: [entry('Cà phê sữa', 25000)],
        now: now,
      );
      expect(m, isNull);
    });
  });

  group('findReceiptDuplicate — nhiều item khớp (AC 5.3)', () {
    test('trùng nhiều item → so với item MỚI NHẤT', () {
      final m = findReceiptDuplicate(
        name: 'Mì gói',
        price: 5000,
        existing: [
          entry('Mì gói', 5000, daysAgo: 6), // cũ hơn
          entry('Mì gói', 5000, daysAgo: 2), // mới nhất
        ],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.purchasedAt, now.subtract(const Duration(days: 2)));
      expect(m.matchedName, 'Mì gói');
    });
  });

  group('receiptEntriesFromItems', () {
    test('map ItemModel → entry với purchasedAt = createdAt', () {
      final ms = DateTime(2026, 9, 10).millisecondsSinceEpoch;
      final item = ItemModel(
        id: 'i1',
        name: 'Khăn giấy',
        price: 12000,
        categoryId: 'cat_other',
        categoryName: '',
        categoryIcon: '',
        categoryColor: '',
        createdAt: ms,
        updatedAt: ms,
      );
      final entries = receiptEntriesFromItems([item]);
      expect(entries.single.name, 'Khăn giấy');
      expect(entries.single.price, 12000);
      expect(entries.single.purchasedAt, DateTime(2026, 9, 10));
    });
  });

  group('bulkBatchLimitError — chặn > 50 TRƯỚC khi gọi API (AC 5.8)', () {
    test('50 dòng → hợp lệ (null)', () {
      expect(bulkBatchLimitError(50), isNull);
    });

    test('51 dòng → message chặn đúng nội dung', () {
      expect(bulkBatchLimitError(51), 'Tối đa 50 món mỗi lần thêm');
    });
  });

  group('CategoryClassifier tự học — AC 5.2', () {
    setUp(CategoryClassifier.resetLearned);

    test('user đổi category cho tên X → lần sau gợi ý lại đúng category đó', () {
      // Ban đầu: rule tĩnh đưa 'Cà phê sữa' vào cat_food.
      expect(CategoryClassifier.classify('Cà phê sữa'), 'cat_food');

      // User chủ động chọn cat_personal → học.
      CategoryClassifier.learn('Cà phê sữa', 'cat_personal');

      expect(CategoryClassifier.suggest('Cà phê sữa'), 'cat_personal');
      expect(CategoryClassifier.suggest('  cà PHÊ   sữa '), 'cat_personal'); // normalize
    });

    test('chưa học gì → suggest = classify (rule tĩnh)', () {
      expect(CategoryClassifier.suggest('quần jean'), 'cat_clothes');
      expect(CategoryClassifier.suggest('blah blah'), 'cat_other');
    });

    test('seedFromHistory: item MỚI NHẤT quyết định (danh sách sắp mới → cũ)', () {
      CategoryClassifier.seedFromHistory(const [
        ('Mì gói', 'cat_other'),  // mới nhất — thắng
        ('Mì gói', 'cat_food'),   // cũ hơn — bị bỏ qua
        ('Trà sữa', 'cat_food'),
      ]);
      expect(CategoryClassifier.suggest('Mì gói'), 'cat_other');
      expect(CategoryClassifier.suggest('Trà sữa'), 'cat_food');
    });

    test('learn ghi đè seed; seed không ghi đè learn', () {
      CategoryClassifier.learn('Bơ đậu phộng', 'cat_personal');
      CategoryClassifier.seedFromHistory(const [('Bơ đậu phộng', 'cat_food')]);
      expect(CategoryClassifier.suggest('Bơ đậu phộng'), 'cat_personal');
    });

    test('input rỗng → bỏ qua, không học rác', () {
      CategoryClassifier.learn('   ', 'cat_food');
      CategoryClassifier.learn('Cà phê', '');
      expect(CategoryClassifier.learnedCategory('Cà phê'), isNull);
      expect(CategoryClassifier.learnedCategory('   '), isNull);
    });
  });
}
