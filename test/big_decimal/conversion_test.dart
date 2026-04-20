import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal integer predicates', () {
    test('identifies integer values across positive and negative scales', () {
      expect(BigDecimal.parse('123').isInteger, isTrue);
      expect(BigDecimal.parse('123.0').isInteger, isTrue);
      expect(BigDecimal.parse('123.1').isInteger, isFalse);
      expect(BigDecimal.parse('1e3').isInteger, isTrue);
    });

    test('identifies negative-scale values', () {
      expect(BigDecimal.parse('1e3').isNegativeScale, isTrue);
      expect(BigDecimal.parse('1.0').isNegativeScale, isFalse);
    });
  });

  group('BigDecimal integer conversion', () {
    test('toBigInt truncates fractional digits toward zero', () {
      expect(BigDecimal.parse('123.456').toBigInt(), BigInt.from(123));
      expect(BigDecimal.parse('-123.456').toBigInt(), BigInt.from(-123));
      expect(BigDecimal.parse('1e3').toBigInt(), BigInt.from(1000));
    });

    test('toBigInt supports scales beyond the shared pow10 cache limit', () {
      final value = BigDecimal.fromComponents(BigInt.one, scale: -20001);

      expect(value.toBigInt(), BigInt.from(10).pow(20001));
    });

    test('toBigInt handles values on both sides of the shared pow10 cache boundary', () {
      final cached = BigDecimal.fromComponents(BigInt.one, scale: -256);
      final uncached = BigDecimal.fromComponents(BigInt.one, scale: -257);

      expect(cached.toBigInt(), BigInt.from(10).pow(256));
      expect(uncached.toBigInt(), BigInt.from(10).pow(257));
    });

    test('toBigIntExact requires an integral value', () {
      expect(BigDecimal.parse('123.0').toBigIntExact(), BigInt.from(123));
      expect(
        () => BigDecimal.parse('123.1').toBigIntExact(),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });

    test('toInt truncates fractional digits toward zero', () {
      expect(BigDecimal.parse('123.456').toInt(), 123);
      expect(BigDecimal.parse('-123.456').toInt(), -123);
    });

    test('toInt rejects values outside the VM int range', testOn: 'vm', () {
      final overflow = BigDecimal.fromComponents(
        BigInt.one << 200,
        scale: 0,
      );

      expect(
        overflow.toInt,
        throwsA(isA<BigDecimalConversionException>()),
      );
    });

    test('toIntExact requires an integral in-range value', () {
      expect(BigDecimal.parse('123.0').toIntExact(), 123);
      expect(
        () => BigDecimal.parse('123.1').toIntExact(),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });

  group('BigDecimal floating conversion', () {
    test('toDouble produces the expected numeric approximation', () {
      expect(BigDecimal.parse('0.1').toDouble(), closeTo(0.1, 0.0));
      expect(BigDecimal.parse('123.456').toDouble(), closeTo(123.456, 0.0));
      expect(BigDecimal.parse('-1e3').toDouble(), closeTo(-1000, 0.0));
    });

    test('round-trips through double for small values', () {
      final value = BigDecimal.parse('123.25');
      final roundTripped = BigDecimal.fromDouble(value.toDouble());

      expect(roundTripped, value);
    });

    test('preserves negative zero when converting to double', () {
      final result = BigDecimal.parse('-0.00').toDouble();

      expect(result, equals(-0.0));
      expect(result.isNegative, isTrue);
    });

    test('fromDoubleExact preserves exact IEEE-754 value for 0.1', () {
      final exact = BigDecimal.fromDoubleExact(0.1);

      expect(
        exact.toPlainString(),
        '0.1000000000000000055511151231257827021181583404541015625',
      );
      expect(exact.toDouble(), equals(0.1));
      expect(exact, isNot(equals(BigDecimal.fromDouble(0.1))));
    });

    test('fromDoubleExact preserves exact value for binary fractions', () {
      expect(BigDecimal.fromDoubleExact(0.5).toPlainString(), '0.5');
      expect(BigDecimal.fromDoubleExact(0.25).toPlainString(), '0.25');
      expect(BigDecimal.fromDoubleExact(-1.5).toPlainString(), '-1.5');
    });

    test('fromDoubleExact preserves the smallest positive subnormal double', () {
      final exact = BigDecimal.fromDoubleExact(_smallestPositiveSubnormalDouble);
      final expected = _smallestPositiveSubnormalExact();

      expect(exact.toPlainString(), expected.toPlainString());
      expect(exact.toDouble(), equals(_smallestPositiveSubnormalDouble));
    });

    test('fromDoubleExact preserves the smallest negative subnormal double', () {
      final exact = BigDecimal.fromDoubleExact(-_smallestPositiveSubnormalDouble);
      final expected = -_smallestPositiveSubnormalExact();

      expect(exact.toPlainString(), expected.toPlainString());
      expect(exact.toDouble(), equals(-_smallestPositiveSubnormalDouble));
    });

    test('fromDoubleExact preserves the largest positive subnormal double', () {
      const largestSubnormal = _smallestPositiveNormalDouble - _smallestPositiveSubnormalDouble;
      final exact = BigDecimal.fromDoubleExact(largestSubnormal);
      final expected = _largestPositiveSubnormalExact();

      expect(exact.toPlainString(), expected.toPlainString());
      expect(exact.toDouble(), equals(largestSubnormal));
    });

    test('fromDoubleExact distinguishes the smallest normal double boundary', () {
      final exact = BigDecimal.fromDoubleExact(_smallestPositiveNormalDouble);
      final expected = _smallestPositiveNormalExact();

      expect(exact.toPlainString(), expected.toPlainString());
      expect(exact.toDouble(), equals(_smallestPositiveNormalDouble));
    });

    test('fromDoubleExact preserves signed zero', () {
      final negativeZero = BigDecimal.fromDoubleExact(-0);
      final positiveZero = BigDecimal.fromDoubleExact(0);

      expect(negativeZero.isNegativeZero, isTrue);
      expect(positiveZero.isNegativeZero, isFalse);
    });

    test('fromDoubleExact rejects non-finite doubles', () {
      expect(
        () => BigDecimal.fromDoubleExact(double.nan),
        throwsA(isA<BigDecimalConversionException>()),
      );
      expect(
        () => BigDecimal.fromDoubleExact(double.infinity),
        throwsA(isA<BigDecimalConversionException>()),
      );
      expect(
        () => BigDecimal.fromDoubleExact(double.negativeInfinity),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });

  group('BigDecimal JSON conversion', () {
    test('serializes as a string', () {
      expect(BigDecimal.parse('12.3400').toJson(), '12.3400');
      expect(BigDecimal.parse('-0.00').toJson(), '-0.00');
    });

    test('parses from string and int JSON values', () {
      expect(BigDecimal.fromJson('12.3400').toString(), '12.3400');
      expect(BigDecimal.fromJson(42).toString(), '42');
    });

    test('rejects double JSON values', () {
      // Doubles are refused because the original decimal literal is already
      // gone by the time JSON is parsed into a Dart double. Emit decimals as
      // JSON strings and round-trip them through toJson / fromJson instead.
      expect(
        () => BigDecimal.fromJson(0.1),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });

    test('rejects unsupported JSON types', () {
      expect(
        () => BigDecimal.fromJson(true),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });
}

const double _smallestPositiveSubnormalDouble = 5e-324;
const double _smallestPositiveNormalDouble = 2.2250738585072014e-308;

BigDecimal _smallestPositiveSubnormalExact() {
  return BigDecimal.fromComponents(BigInt.from(5).pow(1074), scale: 1074);
}

BigDecimal _largestPositiveSubnormalExact() {
  final significand = (BigInt.one << 52) - BigInt.one;
  return BigDecimal.fromComponents(
    significand * BigInt.from(5).pow(1074),
    scale: 1074,
  );
}

BigDecimal _smallestPositiveNormalExact() {
  return BigDecimal.fromComponents(BigInt.from(5).pow(1022), scale: 1022);
}
