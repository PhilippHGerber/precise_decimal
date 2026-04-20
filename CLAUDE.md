# CLAUDE.md

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Project Overview

`precise_decimal` is a Dart package for arbitrary-precision decimal arithmetic. It models decimal values as `unscaledValue * 10^(-scale)` and preserves the parsed or constructed scale unless explicitly changed. Targets financial and precision-critical use cases where `double` is insufficient.

The project follows the General Decimal Arithmetic Specification (IEEE 754-2008).
See `doc/speleotrove.com/decimal/index.html` and all files in `doc/speleotrove.com/decimal/`
Reference implementations are in `doc/reference/` (see [Reference Implementations](#reference-implementations) below).

## Commands

Use the Dart MCP for all commands (analyze, format, test, pub).

## Architecture

### Core Source (`lib/src/`)

- **`big_decimal.dart`**: Core immutable value type. Stores `_unscaledValue` (BigInt) and `_scale` (int). Delegates to mixin files below. Scale range is bounded to [-10000, 10000]. Equality uses numeric comparison (`compareTo == 0`); hash computed from `stripTrailingZeros()` normalized form.
- **`big_decimal_arithmetic.dart`**: Add, subtract, multiply operations.
- **`big_decimal_comparison.dart`**: `compareTo`, `min`, `max`, tie-breaking logic.
- **`big_decimal_conversion.dart`**: Conversions to/from int, double, BigInt.
- **`big_decimal_division.dart`**: Division respecting `DecimalContext` exponent range.
- **`big_decimal_formatting.dart`**: GDA-compliant `toString` / `toEngineeringString` / `toPlainString`.
- **`big_decimal_internal.dart`**: Shared internal helpers.
- **`big_decimal_parsing.dart`**: Parsing including scientific notation.
- **`big_decimal_rounding.dart`**: Rounding logic used by division and context-aware ops.
- **`decimal_context.dart`**: Immutable configuration for precision-limited operations (division, rounding). Includes IEEE-style presets (`decimal32`, `decimal64`, `decimal128`) and `defaultContext` (`decimal128`, 34 digits, halfEven).
- **`decimal_operation_result.dart`**: Wrapper for operation results with context metadata.
- **`rounding_mode.dart`**: Enum of 8 rounding strategies matching the General Decimal Arithmetic spec.
- **`exceptions.dart`**: Sealed `BigDecimalException` hierarchy with `Parse`, `Arithmetic`, `Overflow`, and `Conversion` subtypes.

### Public API (`lib/`)

- **`precise_decimal.dart`**: Barrel export.

### Tests (`test/`)

- **`test/big_decimal/`**: Unit tests per feature area:
  - `arithmetic_test.dart`, `comparison_test.dart`, `constructors_test.dart`, `conversion_test.dart`, `division_test.dart`, `formatting_test.dart`, `properties_test.dart`, `rounding_test.dart`
- **`test/decimal_context_test.dart`**: Context configuration and behavior tests.
- **`test/decimal_operation_result_test.dart`**: Operation result tests.
- **`test/exceptions_test.dart`**: Exception hierarchy tests.
- **`test/gda_shard_1_test.dart`**, **`test/gda_shard_2_test.dart`**: GDA compliance tests (sharded for parallelism).
- **`test/dectest/`**: GDA `.decTest` harness — parser, dispatcher, skip-checker, and test-case model.
- **`test/testdata/`**: `.decTest` files from the GDA test suite.

## Reference Implementations

Located in `doc/reference/`:

| Language | Path | Notes |
|----------|------|-------|
| Python | `doc/reference/cpython/_pydecimal.py` | CPython `decimal` module — pure-Python GDA reference |
| Go (CockroachDB) | `doc/reference/cockroachdb/decimal.go` | CockroachDB apd decimal |
| Go (CockroachDB) | `doc/reference/cockroachdb/context.go` | CockroachDB apd context |
| Go (shopspring) | `doc/reference/shopspring/decimal.go` | shopspring/decimal — popular Go library |
| Rust | `doc/reference/bigdecimal-rs/lib.rs` | bigdecimal-rs crate |

Consult these when implementing or cross-checking GDA behavior, rounding edge cases, or algorithm choices.

## Code Conventions

- Uses `very_good_analysis` lint rules with overrides in `analysis_options.yaml`
- Prefer relative imports within the package
- Trailing commas required (`require_trailing_commas: true`)
- Page width: 100 characters
- Classes use `final class` (Dart 3 sealed class modifiers)
- The `BigDecimal` class is `@immutable`
- SDK constraint: `^3.6.0`
- Key dev dependencies: `test`, `very_good_analysis`
- Repository: https://github.com/PhilippHGerber/precise_decimal

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
