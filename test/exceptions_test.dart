import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Exception messages and toString', () {
    test('BigDecimalParseException carries message and formats toString', () {
      const ex = BigDecimalParseException('bad input', 'invalid');

      expect(ex.message, 'bad input');
      expect(ex.toString(), 'BigDecimalParseException: bad input');
    });

    test('BigDecimalArithmeticException carries message and formats toString', () {
      const ex = BigDecimalArithmeticException('cannot divide by zero');

      expect(ex.message, 'cannot divide by zero');
      expect(ex.toString(), 'BigDecimalArithmeticException: cannot divide by zero');
    });

    test('BigDecimalOverflowException carries message and formats toString', () {
      const ex = BigDecimalOverflowException('scale out of range');

      expect(ex.message, 'scale out of range');
      expect(ex.toString(), 'BigDecimalOverflowException: scale out of range');
    });

    test('BigDecimalConversionException carries message and formats toString', () {
      const ex = BigDecimalConversionException('non-finite double');

      expect(ex.message, 'non-finite double');
      expect(ex.toString(), 'BigDecimalConversionException: non-finite double');
    });

    test('BigDecimalSignalException carries condition and message', () {
      const ex = BigDecimalSignalException(
        DecimalCondition.invalidOperation,
        'Trapped decimal condition: invalid_operation',
      );

      expect(ex.condition, DecimalCondition.invalidOperation);
      expect(ex.message, 'Trapped decimal condition: invalid_operation');
      expect(
        ex.toString(),
        'BigDecimalSignalException(invalidOperation): Trapped decimal condition: invalid_operation',
      );
    });
  });

  group('Exception type hierarchy', () {
    test('all package exceptions are catchable as BigDecimalException', () {
      expect(
        const BigDecimalParseException('', ''),
        isA<BigDecimalException>(),
      );
      expect(
        const BigDecimalArithmeticException(''),
        isA<BigDecimalException>(),
      );
      expect(
        const BigDecimalOverflowException(''),
        isA<BigDecimalException>(),
      );
      expect(
        const BigDecimalConversionException(''),
        isA<BigDecimalException>(),
      );
      expect(
        const BigDecimalSignalException(DecimalCondition.rounded, ''),
        isA<BigDecimalException>(),
      );
    });

    // Overflow is a specific kind of arithmetic failure
    test('BigDecimalOverflowException extends BigDecimalArithmeticException', () {
      expect(
        const BigDecimalOverflowException(''),
        isA<BigDecimalArithmeticException>(),
      );
    });

    test('BigDecimalSignalException extends BigDecimalArithmeticException', () {
      expect(
        const BigDecimalSignalException(DecimalCondition.rounded, ''),
        isA<BigDecimalArithmeticException>(),
      );
    });
  });

  group('Polymorphic catch via public API', () {
    test('parse failures are catchable as BigDecimalException', () {
      expect(
        () => BigDecimal.parse('invalid'),
        throwsA(isA<BigDecimalException>()),
      );
    });

    test('parse failures remain catchable as FormatException', () {
      expect(
        () => BigDecimal.parse('invalid'),
        throwsA(isA<FormatException>()),
      );
    });

    test('overflow failures are catchable as BigDecimalArithmeticException', () {
      expect(
        () => BigDecimal.fromComponents(BigInt.one, scale: 1000000000),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('conversion failures are catchable as BigDecimalException', () {
      expect(
        () => BigDecimal.fromDouble(double.nan),
        throwsA(isA<BigDecimalException>()),
      );
    });
  });
}
