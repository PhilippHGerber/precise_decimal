import 'context/decimal_condition.dart';

/// Base interface for package-specific decimal failures.
///
/// Most package exceptions extend this type directly. Parse failures also
/// implement this type while remaining compatible with [FormatException].
sealed class BigDecimalException implements Exception {
  /// Creates a decimal exception with a message.
  const BigDecimalException(this.message);

  /// Detailed error message.
  final String message;

  @override
  String toString() => 'BigDecimalException: $message';
}

/// Exception thrown when a decimal conversion fails.
final class BigDecimalConversionException extends BigDecimalException {
  /// Creates a conversion exception.
  const BigDecimalConversionException(super.message);

  @override
  String toString() => 'BigDecimalConversionException: $message';
}

/// Exception thrown when an arithmetic operation fails.
class BigDecimalArithmeticException extends BigDecimalException {
  /// Creates an arithmetic exception.
  const BigDecimalArithmeticException(super.message);

  @override
  String toString() => 'BigDecimalArithmeticException: $message';
}

/// Exception thrown when a result exceeds the supported exponent range.
final class BigDecimalOverflowException extends BigDecimalArithmeticException {
  /// Creates an overflow exception.
  const BigDecimalOverflowException(super.message);

  @override
  String toString() => 'BigDecimalOverflowException: $message';
}

/// Exception thrown when a parse operation fails.
final class BigDecimalParseException extends FormatException implements BigDecimalException {
  /// Creates a parse exception.
  const BigDecimalParseException(super.message, [super.source, super.offset]);

  @override
  String toString() => 'BigDecimalParseException: $message';
}

/// Exception thrown when a [DecimalCondition] is signaled and the active
/// `DecimalContext` is configured to trap it.
final class BigDecimalSignalException extends BigDecimalArithmeticException {
  /// Creates a signal exception.
  const BigDecimalSignalException(this.condition, String message) : super(message);

  /// The condition that triggered the trap.
  final DecimalCondition condition;

  @override
  String toString() => 'BigDecimalSignalException(${condition.name}): $message';
}
