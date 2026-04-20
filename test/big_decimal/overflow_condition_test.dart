import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

// A small custom context with tight exponent bounds for triggering overflow
// and underflow without needing astronomically large values.
//
// precision: 3, maxExponent: 3, minExponent: -3
//   → adjusted exponents allowed in [-6, 3]
//   → overflow when exponent > 3  (e.g. 1000 × 1000 = 1000000, adj-exp = 6)
//   → underflow when exponent < -6 AND non-zero (e.g. 1E-7, adj-exp = -7)
const _tightContext = DecimalContext(
  precision: 3,
  maxExponent: 3,
  minExponent: -3,
);

const _trappingOverflow = DecimalContext(
  precision: 3,
  maxExponent: 3,
  minExponent: -3,
  traps: <DecimalCondition>{DecimalCondition.overflow},
);

const _trappingUnderflow = DecimalContext(
  precision: 3,
  maxExponent: 3,
  minExponent: -3,
  traps: <DecimalCondition>{DecimalCondition.underflow},
);

void main() {
  group('Overflow condition via *Result API', () {
    test('multiplyResult emits overflow condition instead of throwing', () {
      // 9999 × 9999 = 99980001 → adj-exp = 7 > maxExponent 3 → overflow
      final a = BigDecimal.parse('9999');
      final b = BigDecimal.parse('9999');

      final result = a.multiplyResult(b, context: _tightContext);

      expect(result.conditions, contains(DecimalCondition.overflow));
      expect(result.conditions, isNot(contains(DecimalCondition.underflow)));
    });

    test('addResult emits overflow condition instead of throwing', () {
      // 9000 + 9000 = 18000 → adj-exp = 4 > maxExponent 3 → overflow
      final a = BigDecimal.parse('9000');
      final b = BigDecimal.parse('9000');

      final result = a.addResult(b, context: _tightContext);

      expect(result.conditions, contains(DecimalCondition.overflow));
    });

    test('divideResult emits overflow condition instead of throwing', () {
      // 10000 / 1 = 10000 → adj-exp = 4 > maxExponent 3 → overflow
      final a = BigDecimal.parse('10000');
      final b = BigDecimal.one;

      final result = a.divideResult(b, context: _tightContext);

      expect(result.conditions, contains(DecimalCondition.overflow));
    });

    test('roundResult emits overflow condition for large value', () {
      final value = BigDecimal.parse('9999');

      // With precision=3 → rounds to 10000 (adj-exp = 4 > 3) → overflow
      final result = value.roundResult(_tightContext);

      expect(result.conditions, contains(DecimalCondition.overflow));
    });
  });

  group('Overflow trapping via valueOrThrow', () {
    test('multiplyResult.valueOrThrow throws BigDecimalSignalException for overflow', () {
      final a = BigDecimal.parse('9999');
      final b = BigDecimal.parse('9999');

      final result = a.multiplyResult(b, context: _trappingOverflow);

      expect(
        () => result.valueOrThrow(_trappingOverflow),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (e) => e.condition,
            'condition',
            DecimalCondition.overflow,
          ),
        ),
      );
    });

    test('trapping API (multiply) throws BigDecimalSignalException for overflow', () {
      // multiply calls multiplyResult().valueOrThrow internally
      final a = BigDecimal.parse('9999');
      final b = BigDecimal.parse('9999');

      expect(
        () => a.multiply(b, context: _trappingOverflow),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (e) => e.condition,
            'condition',
            DecimalCondition.overflow,
          ),
        ),
      );
    });
  });

  group('Underflow condition via *Result API', () {
    test('multiplyResult emits underflow and subnormal conditions', () {
      // 1E-4 × 1E-4 = 1E-8 → adj-exp = -8 < minAllowedExponent -6 → underflow
      final a = BigDecimal.parse('1E-4');
      final b = BigDecimal.parse('1E-4');

      final result = a.multiplyResult(b, context: _tightContext);

      expect(result.conditions, contains(DecimalCondition.underflow));
      expect(result.conditions, contains(DecimalCondition.subnormal));
    });

    test('underflow trapping via valueOrThrow throws BigDecimalSignalException', () {
      final a = BigDecimal.parse('1E-4');
      final b = BigDecimal.parse('1E-4');

      final result = a.multiplyResult(b, context: _trappingUnderflow);

      expect(
        () => result.valueOrThrow(_trappingUnderflow),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (e) => e.condition,
            'condition',
            DecimalCondition.underflow,
          ),
        ),
      );
    });
  });

  group('Within-range operations still clean', () {
    test('multiplyResult with no overflow has no overflow/underflow conditions', () {
      // 10 × 10 = 100 → adj-exp = 2 ≤ maxExponent 3 → clean
      final result = BigDecimal.parse('10').multiplyResult(
        BigDecimal.parse('10'),
        context: _tightContext,
      );

      expect(result.conditions, isNot(contains(DecimalCondition.overflow)));
      expect(result.conditions, isNot(contains(DecimalCondition.underflow)));
    });
  });
}
