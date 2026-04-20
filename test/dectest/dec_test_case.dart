import 'package:meta/meta.dart';

/// Immutable directive snapshot captured when a decTest case is parsed.
@immutable
final class DecTestDirectiveState {
  /// Creates a directive snapshot.
  const DecTestDirectiveState({
    required this.precision,
    required this.rounding,
    required this.maxExponent,
    required this.minExponent,
    required this.extended,
    required this.clamp,
  });

  /// Default directive state used before any file directives are applied.
  static const DecTestDirectiveState initial = DecTestDirectiveState(
    precision: 9,
    rounding: 'half_up',
    maxExponent: 999,
    minExponent: -999,
    extended: true,
    clamp: false,
  );

  /// The active precision in significant digits.
  final int precision;

  /// The active GDA rounding mode name.
  final String rounding;

  /// The active maximum exponent.
  final int maxExponent;

  /// The active minimum exponent.
  final int minExponent;

  /// Whether extended arithmetic is enabled.
  final bool extended;

  /// Whether exponent clamping is enabled.
  final bool clamp;

  /// Returns a copy with selected fields replaced.
  DecTestDirectiveState copyWith({
    int? precision,
    String? rounding,
    int? maxExponent,
    int? minExponent,
    bool? extended,
    bool? clamp,
  }) {
    return DecTestDirectiveState(
      precision: precision ?? this.precision,
      rounding: rounding ?? this.rounding,
      maxExponent: maxExponent ?? this.maxExponent,
      minExponent: minExponent ?? this.minExponent,
      extended: extended ?? this.extended,
      clamp: clamp ?? this.clamp,
    );
  }
}

/// Immutable representation of one parsed GDA decTest case.
@immutable
final class DecTestCase {
  /// Creates a parsed decTest case.
  const DecTestCase({
    required this.id,
    required this.operation,
    required this.operands,
    required this.expected,
    required this.conditions,
    required this.context,
    required this.sourcePath,
    required this.lineNumber,
  });

  /// Stable decTest case identifier, for example `dqadd001`.
  final String id;

  /// Lower-cased GDA operation name.
  final String operation;

  /// Parsed operand strings in source order.
  final List<String> operands;

  /// Expected result token as written in the decTest file.
  final String expected;

  /// Lower-cased expected condition flags.
  final Set<String> conditions;

  /// Active directive snapshot captured at parse time.
  final DecTestDirectiveState context;

  /// Source file path used for diagnostics.
  final String sourcePath;

  /// One-based source line used for diagnostics.
  final int lineNumber;

  /// Active precision in significant digits.
  int get precision => context.precision;

  /// Active GDA rounding mode name.
  String get rounding => context.rounding;

  /// Active maximum exponent.
  int get maxExponent => context.maxExponent;

  /// Active minimum exponent.
  int get minExponent => context.minExponent;

  /// Whether extended arithmetic is enabled.
  bool get extended => context.extended;

  /// Whether exponent clamping is enabled.
  bool get clamp => context.clamp;
}
