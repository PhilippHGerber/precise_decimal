import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.setScale', () {
    // Increasing scale pads with trailing zeros
    test('increases scale by padding trailing zeros', () {
      final result = BigDecimal.parse('12.3').setScale(4, RoundingMode.unnecessary);

      expect(result.unscaledValue, BigInt.parse('123000'));
      expect(result.scale, 4);
      expect(result.toString(), '12.3000');
    });

    test('returns the same instance when scale is unchanged', () {
      final value = BigDecimal.parse('1.23');

      expect(value.setScale(2, RoundingMode.halfUp), same(value));
    });

    // Zero is handled as a special case: any scale, same zero
    test('handles zero at any scale', () {
      final result = BigDecimal.zero.setScale(3, RoundingMode.halfUp);

      expect(result.toString(), '0.000');
      expect(result.scale, 3);
    });

    group('directional rounding modes', () {
      // up/down are magnitude-based; ceiling/floor are sign-based
      test('rounds positive values with up, down, ceiling, floor', () {
        final value = BigDecimal.parse('1.21');

        expect(value.setScale(1, RoundingMode.up).toString(), '1.3');
        expect(value.setScale(1, RoundingMode.down).toString(), '1.2');
        expect(value.setScale(1, RoundingMode.ceiling).toString(), '1.3');
        expect(value.setScale(1, RoundingMode.floor).toString(), '1.2');
      });

      test('rounds negative values with up, down, ceiling, floor', () {
        final value = BigDecimal.parse('-1.21');

        expect(value.setScale(1, RoundingMode.up).toString(), '-1.3');
        expect(value.setScale(1, RoundingMode.down).toString(), '-1.2');
        expect(value.setScale(1, RoundingMode.ceiling).toString(), '-1.2');
        expect(value.setScale(1, RoundingMode.floor).toString(), '-1.3');
      });
    });

    group('half rounding modes at tie values', () {
      test('halfUp rounds the tie away from zero', () {
        expect(
          BigDecimal.parse('2.25').setScale(1, RoundingMode.halfUp).toString(),
          '2.3',
        );
      });

      test('halfDown rounds the tie towards zero', () {
        expect(
          BigDecimal.parse('2.25').setScale(1, RoundingMode.halfDown).toString(),
          '2.2',
        );
      });

      // halfEven rounds to the nearest even retained digit
      test('halfEven rounds to even on a tie', () {
        expect(
          BigDecimal.parse('2.25').setScale(1, RoundingMode.halfEven).toString(),
          '2.2', // 2 is even
        );
        expect(
          BigDecimal.parse('2.35').setScale(1, RoundingMode.halfEven).toString(),
          '2.4', // 4 is even
        );
        expect(
          BigDecimal.parse('-2.35').setScale(1, RoundingMode.halfEven).toString(),
          '-2.4',
        );
      });
    });

    // Negative scales represent multiples of powers of 10 (e.g. scale -1 = tens)
    test('supports rounding down to a negative scale', () {
      final result = BigDecimal.parse('129.41675').setScale(-1, RoundingMode.down);

      expect(result.unscaledValue, BigInt.parse('12'));
      expect(result.scale, -1);
      expect(result.toString(), '120');
    });

    test('rejects unnecessary when non-zero digits would be discarded', () {
      expect(
        () => BigDecimal.parse('1.2301').setScale(2, RoundingMode.unnecessary),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('allows exact rescaling with unnecessary', () {
      final result = BigDecimal.parse('1.2300').setScale(2, RoundingMode.unnecessary);

      expect(result.toString(), '1.23');
    });

    test('throws when the requested scale is out of range', () {
      expect(
        () => BigDecimal.one.setScale(BigDecimal.maxScale + 1, RoundingMode.halfUp),
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });
  });

  group('BigDecimal.round', () {
    // round is an alias for setScale with a more expressive name
    test('delegates to setScale', () {
      final result = BigDecimal.parse('12.345').round(2, RoundingMode.halfUp);

      expect(result.toString(), '12.35');
    });
  });

  group('BigDecimal.roundToPrecision', () {
    test('reduces to the given number of significant digits', () {
      final result = BigDecimal.parse('129.41675').roundToPrecision(
        4,
        RoundingMode.halfEven,
      );

      expect(result.unscaledValue, BigInt.parse('1294'));
      expect(result.scale, 1);
      expect(result.toString(), '129.4');
    });

    // Rounding the most significant digit can produce a carry
    test('handles carry across the most significant digit', () {
      final result = BigDecimal.parse('9.95').roundToPrecision(
        2,
        RoundingMode.halfEven,
      );

      expect(result.toString(), '10');
      expect(result.scale, 0);
      expect(result.precision, 2);
    });

    // Precision rounding can push the scale negative for large numbers
    test('produces a negative scale when rounding large integers', () {
      final result = BigDecimal.parse('1.23e5').roundToPrecision(
        2,
        RoundingMode.down,
      );

      expect(result.unscaledValue, BigInt.parse('12'));
      expect(result.scale, -4);
      expect(result.toString(), '120000');
    });

    test('returns the same instance when already within the requested precision', () {
      final value = BigDecimal.parse('1.2300');

      expect(value.roundToPrecision(6, RoundingMode.halfUp), same(value));
      expect(value.roundToPrecision(5, RoundingMode.halfUp), same(value));
    });

    test('returns the same instance for zero', () {
      expect(
        BigDecimal.zero.roundToPrecision(5, RoundingMode.halfUp),
        same(BigDecimal.zero),
      );
    });

    test('rejects non-positive sigDigits', () {
      expect(
        () => BigDecimal.one.roundToPrecision(0, RoundingMode.halfUp),
        throwsArgumentError,
      );
      expect(
        () => BigDecimal.one.roundToPrecision(-1, RoundingMode.halfUp),
        throwsArgumentError,
      );
    });
  });

  group('BigDecimal.roundResult', () {
    test('applies the precision and rounding mode and reports conditions', () {
      const context = DecimalContext(
        precision: 3,
        roundingMode: RoundingMode.halfUp,
      );

      final result = BigDecimal.parse('12.3456').roundResult(context);

      expect(result.value.toString(), '12.3');
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });

    test('reports empty conditions for unlimited precision', () {
      final value = BigDecimal.parse('12.3456');

      final result = value.roundResult(DecimalContext.unlimited);

      expect(result.value, same(value));
      expect(result.conditions, isEmpty);
    });

    test('does not trap — returns conditions instead', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      // No exception — conditions are returned, not trapped.
      final result = BigDecimal.parse('1000').roundResult(context);

      expect(result.conditions, contains(DecimalCondition.rounded));
    });

    test('folds down non-zero exponents to the clamp boundary', () {
      final result = BigDecimal.parse('1E+95').roundResult(DecimalContext.decimal32);

      expect(result.value.scale, -90);
      expect(result.value.compareTo(BigDecimal.parse('1E+95')), 0);
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.clamped}));
    });

    test('clamps zero exponent to Etiny when too small', () {
      final result = BigDecimal.parse('0E-105').roundResult(DecimalContext.decimal32);

      expect(result.value.isZero, isTrue);
      expect(result.value.scale, 101);
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.clamped}));
    });

    test('clamps zero exponent to high bound when clamp is disabled', () {
      const context = DecimalContext(
        precision: 7,
        maxExponent: 96,
        minExponent: -95,
      );
      final result = BigDecimal.parse('0E+97').roundResult(context);

      expect(result.value.isZero, isTrue);
      expect(result.value.scale, -96);
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.clamped}));
    });

    test('converts overflowing rounded results to infinity', () {
      const context = DecimalContext(
        precision: 7,
        maxExponent: 96,
        minExponent: -95,
        roundingMode: RoundingMode.halfUp,
      );
      final result = BigDecimal.parse('9.9999995E+96').roundResult(context);

      expect(result.value.isInfinite, isTrue);
      expect(result.value.hasNegativeSign, isFalse);
      expect(
        result.conditions,
        equals(<DecimalCondition>{
          DecimalCondition.overflow,
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        }),
      );
    });
  });

  group('BigDecimal.roundWithContext trapping', () {
    test('traps rounded when only zero digits are discarded', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.parse('1000').roundWithContext(context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.rounded,
          ),
        ),
      );
    });
  });

  group('BigDecimal.setScaleResult', () {
    test('reports conditions when digits are discarded', () {
      final result = BigDecimal.parse('12.3456').setScaleResult(
        2,
        RoundingMode.halfUp,
      );

      expect(result.value.toString(), '12.35');
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });

    test('reports rounded when only trailing zeros are discarded', () {
      final result = BigDecimal.parse('12.30').setScaleResult(
        1,
        RoundingMode.halfUp,
      );

      expect(result.value.toString(), '12.3');
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.rounded}));
    });

    test('reports empty conditions when scale increases', () {
      final result = BigDecimal.parse('12.3').setScaleResult(
        5,
        RoundingMode.unnecessary,
      );

      expect(result.value.toString(), '12.30000');
      expect(result.conditions, isEmpty);
    });
  });
}
