import 'package:precise_decimal/precise_decimal.dart';

import 'dec_test_case.dart';

const int _maxFiniteScaleMagnitudeForDecTestRunner = 10000;

/// GDA operations supported by the current runner scope.
const Set<String> supportedOperations = <String>{
  'abs',
  'add',
  'apply',
  'compare',
  'comparetotmag',
  'comparetotal',
  'comparetotalmag',
  'divide',
  'divideint',
  'max',
  'maxmag',
  'min',
  'minmag',
  'minus',
  'multiply',
  'plus',
  'power',
  'reduce',
  'remainder',
  'rescale',
  'squareroot',
  'subtract',
  'toeng',
  'tointegral',
  'tointegralx',
  'tosci',
};

// Keep this empty unless a specific fixture-level deviation must be documented.
const Map<String, String> knownSkipIds = <String, String>{};
const Set<String> supportedConditionAssertions = <String>{
  'clamped',
  'division_by_zero',
  'inexact',
  'invalid_operation',
  'overflow',
  'rounded',
};
const Set<String> supportedConditionOperations = <String>{
  'abs',
  'add',
  'apply',
  'compare',
  'divide',
  'max',
  'maxmag',
  'min',
  'minmag',
  'minus',
  'multiply',
  'plus',
  'power',
  'reduce',
  'rescale',
  'squareroot',
  'subtract',
  'tointegralx',
};

/// Returns a skip reason for unsupported cases, or `null` if the case should run.
String? skipReason(DecTestCase testCase) {
  if (!supportedOperations.contains(testCase.operation)) {
    return '${testCase.operation}: op not implemented in milestone 1';
  }

  final normalizedRounding = testCase.rounding.toLowerCase();
  if (normalizedRounding == '05up' || normalizedRounding == 'round_05up') {
    return 'rounding mode ${testCase.rounding} is not supported';
  }

  final allValues = <String>[...testCase.operands, testCase.expected];
  final hasUnsupportedEncoding = allValues.any(_hasUnsupportedEncoding);
  if (hasUnsupportedEncoding) {
    return 'special encodings are not supported';
  }

  final hasSpecialValues = allValues.any(_hasSpecialValueToken);
  if (hasSpecialValues && !_supportsSpecialValueCase(testCase)) {
    return 'special values are not yet supported for ${testCase.operation}';
  }

  if (allValues.any(_isOutsideCurrentFiniteRange)) {
    return 'finite literal is outside the current supported scale range';
  }

  // For power, skip when the exponent itself is NaN/Infinity (our exponent is int).
  if (testCase.operation == 'power' && testCase.operands.length >= 2) {
    final exponent = testCase.operands[1];
    if (_hasSpecialValueToken(exponent)) {
      return 'power: NaN/Infinity exponent not supported (only integer exponents)';
    }
    // Skip power operations with fractional exponents (not supported by pow(int)).
    // This check runs after special-value/range filtering so BigDecimal.parse is safe.
    final parsedExponent = BigDecimal.parse(exponent);
    if (parsedExponent case final FiniteDecimal finiteExponent) {
      if (!finiteExponent.isInteger) {
        return 'power: fractional exponents not supported (only integer exponents)';
      }
    } else {
      return 'power: non-finite exponent not supported (only integer exponents)';
    }
    // Skip when the exponent does not fit in Dart's int (int64). The pow() API
    // requires an int, so values beyond int64 range cannot be dispatched.
    try {
      parsedExponent.toIntExact();
    } on BigDecimalConversionException {
      return 'power: exponent overflows int64 (value: $exponent)';
    }
  }

  final unsupportedConditions = testCase.conditions.difference(supportedConditionAssertions);
  if (unsupportedConditions.isNotEmpty) {
    return 'condition assertions require unsupported signals: '
        '${unsupportedConditions.toList()..sort()}';
  }

  if (testCase.conditions.isNotEmpty &&
      !supportedConditionOperations.contains(testCase.operation)) {
    return 'condition assertions for ${testCase.operation} are not yet supported';
  }

  final knownReason = knownSkipIds[testCase.id];
  if (knownReason != null) {
    return 'known deviation: $knownReason';
  }

  return null;
}

bool _hasUnsupportedEncoding(String value) {
  final normalized = value.toLowerCase();
  return normalized.startsWith('#');
}

bool _hasSpecialValueToken(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('nan') || normalized.contains('inf');
}

bool _supportsSpecialValueCase(DecTestCase testCase) {
  // These operations have full NaN/Infinity propagation support.
  const supported = <String>{
    'abs',
    'add',
    'apply',
    'compare',
    'divide',
    'max',
    'maxmag',
    'min',
    'minmag',
    'minus',
    'multiply',
    'plus',
    'power',
    'reduce',
    'squareroot',
    'subtract',
    'toeng',
    'tosci',
  };
  return supported.contains(testCase.operation);
}

bool _isOutsideCurrentFiniteRange(String value) {
  try {
    final parsed = BigDecimal.parse(value);
    if (parsed case final FiniteDecimal finiteValue) {
      return finiteValue.scale.abs() > _maxFiniteScaleMagnitudeForDecTestRunner;
    }
    return false;
  } on BigDecimalOverflowException {
    return true;
  }
}
