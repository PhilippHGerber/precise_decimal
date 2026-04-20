import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.divideToScale', () {
    test('rounds to the requested scale with the provided mode', () {
      expect(
        BigDecimal.one
            .divideToScale(
              BigDecimal.fromInt(3),
              scale: 2,
              roundingMode: RoundingMode.halfUp,
            )
            .toString(),
        '0.33',
      );
      expect(
        BigDecimal.fromInt(2)
            .divideToScale(
              BigDecimal.fromInt(3),
              scale: 2,
              roundingMode: RoundingMode.halfUp,
            )
            .toString(),
        '0.67',
      );
      expect(
        BigDecimal.one
            .divideToScale(
              BigDecimal.fromInt(6),
              scale: 2,
              roundingMode: RoundingMode.halfUp,
            )
            .toString(),
        '0.17',
      );
    });

    test('supports negative result scales', () {
      final result = BigDecimal.fromInt(15).divideToScale(
        BigDecimal.fromInt(2),
        scale: -1,
        roundingMode: RoundingMode.halfUp,
      );

      expect(result.unscaledValue, BigInt.one);
      expect(result.scale, -1);
      expect(result.toString(), '10');
    });

    test('throws when division by zero is attempted', () {
      expect(
        () => BigDecimal.one.divideToScale(
          BigDecimal.zero,
          scale: 2,
          roundingMode: RoundingMode.halfEven,
        ),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });
  });

  group('BigDecimal.divideResult', () {
    test('rounds non-terminating quotients and reports conditions', () {
      const context = DecimalContext(precision: 4);

      final result = BigDecimal.parse('12.3456').divideResult(
        BigDecimal.fromInt(7),
        context: context,
      );

      expect(result.value.toString(), '1.764');
      expect(result.value.precision, 4);
      expect(
        result.conditions,
        equals(<DecimalCondition>{DecimalCondition.inexact, DecimalCondition.rounded}),
      );
    });

    test('reports rounded for exact quotients that need rounding', () {
      const context = DecimalContext(precision: 3);

      final result = BigDecimal.parse('1000').divideResult(BigDecimal.one, context: context);

      expect(result.value.toString(), '1000');
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.rounded}));
    });

    test('preserves exact terminating quotients that already fit the context', () {
      const context = DecimalContext(precision: 10);

      final result = BigDecimal.parse('1.00').divideResult(
        BigDecimal.fromInt(2),
        context: context,
      );

      expect(result.value.toString(), '0.50');
      expect(result.value.scale, 2);
      expect(result.value.precision, 2);
      expect(result.conditions, isEmpty);
    });

    test('preserves signed zero and preferred scale for zero dividends', () {
      const context = DecimalContext(precision: 9);

      final result = BigDecimal.parse('0').divideResult(
        BigDecimal.parse('-1.0'),
        context: context,
      );

      expect(result.value.isNegativeZero, isTrue);
      expect(result.value.scale, -1);
      expect(result.value.toString(), '-0');
    });

    test('applies bounded precision to terminating quotients that need rounding', () {
      const context = DecimalContext(precision: 2);

      final result = BigDecimal.one.divideResult(
        BigDecimal.fromInt(128),
        context: context,
      );

      expect(result.value.toString(), '0.0078');
      expect(result.value.scale, 4);
      expect(result.value.precision, 2);
    });

    test('preserves preferred positive exponents for exact quotients', () {
      const context = DecimalContext(precision: 9);

      final result = BigDecimal.one.divideResult(
        BigDecimal.parse('1E-8'),
        context: context,
      );

      expect(result.value.toScientificString(), '1E+8');
      expect(result.value.scale, -8);
      expect(result.value.precision, 1);
    });

    test('keeps rounded carry results within the requested precision', () {
      const context = DecimalContext(precision: 9);

      final result = BigDecimal.parse('999999999.5').divideResult(
        BigDecimal.one,
        context: context,
      );

      expect(result.value.toScientificString(), '1E+9');
      expect(result.value.unscaledValue, BigInt.from(100000000));
      expect(result.value.scale, -1);
      expect(result.value.precision, 9);
    });

    test('treats unlimited precision as exact division', () {
      expect(
        BigDecimal.one
            .divideResult(BigDecimal.fromInt(4), context: DecimalContext.unlimited)
            .value
            .toString(),
        '0.25',
      );

      expect(
        () => BigDecimal.one.divideResult(
          BigDecimal.fromInt(3),
          context: DecimalContext.unlimited,
        ),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('does not trap — returns conditions instead', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      // No exception — conditions are returned, not trapped.
      final result = BigDecimal.parse('1000').divideResult(BigDecimal.one, context: context);

      expect(result.conditions, contains(DecimalCondition.rounded));
    });

    test('emits overflow condition for exact quotients that exceed maxExponent', () {
      // 1 / 1E-100 = 1E+100, adj-exp = 100 > maxExponent 96 → overflow
      final result = BigDecimal.one.divideResult(
        BigDecimal.parse('1E-100'),
        context: DecimalContext.decimal32,
      );

      expect(result.conditions, contains(DecimalCondition.overflow));
    });

    test('emits underflow condition for exact quotients below minAllowedExponent', () {
      // 1E-102 / 1 = 1E-102, adj-exp = -102 < minAllowedExponent -101 → underflow
      final result = BigDecimal.parse('1E-102').divideResult(
        BigDecimal.one,
        context: DecimalContext.decimal32,
      );

      expect(result.conditions, contains(DecimalCondition.underflow));
      expect(result.conditions, contains(DecimalCondition.subnormal));
    });

    test('finite divided by infinity clamps zero exponent to Etiny', () {
      final result = BigDecimal.one.divideResult(
        BigDecimal.infinity(),
        context: DecimalContext.decimal32,
      );

      expect(result.value.isZero, isTrue);
      expect(result.value.scale, 101);
      expect(result.value.hasNegativeSign, isFalse);
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.clamped}));
    });

    test('negative finite divided by infinity preserves signed zero at Etiny', () {
      final result = BigDecimal.minusOne.divideResult(
        BigDecimal.infinity(),
        context: DecimalContext.decimal32,
      );

      expect(result.value.isZero, isTrue);
      expect(result.value.scale, 101);
      expect(result.value.hasNegativeSign, isTrue);
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.clamped}));
    });
  });

  group('BigDecimal.divide trapping', () {
    test('traps rounded via explicit context', () {
      const context = DecimalContext(
        precision: 3,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.parse('1000').divide(BigDecimal.one, context: context),
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

  group('BigDecimal.divideExact', () {
    test('returns terminating quotients exactly', () {
      expect(
        BigDecimal.one.divideExact(BigDecimal.fromInt(4)).toString(),
        '0.25',
      );
      expect(
        BigDecimal.one.divideExact(BigDecimal.fromInt(8)).toString(),
        '0.125',
      );
    });

    test('handles large powers of two exactly', () {
      expect(
        BigDecimal.one.divideExact(BigDecimal.fromInt(1024)).toString(),
        '0.0009765625',
      );
    });

    test('handles denominators with only factors of two and five', () {
      expect(
        BigDecimal.one.divideExact(BigDecimal.fromInt(40)).toString(),
        '0.025',
      );
    });

    test('preserves preferred scale when exact quotient allows it', () {
      final result = BigDecimal.parse('1.00').divideExact(BigDecimal.fromInt(2));

      expect(result.toString(), '0.50');
      expect(result.scale, 2);
    });

    test('preserves preferred positive exponents for exact integer quotients', () {
      final result = BigDecimal.one.divideExact(BigDecimal.parse('1E-8'));

      expect(result.toScientificString(), '1E+8');
      expect(result.scale, -8);
    });

    test('throws for non-terminating quotients', () {
      expect(
        () => BigDecimal.one.divideExact(BigDecimal.fromInt(3)),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
      expect(
        () => BigDecimal.one.divideExact(BigDecimal.fromInt(12)),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });
  });

  group('BigDecimal divide and remainder forms', () {
    test('divideAndRemainder returns truncating quotient and remainder', () {
      final result = BigDecimal.fromInt(7).divideAndRemainder(BigDecimal.fromInt(2));

      expect(result.quotient.toString(), '3');
      expect(result.remainder.toString(), '1');
    });

    test('divideAndRemainder preserves signed zero quotients', () {
      final result = BigDecimal.one.divideAndRemainder(BigDecimal.fromInt(-2));

      expect(result.quotient.isNegativeZero, isTrue);
      expect(result.quotient.toString(), '-0');
      expect(result.remainder.toString(), '1');
    });

    test('divideAndRemainder preserves fractional remainder scale', () {
      final result = BigDecimal.parse('7.5').divideAndRemainder(BigDecimal.fromInt(2));

      expect(result.quotient.toString(), '3');
      expect(result.remainder.toString(), '1.5');
      expect(result.remainder.scale, 1);
    });

    test('operator ~/ returns the truncating integer quotient', () {
      expect(
        BigDecimal.fromInt(7) ~/ BigDecimal.fromInt(2),
        BigInt.from(3),
      );
      expect(
        BigDecimal.parse('7.5') ~/ BigDecimal.fromInt(2),
        BigInt.from(3),
      );
    });

    test('operator % returns a remainder with the dividend sign', () {
      expect(
        (BigDecimal.fromInt(7) % BigDecimal.fromInt(3)).toString(),
        '1',
      );
      expect(
        (BigDecimal.fromInt(-7) % BigDecimal.fromInt(3)).toString(),
        '-1',
      );
    });

    test('operator % preserves negative zero from the dividend', () {
      final result = BigDecimal.parse('-0.00') % BigDecimal.one;

      expect(result.isNegativeZero, isTrue);
      expect(result.toString(), '-0.00');
    });

    test('zero remainders clamp negative preferred exponents to scale zero', () {
      final result = BigDecimal.parse('0.00E+9') % BigDecimal.one;

      expect(result.toString(), '0');
      expect(result.scale, 0);
    });

    test('divide with context propagates, while exact and integer forms still throw', () {
      expect(
        BigDecimal.one.divide(BigDecimal.zero, context: DecimalContext.decimal128),
        BigDecimal.infinity(),
      );
      expect(
        () => BigDecimal.one.divideExact(BigDecimal.zero),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
      expect(
        () => BigDecimal.one ~/ BigDecimal.zero,
        throwsA(isA<BigDecimalArithmeticException>()),
      );
      expect(
        () => BigDecimal.one % BigDecimal.zero,
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });
  });
}
