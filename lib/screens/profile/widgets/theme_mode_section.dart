import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../providers/theme_provider.dart';

/// Mục chọn giao diện (F-#10 — chuyển từ settings sheet cũ sang /profile theo
/// AC 10.6: chỉ MỘT nơi cấu hình appearance): System / Sáng / Tối qua
/// [SegmentedButton], persist qua [themeModeProvider] (SharedPreferences).
///
/// Lịch sử: trước đây widget này là `_ThemeModeSection` private trong
/// main_shell.dart (Phase 4 — dark mode). Keys đổi prefix `shell_` → `profile_`
/// để test bám đúng vị trí mới.
///
/// ConsumerWidget riêng vì trang cha có thể đọc state khác bằng `ref.read`
/// lúc mở (tĩnh), còn lựa chọn theme phải rebuild ngay khi user chạm segment.
class ThemeModeSection extends ConsumerWidget {
  const ThemeModeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull ?? system: khớp wiring ở app.dart cho case prefs chưa load.
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(children: [
            Icon(Icons.palette_outlined, size: 22, color: context.cs.primary),
            const SizedBox(width: AppSpacing.lg),
            Text('Giao diện', style: context.text.titleSmall),
          ]),
        ),
        SegmentedButton<ThemeMode>(
          key: const Key('profile_themeSection'),
          // Key đặt trên Icon (ButtonSegment không nhận key) để test tap
          // theo key thay vì theo text (khuyến nghị memo redesign mục 5).
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined,
                  key: Key('profile_themeOption_system')),
              label: Text('Hệ thống'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined,
                  key: Key('profile_themeOption_light')),
              label: Text('Sáng'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined,
                  key: Key('profile_themeOption_dark')),
              label: Text('Tối'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref
              .read(themeModeProvider.notifier)
              .setMode(selection.first),
        ),
      ],
    );
  }
}
