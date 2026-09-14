import 'package:flutter/material.dart';

/// Scaffold + AppBar + SafeArea chuẩn hoá — thay phần khai báo lặp ở ~10 chỗ.
///
/// Không tự gọi provider; [title] là chuỗi tiếng Việt do caller truyền.
class AppScaffold extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;

  /// Widget góc trái (vd nút ✕ đóng form — thay thế nút back mặc định).
  final Widget? leading;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNav;

  /// Mặc định bọc [SafeArea] — các màn muốn tự quản lý inset đặt `false`.
  final bool safeArea;

  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    this.leading,
    required this.body,
    this.floatingActionButton,
    this.bottomNav,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null || (actions != null && actions!.isNotEmpty);
    return Scaffold(
      appBar: hasAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              leading: leading,
              actions: actions,
            )
          : null,
      body: safeArea ? SafeArea(child: body) : body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNav,
    );
  }
}
