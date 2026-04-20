import 'package:meta/meta.dart';

import '../core/big_decimal.dart';
import '../exceptions.dart';

@internal
BigInt bigDecimalToBigInt(BigDecimal value) {
  if (!value.isFinite) {
    throw const BigDecimalArithmeticException(
      'BigInt conversion does not yet support NaN or Infinity values.',
    );
  }

  final finite = value as FiniteDecimal;
  final ten = BigInt.from(10);

  if (finite.scale <= 0) {
    return finite.unscaledValue * ten.pow(-finite.scale);
  }

  return finite.unscaledValue ~/ ten.pow(finite.scale);
}

@internal
BigInt bigDecimalToBigIntExact(BigDecimal value) {
  if (!value.isFinite || !(value as FiniteDecimal).isInteger) {
    throw BigDecimalConversionException(
      'Value has a fractional part and cannot be converted exactly to BigInt: '
      '$value',
    );
  }

  return bigDecimalToBigInt(value);
}

@internal
int bigDecimalToInt(BigDecimal value) {
  final truncated = bigDecimalToBigInt(value);
  if (!truncated.isValidInt) {
    throw BigDecimalConversionException(
      'Value is outside the supported int range: $value',
    );
  }
  return truncated.toInt();
}

@internal
int bigDecimalToIntExact(BigDecimal value) {
  final exact = bigDecimalToBigIntExact(value);
  if (!exact.isValidInt) {
    throw BigDecimalConversionException(
      'Value is outside the supported int range: $value',
    );
  }
  return exact.toInt();
}

@internal
double bigDecimalToDouble(BigDecimal value) {
  if (value.isInfinite) {
    return value.hasNegativeSign ? double.negativeInfinity : double.infinity;
  }
  if (value.isNaN) {
    return double.nan;
  }

  if (value.isZero) {
    return value.hasNegativeSign ? -0.0 : 0.0;
  }

  return double.parse(value.toScientificString());
}

@internal
String bigDecimalToJson(BigDecimal value) => value.toPlainString();
