import '../core/network/api_client.dart';

/// Các format barcode backend chấp nhận (`BARCODE_FORMATS` của
/// `ContributeBarcodeDto`).
const barcodeContributeFormats = <String>['ean13', 'ean8', 'upca', 'code128', 'qr'];

/// Đoán format từ shape mã vạch để pre-fill — chỉ trả giá trị khi mã toàn chữ
/// số và khớp độ dài chuẩn (backend KHÔNG đối chiếu format với barcode, ghi
/// sai thì dữ liệu đóng góp sai → không chắc chắn thì trả null để bỏ trống).
String? guessBarcodeFormat(String barcode) {
  if (!RegExp(r'^\d+$').hasMatch(barcode)) return null;
  switch (barcode.length) {
    case 8:  return 'ean8';
    case 12: return 'upca';
    case 13: return 'ean13';
    default: return null;
  }
}

/// Kết quả POST /barcode/contribute — shape `{ id, status, message }`.
/// `status` luôn 'pending_review': đóng góp chỉ ghi nhận chờ duyệt,
/// KHÔNG tự sửa dữ liệu lookup của server.
class BarcodeContribution {
  final String id;
  final String status;
  final String message;

  const BarcodeContribution({
    required this.id,
    required this.status,
    required this.message,
  });

  factory BarcodeContribution.fromJson(Map<String, dynamic> j) => BarcodeContribution(
    id:      (j['id']      as String?) ?? '',
    status:  (j['status']  as String?) ?? 'pending_review',
    message: (j['message'] as String?) ?? '',
  );
}

/// Gọi POST /barcode/contribute (Wave 6) — cộng đồng đóng góp dữ liệu barcode.
///
/// Endpoint cần Bearer JWT (`JwtAuthGuard`) → `auth: true` để được
/// 401-refresh-retry của ApiClient. Backend dùng ValidationPipe mặc định nên
/// lỗi 400 trả shape Nest (`message: [...]`) KHÔNG có code riêng kiểu
/// `BARCODE_INVALID` (đã verify bằng curl) → UI dựa vào statusCode, đồng thời
/// validate client-side (barcode 4–30 ký tự, name 1–255, price ≥ 0) để
/// hầu như không chạm 400.
class BarcodeContributeService {
  final ApiClient _client;

  const BarcodeContributeService(this._client);

  /// POST /barcode/contribute → 201 [BarcodeContribution].
  ///
  /// - [barcode] 4–30 ký tự (validate ở UI trước khi gọi).
  /// - [format] một giá trị trong [barcodeContributeFormats], tuỳ chọn.
  /// - Lỗi → ném [ApiException] (caller hiện message tiếng Việt).
  Future<BarcodeContribution> contribute({
    required String barcode,
    required String name,
    String? format,
    String? brand,
    String? categoryId,
    int? price,
    String? storeName,
    String? imageUrl,
  }) async {
    final data = await _client.post('/barcode/contribute', auth: true, body: {
      'barcode': barcode,
      'name':    name,
      if (format     != null) 'format':      format,
      if (brand      != null) 'brand':       brand,
      if (categoryId != null) 'category_id': categoryId,
      if (price      != null) 'price':       price,
      if (storeName  != null) 'store_name':  storeName,
      if (imageUrl   != null) 'image_url':   imageUrl,
    });
    return BarcodeContribution.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
