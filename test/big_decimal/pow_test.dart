import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.powExact', () {
    test('raises positive integers exactly', () {
      final result = BigDecimal.fromInt(2).powExact(10);

      expect(result.toString(), '1024');
      expect(result.scale, 0);
    });

    test('preserves sign for odd exponents', () {
      final result = BigDecimal.fromInt(-2).powExact(3);

      expect(result.toString(), '-8');
      expect(result.scale, 0);
    });

    test('handles terminating negative exponents exactly', () {
      final result = BigDecimal.fromInt(2).powExact(-3);

      expect(result.toString(), '0.125');
      expect(result.scale, 3);
    });

    test('returns one for zero exponent on non-zero bases', () {
      final result = BigDecimal.parse('12.30').powExact(0);

      expect(result, equals(BigDecimal.one));
      expect(result.scale, 0);
    });

    test('canonicalizes zero powers while preserving odd negative-zero sign', () {
      final negativeOdd = BigDecimal.parse('-0.00').powExact(3);
      final negativeEven = BigDecimal.parse('-0.00').powExact(2);
      final positiveScaled = BigDecimal.parse('0E+30').powExact(3);

      expect(negativeOdd.isNegativeZero, isTrue);
      expect(negativeOdd.scale, 0);
      expect(negativeOdd.toString(), '-0');
      expect(negativeEven.isNegativeZero, isFalse);
      expect(negativeEven.scale, 0);
      expect(negativeEven.toString(), '0');
      expect(positiveScaled.scale, 0);
      expect(positiveScaled.toString(), '0');
    });

    test('throws for zero to the zero power', () {
      expect(
        () => BigDecimal.zero.powExact(0),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('throws for zero to a negative power', () {
      expect(
        () => BigDecimal.zero.powExact(-1),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('guards exact mode against huge exponents', () {
      expect(
        () => BigDecimal.fromInt(2).powExact(1000000000),
        throwsA(isA<BigDecimalOverflowException>()),
      );
    });

    test('supports huge exponents for canonical base one', () {
      final result = BigDecimal.one.powExact(4300000000);

      expect(result, BigDecimal.one);
    });

    test('supports huge exponents for canonical base negative one', () {
      final odd = BigDecimal.fromInt(-1).powExact(4300000001);
      final even = BigDecimal.fromInt(-1).powExact(4300000000);

      expect(odd.toString(), '-1');
      expect(even.toString(), '1');
    });
  });

  group('BigDecimal.powResult', () {
    test('keeps exact negative powers of ten quiet when the final context fits', () {
      const context = DecimalContext(
        precision: 16,
        maxExponent: 384,
        minExponent: -383,
      );

      final regular = BigDecimal.fromInt(10).powResult(-77, context: context);
      final boundary = BigDecimal.fromInt(10).powResult(-383, context: context);

      expect(regular.value.toScientificString(), '1E-77');
      expect(regular.conditions, isEmpty);
      expect(boundary.value.toScientificString(), '1E-383');
      expect(boundary.conditions, isEmpty);
    });

    test('rounds large powers with a bounded context', () {
      const context = DecimalContext(precision: 5);

      final result = BigDecimal.fromInt(99999).powResult(99999, context: context);

      expect(result.value.toScientificString(), '3.6788E+499994');
      expect(result.conditions, contains(DecimalCondition.rounded));
      expect(result.conditions, contains(DecimalCondition.inexact));
    });

    test('rounds non-terminating reciprocal paths through divideResult', () {
      const context = DecimalContext(precision: 5);

      final result = BigDecimal.fromInt(3).powResult(-2, context: context);

      expect(result.value.toString(), '0.11111');
      expect(result.conditions, contains(DecimalCondition.rounded));
      expect(result.conditions, contains(DecimalCondition.inexact));
    });

    test('throws for non-terminating reciprocal with unlimited precision', () {
      expect(
        () => BigDecimal.fromInt(3).powResult(-2, context: DecimalContext.unlimited),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('powResult supports huge exponents for canonical base one', () {
      const context = DecimalContext(precision: 5);

      final result = BigDecimal.one.powResult(4300000000, context: context);

      expect(result.value, BigDecimal.one);
      expect(result.conditions, isEmpty);
    });

    test('powResult treats scaled positive one as unit base for huge exponents', () {
      const context = DecimalContext.decimal128;

      final positive = BigDecimal.parse('1.0').powResult(1000000000, context: context);
      final negative = BigDecimal.parse('1.00').powResult(-1000000000, context: context);

      expect(positive.value, BigDecimal.one);
      expect(positive.conditions, isEmpty);
      expect(negative.value, BigDecimal.one);
      expect(negative.conditions, isEmpty);
    });

    test('powResult preserves parity for scaled negative one with huge exponents', () {
      const context = DecimalContext.decimal128;

      final odd = BigDecimal.parse('-1.0').powResult(1000000001, context: context);
      final even = BigDecimal.parse('-1.0').powResult(1000000000, context: context);

      expect(odd.value, BigDecimal.minusOne);
      expect(odd.conditions, isEmpty);
      expect(even.value, BigDecimal.one);
      expect(even.conditions, isEmpty);
    });
  });

  group('BigDecimal.pow trapping', () {
    test('traps invalidOperation for zero to the zero power', () {
      const context = DecimalContext(
        precision: 5,
        traps: <DecimalCondition>{DecimalCondition.invalidOperation},
      );

      expect(
        () => BigDecimal.zero.pow(0, context: context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.invalidOperation,
          ),
        ),
      );
    });

    test('zero to a negative power returns Infinity with no conditions (GDA rule)', () {
      const context = DecimalContext(precision: 5);

      final result = BigDecimal.zero.powResult(-1, context: context);
      expect(result.value, equals(BigDecimal.infinity()));
      // GDA rule: 0^-n = Infinity with no condition (not divisionByZero).
      expect(result.conditions, isEmpty);
    });

    test('traps rounded for bounded-precision powers', () {
      const context = DecimalContext(
        precision: 5,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.fromInt(99999).pow(99999, context: context),
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
