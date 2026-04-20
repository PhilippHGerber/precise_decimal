import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../decimal_operation_result.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;
import '../rounding_mode.dart';
import 'rounding.dart' as rounding;

/// Returns the square root of [value] under [context] and traps signalled conditions.
BigDecimal sqrtBigDecimalWithContextTrapping(
  BigDecimal value,
  DecimalContext context,
) {
  return sqrtBigDecimalsResult(value, context).valueOrThrow(context);
}

/// Returns the exact square root of [value].
BigDecimal sqrtBigDecimalExact(BigDecimal value) {
  math_utils.ensureFiniteValue(value, operation: 'Square root');

  if (value.isZero) {
    return _sqrtZero(value);
  }

  if (value.isNegative) {
    throw const BigDecimalArithmeticException(
      'Square root is undefined for negative values.',
    );
  }

  final normalized = _normalizeSqrtOperand(value);
  final root = _integerSqrt(normalized.unscaledValue);
  if (root * root != normalized.unscaledValue) {
    throw const BigDecimalArithmeticException(
      'Square root is irrational. A finite precision context is required.',
    );
  }

  return math_utils.createBigDecimal(root, normalized.scale ~/ 2);
}

BigInt _getTwo() => BigInt.from(2);
BigInt _getTen() => BigInt.from(10);

/// Returns the square root of [value] under [context].
DecimalOperationResult<BigDecimal> sqrtBigDecimalsResult(
  BigDecimal value,
  DecimalContext context,
) {
  final special = _sqrtSpecialResult(value);
  if (special != null) {
    final rounded = _roundSqrtResult(special.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...special.conditions,
        ...rounded.conditions,
      },
    );
  }

  math_utils.ensureFiniteValue(value, operation: 'Square root');

  if (value.isNegative) {
    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(value),
      conditions: const <DecimalCondition>{DecimalCondition.invalidOperation},
    );
  }

  if (value.isZero) {
    return _roundSqrtResult(_sqrtZero(value), context);
  }

  if (context.precision == null) {
    return _roundSqrtResult(sqrtBigDecimalExact(value), context);
  }

  final candidate = _sqrtRoundedCandidate(value, context.precision!);
  return _roundSqrtResult(candidate, context);
}

({BigInt unscaledValue, int scale}) _normalizeSqrtOperand(BigDecimal value) {
  if (value.scaleForModules.isOdd) {
    return (
      unscaledValue: value.unscaledValueForModules * _getTen(),
      scale: math_utils.checkedScale(
        value.scaleForModules + 1,
        operation: 'Square root normalization scale',
      ),
    );
  }

  return (unscaledValue: value.unscaledValueForModules, scale: value.scaleForModules);
}

BigDecimal _sqrtRoundedCandidate(BigDecimal value, int precision) {
  final extraPrecision = precision + 1;
  final normalized = _normalizeSqrtOperand(value);
  var exponent = (-normalized.scale) >> 1;
  final coefficientDigits = value.precisionForModules;
  final base100Digits =
      value.scaleForModules.isOdd ? (coefficientDigits >> 1) + 1 : (coefficientDigits + 1) >> 1;

  var workingCoefficient = normalized.unscaledValue;
  final shift = extraPrecision - base100Digits;
  var exact = true;

  if (shift >= 0) {
    workingCoefficient *= math_utils.pow10(shift * 2);
  } else {
    final divisor = math_utils.pow10((-shift) * 2);
    final remainder = workingCoefficient.remainder(divisor);
    workingCoefficient ~/= divisor;
    exact = remainder == BigInt.zero;
  }

  exponent -= shift;

  var root = _integerSqrt(
    workingCoefficient,
    initialGuess: math_utils.pow10(extraPrecision),
  );
  exact = exact && root * root == workingCoefficient;

  if (exact) {
    if (shift >= 0) {
      root ~/= math_utils.pow10(shift);
    } else {
      root *= math_utils.pow10(-shift);
    }
    exponent += shift;
  } else if (root.remainder(BigInt.from(5)) == BigInt.zero) {
    // Mirror CPython's decimal sqrt trick so the final half-even round is correct.
    root += BigInt.one;
  }

  return math_utils.createBigDecimal(
    root,
    math_utils.checkedScale(-exponent, operation: 'Square root result scale'),
  );
}

DecimalOperationResult<BigDecimal> _roundSqrtResult(
  BigDecimal value,
  DecimalContext context,
) {
  return rounding.roundBigDecimalResult(
    value,
    context.copyWith(roundingMode: RoundingMode.halfEven),
  );
}

BigDecimal _sqrtZero(BigDecimal value) {
  final resultScale = math_utils.checkedScale(
    -((-value.scaleForModules) >> 1),
    operation: 'Square root zero result scale',
  );
  return math_utils.zeroWithScale(resultScale, isNegative: value.hasNegativeSign);
}

BigInt _integerSqrt(BigInt value, {BigInt? initialGuess}) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'Must be non-negative.');
  }

  final two = _getTwo();
  if (value < two) {
    return value;
  }

  var guess = initialGuess ?? math_utils.pow10((math_utils.getDigitCount(value) + 1) >> 1);
  if (guess <= BigInt.zero) {
    throw ArgumentError.value(initialGuess, 'initialGuess', 'Must be positive when provided.');
  }

  while (true) {
    final quotient = value ~/ guess;
    if (guess <= quotient) {
      return guess;
    }
    guess = (guess + quotient) >> 1;
  }
}

DecimalOperationResult<BigDecimal>? _sqrtSpecialResult(BigDecimal value) {
  if (value.isNaN) {
    final emitted = value.isSignalingNan
        ? const <DecimalCondition>{DecimalCondition.invalidOperation}
        : const <DecimalCondition>{};
    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(value),
      conditions: emitted,
    );
  }

  if (value.isInfinite) {
    if (value.hasNegativeSign) {
      return DecimalOperationResult<BigDecimal>(
        value: math_utils.quietNanFrom(value),
        conditions: const <DecimalCondition>{DecimalCondition.invalidOperation},
      );
    }

    return DecimalOperationResult<BigDecimal>(
      value: BigDecimal.infinity(),
    );
  }

  return null;
}
