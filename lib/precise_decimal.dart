/// Arbitrary-precision decimal arithmetic with explicit scale preservation.
///
/// The package models decimal values as `unscaledValue * 10^(-scale)` and
/// preserves the parsed or constructed scale unless a caller explicitly changes
/// it.
library;

export 'src/context/decimal_condition.dart';
export 'src/context/decimal_context.dart' hide trapDecimalConditions;
export 'src/core/big_decimal.dart';
export 'src/decimal_operation_result.dart';
export 'src/exceptions.dart';
export 'src/ops/extensions.dart';
export 'src/rounding_mode.dart';
