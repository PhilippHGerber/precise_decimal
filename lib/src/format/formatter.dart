import 'dart:collection';

import 'package:meta/meta.dart';

import '../core/big_decimal.dart';
import '../rounding_mode.dart';

@internal
String formatBigDecimalPlain(BigDecimal value) {
  final cacheKey = _PlainStringCacheKey.from(value);
  final cached = _plainStringCache.lookup(cacheKey);
  if (cached != null) {
    return cached;
  }

  final formatted = _formatBigDecimalPlainUncached(value);
  _plainStringCache.store(cacheKey, formatted);
  return formatted;
}

String _formatBigDecimalPlainUncached(BigDecimal value) {
  if (!value.isFinite) {
    return _formatSpecialValue(value);
  }

  final finite = _asFinite(value);
  if (finite.isZero && finite.scale < 0) {
    return '${value.hasNegativeSign ? '-' : ''}0';
  }

  if (finite.scale == 0) {
    if (finite.isZero) {
      return value.hasNegativeSign ? '-0' : '0';
    }
    return finite.unscaledValue.toString();
  }

  final negative = value.hasNegativeSign;
  final digits = finite.unscaledValue.abs().toString();

  if (finite.scale < 0) {
    final buffer = StringBuffer();
    if (negative) {
      buffer.write('-');
    }
    buffer
      ..write(digits)
      ..write('0' * (-finite.scale));
    return buffer.toString();
  }

  if (digits.length > finite.scale) {
    final splitIndex = digits.length - finite.scale;
    final buffer = StringBuffer();
    if (negative) {
      buffer.write('-');
    }
    buffer
      ..write(digits.substring(0, splitIndex))
      ..write('.')
      ..write(digits.substring(splitIndex));
    return buffer.toString();
  }

  final buffer = StringBuffer();
  if (negative) {
    buffer.write('-');
  }
  buffer
    ..write('0.')
    ..write('0' * (finite.scale - digits.length))
    ..write(digits);
  return buffer.toString();
}

const int _plainStringCacheMaxEntries = 512;
const int _plainStringCacheMaxChars = 512;

final _plainStringCache = _BoundedPlainStringCache(
  maxEntries: _plainStringCacheMaxEntries,
  maxChars: _plainStringCacheMaxChars,
);

final class _BoundedPlainStringCache {
  _BoundedPlainStringCache({
    required this.maxEntries,
    required this.maxChars,
  });

  final int maxEntries;
  final int maxChars;
  final LinkedHashMap<_PlainStringCacheKey, String> _entries =
      LinkedHashMap<_PlainStringCacheKey, String>();

  String? lookup(_PlainStringCacheKey key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }

    // Re-insert on hit to keep least-recently-used eviction order.
    _entries[key] = value;
    return value;
  }

  void store(_PlainStringCacheKey key, String value) {
    if (value.length > maxChars) {
      return;
    }

    _entries[key] = value;
    if (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

@immutable
final class _PlainStringCacheKey {
  const _PlainStringCacheKey._({
    required this.unscaledValue,
    required this.scale,
    required this.form,
    required this.isNegativeZero,
    required this.hasNegativeSign,
    this.diagnostic,
  });

  factory _PlainStringCacheKey.from(BigDecimal value) {
    return _PlainStringCacheKey._(
      unscaledValue: value.unscaledValueForModules,
      scale: value.scaleForModules,
      form: value.form,
      isNegativeZero: value.isNegativeZeroForModules,
      hasNegativeSign: value.hasNegativeSign,
      diagnostic: value.diagnostic,
    );
  }

  final BigInt unscaledValue;
  final int scale;
  final DecimalForm form;
  final bool isNegativeZero;
  final bool hasNegativeSign;
  final String? diagnostic;

  @override
  bool operator ==(Object other) {
    if (other is! _PlainStringCacheKey) {
      return false;
    }

    return unscaledValue == other.unscaledValue &&
        scale == other.scale &&
        form == other.form &&
        isNegativeZero == other.isNegativeZero &&
        hasNegativeSign == other.hasNegativeSign &&
        diagnostic == other.diagnostic;
  }

  @override
  int get hashCode {
    return Object.hash(
      unscaledValue,
      scale,
      form,
      isNegativeZero,
      hasNegativeSign,
      diagnostic,
    );
  }
}

@internal
String formatBigDecimalGda(BigDecimal value) {
  if (!value.isFinite) {
    return _formatSpecialValue(value);
  }

  final finite = _asFinite(value);
  final digits = finite.unscaledValue.abs().toString();
  final adjustedExponent = digits.length - finite.scale - 1;

  if (finite.scale >= 0 && adjustedExponent >= -6) {
    return value.toPlainString();
  }

  final buffer = StringBuffer();
  if (value.hasNegativeSign) {
    buffer.write('-');
  }
  if (digits.length == 1) {
    buffer.write(digits);
  } else {
    buffer
      ..write(digits[0])
      ..write('.')
      ..write(digits.substring(1));
  }
  buffer.write(_formatExponent(adjustedExponent));
  return buffer.toString();
}

@internal
String formatBigDecimalScientific(BigDecimal value) {
  if (!value.isFinite) {
    return _formatSpecialValue(value);
  }

  final normalized = value.stripTrailingZeros();
  if (normalized.isZero) {
    return normalized.hasNegativeSign ? '-0' : '0';
  }

  final finite = _asFinite(normalized);
  final digits = finite.unscaledValue.abs().toString();
  final exponent = finite.precision - finite.scale - 1;
  final buffer = StringBuffer();
  if (normalized.hasNegativeSign) {
    buffer.write('-');
  }
  if (digits.length == 1) {
    buffer.write(digits);
  } else {
    buffer
      ..write(digits[0])
      ..write('.')
      ..write(digits.substring(1));
  }
  buffer.write(_formatExponent(exponent));
  return buffer.toString();
}

@internal
String formatBigDecimalEngineering(BigDecimal value) {
  if (!value.isFinite) {
    return _formatSpecialValue(value);
  }

  final normalized = value.stripTrailingZeros();
  if (normalized.isZero) {
    return normalized.hasNegativeSign ? '-0' : '0';
  }

  final finite = _asFinite(normalized);
  final digits = finite.unscaledValue.abs().toString();
  final adjustedExponent = finite.precision - finite.scale - 1;
  final engineeringExponent = _floorDivide(adjustedExponent, 3) * 3;
  final integerDigits = adjustedExponent - engineeringExponent + 1;
  final coefficient = _formatCoefficient(
    digits: digits,
    integerDigits: integerDigits,
  );
  final buffer = StringBuffer();
  if (normalized.hasNegativeSign) {
    buffer.write('-');
  }
  buffer
    ..write(coefficient)
    ..write(_formatExponent(engineeringExponent));
  return buffer.toString();
}

@internal
String formatBigDecimalAsFixed(
  BigDecimal value,
  int decimalPlaces,
  RoundingMode roundingMode,
) {
  if (decimalPlaces < 0) {
    throw ArgumentError.value(
      decimalPlaces,
      'decimalPlaces',
      'Must be non-negative.',
    );
  }

  return value.setScale(decimalPlaces, roundingMode).toPlainString();
}

@internal
String formatBigDecimalAsPrecision(
  BigDecimal value,
  int sigDigits,
  RoundingMode roundingMode,
) {
  return value.roundToPrecision(sigDigits, roundingMode).toPlainString();
}

FiniteDecimal _asFinite(BigDecimal value) {
  if (value case final FiniteDecimal finite) {
    return finite;
  }
  throw StateError('Expected a finite BigDecimal value.');
}

String _formatExponent(int exponent) {
  final buffer = StringBuffer('E');
  if (exponent >= 0) {
    buffer.write('+');
  }
  buffer.write(exponent);
  return buffer.toString();
}

String _formatCoefficient({required String digits, required int integerDigits}) {
  if (digits.length <= integerDigits) {
    return digits.padRight(integerDigits, '0');
  }

  final buffer = StringBuffer()
    ..write(digits.substring(0, integerDigits))
    ..write('.')
    ..write(digits.substring(integerDigits));
  return buffer.toString();
}

String _formatSpecialValue(BigDecimal value) {
  return switch (value) {
    InfinityDecimal() => _formatSpecialToken(
        isNegative: value.hasNegativeSign,
        token: 'Infinity',
      ),
    NaNDecimal(isSignaling: false) => _formatSpecialToken(
        isNegative: value.hasNegativeSign,
        token: 'NaN',
        diagnostic: value.diagnostic,
      ),
    NaNDecimal(isSignaling: true) => _formatSpecialToken(
        isNegative: value.hasNegativeSign,
        token: 'sNaN',
        diagnostic: value.diagnostic,
      ),
    FiniteDecimal() => throw StateError('Expected a non-finite BigDecimal value.'),
  };
}

String _formatSpecialToken({
  required bool isNegative,
  required String token,
  String? diagnostic,
}) {
  final buffer = StringBuffer();
  if (isNegative) {
    buffer.write('-');
  }
  buffer.write(token);
  if (diagnostic != null) {
    buffer.write(diagnostic);
  }
  return buffer.toString();
}

int _floorDivide(int dividend, int divisor) {
  final quotient = dividend ~/ divisor;
  final remainder = dividend.remainder(divisor);
  if (remainder != 0 && ((dividend < 0) != (divisor < 0))) {
    return quotient - 1;
  }
  return quotient;
}
