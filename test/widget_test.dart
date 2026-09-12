import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopsnap/app.dart';

void main() {
  setUpAll(() async {
    // ShopSnap uses 'vi_VN' locale for date/currency formatting
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('ShopSnap app smoke test — boots without throwing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopSnapApp()));
    await tester.pump();
    // App renders a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
