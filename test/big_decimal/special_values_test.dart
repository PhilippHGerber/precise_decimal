import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import '../finite_access.dart';

void main() {
  group('BigDecimal special value parsing and factories', () {
    test('parses infinity tokens case-insensitively', () {
      expect(BigDecimal.parse('Infinity').toString(), 'Infinity');
      expect(BigDecimal.parse('-inf').toString(), '-Infinity');
      expect(BigDecimal.parse('+InFiNiTy').toString(), 'Infinity');
      expect(BigDecimal.infinity().toString(), 'Infinity');
      expect(BigDecimal.infinity(negative: true).toString(), '-Infinity');
    });

    test('parses quiet and signaling NaN diagnostics', () {
      final quiet = BigDecimal.parse('NaN123');
      final signaling = BigDecimal.parse('-sNaN45');

      expect(quiet.isNaN, isTrue);
      expect(quiet.isSignalingNan, isFalse);
      expect(quiet.diagnostic, '123');
      expect(quiet.toString(), 'NaN123');

      expect(signaling.isNaN, isTrue);
      expect(signaling.isSignalingNan, isTrue);
      expect(signaling.hasNegativeSign, isTrue);
      expect(signaling.diagnostic, '45');
      expect(signaling.toString(), '-sNaN45');
    });

    test('rejects non-digit NaN diagnostics', () {
      expect(
        () => BigDecimal.nan(diagnostic: '12x'),
        throwsArgumentError,
      );
    });

    test('rejects malformed special tokens', () {
      for (final invalid in ['infx', 'infinite', 'snanx', 'nan-1', 'sna']) {
        expect(
          () => BigDecimal.parse(invalid),
          throwsA(isA<BigDecimalParseException>()),
          reason: '"$invalid" should be rejected',
        );
      }
    });

    test('tryParse returns null for malformed special tokens', () {
      expect(BigDecimal.tryParse('infx'), isNull);
      expect(BigDecimal.tryParse('snanx'), isNull);
      expect(BigDecimal.tryParse('nan-1'), isNull);
    });
  });

  group('BigDecimal special value formatting', () {
    test('uses the same canonical token across string formatters', () {
      final infinity = BigDecimal.infinity(negative: true);
      final nan = BigDecimal.nan(signaling: true, diagnostic: '9');

      expect(infinity.toPlainString(), '-Infinity');
      expect(infinity.toScientificString(), '-Infinity');
      expect(infinity.toEngineeringString(), '-Infinity');
      expect(infinity.toGdaString(), '-Infinity');

      expect(nan.toPlainString(), 'sNaN9');
      expect(nan.toScientificString(), 'sNaN9');
      expect(nan.toEngineeringString(), 'sNaN9');
      expect(nan.toGdaString(), 'sNaN9');
    });
  });

  group('BigDecimal special value metadata', () {
    test('reports form predicates correctly', () {
      final finite = BigDecimal.one;
      final infinity = BigDecimal.infinity();
      final nan = BigDecimal.nan();
      final signaling = BigDecimal.nan(signaling: true);

      expect(finite.isFinite, isTrue);
      expect(finite.isInfinite, isFalse);
      expect(finite.isNaN, isFalse);

      expect(infinity.isFinite, isFalse);
      expect(infinity.isInfinite, isTrue);
      expect(infinity.isNaN, isFalse);

      expect(nan.isNaN, isTrue);
      expect(nan.isSignalingNan, isFalse);
      expect(signaling.isNaN, isTrue);
      expect(signaling.isSignalingNan, isTrue);
    });

    test('throws when accessing finite-only metadata on special values', () {
      final infinity = BigDecimal.infinity();

      expect(() => infinity.unscaledValue, throwsStateError);
      expect(() => infinity.scale, throwsStateError);
      expect(() => infinity.precision, throwsStateError);
      expect(() => infinity.isNegativeScale, throwsStateError);
      expect(() => infinity.isInteger, throwsStateError);
    });
  });

  group('BigDecimal special value equality and comparison', () {
    test('treats infinities as equal by sign and NaN as unequal to everything', () {
      expect(BigDecimal.infinity(), equals(BigDecimal.infinity()));
      expect(BigDecimal.infinity(), isNot(equals(BigDecimal.infinity(negative: true))));

      final nan = BigDecimal.nan();
      expect(nan == nan, isFalse);
      expect(nan == BigDecimal.nan(), isFalse);
    });

    test('orders infinities, finite values, and NaNs deterministically', () {
      final negativeInfinity = BigDecimal.infinity(negative: true);
      final finite = BigDecimal.one;
      final positiveInfinity = BigDecimal.infinity();
      final quietNan = BigDecimal.nan();
      final signalingNan = BigDecimal.nan(signaling: true);

      expect(negativeInfinity.compareTo(finite), lessThan(0));
      expect(finite.compareTo(positiveInfinity), lessThan(0));
      expect(positiveInfinity.compareTo(quietNan), lessThan(0));
      expect(quietNan.compareTo(signalingNan), lessThan(0));
    });

    test('uses total-order helpers with special values', () {
      expect(BigDecimal.infinity().compareTo(BigDecimal.one), greaterThan(0));
      expect(BigDecimal.infinity(negative: true).compareTo(BigDecimal.one), lessThan(0));

      final quietNan = BigDecimal.nan();
      final signalingNan = BigDecimal.nan(signaling: true);

      expect(quietNan.compareTotal(signalingNan), lessThan(0));
      expect(quietNan.compareTotalMagnitude(signalingNan), lessThan(0));
      expect(
        BigDecimal.max(BigDecimal.fromInt(5), BigDecimal.nan()),
        BigDecimal.fromInt(5),
      );
      expect(
        BigDecimal.min(BigDecimal.fromInt(-5), BigDecimal.nan()),
        BigDecimal.fromInt(-5),
      );
    });
  });

  group('BigDecimal special value conversion', () {
    test('toDouble returns Dart non-finite values', () {
      expect(BigDecimal.infinity().toDouble(), double.infinity);
      expect(BigDecimal.infinity(negative: true).toDouble(), double.negativeInfinity);
      expect(BigDecimal.nan().toDouble().isNaN, isTrue);
    });

    test('JSON round-trips through string serialization', () {
      final value = BigDecimal.parse('-sNaN42');

      expect(BigDecimal.fromJson(value.toJson()).toString(), '-sNaN42');
    });
  });

  group('BigDecimal special values remain outside finite-only arithmetic', () {
    test('keeps finite-only exact arithmetic strict', () {
      expect(
        () => BigDecimal.infinity().powExact(2),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
      expect(
        () => BigDecimal.infinity().divideExact(BigDecimal.one),
        throwsA(isA<BigDecimalArithmeticException>()),
      );
    });

    test('propagates add and multiply special values in result APIs', () {
      final addInf = BigDecimal.infinity().addResult(
        BigDecimal.one,
        context: const DecimalContext(precision: 10),
      );
      final addInvalid = BigDecimal.infinity().addResult(
        BigDecimal.infinity(negative: true),
        context: const DecimalContext(precision: 10),
      );
      final mulInvalid = BigDecimal.infinity().multiplyResult(
        BigDecimal.zero,
        context: const DecimalContext(precision: 10),
      );

      expect(addInf.value.toString(), 'Infinity');
      expect(addInf.conditions, isEmpty);
      expect(addInvalid.value.isNaN, isTrue);
      expect(addInvalid.conditions, contains(DecimalCondition.invalidOperation));
      expect(mulInvalid.value.isNaN, isTrue);
      expect(mulInvalid.conditions, contains(DecimalCondition.invalidOperation));
    });

    test('propagates divide special cases and trap behavior', () {
      const ctx = DecimalContext(precision: 10);

      final finiteOverZero = BigDecimal.one.divideResult(BigDecimal.zero, context: ctx);
      final zeroOverZero = BigDecimal.zero.divideResult(BigDecimal.zero, context: ctx);

      expect(finiteOverZero.value.toString(), 'Infinity');
      expect(finiteOverZero.conditions, contains(DecimalCondition.divisionByZero));
      expect(zeroOverZero.value.isNaN, isTrue);
      // GDA rule: 0/0 raises only invalidOperation, NOT divisionByZero.
      expect(zeroOverZero.conditions, isNot(contains(DecimalCondition.divisionByZero)));
      expect(zeroOverZero.conditions, contains(DecimalCondition.invalidOperation));

      const trappingCtx = DecimalContext(
        precision: 10,
        traps: <DecimalCondition>{DecimalCondition.divisionByZero},
      );
      expect(
        () => BigDecimal.one.divide(BigDecimal.zero, context: trappingCtx),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.divisionByZero,
          ),
        ),
      );
    });

    test('propagates pow and sqrt special result cases', () {
      const ctx = DecimalContext(precision: 10);

      final zeroToZero = BigDecimal.zero.powResult(0, context: ctx);
      final zeroToNegative = BigDecimal.zero.powResult(-1, context: ctx);
      final negSqrt = BigDecimal.fromInt(-1).sqrtResult(context: ctx);
      final infSqrt = BigDecimal.infinity().sqrtResult(context: ctx);

      expect(zeroToZero.value.isNaN, isTrue);
      expect(zeroToZero.conditions, contains(DecimalCondition.invalidOperation));
      expect(zeroToNegative.value.toString(), 'Infinity');
      // GDA rule: 0^-n = Infinity with no condition (not divisionByZero).
      expect(zeroToNegative.conditions, isEmpty);

      expect(negSqrt.value.isNaN, isTrue);
      expect(negSqrt.conditions, contains(DecimalCondition.invalidOperation));
      expect(infSqrt.value.toString(), 'Infinity');
      expect(infSqrt.conditions, isEmpty);
    });
  });
}
