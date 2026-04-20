import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('BigDecimal.compareTo', () {
    // identical() short-circuit path
    test('returns 0 for the same instance', () {
      final value = BigDecimal.parse('3.14');

      expect(value.compareTo(value), 0);
    });

    // Both sides are zero; sign == 0 branch
    test('treats all zero representations as equal', () {
      expect(BigDecimal.parse('0.0').compareTo(BigDecimal.parse('0.00')), 0);
      expect(BigDecimal.zero.compareTo(BigDecimal.zero), 0);
      expect(BigDecimal.parse('-0.0').compareTo(BigDecimal.parse('0.00')), 0);
    });

    // Opposite-sign short-circuit before any rescaling
    test('orders values of opposite signs without rescaling', () {
      expect(BigDecimal.parse('-1').compareTo(BigDecimal.parse('1')), lessThan(0));
      expect(BigDecimal.parse('1').compareTo(BigDecimal.parse('-1')), greaterThan(0));
    });

    test('orders negative values correctly', () {
      expect(BigDecimal.parse('-2').compareTo(BigDecimal.parse('-1')), lessThan(0));
      expect(BigDecimal.parse('-1').compareTo(BigDecimal.parse('-2')), greaterThan(0));
      expect(BigDecimal.parse('-1.5').compareTo(BigDecimal.parse('-1.50')), 0);
    });

    // Same scale: direct unscaled comparison
    test('compares values with the same scale directly', () {
      expect(BigDecimal.parse('1.20').compareTo(BigDecimal.parse('1.20')), 0);
      expect(BigDecimal.parse('1.20').compareTo(BigDecimal.parse('1.21')), lessThan(0));
    });

    // Different scales but same numeric value: rescaling path
    test('treats numerically equal values with different scales as equal', () {
      expect(BigDecimal.parse('1.20').compareTo(BigDecimal.parse('1.2')), 0);
      expect(BigDecimal.parse('1.2').compareTo(BigDecimal.parse('1.20')), 0);
    });

    test('orders values with different scales correctly', () {
      expect(BigDecimal.parse('1.2').compareTo(BigDecimal.parse('1.21')), lessThan(0));
      expect(BigDecimal.parse('1.21').compareTo(BigDecimal.parse('1.2')), greaterThan(0));
    });

    // Magnitude check avoids rescaling values at opposite ends of the scale range
    test('compares extreme-magnitude values without overflow', () {
      final tiny = BigDecimal.parse('1e-10000');
      final huge = BigDecimal.parse('1e10000');

      expect(tiny.compareTo(huge), lessThan(0));
      expect(huge.compareTo(tiny), greaterThan(0));
    });
  });

  group('BigDecimal total-order helpers', () {
    test('compareTotal orders equal values by representation', () {
      expect(
        BigDecimal.parse('12.30').compareTotal(BigDecimal.parse('12.3')),
        lessThan(0),
      );
      expect(
        BigDecimal.parse('12.3').compareTotal(BigDecimal.parse('12.300')),
        greaterThan(0),
      );
    });

    test('compareTotal reverses representation order for negative values', () {
      expect(
        BigDecimal.parse('-7.0').compareTotal(BigDecimal.parse('-7')),
        greaterThan(0),
      );
      expect(
        BigDecimal.parse('-7').compareTotal(BigDecimal.parse('-7.0')),
        lessThan(0),
      );
    });

    test('compareTotal orders negative zero before positive zero', () {
      expect(
        BigDecimal.parse('-0.0').compareTotal(BigDecimal.parse('0.0')),
        lessThan(0),
      );
    });

    test('compareTotal falls back to numeric order when values differ', () {
      expect(
        BigDecimal.parse('-2').compareTotal(BigDecimal.parse('-1')),
        lessThan(0),
      );
      expect(
        BigDecimal.parse('2').compareTotal(BigDecimal.parse('-2')),
        greaterThan(0),
      );
    });

    test('compareTotalMagnitude ignores sign when magnitudes match', () {
      expect(
        BigDecimal.parse('-2.00').compareTotalMagnitude(BigDecimal.parse('2.00')),
        0,
      );
      expect(
        BigDecimal.parse('12.30').compareTotalMagnitude(BigDecimal.parse('12.3')),
        lessThan(0),
      );
    });

    test('sameQuantum compares scale instead of numeric value', () {
      expect(
        BigDecimal.parse('111E-1').sameQuantum(BigDecimal.parse('22.2')),
        isTrue,
      );
      expect(
        BigDecimal.parse('10').sameQuantum(BigDecimal.parse('1E+1')),
        isFalse,
      );
      expect(
        BigDecimal.parse('0.0').sameQuantum(BigDecimal.parse('1.1')),
        isTrue,
      );
    });

    test('maxMagnitude uses total-order tie-breaking for equal magnitudes', () {
      expect(
        BigDecimal.maxMagnitude(BigDecimal.parse('-2.0'), BigDecimal.parse('2.00')),
        BigDecimal.parse('2.00'),
      );
      expect(
        BigDecimal.maxMagnitude(BigDecimal.parse('1.00'), BigDecimal.parse('1')),
        BigDecimal.parse('1'),
      );
    });

    test('minMagnitude uses total-order tie-breaking for equal magnitudes', () {
      expect(
        BigDecimal.minMagnitude(BigDecimal.parse('-2.0'), BigDecimal.parse('2.00')),
        BigDecimal.parse('-2.0'),
      );
      expect(
        BigDecimal.minMagnitude(BigDecimal.parse('1.00'), BigDecimal.parse('1')),
        BigDecimal.parse('1.00'),
      );
    });

    test('min and max return the first NaN when both operands are NaN', () {
      final left = BigDecimal.nan();
      final right = BigDecimal.nan();

      expect(BigDecimal.min(left, right), same(left));
      expect(BigDecimal.max(left, right), same(left));
    });

    test('magnitude min and max return the first NaN when both operands are NaN', () {
      final left = BigDecimal.nan();
      final right = BigDecimal.nan();

      expect(BigDecimal.minMagnitude(left, right), same(left));
      expect(BigDecimal.maxMagnitude(left, right), same(left));
    });
  });

  group('BigDecimal == and hashCode', () {
    // == is defined by compareTo == 0, not by representation
    test('treats numerically equal values as equal regardless of scale', () {
      expect(BigDecimal.parse('1.0'), BigDecimal.parse('1.00'));
      expect(BigDecimal.parse('-1.0'), BigDecimal.parse('-1.00'));
    });

    test('equal values produce the same hash code', () {
      expect(BigDecimal.parse('1.0').hashCode, BigDecimal.parse('1.00').hashCode);
      expect(BigDecimal.parse('0').hashCode, BigDecimal.zero.hashCode);
      expect(BigDecimal.parse('10.0').hashCode, BigDecimal.ten.hashCode);
    });

    test('coalesces equal representations in a Set', () {
      final values = {
        BigDecimal.parse('1'),
        BigDecimal.parse('1.0'),
        BigDecimal.parse('1.00'),
        BigDecimal.parse('0'),
        BigDecimal.parse('0.000'),
      };

      expect(values, hasLength(2));
    });

    test('normalizes trailing zeros for negative values too', () {
      expect(BigDecimal.parse('-120.00').hashCode, BigDecimal.parse('-120').hashCode);
      expect(BigDecimal.parse('-0.0').hashCode, BigDecimal.zero.hashCode);
    });

    test('returns false when compared to a non-BigDecimal object', () {
      expect(BigDecimal.parse('1.0') == ('not a BigDecimal' as dynamic), isFalse);
      expect(BigDecimal.parse('1.0') == (1 as dynamic), isFalse);
    });
  });
}
