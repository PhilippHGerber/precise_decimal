import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.toString / toPlainString', () {
    // scale == 0: no decimal point
    test('formats integers without a decimal point', () {
      expect(BigDecimal.fromInt(42).toString(), '42');
      expect(BigDecimal.fromInt(-7).toString(), '-7');
    });

    // digits.length > scale: normal split
    test('formats ordinary decimals', () {
      expect(BigDecimal.parse('12.34').toString(), '12.34');
      expect(BigDecimal.parse('-12.34').toString(), '-12.34');
    });

    // digits.length <= scale: needs leading fractional zeros (e.g. "0.005")
    test('formats small decimals with leading fractional zeros', () {
      expect(BigDecimal.parse('0.005').toString(), '0.005');
      expect(BigDecimal.parse('0.050').toString(), '0.050');
      expect(BigDecimal.parse('-0.5').toString(), '-0.5');
      expect(BigDecimal.parse('-0.005').toString(), '-0.005');
    });

    test('preserves signed zero in plain formatting', () {
      expect(BigDecimal.parse('-0').toString(), '-0');
      expect(BigDecimal.parse('-0.00').toString(), '-0.00');
      expect(BigDecimal.parse('-0E+5').toString(), '-0');
    });

    // scale < 0: suffix zeros, no decimal point (e.g. 1e3 → "1000")
    test('formats large values with negative scale as trailing zeros', () {
      expect(BigDecimal.parse('1e3').toString(), '1000');
      expect(BigDecimal.parse('-12e2').toString(), '-1200');
    });

    test('toPlainString is an alias for toString', () {
      final value = BigDecimal.parse('12.3400');

      expect(value.toPlainString(), value.toString());
    });

    test('repeated plain-string access remains stable', () {
      final value = BigDecimal.parse('1234567890.0012300');

      final first = value.toPlainString();
      final second = value.toPlainString();

      expect(first, '1234567890.0012300');
      expect(second, first);
      expect(value.toString(), first);
    });

    test('formats large scales beyond the shared pow10 cache limit', () {
      final value = BigDecimal.one.setScale(150, RoundingMode.unnecessary);

      expect(value.toString(), '1.${List.filled(150, '0').join()}');
    });

    test('formats values on both sides of the shared pow10 cache boundary', () {
      final cached = BigDecimal.one.setScale(256, RoundingMode.unnecessary);
      final uncached = BigDecimal.one.setScale(257, RoundingMode.unnecessary);

      expect(cached.toString(), '1.${List.filled(256, '0').join()}');
      expect(uncached.toString(), '1.${List.filled(257, '0').join()}');
    });
  });

  group('BigDecimal scientific formatting', () {
    test('formats normalized scientific notation', () {
      expect(BigDecimal.parse('123.456').toScientificString(), '1.23456E+2');
      expect(BigDecimal.parse('0.001').toScientificString(), '1E-3');
      expect(BigDecimal.parse('1000000').toScientificString(), '1E+6');
      expect(BigDecimal.parse('1500').toScientificString(), '1.5E+3');
      expect(BigDecimal.parse('-0.0001').toScientificString(), '-1E-4');
      expect(BigDecimal.parse('0.5').toScientificString(), '5E-1');
    });

    test('formats zero as plain zero', () {
      expect(BigDecimal.parse('0.000').toScientificString(), '0');
      expect(BigDecimal.parse('-0.000').toScientificString(), '-0');
    });
  });

  group('BigDecimal GDA token formatting', () {
    test('uses plain notation within the adjusted-exponent threshold', () {
      expect(BigDecimal.parse('12.3400').toGdaString(), '12.3400');
      expect(BigDecimal.parse('0.000001').toGdaString(), '0.000001');
    });

    test('uses scientific notation for negative scales and tiny exponents', () {
      expect(BigDecimal.parse('1E+3').toGdaString(), '1E+3');
      expect(BigDecimal.parse('0.0000001').toGdaString(), '1E-7');
      expect(BigDecimal.parse('-0E+5').toGdaString(), '-0E+5');
    });

    test('preserves trailing zeros in scientific output', () {
      expect(BigDecimal.parse('1.23456780E+10').toGdaString(), '1.23456780E+10');
      expect(
        BigDecimal.parse('1000').roundToPrecision(3, RoundingMode.halfUp).toGdaString(),
        '1.00E+3',
      );
    });
  });

  group('BigDecimal engineering formatting', () {
    test('formats engineering notation with exponent multiple of three', () {
      expect(BigDecimal.parse('123.456').toEngineeringString(), '123.456E+0');
      expect(BigDecimal.parse('0.001').toEngineeringString(), '1E-3');
      expect(BigDecimal.parse('1000000').toEngineeringString(), '1E+6');
      expect(BigDecimal.parse('1500').toEngineeringString(), '1.5E+3');
      expect(BigDecimal.parse('-0.0001').toEngineeringString(), '-100E-6');
      expect(BigDecimal.parse('0.5').toEngineeringString(), '500E-3');
    });

    test('formats zero as plain zero', () {
      expect(BigDecimal.zero.toEngineeringString(), '0');
      expect(BigDecimal.parse('-0.00').toEngineeringString(), '-0');
    });
  });

  group('BigDecimal fixed and precision formatting', () {
    test('formats fixed-point output with rounding', () {
      expect(BigDecimal.parse('123.456').toStringAsFixed(2), '123.46');
      expect(BigDecimal.parse('0.001').toStringAsFixed(2), '0.00');
      expect(BigDecimal.parse('1000000').toStringAsFixed(2), '1000000.00');
      expect(BigDecimal.parse('0.5').toStringAsFixed(2), '0.50');
      expect(
        BigDecimal.parse('-1.25').toStringAsFixed(1, RoundingMode.halfDown),
        '-1.2',
      );
    });

    test('formats to significant digits in plain notation', () {
      expect(BigDecimal.parse('123.456').toStringAsPrecision(4), '123.5');
      expect(BigDecimal.parse('0.0012345').toStringAsPrecision(2), '0.0012');
      expect(BigDecimal.parse('999').toStringAsPrecision(2), '1000');
    });

    test('rejects negative decimal places', () {
      expect(
        () => BigDecimal.one.toStringAsFixed(-1),
        throwsArgumentError,
      );
    });
  });

  group('BigDecimal.stripTrailingZeros', () {
    test('removes trailing zeros and reduces scale', () {
      expect(BigDecimal.parse('1.2000').stripTrailingZeros().toString(), '1.2');
      expect(BigDecimal.parse('1.230').stripTrailingZeros().toString(), '1.23');
    });

    // All fractional zeros may be stripped, pushing scale negative
    test('removes all fractional zeros even when it results in a negative scale', () {
      expect(BigDecimal.parse('100.00').stripTrailingZeros().toString(), '100');
    });

    test('zero always returns the BigDecimal.zero constant', () {
      expect(BigDecimal.parse('0.000').stripTrailingZeros().isZero, isTrue);
      expect(BigDecimal.zero.stripTrailingZeros().isZero, isTrue);
    });

    test('preserves negative zero when stripping trailing zeros', () {
      final result = BigDecimal.parse('-0.000').stripTrailingZeros();

      expect(result.isNegativeZero, isTrue);
      expect(result.toString(), '-0');
    });

    test('value with no trailing zeros is returned unchanged', () {
      final value = BigDecimal.parse('1.23');

      expect(value.stripTrailingZeros(), value);
    });
  });
}
