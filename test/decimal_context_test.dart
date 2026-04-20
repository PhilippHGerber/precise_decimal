import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('DecimalContext presets', () {
    // IEEE interchange presets mirror the decimal32/64/128 formats
    test('decimal32 has IEEE precision and exponent bounds', () {
      expect(DecimalContext.decimal32.precision, 7);
      expect(DecimalContext.decimal32.roundingMode, RoundingMode.halfEven);
      expect(DecimalContext.decimal32.maxExponent, 96);
      expect(DecimalContext.decimal32.minExponent, -95);
      expect(DecimalContext.decimal32.extended, isFalse);
      expect(DecimalContext.decimal32.clamp, isTrue);
    });

    test('decimal64 has IEEE precision and exponent bounds', () {
      expect(DecimalContext.decimal64.precision, 16);
      expect(DecimalContext.decimal64.roundingMode, RoundingMode.halfEven);
      expect(DecimalContext.decimal64.maxExponent, 384);
      expect(DecimalContext.decimal64.minExponent, -383);
      expect(DecimalContext.decimal64.extended, isFalse);
      expect(DecimalContext.decimal64.clamp, isTrue);
    });

    test('decimal128 has IEEE precision and exponent bounds', () {
      expect(DecimalContext.decimal128.precision, 34);
      expect(DecimalContext.decimal128.roundingMode, RoundingMode.halfEven);
      expect(DecimalContext.decimal128.maxExponent, 6144);
      expect(DecimalContext.decimal128.minExponent, -6143);
      expect(DecimalContext.decimal128.extended, isFalse);
      expect(DecimalContext.decimal128.clamp, isTrue);
    });

    test('unlimited has no exponent bounds or traps', () {
      expect(DecimalContext.unlimited.precision, isNull);
      expect(DecimalContext.unlimited.maxExponent, isNull);
      expect(DecimalContext.unlimited.minExponent, isNull);
      expect(DecimalContext.unlimited.extended, isTrue);
      expect(DecimalContext.unlimited.clamp, isFalse);
      expect(DecimalContext.unlimited.traps, isEmpty);
    });

    test('defaultContext is decimal128', () {
      expect(DecimalContext.defaultContext, DecimalContext.decimal128);
    });
  });

  group('DecimalContext.copyWith', () {
    test('replaces precision while keeping roundingMode', () {
      const ctx = DecimalContext(precision: 10, roundingMode: RoundingMode.up);
      final copy = ctx.copyWith(precision: 5);

      expect(copy.precision, 5);
      expect(copy.roundingMode, RoundingMode.up);
    });

    test('can clear nullable bounds via copyWith', () {
      const ctx = DecimalContext(
        precision: 10,
        maxExponent: 9,
        minExponent: -9,
        clamp: true,
      );
      final copy = ctx.copyWith(maxExponent: null, minExponent: null, clamp: false);

      expect(copy.maxExponent, isNull);
      expect(copy.minExponent, isNull);
      expect(copy.clamp, isFalse);
    });

    test('replaces roundingMode while keeping precision', () {
      const ctx = DecimalContext(precision: 10);
      final copy = ctx.copyWith(roundingMode: RoundingMode.floor);

      expect(copy.precision, 10);
      expect(copy.roundingMode, RoundingMode.floor);
    });

    test('with no arguments produces an equal copy', () {
      const ctx = DecimalContext(precision: 7, roundingMode: RoundingMode.floor);

      expect(ctx.copyWith(), ctx);
    });

    test('replaces exponent metadata and traps', () {
      const ctx = DecimalContext(
        precision: 7,
        maxExponent: 10,
        minExponent: -10,
      );
      final copy = ctx.copyWith(
        extended: false,
        clamp: true,
        traps: const <DecimalCondition>{
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        },
      );

      expect(copy.maxExponent, 10);
      expect(copy.minExponent, -10);
      expect(copy.extended, isFalse);
      expect(copy.clamp, isTrue);
      expect(copy.traps, const <DecimalCondition>{
        DecimalCondition.inexact,
        DecimalCondition.rounded,
      });
    });
  });

  group('DecimalContext equality and hashCode', () {
    test('equal when all fields match', () {
      const a = DecimalContext(
        precision: 5,
        roundingMode: RoundingMode.up,
        maxExponent: 10,
        minExponent: -10,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );
      const b = DecimalContext(
        precision: 5,
        roundingMode: RoundingMode.up,
        maxExponent: 10,
        minExponent: -10,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(a, equals(b));
    });

    test('not equal when precision differs', () {
      const a = DecimalContext(precision: 5, roundingMode: RoundingMode.up);
      const c = DecimalContext(precision: 6, roundingMode: RoundingMode.up);

      expect(a, isNot(equals(c)));
    });

    test('not equal when roundingMode differs', () {
      const a = DecimalContext(precision: 5, roundingMode: RoundingMode.up);
      const d = DecimalContext(precision: 5, roundingMode: RoundingMode.down);

      expect(a, isNot(equals(d)));
    });

    test('not equal when trap sets differ', () {
      const a = DecimalContext(
        precision: 5,
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );
      const b = DecimalContext(
        precision: 5,
        traps: <DecimalCondition>{DecimalCondition.inexact},
      );

      expect(a, isNot(equals(b)));
    });

    test('not equal to a non-DecimalContext object', () {
      const a = DecimalContext(precision: 5, roundingMode: RoundingMode.up);

      expect(a == ('not a context' as dynamic), isFalse);
    });

    test('equal contexts produce the same hash code', () {
      const a = DecimalContext(precision: 5, roundingMode: RoundingMode.up);
      const b = DecimalContext(precision: 5, roundingMode: RoundingMode.up);

      expect(a.hashCode, b.hashCode);
    });
  });

  group('DecimalContext.toString', () {
    test('includes IEEE metadata', () {
      final str = DecimalContext.decimal32.toString();

      expect(str, contains('7'));
      expect(str, contains('halfEven'));
      expect(str, contains('96'));
      expect(str, contains('clamp: true'));
    });

    test('shows null for unlimited precision', () {
      expect(DecimalContext.unlimited.toString(), contains('null'));
    });

    test('reports trap membership', () {
      const context = DecimalContext(
        traps: <DecimalCondition>{DecimalCondition.rounded},
      );

      expect(context.trapsCondition(DecimalCondition.rounded), isTrue);
      expect(context.trapsCondition(DecimalCondition.inexact), isFalse);
    });
  });
}
