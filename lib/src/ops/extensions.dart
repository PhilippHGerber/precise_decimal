import '../core/big_decimal.dart';

/// Ergonomic conversion from `int` to [BigDecimal].
///
/// Equivalent to `BigDecimal.fromInt(value)`. Integer conversion is always
/// exact, so only one variant is needed.
extension IntToBigDecimal on int {
  /// Returns `BigDecimal.fromInt(this)`.
  BigDecimal toBigDecimal() => BigDecimal.fromInt(this);
}

/// Ergonomic conversions from `double` to [BigDecimal].
///
/// Intentionally provides **no** unqualified `toBigDecimal()` on `double`.
/// The two available paths preserve different things:
///
/// - [toBigDecimalShortest] — shortest round-trip string, matching
///   `double.toString()`. Use when the double came from a human-typed
///   source (for example `0.1` should round-trip as `0.1`).
/// - [toBigDecimalExact] — the mathematically exact IEEE-754 binary value.
///   Use when you need the true numeric content of the float bits
///   (for example `0.1` becomes
///   `0.1000000000000000055511151231257827021181583404541015625`).
///
/// For a precision-focused library the two semantics are meaningfully
/// different; forcing the caller to choose prevents silent loss of
/// information.
extension DoubleToBigDecimal on double {
  /// Returns `BigDecimal.fromDouble(this)` — shortest round-trip value.
  BigDecimal toBigDecimalShortest() => BigDecimal.fromDouble(this);

  /// Returns `BigDecimal.fromDoubleExact(this)` — exact IEEE-754 value.
  BigDecimal toBigDecimalExact() => BigDecimal.fromDoubleExact(this);
}
