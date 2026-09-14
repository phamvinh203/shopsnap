/// Theme mode preference — Phase 4 (dark mode) của UI redesign.
///
/// Đây là UI preference thuần (System / Sáng / Tối), KHÔNG business logic:
/// lưu lựa chọn vào SharedPreferences (key [ThemeModeController.prefKey]),
/// mặc định [ThemeMode.system] khi chưa có lựa chọn.
///
/// Dùng `AsyncNotifier` để đọc prefs đúng 1 lần lúc khởi động; `app.dart`
/// đọc `valueOrNull ?? ThemeMode.system` nên frame đầu tiên luôn render được
/// (system) và tự chuyển sang lựa chọn đã lưu ngay khi load xong — không cần
/// chặn splash.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Điều khiển + persist lựa chọn theme mode của user.
class ThemeModeController extends AsyncNotifier<ThemeMode> {
  /// Key SharedPreferences — cố định để giữ lựa chọn cũ của user giữa các
  /// phiên bản.
  static const prefKey = 'pref_theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(prefKey));
  }

  /// Chọn mode mới: cập nhật state NGAY (MaterialApp đổi theme qua
  /// AnimatedTheme 200ms) rồi persist bất đồng bộ.
  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, encode(mode));
  }

  /// Map giá trị lưu trong prefs → [ThemeMode].
  /// null / 'system' / giá trị lạ → [ThemeMode.system] (an toàn mặc định).
  static ThemeMode decode(String? stored) {
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Map [ThemeMode] → giá trị lưu trong prefs.
  static String encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
