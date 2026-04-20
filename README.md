# precise_decimal

`precise_decimal` is an arbitrary-precision decimal package for Dart.

It models values as `unscaledValue * 10^(-scale)`, preserves the parsed or
constructed scale unless a caller changes it explicitly, and is being built
toward full General Decimal Arithmetic compliance.

Division is explicit by design: `divide` and `divideResult` require a
`DecimalContext`, `divideToScale` requires a target scale plus rounding mode,
and `divideExact`/`tryDivideExact` provide exact workflows.

## Features

- Arbitrary-precision finite decimal arithmetic backed by `BigInt`
- Preserved scale and cohort-sensitive formatting
- IEEE-style decimal contexts (`decimal32`, `decimal64`, `decimal128`)
- Explicit division APIs for context-based and exact workflows

## Getting started

Add the package to your `pubspec.yaml` and import it:

```dart
import 'package:precise_decimal/precise_decimal.dart';
```

## Division

Division APIs are explicit:

- `divideToScale` uses an explicit scale plus rounding mode
- `divide` uses the context you pass explicitly and traps configured conditions
- `divideResult` uses the context you pass explicitly and returns emitted conditions
- `divideExact` returns an exact result or throws for non-terminating division
- `tryDivideExact` returns an exact result or `null` for non-terminating division

```dart
final one = BigDecimal.one;
final three = BigDecimal.fromInt(3);

final explicit = one.divide(three, context: DecimalContext.decimal64);
print(explicit); // 0.3333333333333333

final scaled = one.divideToScale(
  three,
  scale: 6,
  roundingMode: RoundingMode.halfEven,
);
print(scaled); // 0.333333

final diagnostic = one.divideResult(three, context: DecimalContext.decimal64);
print(diagnostic.value); // 0.3333333333333333
print(diagnostic.conditions); // {inexact, rounded}

final exact = BigDecimal.one.divideExact(BigDecimal.fromInt(4));
print(exact); // 0.25

final maybeExact = BigDecimal.one.tryDivideExact(BigDecimal.fromInt(3));
print(maybeExact); // null
```

Use `divide` when the calling code must trap based on context.
Use `divideResult` when the calling code needs emitted conditions without
throwing. Use `divideExact` when non-terminating division should be treated as
an error. Use `tryDivideExact` when non-terminating division is expected and
should be handled with normal control flow instead of exceptions.

When the divisor is zero, context-based division (`divide`, `divideResult`)
follows condition semantics: it emits `divisionByZero` and yields an
infinity/NaN result unless that condition is trapped in the provided context.
`divideExact`, integer division, and remainder remain strict and throw.

## Double Conversion

Two factories are available for `double` values:

- `BigDecimal.fromDouble(x)`: preserves the displayed `double.toString()` value.
- `BigDecimal.fromDoubleExact(x)`: preserves the exact IEEE-754 binary value.

```dart
final displayed = BigDecimal.fromDouble(0.1);
print(displayed); // 0.1

final exact = BigDecimal.fromDoubleExact(0.1);
print(exact);
// 0.1000000000000000055511151231257827021181583404541015625
```

## JSON Safety

`toJson()` returns a `String` by design. This avoids precision loss when JSON
numbers are parsed through IEEE-754 doubles in JavaScript front-ends.

Use decimal strings on the wire and round-trip them with
`BigDecimal.toJson()` and `BigDecimal.fromJson(...)`.

```dart
final amount = BigDecimal.parse('0.1');
final payload = {'amount': amount.toJson()};
final encoded = jsonEncode(payload);
print(encoded); // {"amount":"0.1"}

final decoded = jsonDecode(encoded) as Map<String, Object?>;
final roundTripped = BigDecimal.fromJson(decoded['amount']!);
print(roundTripped); // 0.1
```

## Trapping vs Result APIs

Context-sensitive operations follow a split API:

- trapping path: base method with explicit context (for example `add(other, context)`)
- diagnostic path: `*Result` method (for example `addResult(other, context)`)

The diagnostic path returns `DecimalOperationResult<T>` with:

- `value`: operation output
- `conditions`: emitted GDA conditions
- `valueOrThrow(context)`: apply trap policy later when needed

## Context Usage

Pass `DecimalContext` explicitly for any context-sensitive operation.

```dart
const context = DecimalContext(
  precision: 3,
  roundingMode: RoundingMode.halfUp,
);

final result = BigDecimal.one.divide(
  BigDecimal.fromInt(3),
  context: context,
);
print(result); // 0.333
```

Longer examples live in `/example`, and the design and implementation notes are
tracked in `/doc`.
