import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

import 'helpers.dart';

/// Key nằm trên wrapper AppTextField; ô nhập thật trỏ qua descendant finder
/// (TextField/EditableText là cấu trúc nội bộ cố định của TextFormField).
Finder _fieldOf(Key wrapperKey) => find.descendant(
      of: find.byKey(wrapperKey),
      matching: find.byType(TextField),
    );

void main() {
  testWidgets('app theme: enterText theo key, controller nhận giá trị',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(wrapWithAppTheme(AppTextField(
      key: const Key('field_name'),
      controller: controller,
      label: 'Tên vật phẩm',
      hint: 'VD: Sữa tươi',
      prefixIcon: Icons.shopping_bag_outlined,
    )));

    await tester.enterText(_fieldOf(const Key('field_name')), 'Sữa tươi 1L');
    await tester.pump();
    expect(controller.text, 'Sữa tươi 1L');
  });

  testWidgets('bare MaterialApp: validator lỗi hiển thị, nhập xong biến mất',
      (tester) async {
    await tester.pumpWidget(wrapBare(Form(
      autovalidateMode: AutovalidateMode.always,
      child: AppTextField(
        key: const Key('field_price'),
        label: 'Giá',
        keyboardType: TextInputType.number,
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Không được bỏ trống' : null,
      ),
    )));
    await tester.pump();

    // Nhập hợp lệ → không còn lỗi.
    await tester.enterText(_fieldOf(const Key('field_price')), '12000');
    await tester.pump();
    expect(find.text('Không được bỏ trống'), findsNothing);

    // Xoá trống → autovalidate bắt lỗi, chuỗi lỗi (do caller truyền) hiển thị.
    await tester.enterText(_fieldOf(const Key('field_price')), '');
    await tester.pump();
    expect(find.text('Không được bỏ trống'), findsOneWidget);
  });

  testWidgets('obscure: ẩn text mật khẩu', (tester) async {
    await tester.pumpWidget(wrapWithAppTheme(const AppTextField(
      key: Key('field_password'),
      label: 'Mật khẩu',
      obscure: true,
    )));

    final editable = tester.widget<EditableText>(find.descendant(
      of: _fieldOf(const Key('field_password')),
      matching: find.byType(EditableText),
    ));
    expect(editable.obscureText, isTrue);
    expect(editable.maxLines, 1);
  });
}
