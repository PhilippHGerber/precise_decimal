import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.sign', () {
    test('returns 1 for positive, -1 for negative, 0 for zero', () {
      expect(BigDecimal.parse('5').sign, 1);
      expect(BigDecimal.parse('-5').sign, -1);
      expect(BigDecimal.zero.sign, 0);
      expect(BigDecimal.parse('-0').sign, 0);
    });
  });

  group('BigDecimal.isZero / isPositive / isNegative', () {
    test('zero is only isZero', () {
      expect(BigDecimal.zero.isZero, isTrue);
      expect(BigDecimal.zero.isPositive, isFalse);
      expect(BigDecimal.zero.isNegative, isFalse);
    });

    test('positive value is only isPositive', () {
      final value = BigDecimal.parse('1');

      expect(value.isZero, isFalse);
      expect(value.isPositive, isTrue);
      expect(value.isNegative, isFalse);
    });

    test('negative value is only isNegative', () {
      final value = BigDecimal.parse('-1');

      expect(value.isZero, isFalse);
      expect(value.isPositive, isFalse);
      expect(value.isNegative, isTrue);
    });

    test('negative zero keeps a sign bit without becoming isNegative', () {
      final value = BigDecimal.parse('-0.00');

      expect(value.isZero, isTrue);
      expect(value.isPositive, isFalse);
      expect(value.isNegative, isFalse);
      expect(value.isNegativeZero, isTrue);
      expect(value.hasNegativeSign, isTrue);
    });
  });

  group('BigDecimal.precision', () {
    // precision = number of digits in the absolute unscaled value
    test('counts digits in the unscaled integer', () {
      expect(BigDecimal.parse('12345').precision, 5);
      expect(BigDecimal.parse('0.001').precision, 1); // unscaled = 1
      expect(BigDecimal.parse('100.00').precision, 5); // unscaled = 10000
      expect(BigDecimal.zero.precision, 1); // unscaled = 0 → "0"
    });

    test('handles powers of ten and neighboring values', () {
      expect(BigDecimal.parse('9').precision, 1);
      expect(BigDecimal.parse('10').precision, 2);
      expect(BigDecimal.parse('99').precision, 2);
      expect(BigDecimal.parse('100').precision, 3);
      expect(BigDecimal.parse('-999').precision, 3);
      expect(BigDecimal.parse('-1000').precision, 4);
    });

    test('handles scientific notation and large integer boundaries', () {
      expect(BigDecimal.parse('1e3').precision, 1);
      expect(BigDecimal.parse('1.00e3').precision, 3);
      expect(BigDecimal.parse('9.99e2').precision, 3);

      final oneHundredDigitNines = BigInt.parse(List.filled(100, '9').join());
      final oneFollowedByHundredZeros = BigInt.parse(
        '1${List.filled(100, '0').join()}',
      );

      expect(BigDecimal.fromBigInt(oneHundredDigitNines).precision, 100);
      expect(BigDecimal.fromBigInt(oneFollowedByHundredZeros).precision, 101);
    });

    test('handles precision boundaries well beyond 100 digits', () {
      final fiveHundredDigitNines = BigInt.parse(List.filled(500, '9').join());
      final oneFollowedByFiveHundredZeros = BigInt.parse(
        '1${List.filled(500, '0').join()}',
      );

      expect(BigDecimal.fromBigInt(fiveHundredDigitNines).precision, 500);
      expect(BigDecimal.fromBigInt(oneFollowedByFiveHundredZeros).precision, 501);
    });

    test('matches decimal string length for very large integers', () {
      final hugeValue = (BigInt.one << 20000) - BigInt.one;

      expect(BigDecimal.fromBigInt(hugeValue).precision, hugeValue.toString().length);
    });
  });

  group('BigDecimal.hasSameRepresentation', () {
    // Unlike ==, hasSameRepresentation requires both scale and unscaled value
    // to be identical — useful when distinguishing "1.0" from "1.00".
    test('returns false for numerically equal values with different scales', () {
      final a = BigDecimal.parse('1.0');
      final b = BigDecimal.parse('1.00');

      expect(a == b, isTrue);
      expect(a.hasSameRepresentation(b), isFalse);
    });

    test('returns true when scale and unscaled value both match', () {
      final a = BigDecimal.parse('1.0');
      final c = BigDecimal.parse('1.0');

      expect(a.hasSameRepresentation(c), isTrue);
    });

    test('distinguishes signed zero representations', () {
      expect(
        BigDecimal.parse('-0.0').hasSameRepresentation(BigDecimal.parse('0.0')),
        isFalse,
      );
    });
  });

  group('BigDecimal.precision for large unscaled values', () {
    // Verifies that _getDigitCount is correct for values whose bit-length
    // dwarfs the 53-bit double mantissa.  The estimate uses bitLength * log10(2)
    // which remains accurate even for very large BigInts — the correction loops
    // need at most one iteration regardless of magnitude.
    //
    // Scale is kept within the library's supported range [−999999999, 999999999] by
    // pairing a large unscaled integer with a matching scale so the represented
    // decimal value is still small.
    test('precision is 10000 for a 10000-digit unscaled value', () {
      // 10^9999 has exactly 10000 decimal digits. Pair it with scale=9999 so
      // the represented value is 10^9999 × 10^−9999 = 1.0 (within range).
      final huge = BigDecimal.fromComponents(BigInt.from(10).pow(9999), scale: 9999);

      expect(huge.precision, 10000);
    });

    test('precision is 10000 for a 10000-digit value without trailing zeros', () {
      // 10^9999 + 1 has exactly 10000 digits and no trailing zeros.
      final huge = BigDecimal.fromComponents(
        BigInt.from(10).pow(9999) + BigInt.one,
        scale: 9999,
      );

      expect(huge.precision, 10000);
    });

    test('precision is 1 for 1e9999 parsed from scientific notation', () {
      // Exponent 9999 is within the supported scale range; coefficient is 1.
      expect(BigDecimal.parse('1e9999').precision, 1);
    });
  });
}
