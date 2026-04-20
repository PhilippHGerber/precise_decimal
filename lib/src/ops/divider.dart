import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../decimal_operation_result.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;
import '../rounding_mode.dart';
import 'rounding.dart' as rounding;

final BigInt _bigFive = BigInt.from(5);

({BigInt reducedDenominator, int twos, int fives}) _extractDenominatorPow2Pow5(BigInt denominator) {
  var reduced = denominator;
  var twos = 0;
  while (reduced.isEven) {
    reduced >>= 1;
    twos += 1;
  }

  var fives = 0;
  while (reduced.remainder(_bigFive) == BigInt.zero) {
    reduced ~/= _bigFive;
    fives += 1;
  }

  return (
    reducedDenominator: reduced,
    twos: twos,
    fives: fives,
  );
}

/// Divides [dividend] by [divisor] and rounds to the requested [scale].
BigDecimal divideBigDecimals(
  BigDecimal dividend,
  BigDecimal divisor, {
  required int scale,
  required RoundingMode roundingMode,
}) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'divideToScale currently requires finite operands.',
    );
  }
  math_utils.ensureNonZeroDivisor(divisor, operation: 'Division');

  final targetScale = math_utils.checkedScale(scale, operation: 'Division result scale');
  if (dividend.isZero) {
    return math_utils.zeroWithScale(
      targetScale,
      isNegative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
    );
  }

  final dividendUnscaled = dividend.unscaledValueForModules;
  final divisorUnscaled = divisor.unscaledValueForModules;
  final scaleDelta = targetScale + divisor.scaleForModules - dividend.scaleForModules;

  late final BigInt scaledDividend;
  late final BigInt scaledDivisor;
  if (scaleDelta >= 0) {
    scaledDividend =
        scaleDelta == 0 ? dividendUnscaled : dividendUnscaled * math_utils.pow10(scaleDelta);
    scaledDivisor = divisorUnscaled;
  } else {
    scaledDividend = dividendUnscaled;
    scaledDivisor = divisorUnscaled * math_utils.pow10(-scaleDelta);
  }

  final quotient = scaledDividend ~/ scaledDivisor;
  final remainder = scaledDividend.remainder(scaledDivisor);

  if (remainder.sign == 0) {
    return math_utils.createBigDecimal(
      quotient,
      targetScale,
      isNegativeZero: quotient.sign == 0 &&
          math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
    );
  }

  final roundedQuotient = rounding.roundTruncatedQuotient(
    quotient: quotient,
    sign: math_utils.divisionSign(dividend, divisor),
    remainder: remainder,
    divisor: scaledDivisor,
    roundingMode: roundingMode,
    operation: 'Division',
  );
  return math_utils.createBigDecimal(
    roundedQuotient,
    targetScale,
    isNegativeZero: roundedQuotient.sign == 0 &&
        math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
  );
}

/// Divides [dividend] by [divisor] under [context] and traps signalled conditions.
BigDecimal divideBigDecimalsWithContextTrapping(
  BigDecimal dividend,
  BigDecimal divisor,
  DecimalContext context,
) {
  final result = divideBigDecimalsResult(dividend, divisor, context);
  trapDecimalConditions(context, result.conditions);
  return result.value;
}

/// Divides [dividend] by [divisor] under [context].
DecimalOperationResult<BigDecimal> divideBigDecimalsResult(
  BigDecimal dividend,
  BigDecimal divisor,
  DecimalContext context,
) {
  final special = _divideSpecialResult(dividend, divisor);
  if (special != null) {
    // GDA: finite / infinite = 0 with exponent set to Etiny (always).
    final precision = context.precision;
    if (special.value.isZero &&
        dividend.isFinite &&
        divisor.isInfinite &&
        context.hasExponentBounds &&
        precision != null) {
      final etiny = context.minExponent! - precision + 1;
      final etinyZero = math_utils.zeroWithScale(-etiny, isNegative: special.value.hasNegativeSign);
      return DecimalOperationResult<BigDecimal>(
        value: etinyZero,
        conditions: <DecimalCondition>{...special.conditions, DecimalCondition.clamped},
      );
    }
    final rounded = rounding.roundBigDecimalResult(special.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...special.conditions,
        ...rounded.conditions,
      },
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Division');
  math_utils.ensureNonZeroDivisor(divisor, operation: 'Division');

  final contextPrecision = context.precision;
  if (contextPrecision != null && contextPrecision <= 0) {
    throw ArgumentError.value(
      contextPrecision,
      'context.precision',
      'Must be greater than zero when provided.',
    );
  }

  if (dividend.isZero) {
    final preferredScale = math_utils.checkedScale(
      dividend.scaleForModules - divisor.scaleForModules,
      operation: 'Context division result scale',
    );
    final zeroResult = math_utils.zeroWithScale(
      preferredScale,
      isNegative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
    );
    return rounding.roundBigDecimalResult(zeroResult, context);
  }

  if (contextPrecision == null) {
    final exactResult = tryDivideExactly(dividend, divisor);
    if (exactResult != null) {
      return DecimalOperationResult<BigDecimal>(value: exactResult);
    }

    throw const BigDecimalArithmeticException(
      'Division has a non-terminating decimal expansion.',
    );
  }

  final exactResult = tryDivideExactly(dividend, divisor);
  if (exactResult != null) {
    return rounding.roundBigDecimalResult(exactResult, context);
  }

  final adjustedExponent = _divisionAdjustedExponent(dividend, divisor);
  final targetScale = math_utils.checkedScale(
    contextPrecision - 1 - adjustedExponent,
    operation: 'Context division result scale',
  );
  final roundedResult = divideBigDecimals(
    dividend,
    divisor,
    scale: targetScale,
    roundingMode: context.roundingMode,
  );

  final normalizedResult =
      rounding.normalizeRoundedPrecisionResult(roundedResult, contextPrecision);
  const roundingConditions = <DecimalCondition>{
    DecimalCondition.inexact,
    DecimalCondition.rounded,
  };
  final overflowConditions = math_utils.ensureWithinContextExponentRange(normalizedResult, context);
  if (overflowConditions.contains(DecimalCondition.overflow)) {
    return DecimalOperationResult<BigDecimal>(
      value: BigDecimal.infinity(negative: normalizedResult.hasNegativeSign),
      conditions: {...roundingConditions, ...overflowConditions},
    );
  }
  return DecimalOperationResult<BigDecimal>(
    value: normalizedResult,
    conditions: {...roundingConditions, ...overflowConditions},
  );
}

/// Returns the exact quotient of [dividend] and [divisor].
///
/// Throws when the decimal expansion is non-terminating.
BigDecimal divideBigDecimalsExact(BigDecimal dividend, BigDecimal divisor) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'divideExact currently requires finite operands.',
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Division');
  math_utils.ensureNonZeroDivisor(divisor, operation: 'Division');

  if (dividend.isZero) {
    final preferredScale = math_utils.checkedScale(
      dividend.scaleForModules - divisor.scaleForModules,
      operation: 'Exact division result scale',
    );
    return math_utils.zeroWithScale(
      preferredScale,
      isNegative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
    );
  }

  final exactResult = tryDivideExactly(dividend, divisor);
  if (exactResult != null) {
    return exactResult;
  }

  throw const BigDecimalArithmeticException(
    'Division has a non-terminating decimal expansion.',
  );
}

/// Returns the integer quotient and remainder of dividing [dividend] by [divisor].
({BigDecimal quotient, BigDecimal remainder}) divideAndRemainderBigDecimals(
  BigDecimal dividend,
  BigDecimal divisor,
) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'divideAndRemainder currently requires finite operands.',
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'divideAndRemainder');

  final quotient = _truncatingDivideBigDecimalsAsBigDecimal(dividend, divisor);
  final remainder = remainderBigDecimals(dividend, divisor);
  return (quotient: quotient, remainder: remainder);
}

BigDecimal _truncatingDivideBigDecimalsAsBigDecimal(
  BigDecimal dividend,
  BigDecimal divisor,
) {
  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Integer division');

  final quotient = truncatingDivideBigDecimals(dividend, divisor);
  return math_utils.createBigDecimal(
    quotient,
    0,
    isNegativeZero: quotient == BigInt.zero &&
        math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
  );
}

/// Returns the quotient truncated toward zero as a [BigInt].
BigInt truncatingDivideBigDecimals(BigDecimal dividend, BigDecimal divisor) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'Integer division currently requires finite operands.',
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Integer division');
  math_utils.ensureNonZeroDivisor(divisor, operation: 'Integer division');
  if (dividend.isZero) {
    return BigInt.zero;
  }

  final fraction = _exactDivisionFraction(dividend: dividend, divisor: divisor);
  return fraction.numerator ~/ fraction.denominator;
}

/// Returns the remainder from dividing [dividend] by [divisor].
BigDecimal remainderBigDecimals(BigDecimal dividend, BigDecimal divisor) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'Remainder currently requires finite operands.',
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Remainder');

  if (dividend.isZero) {
    return math_utils.zeroWithScale(
      math_utils.checkedScale(
        dividend.scaleForModules >= divisor.scaleForModules
            ? dividend.scaleForModules
            : divisor.scaleForModules,
        operation: 'Remainder result scale',
      ),
      isNegative: dividend.hasNegativeSign,
    );
  }

  final quotient = truncatingDivideBigDecimals(dividend, divisor);
  final remainder = dividend - (divisor * BigDecimal.fromBigInt(quotient));
  if (!remainder.isZero) {
    return remainder;
  }

  return math_utils.zeroWithScale(
    math_utils.checkedScale(
      dividend.scaleForModules >= divisor.scaleForModules
          ? dividend.scaleForModules
          : divisor.scaleForModules,
      operation: 'Remainder result scale',
    ),
    isNegative: dividend.hasNegativeSign,
  );
}

// Expresses dividend/divisor as an exact rational p/q by folding both
// scale factors into the numerator or denominator so that the result is
// scale-free: (dividend.unscaled * 10^-ds) / (divisor.unscaled * 10^-ds2)
// simplifies to one integer divided by another.
({BigInt numerator, BigInt denominator}) _exactDivisionFraction({
  required BigDecimal dividend,
  required BigDecimal divisor,
}) {
  final scaleDelta = divisor.scaleForModules - dividend.scaleForModules;
  if (scaleDelta > 0) {
    return (
      numerator: dividend.unscaledValueForModules * math_utils.pow10(scaleDelta),
      denominator: divisor.unscaledValueForModules,
    );
  }
  if (scaleDelta < 0) {
    return (
      numerator: dividend.unscaledValueForModules,
      denominator: divisor.unscaledValueForModules * math_utils.pow10(-scaleDelta),
    );
  }
  return (
    numerator: dividend.unscaledValueForModules,
    denominator: divisor.unscaledValueForModules
  );
}

// A decimal expansion terminates iff the denominator's only prime factors are
// 2 and 5. After reducing p/q by the GCD, this function counts the trailing
// factors of 2 and 5 in q. If any other factor remains the division is
// non-terminating and null is returned. Otherwise the minimum scale needed
// to represent the exact result is max(twos, fives), because the result must
// be an integer multiple of 10^-scale = (2*5)^-scale.
/// Returns the exact quotient when [dividend] / [divisor] terminates, else `null`.
BigDecimal? tryDivideExactly(BigDecimal dividend, BigDecimal divisor) {
  if (!dividend.isFinite || !divisor.isFinite) {
    throw const BigDecimalArithmeticException(
      'Exact division currently requires finite operands.',
    );
  }

  math_utils.ensureFiniteOperands(dividend, divisor, operation: 'Exact division');

  final fraction = _exactDivisionFraction(dividend: dividend, divisor: divisor);

  var numerator = fraction.numerator;
  var denominator = fraction.denominator;

  // Fast path: if the denominator divides the numerator exactly the result is
  // an integer — no GCD or prime-factor check needed.
  if (numerator.remainder(denominator) == BigInt.zero) {
    final quotient = numerator ~/ denominator;
    return _exactIntegerDivisionResult(
      quotient: quotient,
      preferredScale: dividend.scaleForModules - divisor.scaleForModules,
    );
  }

  // Slow path: GCD + 2/5 prime-factor check for non-integer terminating decimals.
  final gcd = numerator.gcd(denominator);
  numerator ~/= gcd;
  denominator ~/= gcd;

  if (denominator.isNegative) {
    numerator = -numerator;
    denominator = -denominator;
  }

  final factors = _extractDenominatorPow2Pow5(denominator);
  if (factors.reducedDenominator != BigInt.one) {
    return null;
  }

  final minimumScale = factors.twos >= factors.fives ? factors.twos : factors.fives;
  final preferredScale = dividend.scaleForModules - divisor.scaleForModules;
  final resultScale = math_utils.checkedScale(
    preferredScale >= minimumScale ? preferredScale : minimumScale,
    operation: 'Exact division result scale',
  );

  var unscaledValue = numerator;
  if (factors.twos < minimumScale) {
    unscaledValue *= math_utils.pow2(minimumScale - factors.twos);
  }
  if (factors.fives < minimumScale) {
    unscaledValue *= math_utils.pow5(minimumScale - factors.fives);
  }
  if (resultScale > minimumScale) {
    unscaledValue *= math_utils.pow10(resultScale - minimumScale);
  }

  return math_utils.createBigDecimal(unscaledValue, resultScale);
}

DecimalOperationResult<BigDecimal>? _divideSpecialResult(
  BigDecimal dividend,
  BigDecimal divisor,
) {
  final signalingConditions = math_utils.signalingNanCondition(dividend, divisor);
  return switch ((dividend, divisor)) {
    (NaNDecimal(), _) || (_, NaNDecimal()) => DecimalOperationResult<BigDecimal>(
        value: math_utils.binarySpecialNanValue(dividend, divisor),
        conditions: signalingConditions,
      ),
    (InfinityDecimal(), InfinityDecimal()) => DecimalOperationResult<BigDecimal>(
        value: BigDecimal.nan(),
        conditions: <DecimalCondition>{
          ...signalingConditions,
          DecimalCondition.invalidOperation,
        },
      ),
    (InfinityDecimal(), FiniteDecimal()) => DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(
          negative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
        ),
        conditions: signalingConditions,
      ),
    (FiniteDecimal(), InfinityDecimal()) => DecimalOperationResult<BigDecimal>(
        value: math_utils.zeroWithScale(
          0,
          isNegative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
        ),
        conditions: signalingConditions,
      ),
    (FiniteDecimal(), FiniteDecimal()) when divisor.isZero && dividend.isZero =>
      DecimalOperationResult<BigDecimal>(
        value: BigDecimal.nan(),
        conditions: <DecimalCondition>{
          ...signalingConditions,
          DecimalCondition.invalidOperation,
        },
      ),
    (FiniteDecimal(), FiniteDecimal()) when divisor.isZero => DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(
          negative: math_utils.hasNegativeResultSignForProductOrDivision(dividend, divisor),
        ),
        conditions: <DecimalCondition>{
          ...signalingConditions,
          DecimalCondition.divisionByZero,
        },
      ),
    _ => null,
  };
}

BigDecimal _exactIntegerDivisionResult({
  required BigInt quotient,
  required int preferredScale,
}) {
  final minimumScale = preferredScale >= 0 ? 0 : -math_utils.countTrailingDecimalZeros(quotient);
  final resultScale = math_utils.checkedScale(
    preferredScale >= minimumScale ? preferredScale : minimumScale,
    operation: 'Exact division result scale',
  );

  var unscaledValue = quotient;
  if (resultScale > 0) {
    unscaledValue *= math_utils.pow10(resultScale);
  } else if (resultScale < 0) {
    unscaledValue ~/= math_utils.pow10(-resultScale);
  }

  return math_utils.createBigDecimal(unscaledValue, resultScale);
}

int _divisionAdjustedExponent(BigDecimal dividend, BigDecimal divisor) {
  final fraction = _exactDivisionFraction(dividend: dividend, divisor: divisor);
  return _floorLog10OfRational(
    fraction.numerator.abs(),
    fraction.denominator.abs(),
  );
}

// Computes floor(log10(numerator/denominator)) without floating-point
// arithmetic. Used to determine the adjusted exponent of a division result,
// which in turn drives how many significant digits the context precision
// maps to at a given scale.
int _floorLog10OfRational(BigInt numeratorAbs, BigInt denominatorAbs) {
  final numeratorDigits = math_utils.getDigitCount(numeratorAbs);
  final denominatorDigits = math_utils.getDigitCount(denominatorAbs);
  var exponent = numeratorDigits - denominatorDigits;
  if (exponent >= 0) {
    if (numeratorAbs < denominatorAbs * math_utils.pow10(exponent)) {
      exponent -= 1;
    }
    return exponent;
  }

  if (numeratorAbs * math_utils.pow10(-exponent) < denominatorAbs) {
    exponent -= 1;
  }
  return exponent;
}
