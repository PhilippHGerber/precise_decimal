import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.parse', () {
    test('preserves scale from the literal representation', () {
      final value = BigDecimal.parse('12.3400');

      expect(value.unscaledValue, BigInt.parse('123400'));
      expect(value.scale, 4);
      expect(value.toString(), '12.3400');
    });

    test('trims surrounding whitespace', () {
      expect(BigDecimal.parse('  3.14  ').toString(), '3.14');
      expect(BigDecimal.parse('\t42\n').toString(), '42');
    });

    test('accepts leading-dot notation', () {
      expect(BigDecimal.parse('.5').toString(), '0.5');
      expect(BigDecimal.parse('-.5').toString(), '-0.5');
    });

    test('accepts trailing-dot notation', () {
      expect(BigDecimal.parse('1.').toString(), '1');
      expect(BigDecimal.parse('-1.').toString(), '-1');
      expect(BigDecimal.parse('1.e2').toString(), '100');
    });

    test('accepts explicit positive sign', () {
      expect(BigDecimal.parse('+42').toString(), '42');
      expect(BigDecimal.parse('+3.14').toString(), '3.14');
    });

    test('accepts negative values', () {
      expect(BigDecimal.parse('-3.14').toString(), '-3.14');
      expect(BigDecimal.parse('-0.005').toString(), '-0.005');
    });

    test('preserves signed zero from parsed literals', () {
      final value = BigDecimal.parse('-0.00');

      expect(value.isNegativeZero, isTrue);
      expect(value.hasNegativeSign, isTrue);
      expect(value.sign, 0);
      expect(value.toString(), '-0.00');
    });

    test('accepts scientific notation with positive exponent', () {
      expect(BigDecimal.parse('1e3').toString(), '1000');
      expect(BigDecimal.parse('1.23e10').toString(), '12300000000');
    });

    test('accepts scientific notation with negative exponent', () {
      expect(BigDecimal.parse('5E-3').toString(), '0.005');
      expect(BigDecimal.parse('1.5e-2').toString(), '0.015');
    });

    test('rejects invalid literals', () {
      for (final invalid in ['', 'abc', '1.2.3', '--1', '1e', '  ']) {
        expect(
          () => BigDecimal.parse(invalid),
          throwsA(isA<BigDecimalParseException>()),
          reason: '"$invalid" should be rejected',
        );
      }
    });

    // Scale range is [-999999999, 999999999]; exponents outside this are rejected.
    test('rejects literals whose exponent exceeds the scale bounds', () {
      expect(
        () => BigDecimal.parse('1e1000000000'),
        throwsA(isA<BigDecimalOverflowException>()),
      );
      expect(
        () => BigDecimal.parse('1e-1000000000'),
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });

    test('accepts literals at the supported exponent boundaries', () {
      expect(BigDecimal.parse('1e999999999').scale, -999999999);
      expect(BigDecimal.parse('1e-999999999').scale, 999999999);
    });

    test('rejects malformed exponent forms', () {
      for (final invalid in ['1e+', '1e-', '1e++1', '1e--1', '.e1']) {
        expect(
          () => BigDecimal.parse(invalid),
          throwsA(isA<BigDecimalParseException>()),
          reason: '"$invalid" should be rejected',
        );
      }
    });
  });

  group('BigDecimal.tryParse', () {
    test('returns a value for valid input', () {
      final value = BigDecimal.tryParse('3.14');

      expect(value, isNotNull);
      expect(value!.toString(), '3.14');
    });

    test('returns null for invalid or out-of-range input', () {
      expect(BigDecimal.tryParse('1e1000000000'), isNull);
      expect(BigDecimal.tryParse('invalid'), isNull);
      expect(BigDecimal.tryParse(''), isNull);
      expect(BigDecimal.tryParse('1e+'), isNull);
    });
  });

  group('BigDecimal.fromInt', () {
    test('creates a scale-0 integer', () {
      final value = BigDecimal.fromInt(42);

      expect(value.toString(), '42');
      expect(value.scale, 0);
      expect(value.unscaledValue, BigInt.from(42));
    });

    test('handles negative and zero values', () {
      expect(BigDecimal.fromInt(-7).toString(), '-7');
      expect(BigDecimal.fromInt(0).isZero, isTrue);
    });
  });

  group('BigDecimal.fromBigInt', () {
    test('creates a scale-0 value from an arbitrary-size integer', () {
      final bigValue = BigInt.parse('99999999999999999999');
      final value = BigDecimal.fromBigInt(bigValue);

      expect(value.toString(), '99999999999999999999');
      expect(value.scale, 0);
      expect(value.unscaledValue, bigValue);
    });
  });

  group('BigDecimal.fromDouble', () {
    // Conversion uses double.toString(), so it reflects the string form
    // of the double, not the exact IEEE 754 binary value.
    test('converts finite doubles via their string representation', () {
      expect(BigDecimal.fromDouble(0.1).toString(), '0.1');
      expect(BigDecimal.fromDouble(3.14).toString(), '3.14');
      expect(BigDecimal.fromDouble(-2.5).toString(), '-2.5');
      expect(BigDecimal.fromDouble(10.5).toString(), '10.5');
    });

    test('preserves negative zero from double input', () {
      final value = BigDecimal.fromDouble(-0);

      expect(value.isNegativeZero, isTrue);
      expect(value.toString(), '-0.0');
    });

    test('rejects NaN', () {
      expect(
        () => BigDecimal.fromDouble(double.nan),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });

    test('rejects positive infinity', () {
      expect(
        () => BigDecimal.fromDouble(double.infinity),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });

    test('rejects negative infinity', () {
      expect(
        () => BigDecimal.fromDouble(double.negativeInfinity),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });

  group('BigDecimal.fromComponents', () {
    test('rejects scale values outside the supported range', () {
      expect(
        () => BigDecimal.fromComponents(BigInt.one, scale: BigDecimal.maxScale + 1),
        throwsA(isA<BigDecimalOverflowException>()),
      );
      expect(
        () => BigDecimal.fromComponents(BigInt.one, scale: BigDecimal.minScale - 1),
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });
  });

  group('BigDecimal constants', () {
    test('zero, one, and ten have the expected string representations', () {
      expect(BigDecimal.zero.toString(), '0');
      expect(BigDecimal.zero.isZero, isTrue);
      expect(BigDecimal.one.toString(), '1');
      expect(BigDecimal.one.isPositive, isTrue);
      expect(BigDecimal.ten.toString(), '10');
    });

    test('minScale and maxScale reflect the symmetric scale bounds', () {
      expect(BigDecimal.minScale, -999999999);
      expect(BigDecimal.maxScale, 999999999);
    });
  });
}
