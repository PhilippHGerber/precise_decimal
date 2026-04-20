import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('IntToBigDecimal', () {
    test('converts a positive int exactly', () {
      expect(5.toBigDecimal(), BigDecimal.fromInt(5));
    });

    test('converts zero', () {
      expect(0.toBigDecimal(), BigDecimal.zero);
    });

    test('converts a negative int exactly', () {
      expect((-42).toBigDecimal(), BigDecimal.fromInt(-42));
    });

    test('integrates with arithmetic operators', () {
      final result = 5.toBigDecimal() + BigDecimal.parse('0.5');
      expect(result.toString(), '5.5');
    });
  });

  group('DoubleToBigDecimal.toBigDecimalShortest', () {
    test('preserves the shortest displayed form', () {
      expect(0.1.toBigDecimalShortest().toString(), '0.1');
    });

    test('converts a whole-number double', () {
      expect(5.0.toBigDecimalShortest(), BigDecimal.parse('5.0'));
    });

    test('rejects non-finite values', () {
      expect(
        () => double.nan.toBigDecimalShortest(),
        throwsA(isA<BigDecimalConversionException>()),
      );
      expect(
        () => double.infinity.toBigDecimalShortest(),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });

  group('DoubleToBigDecimal.toBigDecimalExact', () {
    test('exposes the exact IEEE-754 value for 0.1', () {
      expect(
        0.1.toBigDecimalExact().toString(),
        '0.1000000000000000055511151231257827021181583404541015625',
      );
    });

    test('matches shortest form for values that are exact in binary', () {
      expect(
        0.5.toBigDecimalExact(),
        0.5.toBigDecimalShortest(),
      );
    });

    test('rejects non-finite values', () {
      expect(
        () => double.nan.toBigDecimalExact(),
        throwsA(isA<BigDecimalConversionException>()),
      );
    });
  });
}
