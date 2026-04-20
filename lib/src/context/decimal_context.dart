import 'package:meta/meta.dart';

import '../exceptions.dart';
import '../rounding_mode.dart';
import 'decimal_condition.dart';

/// Immutable configuration for decimal operations that require rounding or
/// precision limiting (e.g. division).
@immutable
final class DecimalContext {
  /// Creates a decimal context.
  ///
  /// When [precision] is provided it must be strictly positive and is expressed
  /// in significant digits. When exponent bounds are provided, both
  /// [maxExponent] and [minExponent] must be specified.
  const DecimalContext({
    this.precision,
    this.roundingMode = RoundingMode.halfEven,
    this.maxExponent,
    this.minExponent,
    this.extended = true,
    this.clamp = false,
    this.traps = const <DecimalCondition>{},
  })  : assert(precision == null || precision > 0, 'precision must be > 0'),
        assert(
          (maxExponent == null) == (minExponent == null),
          'maxExponent and minExponent must both be set or both be null',
        ),
        assert(
          maxExponent == null || (minExponent != null && maxExponent >= minExponent),
          'maxExponent must be >= minExponent',
        ),
        assert(
          !clamp || maxExponent != null,
          'clamp requires exponent bounds',
        );
  static const Object _unset = Object();

  /// IEEE decimal32 interchange context.
  static const DecimalContext decimal32 = DecimalContext(
    precision: 7,
    maxExponent: 96,
    minExponent: -95,
    extended: false,
    clamp: true,
  );

  /// IEEE decimal64 interchange context.
  static const DecimalContext decimal64 = DecimalContext(
    precision: 16,
    maxExponent: 384,
    minExponent: -383,
    extended: false,
    clamp: true,
  );

  /// IEEE decimal128 interchange context.
  static const DecimalContext decimal128 = DecimalContext(
    precision: 34,
    maxExponent: 6144,
    minExponent: -6143,
    extended: false,
    clamp: true,
  );

  /// Unlimited precision context.
  static const DecimalContext unlimited = DecimalContext();

  /// Immutable default context used when no scoped context is active.
  static const DecimalContext defaultContext = decimal128;

  /// Maximum number of significant digits to retain, or `null` for unlimited.
  final int? precision;

  /// Rounding strategy to apply when digits must be discarded.
  final RoundingMode roundingMode;

  /// Largest permitted adjusted exponent, or `null` when unbounded.
  final int? maxExponent;

  /// Smallest permitted adjusted exponent, or `null` when unbounded.
  final int? minExponent;

  /// Whether extended arithmetic semantics are enabled.
  final bool extended;

  /// Whether results should be clamped to the maximum exponent.
  final bool clamp;

  /// Conditions that should trap instead of only being recorded.
  final Set<DecimalCondition> traps;

  /// Whether this context has explicit exponent bounds.
  bool get hasExponentBounds => maxExponent != null;

  /// Returns whether [condition] is configured to trap.
  bool trapsCondition(DecimalCondition condition) => traps.contains(condition);

  /// Returns a copy with selected fields replaced.
  ///
  /// Pass `null` to [precision], [maxExponent], or [minExponent] to clear the
  /// respective bound.
  DecimalContext copyWith({
    Object? precision = _unset,
    RoundingMode? roundingMode,
    Object? maxExponent = _unset,
    Object? minExponent = _unset,
    bool? extended,
    bool? clamp,
    Set<DecimalCondition>? traps,
  }) {
    return DecimalContext(
      precision: identical(precision, _unset) ? this.precision : precision as int?,
      roundingMode: roundingMode ?? this.roundingMode,
      maxExponent: identical(maxExponent, _unset) ? this.maxExponent : maxExponent as int?,
      minExponent: identical(minExponent, _unset) ? this.minExponent : minExponent as int?,
      extended: extended ?? this.extended,
      clamp: clamp ?? this.clamp,
      traps: traps ?? this.traps,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DecimalContext &&
            other.precision == precision &&
            other.roundingMode == roundingMode &&
            other.maxExponent == maxExponent &&
            other.minExponent == minExponent &&
            other.extended == extended &&
            other.clamp == clamp &&
            _sameTrapSet(other.traps, traps);
  }

  @override
  int get hashCode => Object.hash(
        precision,
        roundingMode,
        maxExponent,
        minExponent,
        extended,
        clamp,
        Object.hashAllUnordered(traps),
      );

  @override
  String toString() {
    return 'DecimalContext('
        'precision: $precision, '
        'roundingMode: $roundingMode, '
        'maxExponent: $maxExponent, '
        'minExponent: $minExponent, '
        'extended: $extended, '
        'clamp: $clamp, '
        'traps: $traps'
        ')';
  }

  static bool _sameTrapSet(
    Set<DecimalCondition> left,
    Set<DecimalCondition> right,
  ) {
    return left.length == right.length && left.containsAll(right);
  }
}

@internal
void trapDecimalConditions(DecimalContext context, Set<DecimalCondition> conditions) {
  for (final condition in _decimalConditionTrapPrecedence) {
    if (conditions.contains(condition) && context.trapsCondition(condition)) {
      throw BigDecimalSignalException(
        condition,
        'Trapped decimal condition: ${condition.gdaName}',
      );
    }
  }
}

const List<DecimalCondition> _decimalConditionTrapPrecedence = <DecimalCondition>[
  DecimalCondition.invalidOperation,
  DecimalCondition.divisionByZero,
  DecimalCondition.overflow,
  DecimalCondition.underflow,
  DecimalCondition.subnormal,
  DecimalCondition.inexact,
  DecimalCondition.rounded,
  DecimalCondition.clamped,
];
