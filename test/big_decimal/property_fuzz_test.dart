import 'dart:math';

import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

const int _numRuns = 60;

final Random _random = Random(42);

final BigInt _minGeneratedUnscaled = BigInt.from(-1000000);
final BigInt _maxGeneratedUnscaledExclusive = BigInt.from(1000001);
final List<int> _generatedScales = List<int>.generate(25, (index) => index - 12);

final List<String> _signedZeroVariants = <String>[
  '0',
  '0.0',
  '0E+3',
  '-0',
  '-0.0',
  '-0.00',
  '-0E+3',
];

BigDecimal _randomBigDecimal() {
  if (_random.nextBool()) {
    return BigDecimal.parse(_signedZeroVariants[_random.nextInt(_signedZeroVariants.length)]);
  }
  final range = _maxGeneratedUnscaledExclusive - _minGeneratedUnscaled;
  final unscaled = _minGeneratedUnscaled + _randomBigInt(range);
  final scale = _generatedScales[_random.nextInt(_generatedScales.length)];
  return BigDecimal.fromComponents(unscaled, scale: scale);
}

BigInt _randomBigInt(BigInt exclusiveMax) {
  final bits = exclusiveMax.bitLength;
  BigInt result;
  do {
    result = _randomBigIntBits(bits);
  } while (result >= exclusiveMax);
  return result;
}

BigInt _randomBigIntBits(int bits) {
  var result = BigInt.zero;
  var remaining = bits;
  while (remaining > 0) {
    final chunk = remaining < 30 ? remaining : 30;
    result = (result << chunk) | BigInt.from(_random.nextInt(1 << chunk));
    remaining -= chunk;
  }
  return result;
}

BigInt _randomBoundedUnscaled() {
  final range = _maxGeneratedUnscaledExclusive - _minGeneratedUnscaled;
  return _minGeneratedUnscaled + _randomBigInt(range);
}

int _randomBoundedScale() => _generatedScales[_random.nextInt(_generatedScales.length)];

void main() {
  group('BigDecimal property-based invariants', () {
    test('addition is commutative', () {
      for (var i = 0; i < _numRuns; i++) {
        final left = _randomBigDecimal();
        final right = _randomBigDecimal();
        final leftThenRight = left + right;
        final rightThenLeft = right + left;

        expect(
          leftThenRight.hasSameRepresentation(rightThenLeft),
          isTrue,
          reason: 'left=$left right=$right',
        );
      }
    });

    test('multiplication is commutative', () {
      for (var i = 0; i < _numRuns; i++) {
        final left = _randomBigDecimal();
        final right = _randomBigDecimal();
        final leftThenRight = left * right;
        final rightThenLeft = right * left;

        expect(
          leftThenRight.hasSameRepresentation(rightThenLeft),
          isTrue,
          reason: 'left=$left right=$right',
        );
      }
    });

    test('adding zero preserves numeric value', () {
      for (var i = 0; i < _numRuns; i++) {
        final value = _randomBigDecimal();

        expect((value + BigDecimal.zero).compareTo(value), equals(0), reason: 'value=$value');
      }
    });

    test('multiplying by one preserves representation', () {
      for (var i = 0; i < _numRuns; i++) {
        final value = _randomBigDecimal();

        expect(
          (value * BigDecimal.one).hasSameRepresentation(value),
          isTrue,
          reason: 'value=$value',
        );
      }
    });

    test('adding a value to its negation is numerically zero', () {
      for (var i = 0; i < _numRuns; i++) {
        final value = _randomBigDecimal();

        expect((value + (-value)).compareTo(BigDecimal.zero), equals(0), reason: 'value=$value');
      }
    });

    test('stripTrailingZeros is idempotent', () {
      for (var i = 0; i < _numRuns; i++) {
        final value = _randomBigDecimal();
        final stripped = value.stripTrailingZeros();

        expect(
          stripped.stripTrailingZeros().hasSameRepresentation(stripped),
          isTrue,
          reason: 'value=$value',
        );
      }
    });

    test('compareTo is transitive', () {
      for (var i = 0; i < _numRuns; i++) {
        final first = _randomBigDecimal();
        final second = _randomBigDecimal();
        final third = _randomBigDecimal();

        if (first.compareTo(second) < 0 && second.compareTo(third) < 0) {
          expect(
            first.compareTo(third),
            lessThan(0),
            reason: 'first=$first second=$second third=$third',
          );
        }
      }
    });

    test('sameQuantum depends only on scale', () {
      for (var i = 0; i < _numRuns; i++) {
        final leftUnscaled = _randomBoundedUnscaled();
        final rightUnscaled = _randomBoundedUnscaled();
        final scale = _randomBoundedScale();
        final left = BigDecimal.fromComponents(leftUnscaled, scale: scale);
        final right = BigDecimal.fromComponents(rightUnscaled, scale: scale);

        expect(
          left.sameQuantum(right),
          isTrue,
          reason: 'leftUnscaled=$leftUnscaled rightUnscaled=$rightUnscaled scale=$scale',
        );
      }
    });
  });
}
