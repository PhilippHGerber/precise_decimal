/// Supported decimal rounding strategies.
enum RoundingMode {
  /// Round away from zero whenever discarded digits are non-zero.
  up,

  /// Truncate discarded digits towards zero.
  down,

  /// Round towards positive infinity.
  ceiling,

  /// Round towards negative infinity.
  floor,

  /// Round towards the nearest neighbor, ties away from zero.
  halfUp,

  /// Round towards the nearest neighbor, ties towards zero.
  halfDown,

  /// Round towards the nearest neighbor, ties to the even retained digit.
  halfEven,

  /// Reject any result that would require rounding.
  unnecessary,
}
