import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/big_decimal.dart';
import '../exceptions.dart';

@internal
BigDecimal parseBigDecimal(String source) {
  final trimmed = source.trim();
  final specialValue = _tryParseSpecialValue(trimmed);
  if (specialValue != null) {
    return specialValue;
  }

  final literal = _scanFiniteDecimalLiteral(trimmed);
  if (literal == null) {
    throw BigDecimalParseException('Invalid decimal literal: $source', source);
  }

  final exponent = literal.parseExponent(trimmed);
  final scale = _tryScaleFromParsedExponent(
    fractionalDigits: literal.fractionalDigitsLength,
    exponent: exponent,
  );
  if (scale == null) {
    throw BigDecimalOverflowException(
      'Decimal literal is outside supported scale range '
      '[${BigDecimal.minScale}, ${BigDecimal.maxScale}]: $source',
    );
  }

  return BigDecimal.createForModules(
    literal.parseUnscaledDigits(trimmed),
    scale: scale,
    isNegativeZero: literal.isNegative && literal.isZero(trimmed),
  );
}

BigDecimal? _tryParseSpecialValue(String source) {
  final scanned = _scanSpecialValue(source);
  if (scanned == null) {
    return null;
  }

  if (scanned.isInfinity) {
    return BigDecimal.infinity(negative: scanned.isNegative);
  }

  final diagnostic =
      scanned.diagnosticStart == source.length ? null : source.substring(scanned.diagnosticStart);
  return BigDecimal.nan(
    signaling: scanned.isSignalingNan,
    diagnostic: diagnostic,
    negative: scanned.isNegative,
  );
}

@internal
BigDecimal? tryParseBigDecimal(String source) {
  final trimmed = source.trim();
  final specialValue = _tryParseSpecialValue(trimmed);
  if (specialValue != null) {
    return specialValue;
  }

  final literal = _scanFiniteDecimalLiteral(trimmed);
  if (literal == null) {
    return null;
  }

  final scale = _tryScaleFromParsedExponent(
    fractionalDigits: literal.fractionalDigitsLength,
    exponent: literal.parseExponent(trimmed),
  );
  if (scale == null) {
    return null;
  }

  return BigDecimal.createForModules(
    literal.parseUnscaledDigits(trimmed),
    scale: scale,
    isNegativeZero: literal.isNegative && literal.isZero(trimmed),
  );
}

@internal
BigDecimal bigDecimalFromDouble(double value) {
  if (!value.isFinite) {
    throw const BigDecimalConversionException(
      'Non-finite double values are not supported.',
    );
  }
  return BigDecimal.parse(value.toString());
}

@internal
BigDecimal bigDecimalFromDoubleExact(double value) {
  if (!value.isFinite) {
    throw const BigDecimalConversionException(
      'Non-finite double values are not supported.',
    );
  }

  if (value == 0.0) {
    return BigDecimal.createForModules(
      BigInt.zero,
      scale: 0,
      isNegativeZero: value.isNegative,
    );
  }

  const exponentMask = 0x7ff;
  const exponentBias = 1023;
  const fractionBits = 52;

  // Use two 32-bit reads instead of getUint64 so the exact-double path also
  // works under dart2js, where Uint64 accessors are not supported.
  final bytes = ByteData(8)..setFloat64(0, value);
  final highBits = bytes.getUint32(0);
  final lowBits = bytes.getUint32(4);

  final isNegative = (highBits & 0x80000000) != 0;
  final rawExponent = (highBits >> 20) & exponentMask;
  final fraction = ((BigInt.from(highBits & 0x000fffff)) << 32) | BigInt.from(lowBits);

  late final BigInt significand;
  late final int binaryExponent;
  if (rawExponent == 0) {
    // Subnormal: no implicit leading 1.
    significand = fraction;
    binaryExponent = 1 - exponentBias - fractionBits;
  } else {
    significand = (BigInt.one << fractionBits) | fraction;
    binaryExponent = rawExponent - exponentBias - fractionBits;
  }

  late final BigInt unscaled;
  late final int scale;
  if (binaryExponent >= 0) {
    unscaled = significand << binaryExponent;
    scale = 0;
  } else {
    final denominatorPower = -binaryExponent;
    unscaled = significand * BigInt.from(5).pow(denominatorPower);
    scale = denominatorPower;
  }

  var normalizedUnscaled = unscaled;
  var normalizedScale = scale;
  final ten = BigInt.from(10);
  while (normalizedScale > 0 && normalizedUnscaled.remainder(ten) == BigInt.zero) {
    normalizedUnscaled ~/= ten;
    normalizedScale -= 1;
  }

  final signedUnscaled = isNegative ? -normalizedUnscaled : normalizedUnscaled;
  return BigDecimal.fromComponents(signedUnscaled, scale: normalizedScale);
}

@internal
BigDecimal bigDecimalFromJson(Object json) {
  return switch (json) {
    final String value => BigDecimal.parse(value),
    final int value => BigDecimal.fromInt(value),
    final double _ => throw const BigDecimalConversionException(
        'BigDecimal.fromJson refuses double values because the original '
        'decimal literal is lost once JSON is parsed into an IEEE-754 '
        'double. Emit decimal numbers as JSON strings and round-trip them '
        'through BigDecimal.toJson / fromJson. If you deliberately want '
        'the imprecise conversion, call BigDecimal.fromDouble or '
        'BigDecimal.fromDoubleExact explicitly.',
      ),
    _ => throw BigDecimalConversionException(
        'Unsupported JSON value for BigDecimal: ${json.runtimeType}',
      ),
  };
}

// For a literal like "1.23E+1" the unscaled value is 123 and the scale must
// satisfy: 123 * 10^-scale == 12.3, so scale = fractionalDigits - exponent = 2 - 1 = 1.
int? _tryScaleFromParsedExponent({
  required int fractionalDigits,
  required BigInt exponent,
}) {
  final scale = BigInt.from(fractionalDigits) - exponent;
  final minScale = BigInt.from(BigDecimal.minScale);
  final maxScale = BigInt.from(BigDecimal.maxScale);
  if (scale < minScale || scale > maxScale) {
    return null;
  }
  return scale.toInt();
}

_ScannedFiniteDecimalLiteral? _scanFiniteDecimalLiteral(String source) {
  if (source.isEmpty) {
    return null;
  }

  final length = source.length;
  var index = 0;
  var isNegative = false;

  if (index < length) {
    final first = source.codeUnitAt(index);
    if (first == _plus || first == _minus) {
      isNegative = first == _minus;
      index += 1;
      if (index == length) {
        return null;
      }
    }
  }

  final integerStart = index;
  while (index < length && _isAsciiDigit(source.codeUnitAt(index))) {
    index += 1;
  }
  final integerEnd = index;
  final hasIntegerDigits = integerEnd > integerStart;

  var hasDecimalPoint = false;
  var fractionStart = index;
  var fractionEnd = index;
  if (index < length && source.codeUnitAt(index) == _dot) {
    hasDecimalPoint = true;
    index += 1;
    fractionStart = index;
    while (index < length && _isAsciiDigit(source.codeUnitAt(index))) {
      index += 1;
    }
    fractionEnd = index;
  }

  final hasFractionDigits = fractionEnd > fractionStart;
  if (!hasIntegerDigits && !hasFractionDigits) {
    return null;
  }
  if (!hasIntegerDigits && !hasDecimalPoint) {
    return null;
  }

  int? exponentStart;
  int? exponentEnd;
  if (index < length) {
    final codeUnit = source.codeUnitAt(index);
    if (codeUnit == _lowerE || codeUnit == _upperE) {
      index += 1;
      if (index == length) {
        return null;
      }

      exponentStart = index;
      final exponentSign = source.codeUnitAt(index);
      if (exponentSign == _plus || exponentSign == _minus) {
        index += 1;
        if (index == length) {
          return null;
        }
      }

      final exponentDigitsStart = index;
      while (index < length && _isAsciiDigit(source.codeUnitAt(index))) {
        index += 1;
      }
      if (index == exponentDigitsStart) {
        return null;
      }
      exponentEnd = index;
    }
  }

  if (index != length) {
    return null;
  }

  return _ScannedFiniteDecimalLiteral(
    isNegative: isNegative,
    integerStart: integerStart,
    integerEnd: integerEnd,
    fractionStart: fractionStart,
    fractionEnd: fractionEnd,
    exponentStart: exponentStart,
    exponentEnd: exponentEnd,
  );
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= _zero && codeUnit <= _nine;

const int _plus = 0x2b;
const int _minus = 0x2d;
const int _dot = 0x2e;
const int _zero = 0x30;
const int _nine = 0x39;
const int _upperE = 0x45;
const int _lowerE = 0x65;

const int _upperI = 0x49;
const int _lowerI = 0x69;
const int _upperN = 0x4e;
const int _lowerN = 0x6e;
const int _upperF = 0x46;
const int _lowerF = 0x66;
const int _upperA = 0x41;
const int _lowerA = 0x61;
const int _upperS = 0x53;
const int _lowerS = 0x73;

_ScannedSpecialValue? _scanSpecialValue(String source) {
  if (source.isEmpty) {
    return null;
  }

  final length = source.length;
  var index = 0;
  var isNegative = false;

  if (index < length) {
    final sign = source.codeUnitAt(index);
    if (sign == _plus || sign == _minus) {
      isNegative = sign == _minus;
      index += 1;
      if (index == length) {
        return null;
      }
    }
  }

  final first = source.codeUnitAt(index);

  // inf / infinity
  if (_isAsciiLetter(first, _upperI, _lowerI)) {
    if (index + 2 >= length) {
      return null;
    }
    if (!_isAsciiLetter(source.codeUnitAt(index + 1), _upperN, _lowerN) ||
        !_isAsciiLetter(source.codeUnitAt(index + 2), _upperF, _lowerF)) {
      return null;
    }

    index += 3;
    if (index == length) {
      return _ScannedSpecialValue.infinity(isNegative: isNegative);
    }

    const suffix = 'inity';
    if (index + suffix.length != length) {
      return null;
    }

    for (var offset = 0; offset < suffix.length; offset++) {
      final expected = suffix.codeUnitAt(offset);
      final actual = source.codeUnitAt(index + offset);
      if (_toAsciiLower(actual) != expected) {
        return null;
      }
    }

    return _ScannedSpecialValue.infinity(isNegative: isNegative);
  }

  // nan / snan with optional decimal diagnostic payload.
  var signaling = false;
  if (_isAsciiLetter(first, _upperS, _lowerS)) {
    signaling = true;
    index += 1;
    if (index == length) {
      return null;
    }
  }

  if (index + 2 >= length) {
    return null;
  }
  if (!_isAsciiLetter(source.codeUnitAt(index), _upperN, _lowerN) ||
      !_isAsciiLetter(source.codeUnitAt(index + 1), _upperA, _lowerA) ||
      !_isAsciiLetter(source.codeUnitAt(index + 2), _upperN, _lowerN)) {
    return null;
  }

  index += 3;
  final diagnosticStart = index;
  while (index < length) {
    if (!_isAsciiDigit(source.codeUnitAt(index))) {
      return null;
    }
    index += 1;
  }

  return _ScannedSpecialValue.nan(
    isNegative: isNegative,
    isSignalingNan: signaling,
    diagnosticStart: diagnosticStart,
  );
}

bool _isAsciiLetter(int codeUnit, int uppercase, int lowercase) {
  return codeUnit == uppercase || codeUnit == lowercase;
}

int _toAsciiLower(int codeUnit) {
  if (codeUnit >= 0x41 && codeUnit <= 0x5a) {
    return codeUnit + 0x20;
  }
  return codeUnit;
}

final class _ScannedSpecialValue {
  const _ScannedSpecialValue.infinity({required this.isNegative})
      : isInfinity = true,
        isSignalingNan = false,
        diagnosticStart = 0;

  const _ScannedSpecialValue.nan({
    required this.isNegative,
    required this.isSignalingNan,
    required this.diagnosticStart,
  }) : isInfinity = false;

  final bool isNegative;
  final bool isInfinity;
  final bool isSignalingNan;
  final int diagnosticStart;
}

final class _ScannedFiniteDecimalLiteral {
  const _ScannedFiniteDecimalLiteral({
    required this.isNegative,
    required this.integerStart,
    required this.integerEnd,
    required this.fractionStart,
    required this.fractionEnd,
    required this.exponentStart,
    required this.exponentEnd,
  });

  final bool isNegative;
  final int integerStart;
  final int integerEnd;
  final int fractionStart;
  final int fractionEnd;
  final int? exponentStart;
  final int? exponentEnd;

  int get fractionalDigitsLength => fractionEnd - fractionStart;

  BigInt parseExponent(String source) {
    if (exponentStart == null || exponentEnd == null) {
      return BigInt.zero;
    }

    return BigInt.parse(source.substring(exponentStart!, exponentEnd));
  }

  BigInt parseUnscaledDigits(String source) {
    final integerDigits =
        integerEnd == integerStart ? '0' : source.substring(integerStart, integerEnd);
    final fractionalDigits = source.substring(fractionStart, fractionEnd);
    final digitText = fractionalDigits.isEmpty ? integerDigits : '$integerDigits$fractionalDigits';
    final signedDigitText = isNegative ? '-$digitText' : digitText;
    return BigInt.parse(signedDigitText);
  }

  bool isZero(String source) {
    for (var index = integerStart; index < integerEnd; index++) {
      if (source.codeUnitAt(index) != _zero) {
        return false;
      }
    }
    for (var index = fractionStart; index < fractionEnd; index++) {
      if (source.codeUnitAt(index) != _zero) {
        return false;
      }
    }
    return true;
  }
}
