part of 'big_decimal.dart';

/// High-level numeric form of a [BigDecimal] value.
enum DecimalForm {
  /// Finite decimal value backed by `unscaledValue * 10^(-scale)`.
  finite,

  /// Positive or negative infinity.
  infinite,

  /// Quiet NaN.
  nan,

  /// Signaling NaN.
  signalingNan,
}

/// Immutable arbitrary-precision decimal value represented as
/// `unscaledValue * 10^(-scale)`.
///
/// Scale is preserved from the original representation: `BigDecimal.parse('1.20')`
/// keeps scale 2 and formats back as `"1.20"`.
///
/// Equality is by numeric value, not representation — `1.0 == 1.00` is true.
/// Use [hasSameRepresentation] to distinguish between different scales.
@immutable
sealed class BigDecimal implements Comparable<BigDecimal> {
  /// Creates positive or negative infinity.
  factory BigDecimal.infinity({bool negative = false}) {
    return _createInfinityDecimal(negative: negative);
  }

  /// Creates a quiet or signaling NaN.
  factory BigDecimal.nan({
    bool signaling = false,
    String? diagnostic,
    bool negative = false,
  }) {
    if (diagnostic != null && !RegExp(r'^\d+$').hasMatch(diagnostic)) {
      throw ArgumentError.value(
        diagnostic,
        'diagnostic',
        'Must contain decimal digits only.',
      );
    }

    // Normalize payload: strip leading zeros (GDA: diagnostic is a non-negative integer).
    final normalizedDiagnostic = diagnostic?.replaceFirst(RegExp('^0+'), '');
    final finalDiagnostic = (normalizedDiagnostic?.isEmpty ?? true) ? null : normalizedDiagnostic;

    return _createNaNDecimal(
      isSignaling: signaling,
      diagnostic: finalDiagnostic,
      negative: negative,
    );
  }

  /// Creates a decimal from an unscaled value and an explicit scale.
  @internal
  BigDecimal.internal(Object unscaledValue, this._scale) : _unscaled = unscaledValue;

  /// Parses [source] as a decimal value.
  factory BigDecimal.parse(String source) => parser.parseBigDecimal(source);

  /// Creates a decimal from a whole-number [value].
  factory BigDecimal.fromInt(int value) {
    return BigDecimal.fromBigInt(BigInt.from(value));
  }

  /// Creates a decimal from a whole-number [value].
  factory BigDecimal.fromBigInt(BigInt value) {
    return BigDecimal.fromComponents(value, scale: 0);
  }

  /// Creates a [BigDecimal] from [value] by converting it to its shortest
  /// string representation via [double.toString], then parsing that string.
  ///
  /// This preserves the *displayed* value of the double, not its exact IEEE 754
  /// binary value. For example, `fromDouble(0.1)` produces exactly `0.1`, even
  /// though the `double` `0.1` is closer to
  /// `0.1000000000000000055511151231257827...`.
  ///
  /// Throws [BigDecimalConversionException] for non-finite values (NaN,
  /// infinity).
  factory BigDecimal.fromDouble(double value) => parser.bigDecimalFromDouble(value);

  /// Creates a [BigDecimal] from the exact IEEE 754 binary value of [value].
  ///
  /// Unlike `fromDouble`, this does not use `double.toString`. Instead it
  /// decodes the float bits and returns the mathematically exact decimal
  /// value represented by the binary float.
  ///
  /// Example: `fromDoubleExact(0.1)` returns
  /// `0.1000000000000000055511151231257827021181583404541015625`.
  ///
  /// Throws [BigDecimalConversionException] for non-finite values (NaN,
  /// infinity).
  factory BigDecimal.fromDoubleExact(double value) => parser.bigDecimalFromDoubleExact(value);

  /// Creates a decimal from [unscaledValue] and [scale].
  factory BigDecimal.fromComponents(BigInt unscaledValue, {required int scale}) {
    internal_ops.checkedScale(scale, operation: 'Scale');
    return _createFiniteDecimal(internal_ops.compactCoefficient(unscaledValue), scale);
  }

  /// Internal constructor bridge for import-based module implementations.
  @internal
  static BigDecimal createForModules(
    Object unscaledValue, {
    required int scale,
    bool isNegativeZero = false,
  }) {
    if (internal_ops.coefficientSign(unscaledValue) == 0) {
      if (!isNegativeZero && scale == 0) {
        return BigDecimal.zero;
      }
      return _createFiniteDecimal(
        0,
        scale,
        isNegativeZero: isNegativeZero,
      );
    }

    return _createFiniteDecimal(
      unscaledValue,
      scale,
    );
  }

  /// Like [createForModules] but skips the zero check for results known to be
  /// non-zero.
  @internal
  @pragma('vm:prefer-inline')
  static BigDecimal createForModulesNonZero(Object unscaledValue, {required int scale}) {
    return _createFiniteDecimal(unscaledValue, scale);
  }

  /// Parses a JSON value into a [BigDecimal].
  ///
  /// Accepted input types:
  ///
  /// - `String` — parsed with [BigDecimal.parse]. This is the **recommended
  ///   wire format**: a decimal produced by [toJson] round-trips losslessly
  ///   through `jsonEncode` / `jsonDecode` and back through [fromJson].
  /// - `int` — converted exactly via [BigDecimal.fromInt].
  ///
  /// Rejected input types:
  ///
  /// - `double` — throws [BigDecimalConversionException]. By the time JSON
  ///   has been parsed into a Dart `double`, the original decimal literal
  ///   is gone (the number has already been rounded to the nearest IEEE-754
  ///   value), so silently converting it would reintroduce exactly the
  ///   precision loss this library is designed to prevent. Emit decimals as
  ///   JSON strings instead, or call [BigDecimal.fromDouble] /
  ///   [BigDecimal.fromDoubleExact] explicitly if you know what you want.
  /// - anything else — throws [BigDecimalConversionException].
  static BigDecimal fromJson(Object json) => parser.bigDecimalFromJson(json);

  /// Smallest supported scale.
  static const int minScale = -999999999;

  /// Largest supported scale.
  static const int maxScale = 999999999;

  /// Decimal zero.
  static final BigDecimal zero = _createFiniteDecimal(0, 0);

  /// Decimal one.
  static final BigDecimal one = _createFiniteDecimal(1, 0);

  /// Decimal two.
  static final BigDecimal two = _createFiniteDecimal(2, 0);

  /// Decimal ten.
  static final BigDecimal ten = _createFiniteDecimal(10, 0);

  /// Decimal minus one.
  static final BigDecimal minusOne = _createFiniteDecimal(-1, 0);

  /// Returns the numerically smaller of [a] and [b].
  static BigDecimal min(BigDecimal a, BigDecimal b) => comparison.minBigDecimal(a, b);

  /// Returns the numerically larger of [a] and [b].
  static BigDecimal max(BigDecimal a, BigDecimal b) => comparison.maxBigDecimal(a, b);

  /// Returns the operand with the larger absolute value.
  ///
  /// When magnitudes compare equal, finite GDA-style tie-breaking is used.
  static BigDecimal maxMagnitude(BigDecimal a, BigDecimal b) {
    return comparison.maxMagnitudeBigDecimal(a, b);
  }

  /// Returns the operand with the smaller absolute value.
  ///
  /// When magnitudes compare equal, finite GDA-style tie-breaking is used.
  static BigDecimal minMagnitude(BigDecimal a, BigDecimal b) {
    return comparison.minMagnitudeBigDecimal(a, b);
  }

  final Object _unscaled;
  final int _scale;
  late final int _cachedHashCode = comparison.computeBigDecimalHashCode(this);

  /// Attempts to parse [source], returning `null` on failure.
  static BigDecimal? tryParse(String source) => parser.tryParseBigDecimal(source);

  /// Returns the high-level numeric form of this value.
  DecimalForm get form;

  /// Returns the optional NaN diagnostic digits, if present.
  String? get diagnostic => null;

  /// Exposes unscaled value to internal operation modules.
  @internal
  @pragma('vm:prefer-inline')
  BigInt get unscaledValueForModules => internal_ops.coefficientAsBigInt(_unscaled);

  /// Exposes compact unscaled coefficient to internal operation modules.
  @internal
  @pragma('vm:prefer-inline')
  Object get compactUnscaledValueForModules => _unscaled;

  /// Exposes scale to internal operation modules.
  @internal
  @pragma('vm:prefer-inline')
  int get scaleForModules => _scale;

  /// Exposes signed-zero marker to internal operation modules.
  @internal
  bool get isNegativeZeroForModules => false;

  /// Exposes cached precision to internal operation modules.
  @internal
  int get precisionForModules => internal_ops.getDigitCountFromCoefficient(_unscaled);

  /// Whether this value is finite.
  bool get isFinite => form == DecimalForm.finite;

  /// Whether this value is an infinity.
  bool get isInfinite => form == DecimalForm.infinite;

  /// Whether this value is a quiet or signaling NaN.
  bool get isNaN => form == DecimalForm.nan || form == DecimalForm.signalingNan;

  /// Whether this value is a signaling NaN.
  bool get isSignalingNan => form == DecimalForm.signalingNan;

  /// Returns `-1`, `0`, or `1` depending on the sign of the value.
  @pragma('vm:prefer-inline')
  int get sign => internal_ops.coefficientSign(_unscaled);

  /// Whether the value has a negative sign bit.
  @pragma('vm:prefer-inline')
  bool get hasNegativeSign => internal_ops.hasNegativeSignBit(this);

  /// Whether the value is exactly zero.
  @pragma('vm:prefer-inline')
  bool get isZero => isFinite && sign == 0;

  /// Whether the value is greater than zero.
  @pragma('vm:prefer-inline')
  bool get isPositive => sign > 0;

  /// Whether the value is less than zero.
  @pragma('vm:prefer-inline')
  bool get isNegative => sign < 0;

  /// Returns whether [other] has the same numeric value **and** the same scale.
  bool hasSameRepresentation(BigDecimal other) {
    if (!isFinite || !other.isFinite) {
      return form == other.form &&
          hasNegativeSign == other.hasNegativeSign &&
          diagnostic == other.diagnostic;
    }

    return _scale == other._scale &&
        internal_ops.coefficientsEqual(_unscaled, other._unscaled) &&
        isNegativeZeroForModules == other.isNegativeZeroForModules;
  }

  /// Returns whether this value and [other] share the same quantum.
  ///
  /// In the current finite representation, this is equivalent to comparing
  /// scales directly.
  bool sameQuantum(BigDecimal other) => comparison.sameQuantumBigDecimals(this, other);

  @override
  String toString() => toPlainString();

  /// Returns this value in plain decimal notation.
  String toPlainString() => formatter.formatBigDecimalPlain(this);

  /// Returns this value using the package GDA-compatible token policy.
  ///
  /// This preserves the current representation and chooses plain notation only
  /// when the adjusted exponent is at least `-6` and the scale is non-negative.
  /// Otherwise, scientific notation is used.
  String toGdaString() => formatter.formatBigDecimalGda(this);

  /// Returns this value in normalized scientific notation.
  String toScientificString() => formatter.formatBigDecimalScientific(this);

  /// Returns this value in engineering notation.
  String toEngineeringString() => formatter.formatBigDecimalEngineering(this);

  /// Returns fixed-point formatting with exactly [decimalPlaces] digits after
  /// the decimal point.
  String toStringAsFixed(
    int decimalPlaces, [
    RoundingMode roundingMode = RoundingMode.halfUp,
  ]) {
    return formatter.formatBigDecimalAsFixed(this, decimalPlaces, roundingMode);
  }

  /// Returns plain-decimal formatting rounded to [sigDigits] significant
  /// digits.
  String toStringAsPrecision(
    int sigDigits, [
    RoundingMode roundingMode = RoundingMode.halfUp,
  ]) {
    return formatter.formatBigDecimalAsPrecision(this, sigDigits, roundingMode);
  }

  // Arithmetic: add, subtract, multiply.

  /// Returns the sum of this value and [other].
  ///
  /// If [context] is provided, the result is rounded and can trap (throw)
  /// according to `context.traps`. Otherwise, performs exact addition.
  BigDecimal add(BigDecimal other, {DecimalContext? context}) {
    if (context == null) return adder.addBigDecimals(this, other);
    final result = adder.addBigDecimalsResult(this, other, context);
    trapDecimalConditions(context, result.conditions);
    return result.value;
  }

  /// Returns the sum of this value and [other] rounded with [context].
  ///
  /// Returns emitted conditions without trapping. Callers decide how to
  /// handle conditions such as rounding or precision loss.
  DecimalOperationResult<BigDecimal> addResult(
    BigDecimal other, {
    required DecimalContext context,
  }) {
    return adder.addBigDecimalsResult(this, other, context);
  }

  /// Returns the difference of this value and [other].
  ///
  /// If [context] is provided, the result is rounded and can trap (throw)
  /// according to `context.traps`. Otherwise, performs exact subtraction.
  BigDecimal subtract(BigDecimal other, {DecimalContext? context}) {
    if (context == null) return adder.subtractBigDecimals(this, other);
    final result = adder.subtractBigDecimalsResult(this, other, context);
    trapDecimalConditions(context, result.conditions);
    return result.value;
  }

  /// Returns the difference of this value and [other] rounded with [context].
  ///
  /// Returns emitted conditions without trapping. Callers decide how to
  /// handle conditions such as rounding or precision loss.
  DecimalOperationResult<BigDecimal> subtractResult(
    BigDecimal other, {
    required DecimalContext context,
  }) {
    return adder.subtractBigDecimalsResult(this, other, context);
  }

  /// Returns the product of this value and [other].
  ///
  /// If [context] is provided, the result is rounded and can trap (throw)
  /// according to `context.traps`. Otherwise, performs exact multiplication.
  BigDecimal multiply(BigDecimal other, {DecimalContext? context}) {
    if (context == null) return adder.multiplyBigDecimals(this, other);
    final result = adder.multiplyBigDecimalsResult(this, other, context);
    trapDecimalConditions(context, result.conditions);
    return result.value;
  }

  /// Returns the product of this value and [other], rounded with [context].
  ///
  /// Returns emitted conditions without trapping. Callers decide how to
  /// handle conditions such as rounding or precision loss.
  DecimalOperationResult<BigDecimal> multiplyResult(
    BigDecimal other, {
    required DecimalContext context,
  }) {
    return adder.multiplyBigDecimalsResult(this, other, context);
  }

  // Division APIs.

  /// Divides this value by [divisor] using an explicit result [scale].
  BigDecimal divideToScale(
    BigDecimal divisor, {
    required int scale,
    required RoundingMode roundingMode,
  }) {
    return divider.divideBigDecimals(
      this,
      divisor,
      scale: scale,
      roundingMode: roundingMode,
    );
  }

  /// Divides this value by [divisor] using [context] precision and rounding.
  ///
  /// Traps (throws) if any emitted conditions are in `context.traps`.
  BigDecimal divide(
    BigDecimal divisor, {
    required DecimalContext context,
  }) {
    return divider.divideBigDecimalsWithContextTrapping(this, divisor, context);
  }

  /// Divides this value by [divisor] using [context] precision and rounding.
  ///
  /// Returns emitted conditions without trapping. Callers decide how to
  /// handle conditions such as rounding or precision loss.
  DecimalOperationResult<BigDecimal> divideResult(
    BigDecimal divisor, {
    required DecimalContext context,
  }) {
    return divider.divideBigDecimalsResult(this, divisor, context);
  }

  /// Divides this value by [divisor], throwing if the decimal expansion does
  /// not terminate.
  BigDecimal divideExact(BigDecimal divisor) => divider.divideBigDecimalsExact(this, divisor);

  /// Attempts to divide this value by [divisor] exactly.
  ///
  /// Returns the exact quotient when the decimal expansion terminates
  /// (for example `1 / 4 = 0.25`). Returns `null` when the expansion does
  /// not terminate (for example `1 / 3`), so callers can branch without
  /// catching an exception.
  ///
  /// Prefer this over `try { divideExact(...) } on BigDecimalArithmeticException`
  /// when a non-terminating division is an expected, non-exceptional outcome.
  BigDecimal? tryDivideExact(BigDecimal divisor) {
    return divider.tryDivideExactly(this, divisor);
  }

  /// Returns the truncating quotient and remainder as a record.
  ({BigDecimal quotient, BigDecimal remainder}) divideAndRemainder(
    BigDecimal divisor,
  ) {
    return divider.divideAndRemainderBigDecimals(this, divisor);
  }

  // Power and square-root APIs.

  /// Raises this value to the integer [exponent] exactly.
  ///
  /// Negative exponents require a terminating reciprocal - throws
  /// [BigDecimalArithmeticException] if the result is non-terminating.
  /// Use [tryDivideExact] or [pow] with an explicit context when
  /// a non-terminating result is acceptable.
  BigDecimal powExact(int exponent) => pow_ops.powBigDecimalExact(this, exponent);

  /// Raises this value to the integer [exponent] using [context] precision
  /// and rounding.
  ///
  /// The result is computed using a higher-precision working context and then
  /// rounded to [context], trapping configured conditions from the final
  /// operation result.
  BigDecimal pow(int exponent, {required DecimalContext context}) =>
      pow_ops.powBigDecimalWithContextTrapping(this, exponent, context);

  /// Raises this value to the integer [exponent] and returns emitted
  /// conditions without trapping.
  ///
  /// Undefined cases that require NaN or Infinity signaling still throw
  /// [BigDecimalArithmeticException] because this package currently models
  /// finite decimals only.
  DecimalOperationResult<BigDecimal> powResult(
    int exponent, {
    required DecimalContext context,
  }) {
    return pow_ops.powBigDecimalsResult(this, exponent, context);
  }

  /// Returns the exact square root of this value.
  ///
  /// The square root must be exactly representable as a finite decimal or
  /// this method throws [BigDecimalArithmeticException]. Use [sqrt] with an
  /// explicit context when an irrational result is acceptable.
  BigDecimal sqrtExact() => sqrt_ops.sqrtBigDecimalExact(this);

  /// Returns the square root of this value using [context] precision and
  /// rounding.
  ///
  /// The result is computed using a GDA-style extra-digit algorithm and
  /// rounded with `halfEven`, trapping configured conditions from the final
  /// operation result.
  BigDecimal sqrt({required DecimalContext context}) =>
      sqrt_ops.sqrtBigDecimalWithContextTrapping(this, context);

  /// Returns the square root of this value together with emitted conditions.
  ///
  /// Negative operands still throw [BigDecimalArithmeticException] because the
  /// package currently models finite decimals only and does not expose NaN.
  DecimalOperationResult<BigDecimal> sqrtResult({required DecimalContext context}) {
    return sqrt_ops.sqrtBigDecimalsResult(this, context);
  }

  // Scale and rounding APIs.

  /// Returns this value with exactly [newScale] decimal places.
  BigDecimal setScale(int newScale, RoundingMode roundingMode) {
    return rounding.setBigDecimalScale(this, newScale, roundingMode);
  }

  /// Alias for [setScale] that emphasizes rounding to decimal places.
  BigDecimal round(int decimalPlaces, RoundingMode roundingMode) {
    return setScale(decimalPlaces, roundingMode);
  }

  /// Returns an equivalent value rounded to [sigDigits] significant digits.
  BigDecimal roundToPrecision(int sigDigits, RoundingMode roundingMode) {
    return rounding.roundBigDecimalToPrecision(this, sigDigits, roundingMode);
  }

  /// Returns this value rounded according to [context].
  ///
  /// Traps (throws) if any emitted conditions are in `context.traps`.
  BigDecimal roundWithContext(DecimalContext context) {
    final result = rounding.roundBigDecimalResult(this, context);
    trapDecimalConditions(context, result.conditions);
    return result.value;
  }

  /// Returns this value rounded according to [context].
  ///
  /// Returns emitted conditions without trapping. Callers decide how to
  /// handle conditions such as rounding or precision loss.
  DecimalOperationResult<BigDecimal> roundResult(DecimalContext context) {
    return rounding.roundBigDecimalResult(this, context);
  }

  /// Returns this value with exactly [newScale] decimal places, plus
  /// emitted conditions indicating whether digits were discarded.
  ///
  /// This is the non-trapping companion to [setScale]. Use [setScale] when
  /// you only need the rounded value, or [setScaleResult] when callers must
  /// inspect emitted conditions such as [DecimalCondition.rounded] and
  /// [DecimalCondition.inexact].
  DecimalOperationResult<BigDecimal> setScaleResult(
    int newScale,
    RoundingMode roundingMode,
  ) {
    return rounding.setBigDecimalScaleResult(this, newScale, roundingMode);
  }

  // Unary and utility transforms.

  /// Returns the absolute value while preserving the current scale.
  BigDecimal abs() => adder.absBigDecimal(this);

  /// Returns the additive inverse while preserving the current scale.
  BigDecimal negate() => adder.negateBigDecimal(this);

  /// Applies unary plus with context rounding and condition reporting.
  DecimalOperationResult<BigDecimal> plusResult(DecimalContext context) {
    return adder.plusBigDecimalResult(this, context);
  }

  /// Applies unary minus with context rounding and condition reporting.
  DecimalOperationResult<BigDecimal> minusResult(DecimalContext context) {
    return adder.minusBigDecimalResult(this, context);
  }

  /// Applies unary plus with context rounding and trap behavior.
  BigDecimal plus(DecimalContext context) {
    return plusResult(context).valueOrThrow(context);
  }

  /// Applies unary minus with context rounding and trap behavior.
  BigDecimal minus(DecimalContext context) {
    return minusResult(context).valueOrThrow(context);
  }

  /// Clamps this value to the inclusive range [lowerLimit]...[upperLimit].
  BigDecimal clamp(BigDecimal lowerLimit, BigDecimal upperLimit) {
    return adder.clampBigDecimal(this, lowerLimit, upperLimit);
  }

  /// Moves the decimal point left by [n] positions without rounding.
  BigDecimal movePointLeft(int n) => adder.movePointLeftBigDecimal(this, n);

  /// Moves the decimal point right by [n] positions without rounding.
  BigDecimal movePointRight(int n) => adder.movePointRightBigDecimal(this, n);

  // Numeric conversions.

  /// Converts this value to a truncated [BigInt].
  BigInt toBigInt() => conversion.bigDecimalToBigInt(this);

  /// Converts this value to an exact [BigInt].
  BigInt toBigIntExact() => conversion.bigDecimalToBigIntExact(this);

  /// Converts this value to a truncated [int].
  int toInt() => conversion.bigDecimalToInt(this);

  /// Converts this value to an exact [int].
  int toIntExact() => conversion.bigDecimalToIntExact(this);

  /// Converts this value to [double].
  double toDouble() => conversion.bigDecimalToDouble(this);

  /// Serializes this value as a JSON-safe [String].
  ///
  /// Returns the canonical decimal text (the same output as [toString]) so
  /// the value round-trips losslessly through `jsonEncode` and
  /// [BigDecimal.fromJson]. The returned type is always `String` - embed it
  /// as a JSON string rather than a JSON number to avoid the precision loss
  /// that occurs when JSON numbers are parsed into doubles.
  ///
  /// ```dart
  /// final value = BigDecimal.parse('0.1');
  /// jsonEncode({'amount': value.toJson()}); // {"amount":"0.1"}
  /// ```
  String toJson() => conversion.bigDecimalToJson(this);

  /// Removes trailing zero digits from the unscaled representation,
  /// reducing the scale accordingly.
  BigDecimal stripTrailingZeros() => rounding.stripTrailingZeros(this);

  // Operators.

  /// Returns the additive inverse while preserving the current scale.
  BigDecimal operator -() => negate();

  /// Returns the sum of this value and [other].
  BigDecimal operator +(BigDecimal other) => adder.addBigDecimals(this, other);

  /// Returns the difference of this value and [other].
  BigDecimal operator -(BigDecimal other) => adder.subtractBigDecimals(this, other);

  /// Returns the product of this value and [other].
  BigDecimal operator *(BigDecimal other) => adder.multiplyBigDecimals(this, other);

  /// Returns the truncating integer quotient of this value divided by [other].
  BigInt operator ~/(BigDecimal other) => divider.truncatingDivideBigDecimals(this, other);

  /// Returns the remainder after truncating division by [other].
  BigDecimal operator %(BigDecimal other) => divider.remainderBigDecimals(this, other);

  // Comparison and equality semantics.

  @override
  int compareTo(BigDecimal other) => comparison.compareBigDecimals(this, other);

  /// Compares this value and [other] using finite total-order semantics.
  ///
  /// Numerically equal values are ordered by representation so that, for
  /// example, `12.30` sorts before `12.3`.
  int compareTotal(BigDecimal other) => comparison.compareTotalBigDecimals(this, other);

  /// Compares this value and [other] by total order on magnitude.
  ///
  /// The current finite implementation ignores sign when the absolute values
  /// compare equal and then orders by representation.
  int compareTotalMagnitude(BigDecimal other) {
    return comparison.compareTotalMagnitudeBigDecimals(this, other);
  }

  @override
  bool operator ==(Object other) {
    if (other is! BigDecimal) {
      return false;
    }

    if (isNaN || other.isNaN) {
      return false;
    }

    if (!isFinite || !other.isFinite) {
      return form == other.form &&
          hasNegativeSign == other.hasNegativeSign &&
          diagnostic == other.diagnostic;
    }

    return identical(this, other) || compareTo(other) == 0;
  }

  @override
  int get hashCode => _cachedHashCode;
}
