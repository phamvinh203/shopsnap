import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';

import 'helpers.dart';

void main() {
  group('SnapColors (token layer)', () {
    test('light và dark là 2 bảng màu khác nhau, đủ field', () {
      expect(SnapColors.light.tintPrimary, isNot(SnapColors.dark.tintPrimary));
      expect(SnapColors.light.hairline, isNot(SnapColors.dark.hairline));
      expect(SnapColors.light.success, isNot(SnapColors.dark.success));
    });

    test('successDim là bản nhạt (alpha thấp) của success', () {
      expect(SnapColors.light.successDim.alpha, lessThan(SnapColors.light.success.alpha));
      expect(SnapColors.dark.successDim.alpha, lessThan(SnapColors.dark.success.alpha));
    });

    test('colorFor map đúng level → màu (không assert hex cụ thể)', () {
      expect(SnapColors.light.colorFor(BudgetLevel.ok), SnapColors.light.success);
      expect(
          SnapColors.light.colorFor(BudgetLevel.warning), SnapColors.light.warning);
      expect(SnapColors.light.colorFor(BudgetLevel.danger), SnapColors.light.danger);
    });

    test('copyWith chỉ đổi field được chỉ định', () {
      final copied = SnapColors.light.copyWith(danger: const Color(0xFFFF0000));
      expect(copied.danger, const Color(0xFFFF0000));
      expect(copied.success, SnapColors.light.success);
      expect(copied.hairline, SnapColors.light.hairline);
    });

    test('lerp t=0 giữ this, t=1 sang other', () {
      const a = SnapColors.light;
      const b = SnapColors.dark;
      expect(a.lerp(b, 0).tintPrimary, a.tintPrimary);
      expect(a.lerp(b, 1).tintPrimary, b.tintPrimary);
      expect(a.lerp(null, 0.5), a);
    });
  });

  group('SnapColorsX fallback (bẫy null lớn nhất của Phase 1)', () {
    testWidgets('bare MaterialApp: Theme.extension null nhưng context.snap vẫn dùng được',
        (tester) async {
      SnapColors? fromTheme;
      SnapColors? fromSnap;
      await tester.pumpWidget(wrapBare(Builder(
        builder: (context) {
          fromTheme = Theme.of(context).extension<SnapColors>();
          fromSnap = context.snap;
          return const SizedBox();
        },
      )));

      // Bare MaterialApp không wire SnapColors → extension trong theme là null…
      expect(fromTheme, isNull);
      // …nhưng context.snap phải fallback về light, không crash.
      expect(fromSnap, isNotNull);
      expect(fromSnap!.tintPrimary, SnapColors.light.tintPrimary);
      expect(fromSnap!.hairline, SnapColors.light.hairline);
    });

    testWidgets('app theme: extension được wire và context.snap đọc đúng bảng',
        (tester) async {
      SnapColors? fromTheme;
      SnapColors? fromSnapDark;
      await tester.pumpWidget(wrapWithAppTheme(Builder(
        builder: (context) {
          fromTheme = Theme.of(context).extension<SnapColors>();
          return const SizedBox();
        },
      )));
      expect(fromTheme, isNotNull);
      expect(fromTheme!.tintPrimary, SnapColors.light.tintPrimary);

      await tester.pumpWidget(wrapWithDarkTheme(Builder(
        builder: (context) {
          fromSnapDark = context.snap;
          return const SizedBox();
        },
      )));
      // MaterialApp dùng AnimatedTheme (200ms) — đổi theme giữa test phải
      // đợi animation lerp light→dark chạy xong mới đọc được bảng dark.
      await tester.pumpAndSettle();
      expect(fromSnapDark!.tintPrimary, SnapColors.dark.tintPrimary);
      expect(fromSnapDark!.hairline, SnapColors.dark.hairline);
    });
  });
}
