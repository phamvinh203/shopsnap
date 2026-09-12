import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shopsnap/services/category_classifier.dart';

class OcrItem {
  final String name;
  final int?   quantity;
  final int    price;
  final String categoryId;
  final bool   needsReview; // true = low confidence

  OcrItem({
    required this.name,
    required this.price,
    this.quantity,
    required this.categoryId,
    this.needsReview = false,
  });

  OcrItem copyWith({String? name, int? price, String? categoryId}) => OcrItem(
    name:        name        ?? this.name,
    price:       price       ?? this.price,
    quantity:    quantity,
    categoryId:  categoryId  ?? this.categoryId,
    needsReview: needsReview,
  );
}

class OcrResult {
  final List<OcrItem> items;
  final int?          totalFromReceipt; // Số tổng ghi trên hóa đơn
  final String        rawText;
  final OcrQuality    quality;

  const OcrResult({
    required this.items,
    this.totalFromReceipt,
    required this.rawText,
    required this.quality,
  });
}

enum OcrQuality { good, fair, poor }

class OcrService {
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<OcrResult> parseReceipt(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final recognized = await _recognizer.processImage(inputImage);
    final rawText    = recognized.text;

    if (rawText.trim().isEmpty) {
      return OcrResult(items: [], rawText: rawText, quality: OcrQuality.poor);
    }

    final lines   = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final items   = parseLines(lines);
    final total   = extractTotal(lines);
    final quality = assessQuality(items, rawText);

    return OcrResult(
      items: items, totalFromReceipt: total,
      rawText: rawText, quality: quality,
    );
  }

  // ── Parse từng dòng hóa đơn → OcrItem ────────────────────────────────────
  @visibleForTesting
  static List<OcrItem> parseLines(List<String> lines) {
    final items = <OcrItem>[];

    // Regex nhận diện giá tiền VND: 25.000, 25,000, 25000, 25k
    final priceRx  = RegExp(r'(\d{1,3}(?:[.,]\d{3})*(?:\.\d{1,2})?|\d+)(?:\s*[kK])?(?:\s*đ|\s*VND|\s*vnđ)?$');
    // Dòng tổng cộng — bỏ qua
    final totalRx  = RegExp(r'(tổng|total|cộng|thanh toán|payment)', caseSensitive: false);
    // Dòng là số hoặc ký tự đặc biệt — bỏ qua
    final skipRx   = RegExp(r'^[\d\s\-\*\=\/\.,:]+$');
    // Số lượng đứng đầu: "2x Bánh mì" hoặc "2 Bánh mì"
    final qtyRx    = RegExp(r'^(\d+)\s*[xX\*]\s*(.+)');

    for (final line in lines) {
      if (totalRx.hasMatch(line)) continue;
      if (skipRx.hasMatch(line))  continue;
      if (line.length < 3)        continue;

      final priceMatch = priceRx.firstMatch(line);
      if (priceMatch == null) continue;

      final priceStr = priceMatch.group(0) ?? '';
      final price    = parsePrice(priceStr);
      if (price <= 0) continue;

      // Tên = phần còn lại sau khi bỏ giá
      var name = line.replaceFirst(priceMatch.group(0)!, '').trim();
      if (name.isEmpty) continue;

      int? qty;
      final qtyMatch = qtyRx.firstMatch(name);
      if (qtyMatch != null) {
        qty  = int.tryParse(qtyMatch.group(1)!);
        name = qtyMatch.group(2)!.trim();
      }

      items.add(OcrItem(
        name:        name,
        price:       price,
        quantity:    qty,
        categoryId:  CategoryClassifier.classify(name),
        needsReview: name.length < 3 || price > 10000000,
      ));
    }
    return items;
  }

  @visibleForTesting
  static int parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[đVNDvnd\s]'), '');
    // Handle "k" suffix: 25k = 25000
    if (cleaned.toLowerCase().endsWith('k')) {
      final n = int.tryParse(cleaned.toLowerCase().replaceAll('k', ''));
      return (n ?? 0) * 1000;
    }
    // Remove thousand separators
    final normalized = cleaned.replaceAll(RegExp(r'[.,]'), '');
    return int.tryParse(normalized) ?? 0;
  }

  @visibleForTesting
  static int? extractTotal(List<String> lines) {
    final totalRx = RegExp(r'(tổng|total|cộng|thanh toán)', caseSensitive: false);
    final priceRx = RegExp(r'(\d[\d.,]*)');
    for (final line in lines) {
      if (totalRx.hasMatch(line)) {
        final m = priceRx.allMatches(line).toList();
        if (m.isNotEmpty) return parsePrice(m.last.group(0)!);
      }
    }
    return null;
  }

  @visibleForTesting
  static OcrQuality assessQuality(List<OcrItem> items, String rawText) {
    if (items.isEmpty) return OcrQuality.poor;
    final hasReview = items.any((i) => i.needsReview);
    if (items.length >= 2 && !hasReview) return OcrQuality.good;
    return OcrQuality.fair;
  }

  static void dispose() => _recognizer.close();
}
