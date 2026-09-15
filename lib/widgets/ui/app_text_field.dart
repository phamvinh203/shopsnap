import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TextField chuẩn hoá — bọc TextFormField với label/hint đồng nhất,
/// style lấy từ `inputDecorationTheme` (radius 12, fill surfaceVariant).
///
/// Key truyền vào widget nằm trên wrapper; trong test dùng
/// `find.descendant(of: find.byKey(...), matching: find.byType(TextField))`
/// để trỏ vào ô nhập liệu.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;

  /// Widget góc phải (vd nút hiện/ẩn mật khẩu).
  final Widget? suffix;

  /// FocusNode ngoài (vd màn list cần focus lại ô nhập từ CTA empty state).
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool autofocus;

  /// Format dữ liệu đang gõ (vd. `FilteringTextInputFormatter.digitsOnly`).
  final List<TextInputFormatter>? inputFormatters;

  /// Hành động khi bấm "done" trên bàn phím (vd. submit form).
  final ValueChanged<String>? onFieldSubmitted;

  /// Tự động viết hoa khi gõ (vd. `TextCapitalization.sentences` cho tên).
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction,
    this.autofocus = false,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
      ),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textInputAction: textInputAction,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
    );
  }
}
