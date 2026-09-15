import '../core/utils/price_watch.dart' show normalizeMatchKey;

abstract class CategoryClassifier {
  static const _rules = <String, String>{
    'cà phê': 'cat_food',   'coffee': 'cat_food',    'cafe': 'cat_food',
    'bún':    'cat_food',   'phở':    'cat_food',    'bánh': 'cat_food',
    'trà':    'cat_food',   'nước':   'cat_food',    'ăn':   'cat_food',
    'uống':   'cat_food',   'cơm':    'cat_food',    'mì':   'cat_food',
    'sữa':    'cat_food',   'juice':  'cat_food',    'beer': 'cat_food',
    'snack':  'cat_food',   'kẹo':    'cat_food',    'bánh mì': 'cat_food',

    'áo':     'cat_clothes', 'quần':  'cat_clothes', 'váy':  'cat_clothes',
    'giày':   'cat_clothes', 'dép':   'cat_clothes', 'túi':  'cat_clothes',
    'nón':    'cat_clothes', 'mũ':    'cat_clothes', 'vớ':   'cat_clothes',
    'belt':   'cat_clothes', 'thắt lưng': 'cat_clothes',

    'điện thoại': 'cat_tech', 'phone':  'cat_tech', 'laptop': 'cat_tech',
    'tai nghe':   'cat_tech', 'sạc':    'cat_tech', 'cáp':    'cat_tech',
    'ốp lưng':    'cat_tech', 'usb':    'cat_tech', 'tablet': 'cat_tech',
    'máy':        'cat_tech',

    'móc khóa': 'cat_souvenir', 'lưu niệm': 'cat_souvenir', 'quà': 'cat_souvenir',
    'souvenir': 'cat_souvenir', 'kỷ niệm':  'cat_souvenir',

    'kem':   'cat_personal', 'dầu gội': 'cat_personal', 'sữa tắm': 'cat_personal',
    'nước hoa': 'cat_personal', 'son':  'cat_personal', 'phấn':    'cat_personal',
    'skincare': 'cat_personal', 'serum': 'cat_personal',
  };

  static String classify(String itemName) {
    if (itemName.trim().isEmpty) return 'cat_other';
    final lower = itemName.toLowerCase().trim();
    // Multi-word rules first (longer match wins)
    final sorted = _rules.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sorted) {
      if (lower.contains(key)) return _rules[key]!;
    }
    return 'cat_other';
  }

  // ── F-#5 P1 (AC 5.2): lớp TỰ HỌC từ lựa chọn của user ──────────────────────
  // Map "tên normalize → category" học từ (1) seed lịch sử item local khi mở
  // màn confirm và (2) category user vừa chủ động chọn cho dòng OCR. Chỉ sống
  // trong phiên chạy (in-memory) — phiên sau được seed lại từ SQLite nên hành
  // vi "lần sau OCR ra dòng cùng tên X thì chọn lại category đã chọn" vẫn đúng.
  static final Map<String, String> _learned = <String, String>{};

  /// Học: user chọn [categoryId] cho dòng tên [itemName].
  static void learn(String itemName, String categoryId) {
    final key = normalizeMatchKey(itemName);
    if (key.isEmpty || categoryId.isEmpty) return;
    _learned[key] = categoryId;
  }

  /// Category đã học cho đúng tên này (khớp chính xác sau normalize), hoặc null.
  static String? learnedCategory(String itemName) {
    final key = normalizeMatchKey(itemName);
    if (key.isEmpty) return null;
    return _learned[key];
  }

  /// Gợi ý category cho một dòng: TỰ HỌC (ưu tiên — user/history đã quyết)
  /// → luật tĩnh [classify] → 'cat_other'.
  static String suggest(String itemName) =>
      learnedCategory(itemName) ?? classify(itemName);

  /// Seed từ lịch sử item local (sắp MỚI → CŨ): item mới nhất cùng tên quyết
  /// định category (không ghi đè key đã học trước đó).
  static void seedFromHistory(Iterable<(String name, String categoryId)> entries) {
    for (final (name, categoryId) in entries) {
      final key = normalizeMatchKey(name);
      if (key.isEmpty || categoryId.isEmpty) continue;
      if (_learned.containsKey(key)) continue;
      _learned[key] = categoryId;
    }
  }

  /// Dùng cho test — xoá sạch lớp tự học.
  static void resetLearned() => _learned.clear();
}
