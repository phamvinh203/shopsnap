import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/network/api_client.dart';
import 'export_api_service.dart';

/// Kết quả một lần export thành công — file đã lưu trên máy + metadata để
/// hiển thị tên file và chia sẻ lại trong phiên mà không cần export lần nữa
/// (AC 11.3).
class ExportOutcome {
  final ExportFormat format;

  /// File đã ghi xong trong thư mục Documents của app.
  final File file;

  /// Tên file theo AC 11.2: `shopsnap_export_YYYYMMDD.(csv|json)`.
  String get filename => file.uri.pathSegments.last;

  const ExportOutcome({required this.format, required this.file});
}

/// Orchestrator F-#11: gọi BE `/summary/export` → lưu file vào Documents →
/// share qua system share sheet. UI chỉ cần gọi [exportAndSave] và [share].
///
/// Dependency platform (path_provider / share_plus) được inject qua constructor
/// để unit/widget test không chạm channel thật.
class ExportService {
  final ExportApiService _api;

  /// Thư mục lưu file — mặc định Documents của app (path_provider).
  final Future<Directory> Function() _documentsDir;

  /// Mở system share sheet — mặc định share_plus. Inject trong test để record.
  final Future<void> Function(String path) _sharer;

  ExportService(
    ApiClient client, {
    http.Client? httpClient,
    Future<Directory> Function()? documentsDir,
    Future<void> Function(String path)? sharer,
  })  : _api = ExportApiService(client, httpClient: httpClient),
        _documentsDir = documentsDir ?? _defaultDocumentsDir,
        _sharer = sharer ?? _defaultSharer;

  /// Tên file theo AC 11.2 — `shopsnap_export_YYYYMMDD.(csv|json)` với
  /// YYYYMMDD là NGÀY EXPORT (không phải khoảng dữ liệu) để không đè file cũ
  /// khi xuất chéo tháng.
  static String filenameFor(ExportFormat format, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}';
    return 'shopsnap_export_$stamp.${format.fileExtension}';
  }

  /// Tải dữ liệu từ BE và ghi ra file trong Documents.
  Future<ExportOutcome> exportAndSave({
    required ExportFormat format,
    required String dateFrom,
    required String dateTo,
  }) async {
    final payload = await _api.fetch(
      format: format,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    final dir = await _documentsDir();
    final file = File('${dir.path}/${filenameFor(format, DateTime.now())}');
    // Ghi bytes nguyên vẹn — UTF-8/BOM do ExportApiService đảm bảo.
    await file.writeAsBytes(payload.bytes, flush: true);
    return ExportOutcome(format: format, file: file);
  }

  /// Mở system share sheet cho file đã lưu (AC 11.2/11.3).
  Future<void> share(String path) => _sharer(path);

  static Future<Directory> _defaultDocumentsDir() =>
      getApplicationDocumentsDirectory();

  static Future<void> _defaultSharer(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: null),
    );
  }
}
