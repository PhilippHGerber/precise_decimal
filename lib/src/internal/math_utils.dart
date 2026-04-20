import 'package:meta/meta.dart';

import '../context/decimal_condition.dart';
import '../context/decimal_context.dart';
import '../core/big_decimal.dart';
import '../exceptions.dart';

// -=========================================================================
// Platform Boundaries
// -=========================================================================

/// Whether the code is running in a JS/Web environment.
@internal
const bool kIsWeb = identical(0, 0.0);

/// Maximum safe exact integer limit for the current platform.
/// 9,007,199,254,740,991 on JS (2^53 - 1)
/// 9,223,372,036,854,775,807 on Native (2^63 - 1)
@internal
const int kSafeIntLimit = kIsWeb ? 9007199254740991 : 9223372036854775807;

// -=========================================================================
// Scale Bounds
// -=========================================================================

/// Minimum supported scale value for decimal numbers.
@internal
const int minSupportedScale = -999999999;

/// Maximum supported scale value for decimal numbers.
@internal
const int maxSupportedScale = 999999999;

/// Maximum absolute compact coefficient stored as `int`.
///
/// Must remain within JavaScript's exact integer range.
@internal
const int maxCompactAbs = 999999999999999;

// -=========================================================================
// Power of 10 Caching
// -=========================================================================

const int _maxCachedPow10Exponent = 256;
const double _log10Of2 = 0.3010299956639812;

final BigInt _bigTen = BigInt.from(10);
final BigInt _bigTwo = BigInt.from(2);
final BigInt _bigFive = BigInt.from(5);
final BigInt _bigMaxCompactAbs = BigInt.from(maxCompactAbs);
final List<BigInt> _pow10Cache = List<BigInt>.generate(
  _maxCachedPow10Exponent + 1,
  _bigTen.pow,
  growable: false,
);

@internal
const int smallBigIntLimit = 256;

// Pre-allocated BigInts for -256..256. Index i → value (i - 256).
final List<BigInt> _smallBigInts = List<BigInt>.generate(
  smallBigIntLimit * 2 + 1,
  (i) => BigInt.from(i - smallBigIntLimit),
  growable: false,
);

// -=========================================================================
// Sign Inspection
// -=========================================================================

/// Whether the value has a negative sign bit (considering -0 semantics).
@internal
@pragma('vm:prefer-inline')
bool hasNegativeSignBit(BigDecimal value) {
  return value.sign < 0 || value.isNegativeZeroForModules;
}

// -=========================================================================
// Compact Coefficient Helpers
// -=========================================================================

/// Converts [value] to a compact internal representation when possible.
@internal
Object compactCoefficient(BigInt value) {
  if (value >= -_bigMaxCompactAbs && value <= _bigMaxCompactAbs) {
    return value.toInt();
  }

  return value;
}

/// --------------------------

/// Converts an internal coefficient to [BigInt].
@internal
@pragma('vm:prefer-inline')
BigInt coefficientAsBigInt(Object coefficient) {
  if (coefficient is int) return BigInt.from(coefficient);
  if (coefficient is BigInt) return coefficient;
  throw StateError('Unsupported coefficient type: ${coefficient.runtimeType}');
}

/// Returns the sign of an internal coefficient.
@internal
@pragma('vm:prefer-inline')
int coefficientSign(Object coefficient) {
  if (coefficient is int) return coefficient.sign;
  if (coefficient is BigInt) return coefficient.sign;
  throw StateError('Unsupported coefficient type: ${coefficient.runtimeType}');
}

/// Negates an internal coefficient.
@internal
@pragma('vm:prefer-inline')
Object negateCoefficient(Object coefficient) {
  if (coefficient is int) return -coefficient;
  if (coefficient is BigInt) return -coefficient;
  throw StateError('Unsupported coefficient type: ${coefficient.runtimeType}');
}

/// Returns the absolute value of an internal coefficient.
@internal
@pragma('vm:prefer-inline')
Object absCoefficient(Object coefficient) {
  if (coefficient is int) return coefficient < 0 ? -coefficient : coefficient;
  if (coefficient is BigInt) return coefficient.isNegative ? -coefficient : coefficient;
  throw StateError('Unsupported coefficient type: ${coefficient.runtimeType}');
}

/// Returns the digit count of an internal coefficient without allocating BigInt.
@internal
@pragma('vm:prefer-inline')
int getDigitCountFromCoefficient(Object coefficient) {
  if (coefficient is int) {
    return coefficient == 0 ? 1 : _compactDigitCount(coefficient < 0 ? -coefficient : coefficient);
  }
  if (coefficient is BigInt) return getDigitCount(coefficient.abs());
  throw StateError('Unsupported coefficient type: ${coefficient.runtimeType}');
}

/// Multiplies two internal coefficients.
@internal
@pragma('vm:prefer-inline')
Object multiplyCoefficients(Object left, Object right) {
  if (left is BigInt) {
    if (right is BigInt) {
      return left * right;
    } else if (right is int) {
      final rightAbs = right < 0 ? -right : right;
      if (rightAbs <= smallBigIntLimit) return _smallBigInts[right + smallBigIntLimit] * left;
      return left * BigInt.from(right);
    }
  } else if (left is int) {
    if (right is int) {
      final leftAbs = left < 0 ? -left : left;
      final rightAbs = right < 0 ? -right : right;

      // 31622776 is floor(sqrt(maxCompactAbs))
      if (leftAbs <= 31622776 && rightAbs <= 31622776) return left * right;

      // Strict universal threshold (result stays within compact int type)
      if (leftAbs <= maxCompactAbs ~/ rightAbs) return left * right;

      // OPTIMIZATION: Does the product exceed maxCompactAbs but STILL fit
      // within the platform's native exact limit?
      // If yes, execute native multiplication and allocate EXACTLY ONE BigInt.
      if (leftAbs <= kSafeIntLimit ~/ rightAbs) {
        return BigInt.from(left * right);
      }

      // Fallback: Product is massive, allocate 3 BigInts
      return BigInt.from(left) * BigInt.from(right);
    } else if (right is BigInt) {
      final leftAbs = left < 0 ? -left : left;
      if (leftAbs <= smallBigIntLimit) return _smallBigInts[left + smallBigIntLimit] * right;
      return BigInt.from(left) * right;
    }
  }
  throw StateError('Unsupported coefficient types.');
}

/// ---------------------

/// Returns whether internal coefficients are numerically equal.
@internal
@pragma('vm:prefer-inline')
bool coefficientsEqual(Object left, Object right) {
  if (left is int && right is int) {
    return left == right;
  }

  return coefficientAsBigInt(left) == coefficientAsBigInt(right);
}

/// Adds two internal coefficients.
@internal
Object addCoefficients(Object left, Object right) {
  if (left is int && right is int) {
    final sum = left + right;
    if (sum.abs() <= maxCompactAbs) {
      return sum;
    }

    return BigInt.from(sum);
  }

  return coefficientAsBigInt(left) + coefficientAsBigInt(right);
}

/// Subtracts two internal coefficients.
@internal
Object subtractCoefficients(Object left, Object right) {
  if (left is int && right is int) {
    final diff = left - right;
    if (diff.abs() <= maxCompactAbs) {
      return diff;
    }

    return BigInt.from(diff);
  }

  return coefficientAsBigInt(left) - coefficientAsBigInt(right);
}

/// Compares two internal coefficients numerically.
@internal
@pragma('vm:prefer-inline')
int compareCoefficients(Object left, Object right) {
  if (left is int && right is int) return left.compareTo(right);
  return coefficientAsBigInt(left).compareTo(coefficientAsBigInt(right));
}

// Fast digit count for compact int coefficients (abs ≤ maxCompactAbs = 15 digits).
int _compactDigitCount(int abs) {
  if (abs < 10) return 1;
  if (abs < 100) return 2;
  if (abs < 1000) return 3;
  if (abs < 10000) return 4;
  if (abs < 100000) return 5;
  if (abs < 1000000) return 6;
  if (abs < 10000000) return 7;
  if (abs < 100000000) return 8;
  if (abs < 1000000000) return 9;
  if (abs < 10000000000) return 10;
  if (abs < 100000000000) return 11;
  if (abs < 1000000000000) return 12;
  if (abs < 10000000000000) return 13;
  if (abs < 100000000000000) return 14;
  return 15;
}

/// Powers of 10 as plain `int`, for compact-path arithmetic.
/// Index `n` holds `10^n`. All values fit within [maxCompactAbs].
@internal
const List<int> intPow10 = [
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
];

/// Thresholds for compact scale-up: `abs <= _scaleUpThresholds[n]` iff `abs * 10^n <= maxCompactAbs`.
const List<int> _scaleUpThresholds = [
  999999999999999, // n=0
  99999999999999, // n=1
  9999999999999, // n=2
  999999999999, // n=3
  99999999999, // n=4
  9999999999, // n=5
  999999999, // n=6
  99999999, // n=7
  9999999, // n=8
  999999, // n=9
  99999, // n=10
  9999, // n=11
  999, // n=12
  99, // n=13
  9, // n=14
  0, // n=15: any non-zero abs exceeds maxCompactAbs
];

/// Multiplies an internal coefficient by `10^n`, staying compact when the result fits.
@internal
Object scaleUpCoefficient(Object coefficient, int n) {
  if (n == 0) return coefficient;
  if (coefficient is int) {
    final abs = coefficient < 0 ? -coefficient : coefficient;
    if (abs == 0) return 0;
    if (n < _scaleUpThresholds.length) {
      if (abs <= _scaleUpThresholds[n]) {
        return coefficient * intPow10[n];
      }

      // OPTIMIZATION: If scale-up exceeds maxCompactAbs but fits in the
      // platform safe limit, perform native math and allocate one BigInt.
      if (abs <= kSafeIntLimit ~/ intPow10[n]) {
        return BigInt.from(coefficient * intPow10[n]);
      }
    }
    return BigInt.from(coefficient) * pow10(n);
  }
  return (coefficient as BigInt) * pow10(n);
}

// -=========================================================================
// Validation Helpers
// -=========================================================================

/// Validates that a decimal value is finite, throwing if not.
@internal
void ensureFiniteValue(BigDecimal value, {required String operation}) {
  if (!value.isFinite) {
    throw BigDecimalArithmeticException(
      '$operation does not yet support NaN or Infinity values.',
    );
  }
}

/// Validates that both operands are finite, throwing if not.
@internal
void ensureFiniteOperands(
  BigDecimal left,
  BigDecimal right, {
  required String operation,
}) {
  ensureFiniteValue(left, operation: operation);
  ensureFiniteValue(right, operation: operation);
}

/// Validates that a scale is within supported bounds.
@internal
@pragma('vm:prefer-inline')
int checkedScale(int scale, {required String operation}) {
  if (scale < minSupportedScale || scale > maxSupportedScale) {
    throw BigDecimalOverflowException(
      '$operation is outside supported scale range '
      '[$minSupportedScale, $maxSupportedScale]: $scale',
    );
  }
  return scale;
}

/// Validates that a divisor is non-zero and finite.
@internal
void ensureNonZeroDivisor(BigDecimal divisor, {required String operation}) {
  ensureFiniteValue(divisor, operation: operation);

  if (divisor.isZero) {
    throw BigDecimalArithmeticException('$operation by zero is undefined.');
  }
}

// -=========================================================================
// Factory Helpers
// -=========================================================================

/// Creates a zero value with the specified scale and sign.
@internal
BigDecimal zeroWithScale(int scale, {required bool isNegative}) {
  if (!isNegative && scale == 0) {
    return BigDecimal.zero;
  }

  return BigDecimal.createForModules(
    0,
    scale: scale,
    isNegativeZero: isNegative,
  );
}

/// Creates a decimal from unscaled value and scale.
@internal
BigDecimal createBigDecimal(
  Object unscaledValue,
  int scale, {
  bool isNegativeZero = false,
}) {
  return BigDecimal.createForModules(
    unscaledValue,
    scale: scale,
    isNegativeZero: isNegativeZero,
  );
}

/// Creates a decimal for a result known to be non-zero.
///
/// Skips the zero-detection branch in [createBigDecimal]. Only call when the
/// caller has already verified that [unscaledValue] is not zero.
@internal
@pragma('vm:prefer-inline')
BigDecimal createBigDecimalNonZero(Object unscaledValue, int scale) {
  return BigDecimal.createForModulesNonZero(unscaledValue, scale: scale);
}

// -=========================================================================
// Power Operations
// -=========================================================================

/// Returns 10 raised to the given exponent, using a cache for small exponents.
@internal
@pragma('vm:prefer-inline')
BigInt pow10(int exponent) {
  if (exponent < 0) {
    throw ArgumentError.value(exponent, 'exponent', 'Must be non-negative.');
  }

  if (exponent > _maxCachedPow10Exponent) {
    return _bigTen.pow(exponent);
  }
  return _pow10Cache[exponent];
}

/// Returns 2 raised to the given exponent.
@internal
BigInt pow2(int exponent) {
  if (exponent == 0) {
    return BigInt.one;
  }
  return _bigTwo.pow(exponent);
}

/// Returns 5 raised to the given exponent.
@internal
BigInt pow5(int exponent) {
  if (exponent == 0) {
    return BigInt.one;
  }
  return _bigFive.pow(exponent);
}

// -=========================================================================
// Digit and Precision Operations
// -=========================================================================

/// Returns the digit count in the absolute value, using bit-length estimation.
@internal
int getDigitCount(BigInt value) {
  if (value == BigInt.zero) {
    return 1;
  }

  final magnitude = value.abs();
  var digits = (magnitude.bitLength * _log10Of2).floor() + 1;

  while (magnitude < pow10(digits - 1)) {
    digits -= 1;
  }
  while (magnitude >= pow10(digits)) {
    digits += 1;
  }

  return digits;
}

/// Returns the count of trailing decimal zeros using binary search.
@internal
int countTrailingDecimalZeros(BigInt value) {
  if (value == BigInt.zero) {
    return 0;
  }

  final abs = value.abs();
  if (abs.remainder(_bigTen) != BigInt.zero) {
    return 0;
  }

  var lo = 0;
  var hi = getDigitCount(abs); // at most as many zeros as digits

  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (abs.remainder(pow10(mid)) == BigInt.zero) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }

  return lo;
}

/// Strips trailing zeros and returns normalized components.
@internal
({BigInt unscaledValue, int scale}) stripTrailingZerosComponents(
  BigInt unscaledValue,
  int scale,
) {
  if (unscaledValue == BigInt.zero) {
    return (unscaledValue: BigInt.zero, scale: 0);
  }

  // Count trailing zeros efficiently before dividing.
  var trailingZeros = 0;
  var temp = unscaledValue;
  while (trailingZeros < scale - minSupportedScale && temp.remainder(_bigTen) == BigInt.zero) {
    trailingZeros += 1;
    temp ~/= _bigTen;
  }

  if (trailingZeros == 0) {
    return (unscaledValue: unscaledValue, scale: scale);
  }

  return (unscaledValue: temp, scale: scale - trailingZeros);
}

// -=========================================================================
// Sign Logic for Multiplication and Division
// -=========================================================================

/// Determines result sign for product or quotient operations.
@internal
@pragma('vm:prefer-inline')
bool hasNegativeResultSignForProductOrDivision(
  BigDecimal left,
  BigDecimal right,
) {
  return hasNegativeSignBit(left) != hasNegativeSignBit(right);
}

/// Determines the sign for division operations.
@internal
int divisionSign(BigDecimal dividend, BigDecimal divisor) {
  return hasNegativeResultSignForProductOrDivision(dividend, divisor) ? -1 : 1;
}

// -=========================================================================
// NaN Handling (GDA Compliant)
// -=========================================================================

/// Returns a quiet NaN, preserving sign and diagnostic from signaling NaN,
/// or producing a fresh NaN for non-NaN input.
@internal
BigDecimal quietNanFrom(
  BigDecimal value, {
  String? fallbackDiagnostic,
}) {
  if (value.isNaN) {
    // Preserve sign and diagnostic from the NaN operand.
    return BigDecimal.nan(
      diagnostic: value.diagnostic,
      negative: value.hasNegativeSign,
    );
  }

  // Non-NaN input (e.g. Infinity or zero): produce a fresh unsigned NaN.
  // GDA rule: results of invalid operations on non-NaN operands are positive NaN.
  return BigDecimal.nan(diagnostic: fallbackDiagnostic);
}

/// GDA NaN selection rule: sNaN takes priority over qNaN regardless of position;
/// among the same kind the first operand wins.
@internal
BigDecimal binarySpecialNanValue(BigDecimal left, BigDecimal right) {
  if (left.isSignalingNan) return quietNanFrom(left);
  if (right.isSignalingNan) return quietNanFrom(right);
  if (left.isNaN) return quietNanFrom(left);
  if (right.isNaN) return quietNanFrom(right);
  return quietNanFrom(left);
}

/// Returns signaling NaN condition set if either operand is signaling NaN.
@internal
Set<DecimalCondition> signalingNanCondition(
  BigDecimal left,
  BigDecimal right,
) {
  if (left.isSignalingNan || right.isSignalingNan) {
    return const <DecimalCondition>{DecimalCondition.invalidOperation};
  }
  return const <DecimalCondition>{};
}

/// Truncates NaN diagnostic payload to fit context precision (GDA rule).
@internal
BigDecimal truncateNanDiagnostic(BigDecimal nan, DecimalContext context) {
  final diagnostic = nan.diagnostic;
  if (diagnostic == null || diagnostic.isEmpty) return nan;

  final prec = context.precision;
  if (prec == null) return nan;

  final maxLen = prec - (context.clamp ? 1 : 0);
  if (maxLen <= 0 || diagnostic.length <= maxLen) return nan;

  // Keep the rightmost maxLen digits.
  final truncated = diagnostic.substring(diagnostic.length - maxLen);
  // Strip any newly exposed leading zeros from the truncated payload.
  final stripped = truncated.replaceFirst(RegExp('^0+'), '');
  return BigDecimal.nan(
    diagnostic: stripped.isEmpty ? null : stripped,
    negative: nan.hasNegativeSign,
  );
}

// -=========================================================================
// Context-Based Validation
// -=========================================================================

/// Computes the adjusted exponent for scientific notation display.
@internal
int contextAdjustedExponent(BigDecimal value) {
  ensureFiniteValue(value, operation: 'Context exponent checks');

  if (value.isZero) {
    return -value.scaleForModules;
  }

  return value.precisionForModules - value.scaleForModules - 1;
}

/// Returns overflow/underflow condition set for the value under context bounds.
@internal
Set<DecimalCondition> ensureWithinContextExponentRange(
  BigDecimal value,
  DecimalContext context,
) {
  if (!context.hasExponentBounds) {
    return const <DecimalCondition>{};
  }

  final exponent = contextAdjustedExponent(value);
  final maxExponent = context.maxExponent!;
  final minExponent = context.minExponent!;
  final minAllowedExponent =
      context.precision == null ? minExponent : minExponent - (context.precision! - 1);

  if (exponent > maxExponent) {
    return const <DecimalCondition>{DecimalCondition.overflow};
  }
  if (!value.isZero && exponent < minAllowedExponent) {
    return const <DecimalCondition>{
      DecimalCondition.underflow,
      DecimalCondition.subnormal,
    };
  }
  return const <DecimalCondition>{};
}
