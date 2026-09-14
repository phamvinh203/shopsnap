import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_typography.dart';

void main() {
  testWidgets('buildTextTheme: light/dark khác màu chữ, cùng hệ Nunito',
      (tester) async {
    final light = AppTypography.buildTextTheme(Brightness.light);
    final dark = AppTypography.buildTextTheme(Brightness.dark);

    expect(light.bodyMedium!.color, isNot(dark.bodyMedium!.color));
    expect(light.headlineMedium!.fontSize, dark.headlineMedium!.fontSize);
    // Style mới so với theme cũ: displaySmall + titleSmall.
    expect(light.displaySmall, isNotNull);
    expect(light.titleSmall, isNotNull);
    // displayLarge cho hero "Còn lại": 34/w800.
    expect(light.displayLarge!.fontSize, 34);
    expect(light.displayLarge!.fontWeight, FontWeight.w800);
  });

  testWidgets('moneyOf: tabular figures + size tuỳ ý', (tester) async {
    final t = AppTypography.buildTextTheme(Brightness.light);
    final money = AppTypography.moneyOf(t);
    expect(money.fontFeatures!.contains(const FontFeature.tabularFigures()), isTrue);
    expect(money.fontSize, 15);
    expect(AppTypography.moneyOf(t, size: 20).fontSize, 20);
  });
}
