import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../decimal_operation_result.dart';
import '../exceptions.dart';
import '../internal/math_utils.dart' as math_utils;
import '../rounding_mode.dart';
import 'adder.dart' as adder;
import 'rounding.dart' as rounding;

/// Raises [base] to [exponent] under [context] and traps signalled conditions.
BigDecimal powBigDecimalWithContextTrapping(
  BigDecimal base,
  int exponent,
  DecimalContext context,
) {
  return powBigDecimalsResult(base, exponent, context).valueOrThrow(context);
}

/// Returns the exact value of [base] raised to [exponent].
BigDecimal powBigDecimalExact(BigDecimal base, int exponent) {
  math_utils.ensureFiniteValue(base, operation: 'Power');

  final unitBaseResult = _powUnitBase(base, exponent);
  if (unitBaseResult != null) {
    return unitBaseResult;
  }

  _ensurePowExponentInRange(exponent);

  if (exponent == 0) {
    if (base.isZero) {
      throw const BigDecimalArithmeticException(
        'Power is undefined for zero raised to the zero power.',
      );
    }
    return BigDecimal.one;
  }

  if (base.isZero) {
    if (exponent < 0) {
      throw const BigDecimalArithmeticException(
        'Power is undefined for zero raised to a negative exponent.',
      );
    }
    return _powZero(base, exponent);
  }

  final magnitude = exponent.abs();
  final positivePower = _powPositiveExact(base, magnitude);
  if (exponent > 0) {
    return positivePower;
  }

  return BigDecimal.one.divideExact(positivePower);
}

const int _maxPowExponentMagnitude = 999999999;

/// Raises [base] to [exponent] under [context].
DecimalOperationResult<BigDecimal> powBigDecimalsResult(
  BigDecimal base,
  int exponent,
  DecimalContext context,
) {
  final special = _powSpecialResult(base, exponent);
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

  math_utils.ensureFiniteValue(base, operation: 'Power');

  final unitBaseResult = _powUnitBase(base, exponent);
  if (unitBaseResult != null) {
    return rounding.roundBigDecimalResult(unitBaseResult, context);
  }

  if (exponent.abs() > _maxPowExponentMagnitude) {
    if (!context.hasExponentBounds) {
      _ensurePowExponentInRange(exponent);
    }
    // Bounded context: exponent is too large to compute exactly, but the result
    // is guaranteed to overflow (|base|>1 with large positive exponent, or
    // |base|<1 with large negative exponent) or underflow otherwise.
    // Model with an extreme value so _roundBigDecimalResult emits the right conditions.
    final baseAbsGtOne = base.abs().compareTo(BigDecimal.one) > 0;
    final resultIsHuge = (baseAbsGtOne && exponent > 0) || (!baseAbsGtOne && exponent < 0);
    final sign = base.hasNegativeSign && exponent.isOdd ? -BigInt.one : BigInt.one;
    final extremeScale = resultIsHuge ? math_utils.minSupportedScale : math_utils.maxSupportedScale;
    return rounding.roundBigDecimalResult(math_utils.createBigDecimal(sign, extremeScale), context);
  }

  final contextPrecision = context.precision;
  if (contextPrecision != null && contextPrecision <= 0) {
    throw ArgumentError.value(
      contextPrecision,
      'context.precision',
      'Must be greater than zero when provided.',
    );
  }

  if (exponent == 0) {
    if (base.isZero) {
      throw const BigDecimalArithmeticException(
        'Power is undefined for zero raised to the zero power.',
      );
    }
    return rounding.roundBigDecimalResult(BigDecimal.one, context);
  }

  if (base.isZero) {
    if (exponent < 0) {
      throw const BigDecimalArithmeticException(
        'Power is undefined for zero raised to a negative exponent.',
      );
    }
    return rounding.roundBigDecimalResult(_powZero(base, exponent), context);
  }

  if (contextPrecision == null) {
    return rounding.roundBigDecimalResult(powBigDecimalExact(base, exponent), context);
  }

  final exactPowerOfTenResult = _powExactNegativePowerOfTenResult(
    base,
    exponent,
    context,
  );
  if (exactPowerOfTenResult != null) {
    return exactPowerOfTenResult;
  }

  final magnitude = exponent.abs();
  final workingContext = _powWorkingContext(context, magnitude);
  final DecimalOperationResult<BigDecimal> positivePower;
  try {
    positivePower = _powPositiveWithContext(base, magnitude, workingContext);
  } on BigDecimalOverflowException {
    // An intermediate multiplication overflowed _maxSupportedScale. Since
    // _powWorkingContext removes exponent bounds, scale overflow implies the
    // bounded result must also overflow (or underflow).
    final baseAbsGtOne = base.abs().compareTo(BigDecimal.one) > 0;
    final resultIsHuge = (baseAbsGtOne && exponent > 0) || (!baseAbsGtOne && exponent < 0);
    final isNeg = base.hasNegativeSign && exponent.isOdd;
    if (resultIsHuge) {
      return DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(negative: isNeg),
        conditions: const <DecimalCondition>{
          DecimalCondition.overflow,
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        },
      );
    }
    final sign = isNeg ? -BigInt.one : BigInt.one;
    return rounding.roundBigDecimalResult(
      math_utils.createBigDecimal(sign, math_utils.maxSupportedScale),
      context,
    );
  }

  if (exponent > 0) {
    final rounded = rounding.roundBigDecimalResult(positivePower.value, context);
    return DecimalOperationResult<BigDecimal>(
      value: rounded.value,
      conditions: <DecimalCondition>{
        ...positivePower.conditions,
        ...rounded.conditions,
      },
    );
  }

  final reciprocal = BigDecimal.one.divideResult(positivePower.value, context: workingContext);
  final rounded = rounding.roundBigDecimalResult(reciprocal.value, context);
  return DecimalOperationResult<BigDecimal>(
    value: rounded.value,
    conditions: <DecimalCondition>{
      ...positivePower.conditions,
      ...reciprocal.conditions,
      ...rounded.conditions,
    },
  );
}

BigDecimal? _powUnitBase(BigDecimal base, int exponent) {
  final normalizedBase = base.stripTrailingZeros();

  if (normalizedBase.scaleForModules != 0) {
    return null;
  }

  if (normalizedBase.unscaledValueForModules == BigInt.one) {
    return BigDecimal.one;
  }

  if (normalizedBase.unscaledValueForModules == -BigInt.one) {
    return exponent.isOdd ? BigDecimal.minusOne : BigDecimal.one;
  }

  return null;
}

DecimalOperationResult<BigDecimal>? _powExactNegativePowerOfTenResult(
  BigDecimal base,
  int exponent,
  DecimalContext context,
) {
  if (exponent >= 0) {
    return null;
  }

  final normalizedBase = base.stripTrailingZeros();
  if (normalizedBase.unscaledValueForModules.abs() != BigInt.one ||
      normalizedBase.scaleForModules == 0) {
    return null;
  }

  final decimalExponent = -normalizedBase.scaleForModules;
  final rawResultScale = decimalExponent * exponent.abs();
  if (rawResultScale < math_utils.minSupportedScale ||
      rawResultScale > math_utils.maxSupportedScale) {
    final isNeg = normalizedBase.unscaledValueForModules.isNegative && exponent.isOdd;
    if (rawResultScale < math_utils.minSupportedScale) {
      // Scale too negative → result is huge → overflow.
      return DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(negative: isNeg),
        conditions: const <DecimalCondition>{
          DecimalCondition.overflow,
          DecimalCondition.inexact,
          DecimalCondition.rounded,
        },
      );
    }
    // Scale too positive → result is tiny → underflow.
    final sign = isNeg ? -BigInt.one : BigInt.one;
    return rounding.roundBigDecimalResult(
      math_utils.createBigDecimal(sign, math_utils.maxSupportedScale),
      context,
    );
  }
  final resultScale = math_utils.checkedScale(rawResultScale, operation: 'Power result scale');
  final exactResult = math_utils.createBigDecimal(
    normalizedBase.unscaledValueForModules.isNegative && exponent.isOdd ? -BigInt.one : BigInt.one,
    resultScale,
  );
  return rounding.roundBigDecimalResult(exactResult, context);
}

void _ensurePowExponentInRange(int exponent) {
  if (exponent.abs() > _maxPowExponentMagnitude) {
    throw BigDecimalOverflowException(
      'Power exponent is outside supported range '
      '[-$_maxPowExponentMagnitude, $_maxPowExponentMagnitude]: $exponent',
    );
  }
}

BigDecimal _powPositiveExact(BigDecimal base, int exponent) {
  var result = BigDecimal.one;
  var factor = base;
  var remaining = exponent;

  while (remaining > 0) {
    if (remaining.isOdd) {
      result = adder.multiplyBigDecimals(result, factor);
    }

    remaining ~/= 2;
    if (remaining > 0) {
      factor = adder.multiplyBigDecimals(factor, factor);
    }
  }

  return result;
}

DecimalOperationResult<BigDecimal> _powPositiveWithContext(
  BigDecimal base,
  int exponent,
  DecimalContext workingContext,
) {
  var result = BigDecimal.one;
  var factor = base;
  var remaining = exponent;
  final conditions = <DecimalCondition>{};

  while (remaining > 0) {
    if (remaining.isOdd) {
      final multiplied = adder.multiplyBigDecimalsResult(result, factor, workingContext);
      result = multiplied.value;
      conditions.addAll(multiplied.conditions);
    }

    remaining ~/= 2;
    if (remaining > 0) {
      final squared = adder.multiplyBigDecimalsResult(factor, factor, workingContext);
      factor = squared.value;
      conditions.addAll(squared.conditions);
    }
  }

  return DecimalOperationResult<BigDecimal>(
    value: result,
    conditions: conditions,
  );
}

DecimalContext _powWorkingContext(DecimalContext context, int exponentMagnitude) {
  final precision = context.precision! + exponentMagnitude.toString().length + 1;
  return context.copyWith(
    precision: precision,
    roundingMode: RoundingMode.halfEven,
    maxExponent: null,
    minExponent: null,
    clamp: false,
    traps: const <DecimalCondition>{},
  );
}

BigDecimal _powZero(BigDecimal base, int exponent) {
  return math_utils.zeroWithScale(
    0,
    isNegative: base.hasNegativeSign && exponent.isOdd,
  );
}

DecimalOperationResult<BigDecimal>? _powSpecialResult(
  BigDecimal base,
  int exponent,
) {
  if (base.isNaN) {
    final emitted = base.isSignalingNan
        ? const <DecimalCondition>{DecimalCondition.invalidOperation}
        : const <DecimalCondition>{};
    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(base),
      conditions: emitted,
    );
  }

  if (base.isInfinite) {
    if (exponent == 0) {
      // GDA: Infinity^0 = 1 (no condition).
      return DecimalOperationResult<BigDecimal>(value: BigDecimal.one);
    }

    if (exponent > 0) {
      return DecimalOperationResult<BigDecimal>(
        value: BigDecimal.infinity(negative: base.hasNegativeSign && exponent.isOdd),
      );
    }

    return DecimalOperationResult<BigDecimal>(
      value: math_utils.zeroWithScale(0, isNegative: base.hasNegativeSign && exponent.isOdd),
    );
  }

  if (base.isZero && exponent == 0) {
    return DecimalOperationResult<BigDecimal>(
      value: math_utils.quietNanFrom(base),
      conditions: const <DecimalCondition>{DecimalCondition.invalidOperation},
    );
  }

  if (base.isZero && exponent < 0) {
    // GDA: 0^-n = ±Infinity with no condition raised.
    return DecimalOperationResult<BigDecimal>(
      value: BigDecimal.infinity(negative: base.hasNegativeSign && exponent.isOdd),
    );
  }

  return null;
}
