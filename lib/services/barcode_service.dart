import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/database/daos/barcode_cache_dao.dart';
import 'package:shopsnap/services/category_classifier.dart';

class BarcodeResult {
  final String  barcode;
  final String  productName;
  final String? brand;
  final String  categoryId;
  final String? imageUrl;
  final BarcodeSource source;

  const BarcodeResult({
    required this.barcode,
    required this.productName,
    this.brand,
    required this.categoryId,
    this.imageUrl,
    required this.source,
  });
}

enum BarcodeSource { localHistory, openFoodFacts, shopSnapServer, notFound }

class BarcodeService {
  // ── Lookup barcode: 3-tier strategy ──────────────────────────────────────
  // Tier 1: local cache & price_history (offline tức thì)
  // Tier 2: Open Food Facts API (toàn cầu, tự động cache)
  // Tier 3: ShopSnap backend /barcode/lookup (tự động cache)

  static Future<BarcodeResult?> lookup(String barcode, {BarcodeCacheDao? cacheDao}) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    // Tier 1: Local SQLite Cache & Price History
    if (cacheDao != null) {
      final cached = await cacheDao.findByBarcode(cleanCode);
      if (cached != null) return cached;
    }

    // Tier 2: Open Food Facts
    final offResult = await _queryOpenFoodFacts(cleanCode);
    if (offResult != null) {
      if (cacheDao != null) {
        await cacheDao.insertOrUpdate(offResult);
      }
      return offResult;
    }

    // Tier 3: ShopSnap backend
    final serverResult = await _queryShopSnapServer(cleanCode);
    if (serverResult != null && cacheDao != null) {
      await cacheDao.insertOrUpdate(serverResult);
    }
    return serverResult;
  }

  static Future<BarcodeResult?> _queryOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final data    = jsonDecode(res.body) as Map<String, dynamic>;
      final status  = data['status'] as int? ?? 0;
      if (status != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final name    = (product['product_name_vi'] as String?)?.trim() ??
                      (product['product_name']    as String?)?.trim() ??
                      (product['abbreviated_product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;

      return BarcodeResult(
        barcode:     barcode,
        productName: name,
        brand:       product['brands'] as String?,
        categoryId:  CategoryClassifier.classify(name),
        imageUrl:    product['image_front_small_url'] as String?,
        source:      BarcodeSource.openFoodFacts,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<BarcodeResult?> _queryShopSnapServer(String barcode) async {
    try {
      final url = Uri.parse('${AppConstants.backendBaseUrl}/barcode/lookup?code=$barcode');
      final res = await http.get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['data'] == null) return null;
      final d = data['data'] as Map<String, dynamic>;

      return BarcodeResult(
        barcode:     barcode,
        productName: d['name'] as String,
        brand:       d['brand'] as String?,
        categoryId:  d['category_id'] as String? ?? CategoryClassifier.classify(d['name'] as String),
        source:      BarcodeSource.shopSnapServer,
      );
    } catch (_) {
      return null;
    }
  }
}
