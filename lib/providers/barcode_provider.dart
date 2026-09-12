import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/barcode_contribute_service.dart';
import 'auth_provider.dart';

/// Service gọi /barcode/contribute (Wave 6) — tái sử dụng ApiClient chung.
final barcodeContributeServiceProvider = Provider<BarcodeContributeService>((ref) {
  return BarcodeContributeService(ref.watch(apiClientProvider));
});
