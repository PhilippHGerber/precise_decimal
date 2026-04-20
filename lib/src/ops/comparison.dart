import 'package:meta/meta.dart';

import '../core/big_decimal.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;

@internal
BigDecimal minBigDecimal(BigDecimal a, BigDecimal b) {
  if (a.isNaN && !b.isNaN) {
    return b;
  }
  if (b.isNaN && !a.isNaN) {
    return a;
  }
  if (a.isNaN && b.isNaN) {
    return a;
  }

  final numericComparison = a.compareTo(b);
  if (numericComparison < 0) {
    return a;
  }
  if (numericComparison > 0) {
    return b;
  }

  return _minByTotalOrderBigDecimal(a, b);
}

@internal
BigDecimal maxBigDecimal(BigDecimal a, BigDecimal b) {
  if (a.isNaN && !b.isNaN) {
    return b;
  }
  if (b.isNaN && !a.isNaN) {
    return a;
  }
  if (a.isNaN && b.isNaN) {
    return a;
  }

  final numericComparison = a.compareTo(b);
  if (numericComparison > 0) {
    return a;
  }
  if (numericComparison < 0) {
    return b;
  }

  return _maxByTotalOrderBigDecimal(a, b);
}

@internal
BigDecimal maxMagnitudeBigDecimal(BigDecimal left, BigDecimal right) {
  if (left.isNaN && !right.isNaN) {
    return right;
  }
  if (right.isNaN && !left.isNaN) {
    return left;
  }
  if (left.isNaN && right.isNaN) {
    return left;
  }

  final magnitudeComparison = left.abs().compareTo(right.abs());
  if (magnitudeComparison > 0) {
    return left;
  }
  if (magnitudeComparison < 0) {
    return right;
  }

  return _maxByTotalOrderBigDecimal(left, right);
}

@internal
BigDecimal minMagnitudeBigDecimal(BigDecimal left, BigDecimal right) {
  if (left.isNaN && !right.isNaN) {
    return right;
  }
  if (right.isNaN && !left.isNaN) {
    return left;
  }
  if (left.isNaN && right.isNaN) {
    return left;
  }

  final magnitudeComparison = left.abs().compareTo(right.abs());
  if (magnitudeComparison < 0) {
    return left;
  }
  if (magnitudeComparison > 0) {
    return right;
  }

  return _minByTotalOrderBigDecimal(left, right);
}

@internal
bool sameQuantumBigDecimals(BigDecimal left, BigDecimal right) {
  if (!left.isFinite || !right.isFinite) {
    throw const BigDecimalArithmeticException(
      'sameQuantum does not yet support NaN or Infinity values.',
    );
  }

  final leftFinite = left as FiniteDecimal;
  final rightFinite = right as FiniteDecimal;
  return leftFinite.scale == rightFinite.scale;
}

@internal
bool isBigDecimalInteger(FiniteDecimal value) {
  if (value.scale <= 0 || value.isZero) {
    return true;
  }

  return value.unscaledValue.remainder(BigInt.from(10).pow(value.scale)) == BigInt.zero;
}

// Comparison proceeds in three stages to avoid unnecessarily large multiplications:
//   1. Signs differ → result is immediate.
//   2. Adjusted magnitudes (integer-part digit count) differ → result is
//      immediate without touching unscaled values.
//   3. Same magnitude → cross-multiply by the scale delta to bring both
//      values to a common scale before comparing unscaled integers.
@internal
int compareBigDecimals(BigDecimal left, BigDecimal right) {
  if (identical(left, right)) {
    return 0;
  }

  if (!left.isFinite || !right.isFinite) {
    return _comparePossiblySpecialBigDecimals(left, right);
  }

  final signComparison = left.sign.compareTo(right.sign);
  if (signComparison != 0) {
    return signComparison;
  }

  if (left.sign == 0) {
    return 0;
  }

  final leftFinite = left as FiniteDecimal;
  final rightFinite = right as FiniteDecimal;
  if (leftFinite.scale == rightFinite.scale) {
    return math_utils.compareCoefficients(
      leftFinite.compactUnscaledValueForModules,
      rightFinite.compactUnscaledValueForModules,
    );
  }

  final magnitudeComparison = leftFinite.adjustedMagnitude.compareTo(rightFinite.adjustedMagnitude);
  if (magnitudeComparison != 0) {
    return left.sign > 0 ? magnitudeComparison : -magnitudeComparison;
  }

  final scaleDelta = leftFinite.scale - rightFinite.scale;
  if (scaleDelta > 0) {
    return math_utils.compareCoefficients(
      leftFinite.compactUnscaledValueForModules,
      math_utils.scaleUpCoefficient(rightFinite.compactUnscaledValueForModules, scaleDelta),
    );
  }

  return math_utils.compareCoefficients(
    math_utils.scaleUpCoefficient(leftFinite.compactUnscaledValueForModules, -scaleDelta),
    rightFinite.compactUnscaledValueForModules,
  );
}

int _comparePossiblySpecialBigDecimals(BigDecimal left, BigDecimal right) {
  final leftRank = _specialClassRank(left);
  final rightRank = _specialClassRank(right);
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }

  return switch ((left, right)) {
    (InfinityDecimal(), InfinityDecimal()) => left.sign.compareTo(right.sign),
    (NaNDecimal(), NaNDecimal()) => switch (left.sign.compareTo(right.sign)) {
        0 => (left.diagnostic ?? '').compareTo(right.diagnostic ?? ''),
        final signComparison => signComparison,
      },
    _ => throw StateError('Unexpected special-value comparison state.'),
  };
}

@internal
int compareTotalBigDecimals(BigDecimal left, BigDecimal right) {
  if (!left.isFinite || !right.isFinite) {
    return _comparePossiblySpecialBigDecimals(left, right);
  }

  final leftHasNegativeSign = left.hasNegativeSign;
  final rightHasNegativeSign = right.hasNegativeSign;
  final signComparison =
      leftHasNegativeSign == rightHasNegativeSign ? 0 : (leftHasNegativeSign ? -1 : 1);
  if (signComparison != 0) {
    return signComparison;
  }

  final numericComparison = left.compareTo(right);
  if (numericComparison != 0) {
    return numericComparison;
  }

  return leftHasNegativeSign
      ? (left as FiniteDecimal).scale.compareTo((right as FiniteDecimal).scale)
      : (right as FiniteDecimal).scale.compareTo((left as FiniteDecimal).scale);
}

@internal
int compareTotalMagnitudeBigDecimals(BigDecimal left, BigDecimal right) {
  if (!left.isFinite || !right.isFinite) {
    return _comparePossiblySpecialMagnitudes(left, right);
  }

  final magnitudeComparison = left.abs().compareTo(right.abs());
  if (magnitudeComparison != 0) {
    return magnitudeComparison;
  }

  return (right as FiniteDecimal).scale.compareTo((left as FiniteDecimal).scale);
}

BigDecimal _maxByTotalOrderBigDecimal(BigDecimal left, BigDecimal right) {
  return compareTotalBigDecimals(left, right) >= 0 ? left : right;
}

BigDecimal _minByTotalOrderBigDecimal(BigDecimal left, BigDecimal right) {
  return compareTotalBigDecimals(left, right) <= 0 ? left : right;
}

// Hash is computed over the stripped form so that numerically equal values
// with different scales (e.g. 1.0 and 1.00) produce the same hash, consistent
// with the equality contract where compareTo == 0 implies equal.
@internal
int computeBigDecimalHashCode(BigDecimal value) {
  if (!value.isFinite) {
    return Object.hash(value.form, value.hasNegativeSign, value.diagnostic);
  }

  final normalized = value.stripTrailingZeros() as FiniteDecimal;
  return Object.hash(normalized.unscaledValue, normalized.scale);
}

int _comparePossiblySpecialMagnitudes(BigDecimal left, BigDecimal right) {
  final leftRank = _specialClassRank(left);
  final rightRank = _specialClassRank(right);
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }

  return switch ((left, right)) {
    (InfinityDecimal(), InfinityDecimal()) => 0,
    (NaNDecimal(), NaNDecimal()) => (left.diagnostic ?? '').compareTo(right.diagnostic ?? ''),
    _ => throw StateError('Unexpected special-value magnitude comparison state.'),
  };
}

int _specialClassRank(BigDecimal value) {
  return switch (value) {
    FiniteDecimal() => 1,
    InfinityDecimal() => value.hasNegativeSign ? 0 : 2,
    NaNDecimal(isSignaling: false) => 3,
    NaNDecimal(isSignaling: true) => 4,
  };
}
