import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal.sqrtExact', () {
    test('returns exact square roots', () {
      expect(BigDecimal.parse('0.25').sqrtExact().toString(), '0.5');
      expect(BigDecimal.fromInt(4).sqrtExact().toString(), '2');
      expect(BigDecimal.fromInt(100).sqrtExact().toString(), '10');
    });

    test('preserves preferred scale for exact representable results', () {
      expect(BigDecimal.parse('1.00').sqrtExact().toString(), '1.0');
      expect(BigDecimal.parse('4.00').sqrtExact().toString(), '2.0');
      expect(BigDecimal.parse('100.00').sqrtExact().toString(), '10.0');
    });

    test('preserves negative zero and preferred zero scale', () {
      final result = BigDecimal.parse('-0.000').sqrtExact();

      expect(result.isNegativeZero, isTrue);
      expect(result.scale, 2);
      expect(result.toString(), '-0.00');
    });

    test('throws for irrational roots', () {
      expect(
        () => BigDecimal.fromInt(2).sqrtExact(),
        throwsA(
          isA<BigDecimalArithmeticException>().having(
            (exception) => exception.message,
            'message',
            contains('irrational'),
          ),
        ),
      );
    });

    test('throws for negative values', () {
      expect(
        () => BigDecimal.fromInt(-4).sqrtExact(),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });
  });

  group('BigDecimal.sqrtResult', () {
    test('rounds irrational roots with decimal32 precision', () {
      const context = DecimalContext.decimal32;

      final result = BigDecimal.fromInt(2).sqrtResult(context: context);

      expect(result.value.toString(), '1.414214');
      expect(result.conditions, contains(DecimalCondition.rounded));
      expect(result.conditions, contains(DecimalCondition.inexact));
    });

    test('uses half-even rounding regardless of context rounding mode', () {
      const context = DecimalContext(
        precision: 5,
        roundingMode: RoundingMode.up,
      );

      final result = BigDecimal.fromInt(2).sqrt(context: context);

      expect(result.toString(), '1.4142');
    });

    test('treats unlimited precision context like exact mode', () {
      expect(
        () => BigDecimal.fromInt(2).sqrt(context: DecimalContext.unlimited),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('returns exact roots without conditions when context is bounded', () {
      const context = DecimalContext(precision: 7);

      final result = BigDecimal.parse('0.01').sqrtResult(context: context);

      expect(result.value.toString(), '0.1');
      expect(result.conditions, isEmpty);
    });
  });

  group('BigDecimal.sqrt trapping', () {
    test('traps invalidOperation for negative inputs', () {
      const context = DecimalContext(
        precision: 7,
        traps: <DecimalCondition>{DecimalCondition.invalidOperation},
      );

      expect(
        () => BigDecimal.fromInt(-4).sqrt(context: context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.invalidOperation,
          ),
        ),
      );
    });

    test('traps rounded when the rounded result is inexact', () {
      const context = DecimalContext(
        precision: 7,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => BigDecimal.fromInt(2).sqrt(context: context),
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
