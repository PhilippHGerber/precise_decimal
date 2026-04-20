import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../decimal_operation_result.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;
import '../rounding_mode.dart';

final BigInt _bigTwo = BigInt.from(2);
final BigInt _bigTen = BigInt.from(10);

/// Returns [value] with its scale changed to [newScale] using [roundingMode].
BigDecimal setBigDecimalScale(
  BigDecimal value,
  int newScale,
  RoundingMode roundingMode,
) {
  math_utils.ensureFiniteValue(value, operation: 'setScale');

  final checkedScale = math_utils.checkedScale(newScale, operation: 'Scale');
  if (checkedScale == value.scaleForModules) {
    return value;
  }

  if (value.isZero) {
    return math_utils.zeroWithScale(checkedScale, isNegative: value.hasNegativeSign);
  }

  if (checkedScale > value.scaleForModules) {
    return math_utils.createBigDecimal(
      math_utils.scaleUpCoefficient(
        value.compactUnscaledValueForModules,
        checkedScale - value.scaleForModules,
      ),
      checkedScale,
    );
  }

  return _roundByDiscardingDigits(
    value: value,
    discardedDigits: value.scaleForModules - checkedScale,
    newScale: checkedScale,
    roundingMode: roundingMode,
    operation: 'setScale',
  );
}

/// Rounds [value] to [sigDigits] significant digits using [roundingMode].
BigDecimal roundBigDecimalToPrecision(
  BigDecimal value,
  int sigDigits,
  RoundingMode roundingMode,
) {
  math_utils.ensureFiniteValue(value, operation: 'roundToPrecision');

  if (sigDigits <= 0) {
    throw ArgumentError.value(
      sigDigits,
      'sigDigits',
      'Must be greater than zero.',
    );
  }

  if (value.isZero || value.precisionForModules <= sigDigits) {
    return value;
  }

  final discardedDigits = value.precisionForModules - sigDigits;
  final newScale = math_utils.checkedScale(
    value.scaleForModules - discardedDigits,
    operation: 'Precision rounding result scale',
  );

  final rounded = _roundByDiscardingDigits(
    value: value,
    discardedDigits: discardedDigits,
    newScale: newScale,
    roundingMode: roundingMode,
    operation: 'roundToPrecision',
    normalizeCarry: true,
    targetPrecision: sigDigits,
  );

  return rounded;
}

/// Applies the rounding and exponent rules from [context] to [value].
DecimalOperationResult<BigDecimal> roundBigDecimalResult(
  BigDecimal value,
  DecimalContext context,
) {
  if (!value.isFinite) {
    if (value.isNaN) {
      // sNaN → qNaN with invalidOperation; qNaN passes through unchanged.
      // Apply payload truncation to fit the context precision.
      final conditions = value.isSignalingNan
          ? const <DecimalCondition>{DecimalCondition.invalidOperation}
          : const <DecimalCondition>{};
      final quietNan = value.isSignalingNan ? math_utils.quietNanFrom(value) : value;
      return DecimalOperationResult<BigDecimal>(
        value: math_utils.truncateNanDiagnostic(quietNan, context),
        conditions: conditions,
      );
    }
    return DecimalOperationResult<BigDecimal>(value: value);
  }

  final rounded = _roundBigDecimalWithContextAndConditions(value, context);
  return DecimalOperationResult<BigDecimal>(
    value: rounded.value,
    conditions: rounded.conditions,
  );
}

/// Returns [setBigDecimalScale] together with any signalled conditions.
DecimalOperationResult<BigDecimal> setBigDecimalScaleResult(
  BigDecimal value,
  int newScale,
  RoundingMode roundingMode,
) {
  final conditions = _scaleReductionConditions(value, newScale);
  return DecimalOperationResult<BigDecimal>(
    value: setBigDecimalScale(value, newScale, roundingMode),
    conditions: conditions,
  );
}

Set<DecimalCondition> _scaleReductionConditions(BigDecimal value, int newScale) {
  math_utils.ensureFiniteValue(value, operation: 'setScaleResult');

  if (value.isZero || newScale >= value.scaleForModules) {
    return const <DecimalCondition>{};
  }
  return _discardingDigitsConditions(
    value.unscaledValueForModules,
    value.scaleForModules - newScale,
  );
}

({BigDecimal value, Set<DecimalCondition> conditions}) _roundBigDecimalWithContextAndConditions(
  BigDecimal value,
  DecimalContext context,
) {
  if (!value.isFinite) {
    return (value: value, conditions: const <DecimalCondition>{});
  }

  final contextPrecision = context.precision;

  // Phase 1: precision rounding.
  BigDecimal workingValue;
  Set<DecimalCondition> roundingConditions;
  if (contextPrecision == null || value.isZero || value.precisionForModules <= contextPrecision) {
    workingValue = value;
    roundingConditions = const <DecimalCondition>{};
  } else {
    workingValue = roundBigDecimalToPrecision(value, contextPrecision, context.roundingMode);
    roundingConditions = _precisionRoundingConditions(value, contextPrecision);
  }

  // Phase 2: GDA exponent clamping.
  if (context.hasExponentBounds && contextPrecision != null) {
    final clampBoundary = context.maxExponent! - contextPrecision + 1;
    final trailingExponent = -workingValue.scaleForModules;

    if (!workingValue.isZero) {
      // Non-zero: fold-down pads the coefficient with trailing zeros so the
      // trailing exponent equals clampBoundary.  Only when clamp: 1 and the
      // value is NOT overflowing (adjusted exponent ≤ maxExponent).
      if (context.clamp &&
          trailingExponent > clampBoundary &&
          math_utils.contextAdjustedExponent(workingValue) <= context.maxExponent!) {
        final padDigits = trailingExponent - clampBoundary;
        final foldedValue = math_utils.createBigDecimal(
          workingValue.unscaledValueForModules * math_utils.pow10(padDigits),
          workingValue.scaleForModules + padDigits,
        );
        return (
          value: foldedValue,
          conditions: {...roundingConditions, DecimalCondition.clamped},
        );
      }
    } else {
      // Zero: clamp the trailing exponent to [Etiny, highBound].
      // Both bounds always apply when context has exponent bounds.
      // With clamp=1: highBound = clampBoundary (fold-down precision alignment).
      // With clamp=0: highBound = maxExponent (only prevent exponent overflow).
      final etiny = context.minExponent! - contextPrecision + 1;
      final highBound = context.clamp ? clampBoundary : context.maxExponent!;
      final int? targetExp;
      if (trailingExponent > highBound) {
        targetExp = highBound;
      } else if (trailingExponent < etiny) {
        targetExp = etiny;
      } else {
        targetExp = null;
      }
      if (targetExp != null) {
        final clampedValue = math_utils.zeroWithScale(
          -targetExp,
          isNegative: workingValue.hasNegativeSign,
        );
        return (
          value: clampedValue,
          conditions: {...roundingConditions, DecimalCondition.clamped},
        );
      }
    }
  }

  // Phase 3: overflow check.
  // On overflow (non-trapping) GDA requires the result to be ±Infinity with
  // inexact and rounded conditions signalled.
  final overflowConditions = math_utils.ensureWithinContextExponentRange(workingValue, context);
  if (overflowConditions.contains(DecimalCondition.overflow)) {
    final negative = workingValue.hasNegativeSign;
    return (
      value: BigDecimal.infinity(negative: negative),
      conditions: {
        DecimalCondition.overflow,
        DecimalCondition.inexact,
        DecimalCondition.rounded,
        ...roundingConditions,
      },
    );
  }
  return (
    value: workingValue,
    conditions: {...roundingConditions, ...overflowConditions},
  );
}

Set<DecimalCondition> _precisionRoundingConditions(BigDecimal value, int sigDigits) {
  if (value.isZero || value.precisionForModules <= sigDigits) {
    return const <DecimalCondition>{};
  }

  return _discardingDigitsConditions(
    value.unscaledValueForModules,
    value.precisionForModules - sigDigits,
  );
}

Set<DecimalCondition> _discardingDigitsConditions(BigInt unscaledValue, int discardedDigits) {
  if (discardedDigits <= 0) {
    return const <DecimalCondition>{};
  }

  final conditions = <DecimalCondition>{DecimalCondition.rounded};
  if (unscaledValue.remainder(math_utils.pow10(discardedDigits)) != BigInt.zero) {
    conditions.add(DecimalCondition.inexact);
  }
  return conditions;
}

/// Removes trailing decimal zeros from [value] while preserving signed zero.
BigDecimal stripTrailingZeros(BigDecimal value) {
  if (!value.isFinite) {
    return value;
  }

  final unscaled = value.unscaledValueForModules;
  final normalized = math_utils.stripTrailingZerosComponents(unscaled, value.scaleForModules);
  if (normalized.unscaledValue == unscaled && normalized.scale == value.scaleForModules) {
    return value;
  }

  if (normalized.unscaledValue == BigInt.zero && normalized.scale == 0) {
    return math_utils.zeroWithScale(0, isNegative: value.hasNegativeSign);
  }

  return math_utils.createBigDecimal(
    normalized.unscaledValue,
    normalized.scale,
    isNegativeZero: value.isNegativeZeroForModules,
  );
}

// Divides the unscaled value by 10^discardedDigits (truncating), then
// delegates the rounding decision to [_roundTruncatedQuotient] using the
// remainder and the original divisor so rounding modes can compare the
// discarded fraction against 1/2.
BigDecimal _roundByDiscardingDigits({
  required BigDecimal value,
  required int discardedDigits,
  required int newScale,
  required RoundingMode roundingMode,
  required String operation,
  bool normalizeCarry = false,
  int? targetPrecision,
}) {
  // Compact fast path: use int arithmetic when the coefficient fits and the
  // divisor is small enough to stay within int range.
  final compact = value.compactUnscaledValueForModules;
  if (compact is int && discardedDigits < math_utils.intPow10.length) {
    final intDivisor = math_utils.intPow10[discardedDigits];
    final intQuotient = compact ~/ intDivisor;
    final intRemainder = compact.remainder(intDivisor);
    if (intRemainder == 0) {
      return math_utils.createBigDecimal(
        intQuotient,
        newScale,
        isNegativeZero: intQuotient == 0 && value.hasNegativeSign,
      );
    }
  }

  final divisor = math_utils.pow10(discardedDigits);
  final quotient = value.unscaledValueForModules ~/ divisor;
  final remainder = value.unscaledValueForModules.remainder(divisor);

  if (remainder == BigInt.zero) {
    return math_utils.createBigDecimal(
      quotient,
      newScale,
      isNegativeZero: quotient == BigInt.zero && value.hasNegativeSign,
    );
  }

  final roundedQuotient = roundTruncatedQuotient(
    quotient: quotient,
    sign: value.sign,
    remainder: remainder,
    divisor: divisor,
    roundingMode: roundingMode,
    operation: operation,
  );

  // Check if rounding carry exceeded target precision.
  // After rounding, we might have one extra digit beyond the target precision.
  if (normalizeCarry && targetPrecision != null) {
    final resultPrecision = math_utils.getDigitCount(roundedQuotient);
    if (resultPrecision > targetPrecision) {
      // Rounding carry increased digit count beyond target precision.
      // Normalize by dividing by 10 and adjusting scale.
      return math_utils.createBigDecimal(
        roundedQuotient ~/ _bigTen,
        math_utils.checkedScale(newScale - 1, operation: 'Precision rounding carry scale'),
        isNegativeZero: roundedQuotient == BigInt.zero && value.hasNegativeSign,
      );
    }
  }

  return math_utils.createBigDecimal(
    roundedQuotient,
    newScale,
    isNegativeZero: roundedQuotient == BigInt.zero && value.hasNegativeSign,
  );
}

// After [_roundByDiscardingDigits], a rounding carry can add at most one digit
// beyond the target precision. Strip that single excess digit when it occurs.
/// Normalizes a precision-rounded value back to at most [sigDigits] digits.
BigDecimal normalizeRoundedPrecisionResult(BigDecimal value, int sigDigits) {
  if (value.isZero || value.precisionForModules <= sigDigits) {
    return value;
  }

  return math_utils.createBigDecimal(
    value.unscaledValueForModules ~/ _bigTen,
    math_utils.checkedScale(value.scaleForModules - 1, operation: 'Precision rounding carry scale'),
  );
}

/// Rounds a truncated integer quotient according to [roundingMode].
BigInt roundTruncatedQuotient({
  required BigInt quotient,
  required int sign,
  required BigInt remainder,
  required BigInt divisor,
  required RoundingMode roundingMode,
  required String operation,
}) {
  final remainderAbs = remainder.abs();
  if (remainderAbs == BigInt.zero) {
    return quotient;
  }

  if (!_shouldRoundAwayFromZero(
    quotient: quotient,
    sign: sign,
    remainderAbs: remainderAbs,
    divisorAbs: divisor.abs(),
    roundingMode: roundingMode,
    operation: operation,
  )) {
    return quotient;
  }

  return quotient + BigInt.from(sign);
}

bool _shouldRoundAwayFromZero({
  required BigInt quotient,
  required int sign,
  required BigInt remainderAbs,
  required BigInt divisorAbs,
  required RoundingMode roundingMode,
  required String operation,
}) {
  switch (roundingMode) {
    case RoundingMode.up:
      return true;
    case RoundingMode.down:
      return false;
    case RoundingMode.ceiling:
      return sign > 0;
    case RoundingMode.floor:
      return sign < 0;
    case RoundingMode.halfUp:
      return _compareDiscardedFractionToHalf(remainderAbs, divisorAbs) >= 0;
    case RoundingMode.halfDown:
      return _compareDiscardedFractionToHalf(remainderAbs, divisorAbs) > 0;
    case RoundingMode.halfEven:
      final halfComparison = _compareDiscardedFractionToHalf(
        remainderAbs,
        divisorAbs,
      );
      if (halfComparison > 0) {
        return true;
      }
      if (halfComparison < 0) {
        return false;
      }
      return quotient.abs().isOdd;
    case RoundingMode.unnecessary:
      throw BigDecimalArithmeticException(
        '$operation requires rounding, but RoundingMode.unnecessary was used.',
      );
  }
}

// Returns the sign of (2 * remainder - divisor): negative if remainder < half,
// zero if exactly half, positive if remainder > half. Avoids division by using
// cross-multiplication, keeping all arithmetic in BigInt.
int _compareDiscardedFractionToHalf(BigInt remainderAbs, BigInt divisorAbs) {
  return (remainderAbs * _bigTwo).compareTo(divisorAbs);
}
