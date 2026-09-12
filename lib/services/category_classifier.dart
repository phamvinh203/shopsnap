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
}
