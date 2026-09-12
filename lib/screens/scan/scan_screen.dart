import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shopsnap/core/theme/app_colors.dart';
import 'package:shopsnap/services/barcode_service.dart';
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

  bool _processing   = false;
  bool _torchOn      = false;
  String? _lastCode;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _onDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final code = barcode.rawValue!;
    if (code == _lastCode || _processing) return;

    setState(() { _processing = true; _lastCode = code; });
    await _controller.stop();

    if (!mounted) return;

    // Show bottom sheet ngay lập tức với skeleton
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResultSheet(barcode: code, controller: _controller),
    ).then((_) {
      if (mounted) setState(() { _processing = false; _lastCode = null; });
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
        const ScanOverlay(),
        // Top bar
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _CircleBtn(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Text('Scan barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showManualInput(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.keyboard_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Nhập mã thủ công', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
        // Processing indicator
        if (_processing)
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
class _ResultSheet extends StatefulWidget {
  final String barcode;
  final MobileScannerController controller;
  const _ResultSheet({required this.barcode, required this.controller});
  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  BarcodeResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    final result = await BarcodeService.lookup(widget.barcode);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        if (_loading) ...[
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Đang tìm sản phẩm...', style: TextStyle(color: AppColors.textSecondary)),
        ] else if (_result == null) ...[
          const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          const Text('Không tìm thấy sản phẩm', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('Barcode: ${widget.barcode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {'barcode': widget.barcode}),
            child: const Text('Nhập thủ công'),
          ),
        ] else ...[
          const Icon(Icons.check_circle, color: AppColors.success, size: 40),
          const SizedBox(height: 8),
          Text(_result!.productName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center),
          if (_result!.brand != null)
            Text(_result!.brand!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Chip(
            label: Text(_result!.source == BarcodeSource.openFoodFacts ? 'Open Food Facts' : 'ShopSnap DB',
                style: const TextStyle(fontSize: 11)),
            backgroundColor: AppColors.primaryLight,
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.controller.start();
                  Navigator.pop(context);
                },
                child: const Text('Quét lại'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'name':        _result!.productName,
                  'barcode':     widget.barcode,
                  'category_id': _result!.categoryId,
                }),
                child: const Text('Xác nhận'),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 8),
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
      decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
