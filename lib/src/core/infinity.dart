part of 'big_decimal.dart';

BigDecimal _createInfinityDecimal({required bool negative}) {
  return InfinityDecimal._(negative: negative);
}

/// Positive or negative infinity.
///
/// Infinity carries only a sign. It does not expose finite metadata such as
/// scale or precision.
@immutable
final class InfinityDecimal extends BigDecimal {
  InfinityDecimal._({required bool negative}) : super.internal(negative ? -1 : 1, 0);

  @override
  DecimalForm get form => DecimalForm.infinite;
}
