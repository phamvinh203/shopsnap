import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../widgets/ui/ui.dart';

/// Section chọn ảnh vật phẩm — InkWell có ripple, style từ tokens,
/// options sheet dùng AppBottomSheet chuẩn.
class ImagePickerSection extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onImagePicked;

  const ImagePickerSection({required this.imagePath, required this.onImagePicked, super.key});

  Future<void> _pick(BuildContext ctx, ImageSource source) async {
    final picker = ImagePicker();
    final xFile  = await picker.pickImage(
      source: source,
      maxWidth:  1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (xFile != null) onImagePicked(xFile.path);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;
    final colors = context.snap;
    return Material(
      color: hasImage ? context.cs.surface : colors.tintPrimary,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showOptions(context),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: hasImage
              ? Stack(fit: StackFit.expand, children: [
                  Image.file(File(imagePath!), fit: BoxFit.cover),
                  Positioned(
                    top: AppSpacing.sm, right: AppSpacing.sm,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onImagePicked(null),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: colors.onTintPrimary, size: 40),
                  const SizedBox(height: 10),
                  Text('Chụp ảnh vật phẩm',
                      style: context.text.labelLarge
                          ?.copyWith(color: colors.onTintPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _SourceBtn(
                      icon: Icons.camera_alt_outlined, label: 'Camera',
                      onTap: () => _pick(context, ImageSource.camera),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _SourceBtn(
                      icon: Icons.photo_library_outlined, label: 'Thư viện',
                      onTap: () => _pick(context, ImageSource.gallery),
                    ),
                  ]),
                ]),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      title: 'Chụp ảnh vật phẩm',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: context.cs.primary),
            title: const Text('Chụp ảnh mới'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(context, ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: context.cs.primary),
            title: const Text('Chọn từ thư viện'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(context, ImageSource.gallery);
            },
          ),
          if (imagePath != null)
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.snap.danger),
              title: Text('Xoá ảnh', style: TextStyle(color: context.snap.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                onImagePicked(null);
              },
            ),
        ],
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _SourceBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: colors.onTintPrimary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: colors.onTintPrimary),
          ),
        ]),
      ),
    );
  }
}
