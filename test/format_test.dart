import 'package:flutter_app_project/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPeso', () {
    test('keeps whole pesos whole and adds the symbol', () {
      expect(formatPeso(0), '₱0');
      expect(formatPeso(85), '₱85');
      expect(formatPeso(999), '₱999');
    });

    test('groups thousands', () {
      expect(formatPeso(1000), '₱1,000');
      expect(formatPeso(6000), '₱6,000');
      expect(formatPeso(1234567), '₱1,234,567');
    });

    test('groups without decimals when asked for none', () {
      expect(formatPeso(1234.5), '₱1,235');
      expect(formatPeso(1234.4), '₱1,234');
    });

    test('groups and pads the fraction when asked for two', () {
      expect(formatPeso(1234.5, decimals: 2), '₱1,234.50');
      expect(formatPeso(85.5, decimals: 2), '₱85.50');
      expect(formatPeso(1234567.891, decimals: 2), '₱1,234,567.89');
    });

    test('puts the minus before the symbol', () {
      expect(formatPeso(-150), '-₱150');
      expect(formatPeso(-1234.5), '-₱1,235');
      expect(formatPeso(-99.9, decimals: 2), '-₱99.90');
    });

    test('treats a negative decimals count as zero', () {
      expect(formatPeso(1234.5, decimals: -1), '₱1,235');
    });
  });

  group('formatAmountInput', () {
    test('seeds text fields without the symbol or separators', () {
      expect(formatAmountInput(85), '85.00');
      expect(formatAmountInput(1234.5), '1234.50');
    });

    test('drops cents for whole-peso-only fields', () {
      expect(formatAmountInput(6000, decimals: 0), '6000');
      expect(formatAmountInput(6000.4, decimals: 0), '6000');
    });
  });
}
