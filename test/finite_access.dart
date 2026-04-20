import 'package:precise_decimal/precise_decimal.dart';

extension FiniteAccess on BigDecimal {
  FiniteDecimal get _finite {
    if (this case final FiniteDecimal finite) {
      return finite;
    }
    throw StateError('Non-finite BigDecimal values do not expose finite metadata.');
  }

  BigInt get unscaledValue => _finite.unscaledValue;

  int get scale => _finite.scale;

  bool get isNegativeZero => _finite.isNegativeZero;

  bool get isInteger => _finite.isInteger;

  bool get isNegativeScale => _finite.isNegativeScale;

  int get precision => _finite.precision;
}
