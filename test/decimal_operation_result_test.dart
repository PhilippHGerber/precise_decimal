import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('DecimalOperationResult', () {
    test('stores value and conditions', () {
      final result = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.parse('1.23'),
        conditions: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(result.value.toString(), '1.23');
      expect(result.conditions, equals(<DecimalCondition>{DecimalCondition.rounded}));
      expect(result.hasCondition(DecimalCondition.rounded), isTrue);
      expect(result.hasCondition(DecimalCondition.inexact), isFalse);
    });

    test('conditions are immutable', () {
      final result = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.one,
        conditions: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(
        () => result.conditions.add(DecimalCondition.inexact),
        throwsUnsupportedError,
      );
    });

    test('valueOrThrow returns value when no trapped condition is present', () {
      const context = DecimalContext(
        traps: <DecimalCondition>{DecimalCondition.invalidOperation},
      );
      final result = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.parse('9.99'),
        conditions: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(result.valueOrThrow(context), equals(BigDecimal.parse('9.99')));
    });

    test('valueOrThrow traps according decimal condition precedence', () {
      const context = DecimalContext(
        traps: <DecimalCondition>{
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        },
      );
      final result = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.parse('1.23'),
        conditions: <DecimalCondition>{
          DecimalCondition.rounded,
          DecimalCondition.inexact,
        },
      );

      expect(
        () => result.valueOrThrow(context),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.inexact,
          ),
        ),
      );
    });

    test('supports equality and hashCode by value and condition set', () {
      final left = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.parse('1.23'),
        conditions: <DecimalCondition>{
          DecimalCondition.rounded,
          DecimalCondition.inexact,
        },
      );
      final right = DecimalOperationResult<BigDecimal>(
        value: BigDecimal.parse('1.23'),
        conditions: <DecimalCondition>{
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        },
      );

      expect(left, equals(right));
      expect(left.hashCode, equals(right.hashCode));
    });
  });
}
