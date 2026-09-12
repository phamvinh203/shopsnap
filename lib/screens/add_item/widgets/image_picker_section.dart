import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';

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
    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color:        AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        ),
        child: imagePath != null
            ? Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(File(imagePath!), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => onImagePicked(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 40),
                const SizedBox(height: 10),
                const Text('Chụp ảnh vật phẩm',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _SourceBtn(
                    icon: Icons.camera_alt_outlined, label: 'Camera',
                    onTap: () => _pick(context, ImageSource.camera),
                  ),
                  const SizedBox(width: 12),
                  _SourceBtn(
                    icon: Icons.photo_library_outlined, label: 'Thư viện',
                    onTap: () => _pick(context, ImageSource.gallery),
                  ),
                ]),
              ]),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.divider, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Chụp ảnh mới'),
              onTap: () { Navigator.pop(context); _pick(context, ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Chọn từ thư viện'),
              onTap: () { Navigator.pop(context); _pick(context, ImageSource.gallery); },
            ),
            if (imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Xoá ảnh', style: TextStyle(color: AppColors.danger)),
                onTap: () { Navigator.pop(context); onImagePicked(null); },
              ),
          ]),
        ),
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
    ]),
  );
}
