import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File testImageFile;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'mock_access_token',
      'auth_refresh_token': 'mock_refresh_token',
    });

    tempDir = await Directory.systemTemp.createTemp('ocr_vision_test_');
    testImageFile = File('${tempDir.path}/test_receipt.jpg');
    // Ghi một số bytes mẫu đại diện cho ảnh
    await testImageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OcrService.parseReceiptWithVision', () {
    test('gọi POST /ocr/scan-vision và parse thành công kết quả từ Gemini AI Vision', () async {
      http.Request? capturedRequest;

      final mockHttp = MockClient((req) async {
        capturedRequest = req;
        final responseData = {
          'success': true,
          'data': {
            'store_name': 'Siêu Thị WinMart+',
            'purchase_date': '2026-09-13T10:30:00.000Z',
            'items': [
              {
                'name': 'Sữa chua Vinamilk nha đam',
                'price': 32000,
                'quantity': 2,
                'total_price': 64000,
                'category_id': 'cat_food',
                'confidence': 0.95,
                'needs_review': false,
              },
              {
                'name': 'Nước xả vải Comfort 800ml',
                'price': 58000,
                'quantity': 1,
                'total_price': 58000,
                'category_id': 'cat_household',
                'confidence': 0.92,
                'needs_review': false,
              },
            ],
            'total_from_receipt': 122000,
            'tax_amount': 0,
            'discount_amount': 0,
            'source': 'gemini_vision',
          },
        };

        return http.Response(
          jsonEncode(responseData),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(client: mockHttp);

      final result = await OcrService.parseReceiptWithVision(
        testImageFile.path,
        apiClient: apiClient,
      );

      // Verify request được gửi đúng
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/v1/ocr/scan-vision');
      final reqBody = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(reqBody['imageBase64'], isNotEmpty);
      expect(reqBody['mimeType'], 'image/jpeg');

      // Verify kết quả bóc tách
      expect(result.source, OcrSource.geminiVision);
      expect(result.storeName, 'Siêu Thị WinMart+');
      expect(result.purchaseDate, isNotNull);
      expect(result.purchaseDate!.year, 2026);
      expect(result.purchaseDate!.month, 9);
      expect(result.totalFromReceipt, 122000);
      expect(result.quality, OcrQuality.good);

      // Verify items
      expect(result.items.length, 2);
      final item1 = result.items[0];
      expect(item1.name, 'Sữa chua Vinamilk nha đam');
      expect(item1.price, 32000);
      expect(item1.quantity, 2);
      expect(item1.totalPrice, 64000);
      expect(item1.categoryId, 'cat_food');
      expect(item1.storeName, 'Siêu Thị WinMart+');

      final item2 = result.items[1];
      expect(item2.name, 'Nước xả vải Comfort 800ml');
      expect(item2.price, 58000);
      expect(item2.quantity, 1);
      expect(item2.categoryId, 'cat_household');
    });

    test('loại bỏ items có price <= 0 hoặc name rỗng từ response Gemini', () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'store_name': 'Co.opmart',
              'purchase_date': null,
              'items': [
                {
                  'name': 'Gạo thơm ST25 5kg',
                  'price': 185000,
                  'quantity': 1,
                  'total_price': 185000,
                  'category_id': 'cat_food',
                },
                {
                  'name': '',
                  'price': 20000,
                },
                {
                  'name': 'Mục không có giá',
                  'price': 0,
                },
              ],
              'total_from_receipt': 185000,
              'source': 'gemini_vision',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttp);

      final result = await OcrService.parseReceiptWithVision(
        testImageFile.path,
        apiClient: apiClient,
      );

      expect(result.source, OcrSource.geminiVision);
      expect(result.storeName, 'Co.opmart');
      expect(result.items.length, 1);
      expect(result.items.first.name, 'Gạo thơm ST25 5kg');
      expect(result.items.first.price, 185000);
    });
  });
}
