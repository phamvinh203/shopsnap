import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/database/daos/barcode_cache_dao.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/database_provider.dart';
import 'package:shopsnap/services/barcode_contribute_service.dart';
import 'package:shopsnap/services/barcode_service.dart';
import 'package:shopsnap/widgets/ui/ui.dart';
import 'widgets/barcode_contribute_sheet.dart';
import 'widgets/scan_overlay.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _processing     = false;
  bool _torchOn        = false;
  bool _isSuccessFlash = false;
  String? _lastCode;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _onDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final code = barcode.rawValue!;
    if (code == _lastCode || _processing) return;

    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      _processing = true;
      _lastCode = code;
      _isSuccessFlash = true;
    });
    await _controller.stop();

    if (!mounted) return;

    // Show bottom sheet ngay lập tức với skeleton
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResultSheet(barcode: code, controller: _controller),
    ).then((_) {
      if (mounted) setState(() { _processing = false; _lastCode = null; _isSuccessFlash = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera feed
        MobileScanner(controller: _controller, onDetect: _onDetected),
        // Overlay UI
        ScanOverlay(isSuccess: _isSuccessFlash),
        // Top bar
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(children: [
            _CircleBtn(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            // Glossary R14: "Quét mã vạch" thay "Scan barcode".
            const Text('Quét mã vạch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            _CircleBtn(
              icon: Icons.flip_camera_ios_outlined,
              onTap: () => _controller.switchCamera(),
            ),
            const SizedBox(width: AppSpacing.md - 2),
            _CircleBtn(
              icon: _torchOn ? Icons.flash_on : Icons.flash_off,
              onTap: () { _controller.toggleTorch(); setState(() => _torchOn = !_torchOn); },
            ),
          ]),
        )),
        // Hint text
        Positioned(
          bottom: 100,
          left: 0, right: 0,
          child: Column(children: [
            const Text('Đưa barcode vào khung để quét', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () => _showManualInput(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md - 2),
                decoration: BoxDecoration(
                  // Chip hướng dẫn = nền ink @60% (4.6); scan screen luôn
                  // nằm trên camera nên giữ đen/bạchkim, không theo theme.
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.keyboard_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    'Nhập mã thủ công',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.5,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        // Processing indicator
        if (_processing)
          Center(child: CircularProgressIndicator(color: context.cs.primary)),
      ]),
    );
  }

  void _showManualInput(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nhập mã barcode'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '8935024130016...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.isNotEmpty) {
                _onDetected(BarcodeCapture(barcodes: [Barcode(rawValue: ctrl.text)]));
              }
            },
            child: const Text('Tìm kiếm'),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet kết quả ───────────────────────────────────────────────────
class _ResultSheet extends ConsumerStatefulWidget {
  final String barcode;
  final MobileScannerController controller;
  const _ResultSheet({required this.barcode, required this.controller});
  @override
  ConsumerState<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends ConsumerState<_ResultSheet> {
  BarcodeResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final cacheDao = BarcodeCacheDao(db);
      final result = await BarcodeService.lookup(widget.barcode, cacheDao: cacheDao);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (_) {
      final result = await BarcodeService.lookup(widget.barcode);
      if (mounted) setState(() { _result = result; _loading = false; });
    }
  }

  /// Wave 6 — mở sheet đóng góp dữ liệu cho mã không tìm thấy.
  /// Thành công → snackbar cảm ơn (kèm message server) rồi đóng sheet kết quả,
  /// vẫn trả barcode về add_item (kèm cờ `contributed`) để tiếp tục nhập tay.
  Future<void> _contribute() async {
    final contributed = await showModalBottomSheet<BarcodeContribution>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeContributeSheet(barcode: widget.barcode),
    );
    if (contributed == null || !mounted) return;

    AppSnackBar.show(
      context: context,
      message: contributed.message.isEmpty
          ? 'Cảm ơn bạn đã đóng góp!'
          : 'Cảm ơn bạn đã đóng góp! ${contributed.message}',
      tone: AppSnackBarTone.success,
      duration: const Duration(seconds: 3),
    );
    Navigator.pop(context, {'barcode': widget.barcode, 'contributed': true});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_loading) ...[
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: AppSpacing.md),
          Text('Đang tìm sản phẩm...', style: context.text.bodySmall),
        ] else if (_result == null) ...[
          Icon(Icons.search_off, size: 48, color: context.cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text('Không tìm thấy sản phẩm', style: context.text.titleMedium),
          Text('Barcode: ${widget.barcode}',
              style: context.text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            key: const Key('scanSheet_manualInputButton'),
            label: 'Nhập thủ công',
            onPressed: () => Navigator.pop(context, {'barcode': widget.barcode}),
          ),
          // Wave 6 — đóng góp dữ liệu cho mã chưa có (ẩn khi chưa đăng nhập:
          // endpoint cần JWT, không hiện hint thừa cho khách vãng lai)
          if (ref.watch(authStateProvider).value?.isAuthenticated == true)
            TextButton.icon(
              onPressed: _contribute,
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
              label: const Text('Đóng góp thông tin'),
            ),
        ] else ...[
          Icon(Icons.check_circle, color: colors.success, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(_result!.productName,
              style: context.text.titleMedium, textAlign: TextAlign.center),
          if (_result!.brand != null)
            Text(_result!.brand!, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.xs + 2),
          Chip(
            avatar: Icon(
              _result!.source == BarcodeSource.localHistory
                  ? Icons.offline_pin_outlined
                  : (_result!.source == BarcodeSource.openFoodFacts
                      ? Icons.public
                      : Icons.cloud_done_outlined),
              size: 16,
              color: context.cs.primary,
            ),
            label: Text(
              _result!.source == BarcodeSource.localHistory
                  ? 'Đã lưu Offline'
                  : (_result!.source == BarcodeSource.openFoodFacts
                      ? 'Open Food Facts'
                      : 'ShopSnap Cloud'),
              style: context.text.labelLarge?.copyWith(fontSize: 11),
            ),
            backgroundColor: colors.tintPrimary,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: SecondaryButton(
                onPressed: () {
                  widget.controller.start();
                  Navigator.pop(context);
                },
                label: 'Quét lại',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                onPressed: () => Navigator.pop(context, {
                  'name':        _result!.productName,
                  'barcode':     widget.barcode,
                  'category_id': _result!.categoryId,
                }),
                label: 'Xác nhận',
              ),
            ),
          ]),
        ],
        const SizedBox(height: AppSpacing.sm),
      ]),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
