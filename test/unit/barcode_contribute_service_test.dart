import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/services/barcode_contribute_service.dart';

/// Wave 6 — BarcodeContributeService với ApiClient mock (MockClient của
/// package:http). Shape 201/400 verify bằng curl trực tiếp lên backend:
/// - 201: `{ success, data: { id, status: 'pending_review', message } }`
/// - 400: shape Nest mặc định `{ message: [...], error, statusCode }` —
///   KHÔNG có code `BARCODE_INVALID` (ValidationPipe không custom).
///
/// LƯU Ý: http.Response(String) mặc định latin1 khi không có content-type
/// json trong headers — body tiếng Việt làm encoder ném lỗi ngay trong
/// handler mock → ApiClient biến thành NETWORK_ERROR. Header
/// 'application/json; charset=utf-8' vừa ép encode utf8 vừa để `res.body`
/// decode ngược đúng utf8.
http.Response okJson(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// Body lỗi 400 chuẩn của ValidationPipe mặc định (message dạng mảng).
http.Response validationError(List<String> messages) => http.Response(
    jsonEncode({'message': messages, 'error': 'Bad Request', 'statusCode': 400}),
    400,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() async {
    // TokenStorage mặc định dùng SharedPreferences → cần mock trong unit test
    SharedPreferences.setMockInitialValues({});
  });

  group('contribute (POST /barcode/contribute)', () {
    test('201 → parse { id, status, message }, body snake_case + Bearer token', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'access-1', 'auth_refresh_token': 'refresh-1',
      });
      final urls    = <Uri>[];
      final bodies  = <Map<String, dynamic>>[];
      final headers = <Map<String, String>>[];
      final service = BarcodeContributeService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        headers.add(req.headers);
        return okJson({
          'id': 'ctb-1',
          'status': 'pending_review',
          'message': 'Thank you for contributing. Your submission will be reviewed.',
        }, status: 201);
      })));

      final result = await service.contribute(
        barcode:    '8934673123456',
        name:       'Sữa tươi Vinamilk 1L',
        format:     'ean13',
        brand:      'Vinamilk',
        categoryId: 'cat_food',
        price:      28000,
        storeName:  'Co.opmart',
      );

      expect(urls.single.path, endsWith('/barcode/contribute'));
      expect(headers.single['Authorization'], 'Bearer access-1'); // auth: true
      expect(headers.single['Content-Type'], contains('charset=utf-8'));
      expect(bodies.single, {
        'barcode': '8934673123456',
        'name': 'Sữa tươi Vinamilk 1L',
        'format': 'ean13',
        'brand': 'Vinamilk',
        'category_id': 'cat_food',
        'price': 28000,
        'store_name': 'Co.opmart',
      });

      expect(result.id, 'ctb-1');
      expect(result.status, 'pending_review');
      expect(result.message, contains('Thank you'));
    });

    test('chỉ field bắt buộc → body đúng { barcode, name }, không gửi optional', () async {
      Map<String, dynamic>? body;
      final service = BarcodeContributeService(ApiClient(client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return okJson({'id': 'ctb-2', 'status': 'pending_review', 'message': 'ok'}, status: 201);
      })));

      await service.contribute(barcode: '12345', name: 'Đóng góp tối thiểu');

      expect(body!.keys.toSet(), {'barcode', 'name'});
    });

    test('400 shape Nest (không có code BARCODE_INVALID) → message gộp tiếng Anh', () async {
      final service = BarcodeContributeService(ApiClient(client: MockClient((req) async {
        return validationError(['barcode must be longer than or equal to 4 characters']);
      })));

      // Lưu ý: ApiException.fromBody ưu tiên chuỗi `error` của Nest ('Bad
      // Request') làm code — chính là behavior thật đã verify bằng curl.
      expect(
        () => service.contribute(barcode: '12', name: 'Mã quá ngắn'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'Bad Request')
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', contains('4 characters'))),
      );
    });

    test('401 → refresh đúng 1 lần rồi retry với token mới, persist lại', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'expired-a', 'auth_refresh_token': 'old-r',
      });

      var contributeCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return okJson({'accessToken': 'new-a', 'refreshToken': 'new-r'});
        }
        contributeCalls++;
        if (contributeCalls == 1) {
          return http.Response(
              jsonEncode({'message': 'Unauthorized', 'statusCode': 401}), 401,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        // Retry phải mang token mới sau refresh
        expect(req.headers['Authorization'], 'Bearer new-a');
        return okJson({
          'id': 'ctb-3', 'status': 'pending_review',
          'message': 'Thank you for contributing. Your submission will be reviewed.',
        }, status: 201);
      });

      final client  = ApiClient(client: mock);
      final service = BarcodeContributeService(client);

      final result = await service.contribute(barcode: '99999999999TEST', name: 'Sau refresh');

      expect(contributeCalls, 2); // gốc + retry đúng 1 lần
      expect(result.id, 'ctb-3');
      expect((await client.storage.readTokens())!.accessToken, 'new-a');
    });
  });

  group('guessBarcodeFormat', () {
    test('độ dài chuẩn toàn chữ số → ean8/upca/ean13', () {
      expect(guessBarcodeFormat('12345678'), 'ean8');
      expect(guessBarcodeFormat('012345678912'), 'upca');
      expect(guessBarcodeFormat('8934673123456'), 'ean13');
    });

    test('có chữ cái hoặc độ dài lạ → null (bỏ trống, khỏi đoán bừa)', () {
      expect(guessBarcodeFormat('99999999999TEST'), isNull);
      expect(guessBarcodeFormat('12345'), isNull);
      expect(guessBarcodeFormat(''), isNull);
    });
  });
}
