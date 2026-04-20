// Example output uses print for package demonstration.
// ignore_for_file: avoid_print

import 'package:precise_decimal/precise_decimal.dart';

void main() {
  final one = BigDecimal.one;
  final three = BigDecimal.fromInt(3);

  // divide requires an explicit context — the precision policy is always visible
  // at the call site.
  final decimal32Result = one.divide(three, context: DecimalContext.decimal32);
  print('1 / 3 with decimal32 context: $decimal32Result');

  final decimal64Result = one.divide(three, context: DecimalContext.decimal64);
  print('1 / 3 with decimal64 context: $decimal64Result');

  // divideExact returns the exact result or throws for non-terminating input.
  final exact = one.divideExact(BigDecimal.fromInt(4));
  print('1 / 4 with divideExact: $exact');

  // Operators +, -, *, ~/, % are strictly exact — no context needed.
  final total = BigDecimal.parse('1.20') + BigDecimal.parse('0.03');
  print('1.20 + 0.03 = $total');

  // sqrtExact throws for irrational inputs; sqrt() requires an explicit context.
  final sqrtTwo = BigDecimal.fromInt(2).sqrt(context: DecimalContext.decimal64);
  print('sqrt(2) with decimal64 context: $sqrtTwo');
}
