import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal addition', () {
    // Result scale = max(left.scale, right.scale)
    test('uses the larger operand scale', () {
      final result = BigDecimal.parse('1.20') + BigDecimal.parse('3.4');

      expect(result.unscaledValue, BigInt.parse('460'));
      expect(result.scale, 2);
      expect(result.toString(), '4.60');
    });

    // Negative scales are treated as the lower bound; common scale is max.
    test('handles operands with negative scale', () {
      final result = BigDecimal.parse('1e3') + BigDecimal.parse('2');

      expect(result.unscaledValue, BigInt.parse('1002'));
      expect(result.scale, 0);
      expect(result.toString(), '1002');
    });
  });

  group('BigDecimal subtraction', () {
    test('aligns scales before subtracting', () {
      final result = BigDecimal.parse('5.0') - BigDecimal.parse('0.25');

      expect(result.unscaledValue, BigInt.parse('475'));
      expect(result.scale, 2);
      expect(result.toString(), '4.75');
    });
  });

  group('BigDecimal multiplication', () {
    // Result scale = left.scale + right.scale
    test('combines operand scales', () {
      final result = BigDecimal.parse('1.20') * BigDecimal.parse('3.4');

      expect(result.unscaledValue, BigInt.parse('4080'));
      expect(result.scale, 3);
      expect(result.toString(), '4.080');
    });

    test('throws when combined scale exceeds the supported range', () {
      final left = BigDecimal.parse('1e600000000');
      final right = BigDecimal.parse('1e500000000');

      expect(
        () => left * right,
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });

    test('multiplyResult rounds and reports conditions', () {
      const context = DecimalContext(
        precision: 4,
        roundingMode: RoundingMode.halfUp,
      );

      final result = BigDecimal.parse('12.34').multiplyResult(
        BigDecimal.parse('5.67'),
        context: context,
      );

      expect(result.value.toString(), '69.97');
      expect(result.value.precision, 4);
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });

    test('multiplyResult preserves exact results that fit the context', () {
      const context = DecimalContext(precision: 10);

      final result = BigDecimal.parse('1.20').multiplyResult(
        BigDecimal.fromInt(2),
        context: context,
      );

      expect(result.value.toString(), '2.40');
      expect(result.value.scale, 2);
      expect(result.conditions, isEmpty);
    });

    test('multiplyResult leaves unlimited precision unrounded', () {
      final result = BigDecimal.parse('1.20').multiplyResult(
        BigDecimal.parse('3.4'),
        context: DecimalContext.unlimited,
      );

      expect(result.value.toString(), '4.080');
      expect(result.value.scale, 3);
      expect(result.conditions, isEmpty);
    });

    test('multiplyResult does not trap — returns conditions instead', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      // No exception — conditions are returned, not trapped.
      final result = BigDecimal.parse('1000').multiplyResult(BigDecimal.one, context: context);

      expect(result.conditions, contains(DecimalCondition.rounded));
    });
  });

  group('BigDecimal.multiply trapping', () {
    test('traps rounded via explicit context', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.parse('1000').multiply(BigDecimal.one, context: context),
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

  group('BigDecimal sign helpers', () {
    test('abs returns positive values unchanged and preserves scale', () {
      final value = BigDecimal.parse('0.00');

      expect(value.abs(), same(value));
      expect(value.abs().toString(), '0.00');
    });

    test('abs removes the sign from negative values', () {
      final result = BigDecimal.parse('-3.140').abs();

      expect(result.toString(), '3.140');
      expect(result.scale, 3);
    });

    test('negate matches unary negation', () {
      final value = BigDecimal.parse('3.14');

      expect(value.negate(), equals(-value));
      expect(value.negate().scale, value.scale);
    });

    test('negate toggles the zero sign bit', () {
      final negativeZero = -BigDecimal.zero;

      expect(negativeZero.isNegativeZero, isTrue);
      expect((-negativeZero).isNegativeZero, isFalse);
      expect((-negativeZero).toString(), '0');
    });

    test('preserves scale and inverts sign', () {
      final value = BigDecimal.parse('3.14');
      final negated = -value;

      expect(negated.toString(), '-3.14');
      expect(negated.scale, value.scale);
      expect((-negated).toString(), '3.14');
    });

    test('negating zero keeps it zero', () {
      expect((-BigDecimal.zero).isZero, isTrue);
      expect((-BigDecimal.zero).scale, 0);
    });

    test('abs clears the sign bit on negative zero', () {
      final result = BigDecimal.parse('-0.00').abs();

      expect(result.isNegativeZero, isFalse);
      expect(result.toString(), '0.00');
    });
  });

  group('BigDecimal signed zero arithmetic', () {
    test('preserves negative zero when both zero addends are negative', () {
      final result = BigDecimal.parse('-0') + BigDecimal.parse('-0.00');

      expect(result.isNegativeZero, isTrue);
      expect(result.toString(), '-0.00');
    });

    test('uses positive zero for mixed-sign exact zero sums', () {
      final result = BigDecimal.parse('-0') + BigDecimal.parse('0.00');

      expect(result.isNegativeZero, isFalse);
      expect(result.toString(), '0.00');
    });

    test('preserves product sign when multiplying by zero', () {
      final result = BigDecimal.parse('-1.20') * BigDecimal.zero;

      expect(result.isNegativeZero, isTrue);
      expect(result.toString(), '-0.00');
    });
  });

  group('BigDecimal min/max/clamp', () {
    test('min and max use numeric comparison across different scales', () {
      final a = BigDecimal.parse('1.20');
      final b = BigDecimal.parse('1.3');

      expect(BigDecimal.min(a, b), same(a));
      expect(BigDecimal.max(a, b), same(b));
    });

    test('min and max use total-order tie-breaking on numeric ties', () {
      final first = BigDecimal.parse('1.0');
      final second = BigDecimal.parse('1.00');

      expect(BigDecimal.min(first, second), same(second));
      expect(BigDecimal.max(first, second), same(first));
    });

    test('clamp returns lower or upper bounds when outside the range', () {
      final lower = BigDecimal.parse('1.00');
      final upper = BigDecimal.parse('2.00');

      expect(BigDecimal.parse('0.5').clamp(lower, upper), same(lower));
      expect(BigDecimal.parse('2.5').clamp(lower, upper), same(upper));
    });

    test('clamp preserves the current representation when already in range', () {
      final value = BigDecimal.parse('1.000');

      final clamped = value.clamp(
        BigDecimal.parse('1.0'),
        BigDecimal.parse('2.0'),
      );

      expect(clamped, same(value));
      expect(clamped.scale, 3);
    });

    test('clamp throws when lower is greater than upper', () {
      expect(
        () => BigDecimal.one.clamp(BigDecimal.two, BigDecimal.one),
        throwsArgumentError,
      );
    });
  });

  group('BigDecimal decimal point movement', () {
    test('movePointLeft increases scale without rounding', () {
      final result = BigDecimal.fromInt(123456).movePointLeft(3);

      expect(result.toString(), '123.456');
      expect(result.scale, 3);
    });

    test('movePointRight decreases scale without rounding', () {
      final result = BigDecimal.parse('123.45').movePointRight(2);

      expect(result.toString(), '12345');
      expect(result.scale, 0);
    });

    test('supports negative shift counts by delegating direction', () {
      expect(
        BigDecimal.parse('12.3').movePointLeft(-2).toString(),
        '1230',
      );
      expect(
        BigDecimal.parse('12.3').movePointRight(-2).toString(),
        '0.123',
      );
    });

    test('preserves zero semantics when shifting into a negative scale', () {
      final result = BigDecimal.parse('0.00').movePointRight(3);

      expect(result.isZero, isTrue);
      expect(result.scale, -1);
      expect(result.toString(), '0');
    });

    test('throws when the shifted scale would overflow', () {
      final maxPositiveScale = BigDecimal.fromComponents(
        BigInt.one,
        scale: BigDecimal.maxScale,
      );
      final maxNegativeScale = BigDecimal.fromComponents(
        BigInt.one,
        scale: BigDecimal.minScale,
      );

      expect(
        () => maxNegativeScale.movePointRight(1),
        throwsA(isA<BigDecimalOverflowException>()),
      );
      expect(
        () => maxPositiveScale.movePointLeft(1),
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });
  });

  group('BigDecimal.addResult', () {
    test('rounds the sum and reports conditions', () {
      const context = DecimalContext(
        precision: 3,
        roundingMode: RoundingMode.halfUp,
      );

      final result = BigDecimal.parse('1.234').addResult(
        BigDecimal.parse('5.678'),
        context: context,
      );

      expect(result.value.toString(), '6.91');
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });

    test('returns empty conditions when sum fits the context', () {
      const context = DecimalContext(precision: 10);

      final result = BigDecimal.parse('1.20').addResult(
        BigDecimal.parse('3.4'),
        context: context,
      );

      expect(result.value.toString(), '4.60');
      expect(result.conditions, isEmpty);
    });
  });

  group('BigDecimal.add trapping', () {
    test('traps rounded via explicit context', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.parse('1.234').add(BigDecimal.parse('5.678'), context: context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.rounded,
          ),
        ),
      );
    });

    test('applies GDA zero-sign rule for floor rounding', () {
      const context = DecimalContext(
        precision: 3,
        roundingMode: RoundingMode.floor,
      );

      final sum = BigDecimal.parse('-1.00').add(
        BigDecimal.parse('1.00'),
        context: context,
      );

      expect(sum.isZero, isTrue);
      expect(sum.hasNegativeSign, isTrue);
    });

    test('does not negate zero for non-floor rounding', () {
      const context = DecimalContext(
        precision: 3,
        // Set default rounding mode explicitly.
        // ignore: avoid_redundant_argument_values
        roundingMode: RoundingMode.halfEven,
      );

      final sum = BigDecimal.parse('-1.00').add(
        BigDecimal.parse('1.00'),
        context: context,
      );

      expect(sum.isZero, isTrue);
      expect(sum.hasNegativeSign, isFalse);
    });
  });

  group('BigDecimal.subtractResult', () {
    test('rounds the difference and reports conditions', () {
      const context = DecimalContext(
        precision: 3,
        roundingMode: RoundingMode.halfUp,
      );

      final result = BigDecimal.parse('5.678').subtractResult(
        BigDecimal.parse('1.234'),
        context: context,
      );

      expect(result.value.toString(), '4.44');
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });
  });

  group('BigDecimal constants', () {
    test('exposes two and minusOne', () {
      expect(BigDecimal.two.toString(), '2');
      expect(BigDecimal.minusOne.toString(), '-1');
    });
  });

  group('BigDecimal unary context operations', () {
    test('plusResult rounds and canonicalizes negative zero to positive', () {
      const context = DecimalContext(precision: 2, roundingMode: RoundingMode.halfUp);

      final rounded = BigDecimal.parse('123').plusResult(context);
      final zero = BigDecimal.parse('-0E+3').plusResult(DecimalContext.unlimited);

      expect(rounded.value.toScientificString(), '1.2E+2');
      expect(rounded.value.scale, -1);
      expect(
        rounded.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
      expect(zero.value.toString(), '0');
      expect(zero.value.hasNegativeSign, isFalse);
      expect(zero.value.scale, -3);
    });

    test('minusResult rounds and canonicalizes zero sign to positive', () {
      const context = DecimalContext(precision: 2, roundingMode: RoundingMode.halfUp);

      final rounded = BigDecimal.parse('123').minusResult(context);
      final zero = BigDecimal.parse('0E+3').minusResult(DecimalContext.unlimited);

      expect(rounded.value.toScientificString(), '-1.2E+2');
      expect(rounded.value.scale, -1);
      expect(
        rounded.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
      expect(zero.value.hasNegativeSign, isFalse);
      expect(zero.value.scale, -3);
    });

    test('plus and minus trap through context policy', () {
      const context = DecimalContext(
        precision: 2,
        roundingMode: RoundingMode.halfUp,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.parse('123').plus(context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.rounded,
          ),
        ),
      );
      expect(
        () => BigDecimal.parse('123').minus(context),
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
}
