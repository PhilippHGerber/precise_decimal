import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../decimal_operation_result.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;
import '../rounding_mode.dart';
import 'rounding.dart' as rounding;

bool _hasNegativeZeroFromExactAddition(BigDecimal left, BigDecimal right) {
  return left.hasNegativeSign && right.hasNegativeSign;
}

/// Returns the exact sum of [left] and [right].
BigDecimal addBigDecimals(BigDecimal left, BigDecimal right) {
  if (left is FiniteDecimal && right is FiniteDecimal) {
    final aligned = _alignForAddOrSubtract(left, right);
    final resultUnscaled = math_utils.addCoefficients(aligned.leftUnscaled, aligned.rightUnscaled);
    if (math_utils.coefficientSign(resultUnscaled) == 0) {
      return math_utils.createBigDecimal(
        resultUnscaled,
        aligned.scale,
        isNegativeZero: _hasNegativeZeroFromExactAddition(left, right),
      );
    }
    return math_utils.createBigDecimalNonZero(resultUnscaled, aligned.scale);
  }

  final special = _addOrSubtractSpecialResult(left, right, isSubtraction: false);
  if (special != null) {
    return special.value;
  }

  throw StateError('Unreachable: all non-finite add cases handled by _addOrSubtractSpecialResult.');
}

/// Returns the exact difference `left - right`.
BigDecimal subtractBigDecimals(BigDecimal left, BigDecimal right) {
  if (left is FiniteDecimal && right is FiniteDecimal) {
    final aligned = _alignForAddOrSubtract(left, right);
    final resultUnscaled =
        math_utils.subtractCoefficients(aligned.leftUnscaled, aligned.rightUnscaled);
    if (math_utils.coefficientSign(resultUnscaled) == 0) {
      return math_utils.createBigDecimal(
        resultUnscaled,
        aligned.scale,
        isNegativeZero: _hasNegativeZeroFromExactAddition(left, negateBigDecimal(right)),
      );
    }
    return math_utils.createBigDecimalNonZero(resultUnscaled, aligned.scale);
  }

  final special = _addOrSubtractSpecialResult(left, right, isSubtraction: true);
  if (special != null) {
    return special.value;
  }

  throw StateError(
    'Unreachable: all non-finite subtract cases handled by _addOrSubtractSpecialResult.',
  );
}

/// Returns the exact product of [left] and [right].
BigDecimal multiplyBigDecimals(BigDecimal left, BigDecimal right) {
  if (left is FiniteDecimal && right is FiniteDecimal) {
    final resultScale = left.scaleForModules + right.scaleForModules;
    if (resultScale < math_utils.minSupportedScale || resultScale > math_utils.maxSupportedScale) {
      throw BigDecimalOverflowException(
        'Multiplication result scale is outside supported scale range '
        '[${math_utils.minSupportedScale}, ${math_utils.maxSupportedScale}]: $resultScale',
      );
    }

    final leftUnscaled = left.compactUnscaledValueForModules;
    final rightUnscaled = right.compactUnscaledValueForModules;

    // Fast, strict-typed zero checks.
    // This perfectly preserves static types and avoids Object == int deoptimization.
    final leftIsZero = leftUnscaled is int ? leftUnscaled == 0 : (leftUnscaled as BigInt).sign == 0;

    final rightIsZero =
        rightUnscaled is int ? rightUnscaled == 0 : (rightUnscaled as BigInt).sign == 0;

    if (leftIsZero || rightIsZero) {
      return math_utils.zeroWithScale(
        resultScale,
        isNegative: math_utils.hasNegativeResultSignForProductOrDivision(left, right),
      );
    }

    return math_utils.createBigDecimalNonZero(
      math_utils.multiplyCoefficients(leftUnscaled, rightUnscaled),
      resultScale,
    );
  }

  final special = _multiplySpecialResult(left, right);
  if (special != null) {
    return special.value;
  }

  throw StateError('Unreachable: all non-finite multiply cases handled by _multiplySpecialResult.');
}

/// Returns the rounded product of [left] and [right] under [context].
DecimalOperationResult<BigDecimal> multiplyBigDecimalsResult(
  BigDecimal left,
  BigDecimal right,
  DecimalContext context,
) {
  final special = _multiplySpecialResult(left, right);
  if (special != null) {
    final rounded = rounding.roundBigDecimalResult(special.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...special.conditions,
        ...rounded.conditions,
      },
    );
  }

  return rounding.roundBigDecimalResult(multiplyBigDecimals(left, right), context);
}

/// Returns the rounded sum of [left] and [right] under [context].
DecimalOperationResult<BigDecimal> addBigDecimalsResult(
  BigDecimal left,
  BigDecimal right,
  DecimalContext context,
) {
  final special = _addOrSubtractSpecialResult(
    left,
    right,
    isSubtraction: false,
  );
  if (special != null) {
    final rounded = rounding.roundBigDecimalResult(special.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...special.conditions,
        ...rounded.conditions,
      },
    );
  }

  final exactSum = addBigDecimals(left, right);
  final rounded = rounding.roundBigDecimalResult(exactSum, context);
  return DecimalOperationResult<BigDecimal>(
    value: _canonicalizeAdditionZeroSign(rounded.value, left, right, context.roundingMode),
    conditions: rounded.conditions,
  );
}

/// Returns the rounded difference `left - right` under [context].
DecimalOperationResult<BigDecimal> subtractBigDecimalsResult(
  BigDecimal left,
  BigDecimal right,
  DecimalContext context,
) {
  final special = _addOrSubtractSpecialResult(
    left,
    right,
    isSubtraction: true,
  );
  if (special != null) {
    final rounded = rounding.roundBigDecimalResult(special.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...special.conditions,
        ...rounded.conditions,
      },
    );
  }

  return addBigDecimalsResult(left, negateBigDecimal(right), context);
}

/// Applies unary plus semantics under [context].
DecimalOperationResult<BigDecimal> plusBigDecimalResult(
  BigDecimal value,
  DecimalContext context,
) {
  if (!value.isFinite) {
    final emitted = value.isSignalingNan
        ? const <DecimalCondition>{DecimalCondition.invalidOperation}
        : const <DecimalCondition>{};

    if (value.isInfinite) {
      return DecimalOperationResult<BigDecimal>(
        value: value,
        conditions: emitted,
      );
    }

    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(value),
      conditions: emitted,
    );
  }

  final rounded = rounding.roundBigDecimalResult(value, context);
  return DecimalOperationResult<BigDecimal>(
    value: _canonicalizeUnaryZeroSign(rounded.value),
    conditions: rounded.conditions,
  );
}

/// Applies unary minus semantics under [context].
DecimalOperationResult<BigDecimal> minusBigDecimalResult(
  BigDecimal value,
  DecimalContext context,
) {
  if (!value.isFinite) {
    final emitted = value.isSignalingNan
        ? const <DecimalCondition>{DecimalCondition.invalidOperation}
        : const <DecimalCondition>{};

    if (value.isInfinite) {
      return DecimalOperationResult<BigDecimal>(
        value: negateBigDecimal(value),
        conditions: emitted,
      );
    }

    // NaN: sign is preserved (not flipped) per GDA rule.
    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(value),
      conditions: emitted,
    );
  }

  final rounded = rounding.roundBigDecimalResult(negateBigDecimal(value), context);
  return DecimalOperationResult<BigDecimal>(
    value: _canonicalizeUnaryZeroSign(rounded.value),
    conditions: rounded.conditions,
  );
}

// GDA rule: when addition produces zero and rounding mode is floor,
// the result is negative if either operand had a negative sign.
BigDecimal _canonicalizeAdditionZeroSign(
  BigDecimal result,
  BigDecimal left,
  BigDecimal right,
  RoundingMode roundingMode,
) {
  if (!result.isZero || roundingMode != RoundingMode.floor) {
    return result;
  }
  if (!left.hasNegativeSign && !right.hasNegativeSign) {
    return result;
  }
  return result.hasNegativeSign ? result : negateBigDecimal(result);
}

BigDecimal _canonicalizeUnaryZeroSign(BigDecimal value) {
  if (!value.isZero || !value.hasNegativeSign) {
    return value;
  }

  return math_utils.zeroWithScale(value.scaleForModules, isNegative: false);
}

/// Returns the absolute value of [value].
BigDecimal absBigDecimal(BigDecimal value) {
  if (!value.isFinite) {
    // GDA: abs on NaN preserves the sign; sNaN→qNaN is handled by
    // _roundBigDecimalResult when the value flows through rounding.
    return switch (value) {
      NaNDecimal() => value,
      InfinityDecimal() when value.hasNegativeSign => BigDecimal.infinity(),
      InfinityDecimal() => value,
      _ => value,
    };
  }

  if (!value.hasNegativeSign) {
    return value;
  }

  return math_utils.createBigDecimal(
    math_utils.absCoefficient(value.compactUnscaledValueForModules),
    value.scaleForModules,
  );
}

DecimalOperationResult<BigDecimal>? _addOrSubtractSpecialResult(
  BigDecimal left,
  BigDecimal right, {
  required bool isSubtraction,
}) {
  // NaN propagation uses the ORIGINAL operands: the sign of a NaN operand is
  // not affected by the subtraction negation.
  final signalingConditions = math_utils.signalingNanCondition(left, right);
  switch ((left, right)) {
    case (NaNDecimal(), _) || (_, NaNDecimal()):
      return DecimalOperationResult<BigDecimal>(
        value: math_utils.binarySpecialNanValue(left, right),
        conditions: signalingConditions,
      );
    default:
      break;
  }

  // Apply subtraction negation only for the infinity arithmetic path.
  final rightOperand = isSubtraction ? negateBigDecimal(right) : right;

  switch ((left, rightOperand)) {
    case (InfinityDecimal(), InfinityDecimal()):
      if (left.hasNegativeSign != rightOperand.hasNegativeSign) {
        // ±Inf + ∓Inf is undefined: produce a fresh unsigned NaN.
        return DecimalOperationResult<BigDecimal>(
          value: BigDecimal.nan(),
          conditions: <DecimalCondition>{
            ...signalingConditions,
            DecimalCondition.invalidOperation,
          },
        );
      }

      return DecimalOperationResult<BigDecimal>(
        value: left,
        conditions: signalingConditions,
      );
    case (InfinityDecimal(), _):
      return DecimalOperationResult<BigDecimal>(
        value: left,
        conditions: signalingConditions,
      );
    case (_, InfinityDecimal()):
      return DecimalOperationResult<BigDecimal>(
        value: rightOperand,
        conditions: signalingConditions,
      );
    default:
      break;
  }

  return null;
}

DecimalOperationResult<BigDecimal>? _multiplySpecialResult(
  BigDecimal left,
  BigDecimal right,
) {
  final signalingConditions = math_utils.signalingNanCondition(left, right);
  switch ((left, right)) {
    case (NaNDecimal(), _) || (_, NaNDecimal()):
      return DecimalOperationResult<BigDecimal>(
        value: math_utils.binarySpecialNanValue(left, right),
        conditions: signalingConditions,
      );
    default:
      break;
  }

  switch ((left, right)) {
    case (InfinityDecimal(), _) || (_, InfinityDecimal()):
      if (left.isZero || right.isZero) {
        // ±Inf × 0 is undefined: produce a fresh unsigned NaN.
        return DecimalOperationResult<BigDecimal>(
          value: BigDecimal.nan(),
          conditions: <DecimalCondition>{
            ...signalingConditions,
            DecimalCondition.invalidOperation,
          },
        );
      }

      final negative = math_utils.hasNegativeResultSignForProductOrDivision(left, right);
      return DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(negative: negative),
        conditions: signalingConditions,
      );
    default:
      break;
  }

  return null;
}

/// Returns [value] with its sign flipped.
BigDecimal negateBigDecimal(BigDecimal value) {
  if (!value.isFinite) {
    return switch (value) {
      InfinityDecimal() => BigDecimal.infinity(negative: !value.hasNegativeSign),
      NaNDecimal() => BigDecimal.nan(
          signaling: value.isSignalingNan,
          diagnostic: value.diagnostic,
          negative: !value.hasNegativeSign,
        ),
      _ => value,
    };
  }

  if (value.isZero) {
    return math_utils.zeroWithScale(value.scaleForModules, isNegative: !value.hasNegativeSign);
  }

  return math_utils.createBigDecimal(
    math_utils.negateCoefficient(value.compactUnscaledValueForModules),
    value.scaleForModules,
  );
}

/// Clamps [value] to the inclusive range `[lowerLimit, upperLimit]`.
BigDecimal clampBigDecimal(
  BigDecimal value,
  BigDecimal lowerLimit,
  BigDecimal upperLimit,
) {
  math_utils.ensureFiniteOperands(lowerLimit, upperLimit, operation: 'Clamp');
  math_utils.ensureFiniteValue(value, operation: 'Clamp');

  if (lowerLimit.compareTo(upperLimit) > 0) {
    throw ArgumentError.value(
      lowerLimit,
      'lowerLimit',
      'Must be less than or equal to upperLimit.',
    );
  }

  if (value.compareTo(lowerLimit) < 0) {
    return lowerLimit;
  }
  if (value.compareTo(upperLimit) > 0) {
    return upperLimit;
  }
  return value;
}

/// Moves the decimal point of [value] left by [n] places.
BigDecimal movePointLeftBigDecimal(BigDecimal value, int n) {
  math_utils.ensureFiniteValue(value, operation: 'movePointLeft');

  if (n == 0) {
    return value;
  }
  if (n < 0) {
    return movePointRightBigDecimal(value, -n);
  }

  final newScale = math_utils.checkedScale(
    value.scaleForModules + n,
    operation: 'movePointLeft result scale',
  );
  return math_utils.createBigDecimal(
    value.compactUnscaledValueForModules,
    newScale,
    isNegativeZero: value.isNegativeZeroForModules,
  );
}

/// Moves the decimal point of [value] right by [n] places.
BigDecimal movePointRightBigDecimal(BigDecimal value, int n) {
  math_utils.ensureFiniteValue(value, operation: 'movePointRight');

  if (n == 0) {
    return value;
  }
  if (n < 0) {
    return movePointLeftBigDecimal(value, -n);
  }

  final newScale = math_utils.checkedScale(
    value.scaleForModules - n,
    operation: 'movePointRight result scale',
  );
  return math_utils.createBigDecimal(
    value.compactUnscaledValueForModules,
    newScale,
    isNegativeZero: value.isNegativeZeroForModules,
  );
}

// Both operands are aligned to the larger of the two scales so that addition
// and subtraction can be performed on integer unscaled values directly.
({Object leftUnscaled, Object rightUnscaled, int scale}) _alignForAddOrSubtract(
  BigDecimal left,
  BigDecimal right,
) {
  math_utils.ensureFiniteOperands(left, right, operation: 'Add/subtract alignment');

  final leftScale = left.scaleForModules;
  final rightScale = right.scaleForModules;
  final leftUnscaled = left.compactUnscaledValueForModules;
  final rightUnscaled = right.compactUnscaledValueForModules;

  if (leftScale == rightScale) {
    return (
      leftUnscaled: leftUnscaled,
      rightUnscaled: rightUnscaled,
      scale: leftScale,
    );
  }

  final commonScale = leftScale >= rightScale ? leftScale : rightScale;
  return (
    leftUnscaled: leftScale == commonScale
        ? leftUnscaled
        : math_utils.scaleUpCoefficient(leftUnscaled, commonScale - leftScale),
    rightUnscaled: rightScale == commonScale
        ? rightUnscaled
        : math_utils.scaleUpCoefficient(rightUnscaled, commonScale - rightScale),
    scale: commonScale,
  );
}
