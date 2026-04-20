/// IEEE 754 / GDA condition that can be signaled during decimal arithmetic.
enum DecimalCondition {
  /// Result exponent was adjusted to fit the available range.
  clamped('clamped'),

  /// Division by zero was attempted.
  divisionByZero('division_by_zero'),

  /// The exact result could not be represented.
  inexact('inexact'),

  /// The requested operation has no defined result.
  invalidOperation('invalid_operation'),

  /// The rounded result exceeded the maximum exponent.
  overflow('overflow'),

  /// Digits were discarded during rounding.
  rounded('rounded'),

  /// The result lies in the subnormal range.
  subnormal('subnormal'),

  /// The rounded result was both tiny and inexact.
  underflow('underflow');

  const DecimalCondition(this.gdaName);

  /// Canonical lower-case GDA spelling used in `.decTest` files.
  final String gdaName;

  @override
  String toString() => 'DecimalCondition.$name';
}
