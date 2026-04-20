part of 'big_decimal.dart';

BigDecimal _createFiniteDecimal(
  Object unscaledValue,
  int scale, {
  bool isNegativeZero = false,
}) {
  return FiniteDecimal._(
    unscaledValue,
    scale,
    isNegativeZero: isNegativeZero,
  );
}

/// Finite decimal value represented as `unscaledValue * 10^(-scale)`.
///
/// This subtype exposes finite-only metadata such as [unscaledValue], [scale],
/// and [precision]. Non-finite values are represented by [InfinityDecimal] and
/// [NaNDecimal].
@immutable
final class FiniteDecimal extends BigDecimal {
  FiniteDecimal._(
    super.unscaledValue,
    super._scale, {
    bool isNegativeZero = false,
  })  : _isNegativeZero =
            isNegativeZero && internal_ops.coefficientSign(unscaledValue) == 0,
        super.internal();

  final bool _isNegativeZero;

  @override
  DecimalForm get form => DecimalForm.finite;

  @override
  bool get isNegativeZeroForModules => _isNegativeZero;

  /// Returns the raw unscaled integer coefficient.
  @pragma('vm:prefer-inline')
  BigInt get unscaledValue => unscaledValueForModules;

  /// Returns the decimal scale where the numeric value is `unscaled * 10^-scale`.
  @pragma('vm:prefer-inline')
  int get scale => scaleForModules;

  /// Whether the finite value is zero with a negative sign bit.
  bool get isNegativeZero => isNegativeZeroForModules;

  /// Whether this value has no fractional component.
  bool get isInteger => comparison.isBigDecimalInteger(this);

  /// Whether this value uses a negative scale.
  bool get isNegativeScale => scaleForModules < 0;

  /// Returns the number of significant digits in the unscaled representation.
  int get precision => precisionForModules;

  /// Returns the adjusted exponent used by scientific notation.
  int get adjustedMagnitude => precisionForModules - scaleForModules;
}
