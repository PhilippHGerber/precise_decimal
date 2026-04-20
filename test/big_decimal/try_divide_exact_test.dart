import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('BigDecimal.tryDivideExact', () {
    test('returns the exact quotient for terminating division', () {
      final result = BigDecimal.one.tryDivideExact(BigDecimal.fromInt(4));
      expect(result, isNotNull);
      expect(result, BigDecimal.parse('0.25'));
    });

    test('returns null for non-terminating division (1/3)', () {
      final result = BigDecimal.one.tryDivideExact(BigDecimal.fromInt(3));
      expect(result, isNull);
    });

    test('returns null for non-terminating division (1/7)', () {
      final result = BigDecimal.one.tryDivideExact(BigDecimal.fromInt(7));
      expect(result, isNull);
    });

    test('integer division that reduces exactly', () {
      final result = BigDecimal.fromInt(10).tryDivideExact(BigDecimal.fromInt(2));
      expect(result, BigDecimal.fromInt(5));
    });

    test('matches divideExact on terminating division', () {
      final a = BigDecimal.parse('3.5');
      final b = BigDecimal.parse('2');
      expect(a.tryDivideExact(b), a.divideExact(b));
    });

    test('divideExact throws where tryDivideExact returns null', () {
      final a = BigDecimal.one;
      final b = BigDecimal.fromInt(3);
      expect(a.tryDivideExact(b), isNull);
      expect(() => a.divideExact(b), throwsA(isA<BigDecimalArithmeticException>()));
    });
  });
}
