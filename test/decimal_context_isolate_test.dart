@TestOn('vm')
library;

import 'dart:isolate';

import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('DecimalContext across Isolate boundaries', () {
    test('explicit context passed to an isolate produces the correct result', () async {
      const ctx = DecimalContext(precision: 3);

      final result = await Isolate.run(() => _divideWithContext(ctx));

      expect(result, '0.333');
    });

    test('different explicit contexts produce different results', () async {
      final result32 = await Isolate.run(
        () => _divideWithContext(DecimalContext.decimal32),
      );
      final result64 = await Isolate.run(
        () => _divideWithContext(DecimalContext.decimal64),
      );

      expect(result32, '0.3333333');
      expect(result64, '0.3333333333333333');
    });
  });
}

String _divideWithContext(DecimalContext context) =>
    BigDecimal.one.divide(BigDecimal.fromInt(3), context: context).toString();
