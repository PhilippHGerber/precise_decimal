part of 'big_decimal.dart';

BigDecimal _createNaNDecimal({
  required bool isSignaling,
  required bool negative,
  String? diagnostic,
}) {
  return NaNDecimal._(
    isSignaling: isSignaling,
    diagnostic: diagnostic,
    negative: negative,
  );
}

/// Quiet or signaling not-a-number value.
///
/// NaN values may carry optional diagnostic digits and may be signed.
@immutable
final class NaNDecimal extends BigDecimal {
  NaNDecimal._({
    required this.isSignaling,
    String? diagnostic,
    bool negative = false,
  })  : _diagnostic = diagnostic,
        super.internal(negative ? -1 : 1, 0);

  /// Whether this NaN is signaling rather than quiet.
  final bool isSignaling;

  final String? _diagnostic;

  @override
  DecimalForm get form => isSignaling ? DecimalForm.signalingNan : DecimalForm.nan;

  @override
  String? get diagnostic => _diagnostic;
}
