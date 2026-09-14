import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/providers/theme_provider.dart';

/// Unit test theme provider (Phase 4 — dark mode), mock SharedPreferences
/// cùng pattern với các service test hiện có.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeController — persist lựa chọn theme', () {
    test('decode: null / system / giá trị lạ → system; light/dark đúng', () {
      expect(ThemeModeController.decode(null), ThemeMode.system);
      expect(ThemeModeController.decode('system'), ThemeMode.system);
      expect(ThemeModeController.decode('neon'), ThemeMode.system);
      expect(ThemeModeController.decode('light'), ThemeMode.light);
      expect(ThemeModeController.decode('dark'), ThemeMode.dark);
    });

    test('encode ↔ decode khớp nhau cho cả 3 mode', () {
      for (final mode in ThemeMode.values) {
        expect(
          ThemeModeController.decode(ThemeModeController.encode(mode)),
          mode,
        );
      }
    });

    test('prefs trống → mặc định system sau khi build hoàn tất', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(themeModeProvider.future), ThemeMode.system);
      expect(
        container.read(themeModeProvider).valueOrNull,
        ThemeMode.system,
      );
    });

    test('restore lựa chọn đã lưu (dark) từ SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeController.prefKey: 'dark',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(themeModeProvider.future), ThemeMode.dark);
    });

    test('setMode cập nhật state NGAY và persist vào SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future); // load xong → system

      await container
          .read(themeModeProvider.notifier)
          .setMode(ThemeMode.dark);

      expect(
        container.read(themeModeProvider).valueOrNull,
        ThemeMode.dark,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeController.prefKey), 'dark');
    });

    test('setMode(light) sau khi đã dark → persist đè giá trị cũ', () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeController.prefKey: 'dark',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeController.prefKey), 'light');
    });
  });
}
