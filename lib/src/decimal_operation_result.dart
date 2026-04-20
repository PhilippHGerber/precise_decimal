import 'package:meta/meta.dart';

import 'context/decimal_condition.dart';
import 'context/decimal_context.dart';

/// Immutable result of a decimal operation that can emit GDA conditions.
@immutable
final class DecimalOperationResult<T> {
  /// Creates an operation result.
  DecimalOperationResult({
    required this.value,
    Set<DecimalCondition> conditions = const <DecimalCondition>{},
  }) : conditions = Set.unmodifiable(conditions);

  /// Result value produced by the operation.
  final T value;

  /// Conditions emitted while computing [value].
  final Set<DecimalCondition> conditions;

  /// Returns [value] after applying the trap policy of [context] to [conditions].
  ///
  /// If any of the [conditions] are in `context.traps`, the first matching
  /// condition will trigger an exception.
  ///
  /// This provides a bridge between diagnostic and trapping APIs.
  T valueOrThrow(DecimalContext context) {
    trapDecimalConditions(context, conditions);
    return value;
  }

  /// Whether [condition] was emitted.
  bool hasCondition(DecimalCondition condition) => conditions.contains(condition);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DecimalOperationResult<T> &&
            other.value == value &&
            other.conditions.length == conditions.length &&
            other.conditions.containsAll(conditions);
  }

  @override
  int get hashCode => Object.hash(value, Object.hashAllUnordered(conditions));

  @override
  String toString() {
    return 'DecimalOperationResult(value: $value, conditions: $conditions)';
  }
}
