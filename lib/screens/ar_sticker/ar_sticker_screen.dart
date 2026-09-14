import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/price_sticker_widget.dart';

// ── Data class ────────────────────────────────────────────────────────────────

class _StickerData {
  final String id;
  String label;
  Offset position;
  Color  color;

  _StickerData({
    required this.id,
    required this.label,
    required this.position,
    required this.color,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ArStickerScreen extends StatefulWidget {
  const ArStickerScreen({super.key});

  @override
  State<ArStickerScreen> createState() => _ArStickerScreenState();
}

class _ArStickerScreenState extends State<ArStickerScreen> {
  CameraController? _ctrl;
  bool _initialized = false;
  bool _capturing   = false;

  final _boundaryKey = GlobalKey();
  final _stickers    = <_StickerData>[];

  static const _palette = <Color>[
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    Color(0xFF111827),
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _ctrl = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _ctrl!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      // Simulator or permission denied — show placeholder
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _showAddSheet([_StickerData? editing]) {
    AppBottomSheet.show<void>(
      context: context,
      title: editing != null ? 'Sửa sticker' : 'Thêm sticker',
      builder: (_) => _StickerSheet(
        initialLabel: editing?.label,
        initialColor: editing?.color,
        palette:      _palette,
        onConfirm:    (label, color) {
          setState(() {
            if (editing != null) {
              editing.label = label;
              editing.color = color;
            } else {
              final size = MediaQuery.of(context).size;
              _stickers.add(_StickerData(
                id:       const Uuid().v4(),
                label:    label,
                position: Offset(size.width / 2 - 55, size.height / 2 - 25),
                color:    color,
              ));
            }
          });
        },
      ),
    );
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image    = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/ar_${const Uuid().v4()}.png';
      await File(path).writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) context.pop<String>(path);
    } catch (e) {
      if (mounted) {
        // Không còn 'Lỗi chụp ảnh: $e' raw — microcopy tiếng Việt.
        AppSnackBar.show(
          context: context,
          message: apiErrorMessage(e),
          tone: AppSnackBarTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    if (_ctrl == null || !_initialized) return;
    final next = _ctrl!.value.flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    await _ctrl!.setFlashMode(next);
    setState(() {});
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Camera + sticker composite ──────────────────────────────────────
        RepaintBoundary(
          key: _boundaryKey,
          child: Stack(children: [
            Positioned.fill(child: _cameraOrPlaceholder()),
            ..._stickers.map(_buildDraggable),
          ]),
        ),

        // ── Top bar ─────────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _CircleBtn(icon: Icons.close, onTap: () => context.pop()),
              const Spacer(),
              if (_stickers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md - 2, vertical: 3),
                  margin:  const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color:        context.cs.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_stickers.length} sticker',
                    style: context.text.labelLarge
                        ?.copyWith(fontSize: 11, color: context.cs.onPrimary),
                  ),
                ),
              _CircleBtn(
                icon: _ctrl?.value.flashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                onTap: _toggleFlash,
              ),
            ]),
          ),
        ),

        // ── Hint ────────────────────────────────────────────────────────────
        if (_stickers.isNotEmpty)
          const Positioned(
            bottom: 120,
            left:   0,
            right:  0,
            child: Center(
              child: Text(
                'Kéo để di chuyển · Nhấn giữ để xoá · Nhấn đúp để sửa',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ),

        // ── Bottom toolbar ──────────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleBtn(
                    icon:  Icons.undo,
                    onTap: _stickers.isEmpty
                        ? null
                        : () => setState(() => _stickers.removeLast()),
                  ),
                  // Shutter button
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width:  72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white54, width: 4),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: AppColors.primary),
                            )
                          : const Icon(Icons.camera, color: Colors.black, size: 34),
                    ),
                  ),
                  _CircleBtn(icon: Icons.add_circle_outline, onTap: _showAddSheet),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cameraOrPlaceholder() {
    if (_initialized && _ctrl != null) {
      return CameraPreview(_ctrl!);
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 72),
          SizedBox(height: 12),
          Text(
            'Camera không khả dụng\nThêm sticker để xem preview',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _buildDraggable(_StickerData s) => Positioned(
        left: s.position.dx,
        top:  s.position.dy,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => s.position += d.delta),
          onDoubleTap: ()  => _showAddSheet(s),
          onLongPress: ()  {
            setState(() => _stickers.remove(s));
            AppSnackBar.show(
              context: context,
              message: 'Đã xoá sticker',
              duration: const Duration(seconds: 1),
            );
          },
          child: PriceStickerWidget(label: s.label, color: s.color),
        ),
      );
}

// ── Add/Edit sticker bottom sheet ─────────────────────────────────────────────
// Content-only: handle + title + scroll do AppBottomSheet.show lo (caller).

class _StickerSheet extends StatefulWidget {
  final String?  initialLabel;
  final Color?   initialColor;
  final List<Color> palette;
  final void Function(String label, Color color) onConfirm;

  const _StickerSheet({
    required this.palette,
    required this.onConfirm,
    this.initialLabel,
    this.initialColor,
  });

  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet> {
  late final TextEditingController _ctrl;
  late Color _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl     = TextEditingController(text: widget.initialLabel ?? '');
    _selected = widget.initialColor ?? widget.palette.first;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            key: const Key('arSticker_labelField'),
            controller: _ctrl,
            autofocus: true,
            prefixIcon: Icons.local_offer_outlined,
            hint: 'VD: 45,000đ hoặc -50%',
          ),
          // FIX: trước đây label rỗng thì `return;` im lặng — giờ báo lỗi rõ.
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              key: const Key('arSticker_error'),
              style: context.text.bodySmall
                  ?.copyWith(color: context.snap.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Màu', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.md - 2),
          Row(
            children: widget.palette.map((c) => GestureDetector(
              onTap: () => setState(() => _selected = c),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: AppSpacing.md - 2),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _selected == c
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: _selected == c
                      ? [BoxShadow(color: c.withOpacity(0.7), blurRadius: 10, spreadRadius: 2)]
                      : null,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            key: const Key('arSticker_submitButton'),
            label: widget.initialLabel != null ? 'Cập nhật' : 'Thêm sticker',
            onPressed: _confirm,
          ),
        ],
      );

  void _confirm() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập nội dung sticker');
      return;
    }
    widget.onConfirm(text, _selected);
    Navigator.pop(context);
  }
}

// ── Circle icon button ────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  const _CircleBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width:  46,
          height: 46,
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: onTap == null ? Colors.white24 : Colors.white,
            size:  22,
          ),
        ),
      );
}
