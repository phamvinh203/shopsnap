import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/core/utils/receipt_auto_match.dart';

/// M-1 — F-#5 Phase 2 Auto-Match: unit test logic thuần
/// `receipt_auto_match.dart`, map 1-1 ranh giới spec:
/// - AC 5.15: nhánh tên normalize + giá ±10% (dùng lại tolerance p1).
/// - AC 5.16: nhánh barcode (ưu tiên tên), inert khi barcode vắng.
/// - AC 5.17: tên rác ≤ 2 ký tự / giá ≤ 0 → chặn tuyệt đối.
/// - AC 5.18: record trong cửa sổ trùng ≤ 7 ngày → KHÔNG auto-match.
/// - AC 5.20: threshold constant một nơi (0.80) + điểm nhánh 1.0/0.85.
void main() {
  final now = DateTime(2026, 9, 15, 12, 0);

  PriceHistoryMatchRecord rec(
    String name,
    int price, {
    int daysAgo = 40,
    String? barcode,
  }) =>
      PriceHistoryMatchRecord(
        name: name,
        price: price,
        barcode: barcode,
        purchasedAt: now.subtract(Duration(days: daysAgo)),
      );

  group('constants — AC 5.20 (threshold một nơi, không hardcode rải rác)', () {
    test('ngưỡng auto-match = 0.80, điểm nhánh barcode = 1.0, tên = 0.85', () {
      expect(AppConstants.receiptAutoMatchConfidence, 0.80);
      expect(kReceiptAutoMatchBarcodeConfidence, 1.0);
      expect(kReceiptAutoMatchNameConfidence, 0.85);
    });

    test('dùng lại constant khung có sẵn: 90 ngày / ±10% / cửa sổ trùng 7 ngày',
        () {
      expect(AppConstants.priceHistoryDays, 90);
      expect(AppConstants.receiptDuplicatePriceTolerance, 0.10);
      expect(AppConstants.receiptDuplicateWindowDays, 7);
    });

    test('grep: literal 0.80/0.85 trong lib/ chỉ ở AppConstants, matcher và '
        'các file budget có TRƯỚC (domain khác, baseline — không phải auto-match)',
        () {
      final regex = RegExp(r'0\.8[05]');
      // File được phép chứa literal: 2 vị trí designated của AC 5.20 + các
      // file budget ngưỡng 80% có sẵn từ trước baseline (budgetWarnRatio).
      const allowed = {
        'lib/core/constants/app_constants.dart',
        'lib/core/utils/receipt_auto_match.dart',
        'lib/core/theme/snap_colors.dart',
        'lib/core/utils/budget_alert.dart',
        'lib/models/budget_model.dart',
      };
      final offenders = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll('\\', '/');
        if (regex.hasMatch(f.readAsStringSync()) && !allowed.contains(path)) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty);
    });

    test('matcher khai báo điểm nhánh ở đúng một chỗ (không rải literal)', () {
      final src =
          File('lib/core/utils/receipt_auto_match.dart').readAsStringSync();
      expect(
          RegExp('kReceiptAutoMatchNameConfidence = 0\\.85;').hasMatch(src),
          isTrue);
      expect(
          RegExp('kReceiptAutoMatchBarcodeConfidence = 1\\.0;').hasMatch(src),
          isTrue);
      // Không ai hardcode ngưỡng 0.80 trong matcher — luôn đọc AppConstants.
      expect(src.contains('receiptAutoMatchConfidence'), isTrue);
    });
  });

  group('nhánh tên + giá (AC 5.15)', () {
    test('đúng kịch bản spec: OCR 12.000đ, record 12.500đ cách đây 40 ngày '
        '(ngoài cửa sổ trùng 7 ngày, trong ±10%) → auto-match', () {
      final m = findAutoMatch(
        name: 'Trà Xanh  500ml', // normalize: 'trà xanh 500ml'
        price: 12000,
        history: [rec('trà xanh 500ml', 12500, daysAgo: 40)],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.matchedName, 'trà xanh 500ml'); // badge = tên record khớp
      expect(m.matchedPrice, 12500);
      expect(m.matchedBy, AutoMatchBy.name);
      expect(m.confidence, 0.85);
    });

    test('normalize khớp: hoa/thường + khoảng trắng thừa không cản match', () {
      final m = findAutoMatch(
        name: '  SUA TUOI  TRONG 100ml ',
        price: 25000,
        history: [rec('sua tuoi  trong 100ml', 25000, daysAgo: 10)],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('ranh giới giá: lệch đúng ±10% → VẪN match (inclusive như p1)', () {
      expect(
        findAutoMatch(
            name: 'Sữa', price: 11000, history: [rec('sữa', 10000)], now: now),
        isNotNull,
      ); // +10%
      expect(
        findAutoMatch(
            name: 'Sữa', price: 9000, history: [rec('sữa', 10000)], now: now),
        isNotNull,
      ); // −10%
    });

    test('lệch quá ±10% (10% + 1đ) → không match', () {
      expect(
        findAutoMatch(
            name: 'Sữa', price: 11001, history: [rec('sữa', 10000)], now: now),
        isNull,
      );
    });

    test('ranh giới cửa sổ 90 ngày: đúng 90 ngày → match; 90 ngày + 1 phút → hết',
        () {
      expect(
        findAutoMatch(
            name: 'Sữa',
            price: 10000,
            history: [rec('sữa', 10000, daysAgo: 90)],
            now: now),
        isNotNull,
      );
      final tooOld = PriceHistoryMatchRecord(
        name: 'sữa',
        price: 10000,
        purchasedAt: now.subtract(const Duration(days: 90, minutes: 1)),
      );
      expect(
        findAutoMatch(name: 'Sữa', price: 10000, history: [tooOld], now: now),
        isNull,
      );
    });

    test('nhiều record khớp → lấy MỚI NHẤT (pattern AC 5.3)', () {
      final m = findAutoMatch(
        name: 'Trứng',
        price: 30000,
        history: [
          rec('trứng', 30000, daysAgo: 80),
          rec('trứng', 29500, daysAgo: 15),
          rec('trứng', 29000, daysAgo: 50),
        ],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.matchedPrice, 29500); // 15 ngày — mới nhất
    });

    test('record history giá ≤ 0 → bỏ (không chia 0)', () {
      expect(
        findAutoMatch(
            name: 'Sữa', price: 10000, history: [rec('sữa', 0)], now: now),
        isNull,
      );
    });
  });

  group('nhánh barcode (AC 5.16)', () {
    test('barcode khớp → auto-match BẤKỂ giá lệch bao nhiêu (lệch ~80%)', () {
      final m = findAutoMatch(
        name: 'Mì gói Hảo Hảo',
        price: 18000, // record 10000 — lệch 80%, nhánh tên KHÔNG thể khớp
        barcode: '  8934567890123 ',
        history: [
          rec('mì ăn liền', 10000, daysAgo: 20, barcode: '8934567890123'),
        ],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.matchedBy, AutoMatchBy.barcode);
      expect(m.confidence, 1.0);
      expect(m.matchedName, 'mì ăn liền');
    });

    test('hai nhánh cùng khớp NHƯNG trỏ hai sản phẩm khác nhau → barcode thắng '
        '(kể cả record tên mới hơn)', () {
      final m = findAutoMatch(
        name: 'Nước suối 500ml',
        price: 5000,
        barcode: 'BC001',
        history: [
          // Nhánh tên: khớp normalize + giá, MỚI HƠN record barcode.
          rec('nước suối 500ml', 5100, daysAgo: 10),
          // Nhánh barcode: tên/giá khác hẳn, CŨ hơn.
          rec('bánh quy coco', 25000, daysAgo: 60, barcode: 'BC001'),
        ],
        now: now,
      );
      expect(m, isNotNull);
      expect(m!.matchedBy, AutoMatchBy.barcode);
      expect(m.matchedName, 'bánh quy coco'); // barcode định danh mạnh hơn tên
    });

    test('barcode vắng (null / rỗng / whitespace) → nhánh inert: không crash, '
        'không match do barcode (response chưa có barcode — contract pending)',
        () {
          final history = [
            rec('mì ăn liền', 10000, daysAgo: 20, barcode: '8934567890123'),
          ];
          for (final bc in [null, '', '   ']) {
            final m = findAutoMatch(
              name: 'Mì gói Hảo Hảo', // tên KHÔNG khớp record
              price: 18000,
              barcode: bc,
              history: history,
              now: now,
            );
            expect(m, isNull, reason: 'barcode = $bc');
          }
        });

    test('record chưa có barcode (BE chưa ghi) → chỉ nhánh tên quyết định', () {
      expect(
        findAutoMatch(
          name: 'Sữa',
          price: 10000,
          barcode: 'BC999',
          history: [rec('sữa', 10000, daysAgo: 20)], // barcode null
          now: now,
        )!.matchedBy,
        AutoMatchBy.name,
      );
    });
  });

  group('edge — tên rác / giá rác (AC 5.17)', () {
    test('tên ≤ 2 ký tự sau trim → KHÔNG auto-match DƯỚI BẤT KỂ nhánh nào '
        '(kể cả barcode khớp)', () {
      final history = [
        rec('ab', 10000, daysAgo: 20, barcode: 'BC1'),
      ];
      for (final name in ['ab', 'A ', '  x  ']) {
        expect(
          findAutoMatch(
              name: name, price: 10000, barcode: 'BC1', history: history, now: now),
          isNull,
          reason: 'tên "$name"',
        );
      }
    });

    test('tên đúng 3 ký tự (dài hơn 2) → nhánh barcode vẫn hoạt động', () {
      final m = findAutoMatch(
        name: 'abc',
        price: 10000,
        barcode: 'BC1',
        history: [rec('khác hẳn', 1000, daysAgo: 20, barcode: 'BC1')],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('giá ≤ 0 → chặn cả hai nhánh (kể cả barcode khớp)', () {
      final history = [
        rec('mì ăn liền', 10000, daysAgo: 20, barcode: 'BC1'),
      ];
      for (final price in [0, -15000]) {
        expect(
          findAutoMatch(
              name: 'Mì Hảo Hảo',
              price: price,
              barcode: 'BC1',
              history: history,
              now: now),
          isNull,
          reason: 'giá $price',
        );
      }
    });

    test('sổ giá rỗng / tên không khớp gì → null (đi luồng uncertain p1)',
        () {
      expect(findAutoMatch(name: 'Sữa', price: 10000, history: const [], now: now),
          isNull);
      expect(
        findAutoMatch(
            name: 'Sữa', price: 10000, history: [rec('bánh mì', 10000)], now: now),
        isNull,
      );
    });
  });

  group('precedence — trùng ≤ 7 ngày thắng auto-match (AC 5.18)', () {
    test('record khớp nằm trong cửa sổ trùng đúng 7 ngày → KHÔNG tự tick', () {
      expect(
        findAutoMatch(
            name: 'Sữa',
            price: 10000,
            history: [rec('sữa', 10000, daysAgo: 7)],
            now: now),
        isNull,
      );
    });

    test('7 ngày + 1 phút (hết cửa sổ trùng, còn trong 90 ngày) → auto-match',
        () {
      final m = findAutoMatch(
        name: 'Sữa',
        price: 10000,
        history: [
          PriceHistoryMatchRecord(
            name: 'sữa',
            price: 10000,
            purchasedAt:
                now.subtract(const Duration(days: 7, minutes: 1)),
          ),
        ],
        now: now,
      );
      expect(m, isNotNull);
    });

    test('nhánh barcode cũng bị chặn khi record barcode trong cửa sổ trùng',
        () {
      expect(
        findAutoMatch(
          name: 'Mì Hảo Hảo',
          price: 18000,
          barcode: 'BC1',
          history: [rec('mì ăn liền', 10000, daysAgo: 3, barcode: 'BC1')],
          now: now,
        ),
        isNull,
      );
    });

    test('record "tương lai" (lệch đồng hồ) → coi như trong cửa sổ trùng → bỏ',
        () {
      expect(
        findAutoMatch(
          name: 'Sữa',
          price: 10000,
          history: [
            PriceHistoryMatchRecord(
              name: 'sữa',
              price: 10000,
              purchasedAt: now.add(const Duration(days: 1)),
            ),
          ],
          now: now,
        ),
        isNull,
      );
    });
  });

  group('cơ chế ngưỡng tin cậy (AC 5.20)', () {
    test('điểm nhánh >= ngưỡng mới auto: 0.85 ≥ 0.80 và 1.0 ≥ 0.80 (default)',
        () {
      final history = [rec('sữa', 10000)];
      expect(findAutoMatch(name: 'Sữa', price: 10000, history: history, now: now),
          isNotNull);
    });

    test('ngưỡng override cao hơn điểm nhánh → không auto (cơ chế configurable)',
        () {
      final history = [rec('sữa', 10000)];
      // Nhánh tên 0.85 < ngưỡng 0.90 → bị chặn…
      expect(
        findAutoMatch(
            name: 'Sữa',
            price: 10000,
            history: history,
            now: now,
            minConfidence: 0.90),
        isNull,
      );
      // …nhưng nhánh barcode 1.0 vẫn đạt.
      final bcHistory = [rec('mì', 10000, daysAgo: 20, barcode: 'BC1')];
      expect(
        findAutoMatch(
            name: 'Mì Hảo Hảo',
            price: 50000,
            barcode: 'BC1',
            history: bcHistory,
            now: now,
            minConfidence: 0.90),
        isNotNull,
      );
    });

    test('ngưỡng đúng bằng điểm nhánh tên (0.85) → vẫn auto (>=, inclusive)',
        () {
      expect(
        findAutoMatch(
            name: 'Sữa',
            price: 10000,
            history: [rec('sữa', 10000)],
            now: now,
            minConfidence: 0.85),
        isNotNull,
      );
    });
  });
}
