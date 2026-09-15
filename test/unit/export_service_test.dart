import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/services/export_api_service.dart';
import 'package:shopsnap/services/export_service.dart';

/// F-#11 — ExportApiService + ExportService với MockClient (pattern của
/// summary_api_service_test). File thật được ghi vào temp dir của test runner
/// (inject `_documentsDir` vào ExportService) để verify bytes trên đĩa.
///
/// LƯU Ý: http.Response(String) mặc định latin1 khi không khai báo charset →
/// handler mock trả body tiếng Việt luôn kèm header '...; charset=utf-8'.

http.Response csvBody({bool withBom = true, int status = 200}) {
  const content = 'id,name,price\r\n1,Cà phê sữa,30000\r\n';
  final body = (withBom ? '\uFEFF' : '') + content;
  return http.Response(body, status, headers: {
    'content-type': 'text/csv; charset=utf-8',
  });
}

http.Response jsonResponse(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response errorJson(String code, String message, {int status = 400}) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message, 'timestamp': 'x'},
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUpAll(() async {
    // TokenStorage mặc định dùng SharedPreferences → mock trong unit test.
    SharedPreferences.setMockInitialValues({});
  });

  group('ExportApiService (GET /summary/export)', () {
    test('AC 11.5: CSV thiếu BOM từ server → client tự chèn UTF-8 BOM', () async {
      late Uri captured;
      final client = MockClient((req) async {
        captured = req.url;
        return csvBody(withBom: false);
      });
      final service = ExportApiService(ApiClient(client: client), httpClient: client);

      final payload = await service.fetch(
        format: ExportFormat.csv,
        dateFrom: '2026-09-01',
        dateTo: '2026-09-15',
      );

      // Query params đúng contract BE.
      expect(captured.path, endsWith('/summary/export'));
      expect(captured.queryParameters['format'], 'csv');
      expect(captured.queryParameters['date_from'], '2026-09-01');
      expect(captured.queryParameters['date_to'], '2026-09-15');

      final bytes = payload.bytes;
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
      // Nội dung tiếng Việt giữ nguyên sau BOM. LƯU Ý: `utf8.decode` của Dart
      // TỰ STRIP BOM đầu chuỗi (vì vậy assert BOM phải bằng bytes) — đây cũng
      // là lý do service giữ bytes nguyên vẹn thay vì đi qua decode/encode.
      final text = utf8.decode(bytes);
      expect(text, contains('Cà phê sữa'));
      // Không chèn BOM lặp: ngay sau BOM đầu là chữ 'i' (id...), không phải EF BB BF.
      expect(bytes[3], 0x69); // 'i' của 'id,name...'
    });

    test('AC 11.5: CSV đã có BOM từ server → giữ nguyên, không chèn thêm',
        () async {
      final client = MockClient((req) async => csvBody(withBom: true));
      final service = ExportApiService(ApiClient(client: client), httpClient: client);

      final payload = await service.fetch(
        format: ExportFormat.csv,
        dateFrom: '2026-09-01',
        dateTo: '2026-09-15',
      );

      final bytes = payload.bytes;
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
      expect(bytes[3], 0x69,
          reason: 'BOM không bị nhân đôi — ngay sau BOM là header CSV');
    });

    test('AC 11.6: JSON trả bytes NGUYÊN body của BE (envelope không bị bóc)',
        () async {
      const items = [
        {'id': 'i1', 'name': 'Cà phê', 'price': 30000},
      ];
      final client = MockClient((req) async {
        return jsonResponse({'items': items});
      });
      final service = ExportApiService(ApiClient(client: client), httpClient: client);

      final payload = await service.fetch(
        format: ExportFormat.json,
        dateFrom: '2026-09-01',
        dateTo: '2026-09-15',
      );

      final decoded = jsonDecode(utf8.decode(payload.bytes)) as Map;
      // Schema khớp 100% /summary/export: { success, data: { items } }.
      expect(decoded['success'], true);
      expect((decoded['data'] as Map)['items'], items);
    });

    test('AC 11.4: BE trả lỗi 4xx/5xx → ApiException với message rõ ràng',
        () async {
      final client = MockClient((req) async => errorJson(
            'SUMMARY_DATE_RANGE_TOO_LARGE',
            'Tối đa 366 ngày.',
            status: 400,
          ));
      final service = ExportApiService(ApiClient(client: client), httpClient: client);

      await expectLater(
        service.fetch(
          format: ExportFormat.csv,
          dateFrom: '2020-01-01',
          dateTo: '2026-09-15',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('AC 11.4: mất mạng (SocketException) → ApiException.network', () async {
      final client = MockClient((req) async => throw Exception('socket'));
      final service = ExportApiService(ApiClient(client: client), httpClient: client);

      await expectLater(
        service.fetch(
          format: ExportFormat.csv,
          dateFrom: '2026-09-01',
          dateTo: '2026-09-15',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')),
      );
    });
  });

  group('ExportService (lưu file + share)', () {
    late Directory tempDir;
    final sharedPaths = <String>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('shopsnap_export_test');
      sharedPaths.clear();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    ExportService buildService(http.Client client) => ExportService(
          ApiClient(client: client),
          httpClient: client,
          documentsDir: () async => tempDir,
          sharer: (path) async => sharedPaths.add(path),
        );

    test('AC 11.2: tên file dạng shopsnap_export_YYYYMMDD.(csv|json)', () {
      final name =
          ExportService.filenameFor(ExportFormat.csv, DateTime(2026, 9, 15));
      expect(name, 'shopsnap_export_20260915.csv');

      final json =
          ExportService.filenameFor(ExportFormat.json, DateTime(2026, 9, 5));
      expect(json, 'shopsnap_export_20260905.json');
    });

    test('AC 11.2: exportAndSave ghi file vào Documents và share path đó',
        () async {
      final client = MockClient((req) async => csvBody(withBom: true));
      final service = buildService(client);

      final outcome = await service.exportAndSave(
        format: ExportFormat.csv,
        dateFrom: '2026-09-01',
        dateTo: '2026-09-15',
      );

      // File tồn tại, tên theo AC 11.2, nội dung giữ BOM.
      expect(outcome.file.existsSync(), isTrue);
      expect(outcome.filename, matches(RegExp(r'^shopsnap_export_\d{8}\.csv$')));
      final bytes = outcome.file.readAsBytesSync();
      expect(bytes[0], 0xEF);

      await service.share(outcome.file.path);
      expect(sharedPaths, [outcome.file.path]);
    });

    test('AC 11.3: share lại dùng đúng path đã lưu (không cần export lần nữa)',
        () async {
      final client = MockClient((req) async => jsonResponse({'items': []}));
      final service = buildService(client);

      final outcome = await service.exportAndSave(
        format: ExportFormat.json,
        dateFrom: '2026-09-01',
        dateTo: '2026-09-15',
      );
      expect(outcome.filename, matches(RegExp(r'^shopsnap_export_\d{8}\.json$')));

      await service.share(outcome.file.path);
      await service.share(outcome.file.path);
      expect(sharedPaths.length, 2,
          reason: 'share lại không tăng số lần gọi BE');
    });
  });
}
