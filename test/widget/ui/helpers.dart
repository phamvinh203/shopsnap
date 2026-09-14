import 'package:flutter/material.dart';
import 'package:shopsnap/core/theme/app_theme.dart';

/// Wrap với theme CỦA APP (buildAppTheme light) — theo QA plan mục 3.7:
/// widget test mới phải set theme tường minh, không phụ thuộc mặc định.
Widget wrapWithAppTheme(Widget child) {
  return MaterialApp(theme: buildAppTheme(), home: Scaffold(body: child));
}

/// Wrap với theme CỦA APP ở chế độ dark.
Widget wrapWithDarkTheme(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    home: Scaffold(body: child),
  );
}

/// Wrap BARE `MaterialApp` (không qua buildAppTheme) — đảm bảo fallback
/// `?? SnapColors.light()` trong `context.snap` hoạt động, không crash.
Widget wrapBare(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
