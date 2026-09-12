import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.format', () {
    test('formats zero', () {
      expect(CurrencyFormatter.format(0), '0đ');
    });

    test('formats hundreds', () {
      expect(CurrencyFormatter.format(500), '500đ');
    });

    test('formats thousands with separator', () {
      expect(CurrencyFormatter.format(25000), '25.000đ');
    });

    test('formats millions', () {
      expect(CurrencyFormatter.format(1500000), '1.500.000đ');
    });
  });

  group('CurrencyFormatter.formatShort', () {
    test('formats small amount as đ suffix', () {
      expect(CurrencyFormatter.formatShort(500), '500đ');
    });

    test('formats thousands as k', () {
      expect(CurrencyFormatter.formatShort(25000), '25k');
    });

    test('formats millions as tr', () {
      expect(CurrencyFormatter.formatShort(1500000), '1.5tr');
    });

    test('formats exactly 1 million as 1.0tr', () {
      expect(CurrencyFormatter.formatShort(1000000), '1.0tr');
    });

    test('formats exactly 1000 as 1k', () {
      expect(CurrencyFormatter.formatShort(1000), '1k');
    });
  });

  group('CurrencyFormatter.parse', () {
    test('parses plain integer string', () {
      expect(CurrencyFormatter.parse('25000'), 25000);
    });

    test('parses formatted string with dots', () {
      expect(CurrencyFormatter.parse('25.000'), 25000);
    });

    test('parses string with đ suffix', () {
      expect(CurrencyFormatter.parse('25.000đ'), 25000);
    });

    test('returns 0 for empty string', () {
      expect(CurrencyFormatter.parse(''), 0);
    });

    test('returns 0 for non-numeric text', () {
      expect(CurrencyFormatter.parse('abc'), 0);
    });

    test('parses large number', () {
      expect(CurrencyFormatter.parse('1.500.000đ'), 1500000);
    });
  });
}
