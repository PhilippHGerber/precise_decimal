import 'package:meta/meta.dart';
import 'package:precise_decimal/precise_decimal.dart';

import 'dec_test_case.dart';

/// Structured output emitted by the decTest dispatcher.
@immutable
final class DispatchResult {
  /// Creates a dispatch result.
  DispatchResult({
    required this.resultToken,
    Set<String> emittedConditions = const <String>{},
  }) : emittedConditions = Set.unmodifiable(emittedConditions);

  /// Actual result token emitted for comparison with the official fixture.
  final String resultToken;

  /// Emitted condition flags for exact comparison with the fixture.
  final Set<String> emittedConditions;
}

/// Executes a finite, supported decTest case and returns the actual result.
DispatchResult dispatch(DecTestCase testCase) {
  final context = _buildContext(testCase);
  final operands = testCase.operands.map(BigDecimal.parse).toList(growable: false);

  return switch (testCase.operation) {
    'abs' => _roundedFiniteResult(operands[0].abs(), context),
    'add' => _resultFromOp(operands[0].addResult(operands[1], context: context)),
    'apply' => _roundedFiniteResult(operands[0], context),
    'compare' => _compareResult(operands, context),
    'comparetotmag' => _tokenResult(
        _canonicalSignum(operands[0].compareTotalMagnitude(operands[1])).toString(),
      ),
    'comparetotal' => _tokenResult(
        _canonicalSignum(operands[0].compareTotal(operands[1])).toString(),
      ),
    'comparetotalmag' => _tokenResult(
        _canonicalSignum(operands[0].compareTotalMagnitude(operands[1])).toString(),
      ),
    'divide' => _resultFromOp(operands[0].divideResult(operands[1], context: context)),
    'divideint' => _finiteResult(operands[0].divideAndRemainder(operands[1]).quotient),
    'max' => _sNaNGuard(operands, context) ??
        _roundedFiniteResult(BigDecimal.max(operands[0], operands[1]), context),
    'maxmag' => _sNaNGuard(operands, context) ??
        _roundedFiniteResult(BigDecimal.maxMagnitude(operands[0], operands[1]), context),
    'min' => _sNaNGuard(operands, context) ??
        _roundedFiniteResult(BigDecimal.min(operands[0], operands[1]), context),
    'minmag' => _sNaNGuard(operands, context) ??
        _roundedFiniteResult(BigDecimal.minMagnitude(operands[0], operands[1]), context),
    'minus' => _resultFromOp(operands[0].minusResult(context)),
    'multiply' => _resultFromOp(operands[0].multiplyResult(operands[1], context: context)),
    'plus' => _resultFromOp(operands[0].plusResult(context)),
    'power' => _resultFromOp(
        operands[0].powResult(_parseIntegralOperand(testCase.operands[1]), context: context),
      ),
    'reduce' => _roundedFiniteResult(
        operands[0],
        context,
        finalize: (value) => value.stripTrailingZeros(),
      ),
    'remainder' => _finiteResult(operands[0] % operands[1]),
    'rescale' => _rescaleResult(
        operands[0],
        -_parseIntegralOperand(testCase.operands[1]),
        context,
      ),
    'squareroot' => _resultFromOp(operands[0].sqrtResult(context: context)),
    'subtract' => _resultFromOp(operands[0].subtractResult(operands[1], context: context)),
    'toeng' => _roundedTokenResult(
        operands[0],
        context,
        (value) => value.toEngineeringString(),
      ),
    'tointegral' => _finiteResult(_toIntegralWithContext(operands[0], context)),
    'tointegralx' => _toIntegralXResult(operands[0], context),
    'tosci' => _roundedTokenResult(
        operands[0],
        context,
        (value) => value.toScientificString(),
      ),
    _ => throw UnsupportedError('${testCase.operation} is not supported by the runner'),
  };
}

/// Executes a supported decTest operation with traps enabled for expected conditions.
void dispatchTrapping(DecTestCase testCase) {
  final traps = testCase.conditions.map(_decimalConditionFromGdaName).toSet();
  final context = _buildContext(testCase, traps: traps);
  final operands = testCase.operands.map(BigDecimal.parse).toList(growable: false);

  switch (testCase.operation) {
    case 'abs':
      operands[0].abs().roundWithContext(context);
      return;
    case 'add':
      operands[0].add(operands[1], context: context);
      return;
    case 'compare':
      // Only sNaN raises invalid_operation; quiet NaN is silent.
      if (operands.any((o) => o.isSignalingNan) &&
          context.trapsCondition(DecimalCondition.invalidOperation)) {
        throw const BigDecimalSignalException(
          DecimalCondition.invalidOperation,
          'compare: signaling NaN operand',
        );
      }
      return;
    case 'apply':
      operands[0].roundWithContext(context);
      return;
    case 'divide':
      operands[0].divide(operands[1], context: context);
      return;
    case 'max':
      if (operands.any((o) => o.isSignalingNan) &&
          context.trapsCondition(DecimalCondition.invalidOperation)) {
        throw const BigDecimalSignalException(
          DecimalCondition.invalidOperation,
          'max: signaling NaN operand',
        );
      }
      BigDecimal.max(operands[0], operands[1]).roundWithContext(context);
      return;
    case 'maxmag':
      if (operands.any((o) => o.isSignalingNan) &&
          context.trapsCondition(DecimalCondition.invalidOperation)) {
        throw const BigDecimalSignalException(
          DecimalCondition.invalidOperation,
          'maxmag: signaling NaN operand',
        );
      }
      BigDecimal.maxMagnitude(operands[0], operands[1]).roundWithContext(context);
      return;
    case 'min':
      if (operands.any((o) => o.isSignalingNan) &&
          context.trapsCondition(DecimalCondition.invalidOperation)) {
        throw const BigDecimalSignalException(
          DecimalCondition.invalidOperation,
          'min: signaling NaN operand',
        );
      }
      BigDecimal.min(operands[0], operands[1]).roundWithContext(context);
      return;
    case 'minmag':
      if (operands.any((o) => o.isSignalingNan) &&
          context.trapsCondition(DecimalCondition.invalidOperation)) {
        throw const BigDecimalSignalException(
          DecimalCondition.invalidOperation,
          'minmag: signaling NaN operand',
        );
      }
      BigDecimal.minMagnitude(operands[0], operands[1]).roundWithContext(context);
      return;
    case 'minus':
      operands[0].minus(context);
      return;
    case 'multiply':
      operands[0].multiply(operands[1], context: context);
      return;
    case 'plus':
      operands[0].plus(context);
      return;
    case 'power':
      operands[0].pow(_parseIntegralOperand(testCase.operands[1]), context: context);
      return;
    case 'reduce':
      operands[0].roundWithContext(context).stripTrailingZeros();
      return;
    case 'rescale':
      operands[0]
          .setScaleResult(-_parseIntegralOperand(testCase.operands[1]), context.roundingMode)
          .valueOrThrow(context);
      return;
    case 'squareroot':
      operands[0].sqrt(context: context);
      return;
    case 'subtract':
      operands[0].subtract(operands[1], context: context);
      return;
    case 'tointegralx':
      if (operands[0] case final FiniteDecimal finiteOperand when finiteOperand.scale > 0) {
        finiteOperand.setScaleResult(0, context.roundingMode).valueOrThrow(context);
      }
      return;
    default:
      throw UnsupportedError('${testCase.operation} does not have trap-path coverage');
  }
}

DecimalContext _buildContext(
  DecTestCase testCase, {
  Set<DecimalCondition> traps = const <DecimalCondition>{},
}) {
  return DecimalContext(
    precision: testCase.precision,
    roundingMode: _toRoundingMode(testCase.rounding),
    maxExponent: testCase.maxExponent,
    minExponent: testCase.minExponent,
    extended: testCase.extended,
    clamp: testCase.clamp,
    traps: traps,
  );
}

DispatchResult _resultFromOp(DecimalOperationResult<BigDecimal> result) {
  return _finiteResult(
    result.value,
    emittedConditions: _conditionNames(result.conditions),
  );
}

DispatchResult _rescaleResult(
  BigDecimal value,
  int newScale,
  DecimalContext context,
) {
  final result = value.setScaleResult(newScale, context.roundingMode);
  return _finiteResult(
    result.value,
    emittedConditions: _conditionNames(result.conditions),
  );
}

DispatchResult _toIntegralXResult(BigDecimal value, DecimalContext context) {
  if (value case final FiniteDecimal finiteValue) {
    if (finiteValue.scale <= 0) {
      return _finiteResult(value);
    }
    final result = finiteValue.setScaleResult(0, context.roundingMode);
    return _finiteResult(
      result.value,
      emittedConditions: _conditionNames(result.conditions),
    );
  }

  return _finiteResult(value);
}

DispatchResult _roundedFiniteResult(
  BigDecimal exactValue,
  DecimalContext context, {
  BigDecimal Function(BigDecimal value)? finalize,
}) {
  final result = exactValue.roundResult(context);
  return _finiteResult(
    finalize == null ? result.value : finalize(result.value),
    emittedConditions: _conditionNames(result.conditions),
  );
}

DispatchResult _roundedTokenResult(
  BigDecimal exactValue,
  DecimalContext context,
  String Function(BigDecimal value) emitToken,
) {
  final result = exactValue.roundResult(context);
  return _tokenResult(
    emitToken(result.value),
    emittedConditions: _conditionNames(result.conditions),
  );
}

DispatchResult _finiteResult(
  BigDecimal value, {
  Set<String> emittedConditions = const <String>{},
}) {
  return DispatchResult(
    resultToken: value.toGdaString(),
    emittedConditions: emittedConditions,
  );
}

DispatchResult _tokenResult(
  String token, {
  Set<String> emittedConditions = const <String>{},
}) {
  return DispatchResult(
    resultToken: token,
    emittedConditions: emittedConditions,
  );
}

BigDecimal _toIntegralWithContext(BigDecimal value, DecimalContext context) {
  if (value case final FiniteDecimal finiteValue) {
    if (finiteValue.scale <= 0) {
      return value;
    }

    return finiteValue.setScale(0, context.roundingMode);
  }

  return value;
}

Set<String> _conditionNames(Set<DecimalCondition> conditions) {
  return conditions.map((condition) => condition.gdaName).toSet();
}

RoundingMode _toRoundingMode(String gdaRoundingMode) {
  return switch (gdaRoundingMode.toLowerCase()) {
    'ceiling' => RoundingMode.ceiling,
    'down' => RoundingMode.down,
    'floor' => RoundingMode.floor,
    'half_down' || 'half-down' => RoundingMode.halfDown,
    'half_even' || 'half-even' => RoundingMode.halfEven,
    'half_up' || 'half-up' => RoundingMode.halfUp,
    'up' => RoundingMode.up,
    _ => throw ArgumentError('Unknown GDA rounding mode: $gdaRoundingMode'),
  };
}

int _parseIntegralOperand(String operand) {
  return BigDecimal.parse(operand).toIntExact();
}

DecimalCondition _decimalConditionFromGdaName(String conditionName) {
  return switch (conditionName.toLowerCase()) {
    'clamped' => DecimalCondition.clamped,
    'division_by_zero' => DecimalCondition.divisionByZero,
    'inexact' => DecimalCondition.inexact,
    'invalid_operation' => DecimalCondition.invalidOperation,
    'overflow' => DecimalCondition.overflow,
    'rounded' => DecimalCondition.rounded,
    'subnormal' => DecimalCondition.subnormal,
    'underflow' => DecimalCondition.underflow,
    _ => throw ArgumentError('Unknown GDA condition: $conditionName'),
  };
}

int _canonicalSignum(int value) {
  if (value < 0) {
    return -1;
  }
  if (value > 0) {
    return 1;
  }
  return 0;
}

/// GDA compare: qNaN propagates silently (first NaN wins); sNaN → qNaN + invalid_operation.
DispatchResult _compareResult(List<BigDecimal> operands, DecimalContext context) {
  // sNaN takes priority: any sNaN → first sNaN converted to qNaN + invalid_operation.
  final sNaNGuard = _sNaNGuard(operands, context);
  if (sNaNGuard != null) return sNaNGuard;
  // qNaN propagates: return first NaN operand as-is (preserving sign and diagnostic).
  final firstNaN = operands.firstWhere((o) => o.isNaN, orElse: () => operands[0]);
  if (firstNaN.isNaN) {
    return _tokenResult(firstNaN.toGdaString());
  }
  return _tokenResult(_canonicalSignum(operands[0].compareTo(operands[1])).toString());
}

/// Returns sNaN converted to qNaN + invalid_operation if any operand is sNaN, else null.
///
/// Routes through [BigDecimal.roundResult] to apply diagnostic truncation per context
/// precision (GDA rule: keep rightmost `precision` digits of the payload).
DispatchResult? _sNaNGuard(List<BigDecimal> operands, DecimalContext context) {
  // sNaN takes priority over qNaN; among multiple sNaN the first (left) wins.
  final firstSNaN = operands.firstWhere(
    (o) => o.isSignalingNan,
    orElse: () => operands[0],
  );
  if (!firstSNaN.isSignalingNan) return null;
  // roundResult converts sNaN → qNaN and truncates the diagnostic to fit precision.
  final result = firstSNaN.roundResult(context);
  return _finiteResult(result.value, emittedConditions: _conditionNames(result.conditions));
}
