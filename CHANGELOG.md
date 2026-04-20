# Changelog

## Unreleased

### Breaking changes (pre-release API cleanup)

This package has not yet been published. The items below are intentional
pre-release API improvements. Adapt to the new names before the first
published release.

#### Exception hierarchy

- Added shared `BigDecimalException` sealed base interface. Catch
  `BigDecimalException` to handle any package error uniformly.
- `BigDecimalParseException` now extends `FormatException` **and** implements
  `BigDecimalException`, satisfying both Dart parse conventions and the
  package-specific catch surface.
- `BigDecimalConversionException` now extends `BigDecimalException` directly.
- `BigDecimalArithmeticException` is now a non-`final` class so subtypes
  (`BigDecimalOverflowException`, `BigDecimalSignalException`) can extend it.
- Removed `BigDecimalFormatException` (old name). Use `BigDecimalParseException`.
- `BigDecimalSignalException` now requires an explicit `message` argument;
  previously the message defaulted to the condition GDA name.

#### Context-sensitive arithmetic — split trapping / result API

All context-sensitive arithmetic operations follow a consistent two-method
pattern. The base method is the trapping path; the `*Result` companion is the
non-trapping, condition-returning path.

| Trapping method | Non-trapping companion | Notes |
|---|---|---|
| `add(other, context)` | `addResult(other, context)` | `add(other)` without context is still exact |
| `subtract(other, context)` | `subtractResult(other, context)` | same |
| `multiply(other, context)` | `multiplyResult(other, context)` | same |
| `divide(divisor, context: ...)` | `divideResult(divisor, context: ...)` | `divideToScale(...)` is the fixed-scale form |
| `roundWithContext(context)` | `roundResult(context)` | uses reserved name `round` for decimal-places alias |
| `setScale(…)` | `setScaleResult(…)` | non-context; returns emitted conditions |

- Removed `multiplyWithContext(other, context)`. Replace with
  `multiply(other, context)` (trapping) or `multiplyResult(other, context)`
  (non-trapping).
- `add`, `subtract`, and `multiply` now each accept an optional
  `[DecimalContext? context]` parameter. Calling them without a context
  performs exact arithmetic as before, with no behaviour change.
- Added `DecimalOperationResult<T>` as a public type. It carries `value`,
  `conditions`, `hasCondition(condition)`, and `valueOrThrow(context)`.

## 0.0.1

- Initial version.
