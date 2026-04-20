@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'dec_test_parser.dart';
import 'skip_checker.dart';

void main() {
  group('DecTestParser', () {
    test('parses a simple add case with directive snapshot fields', () {
      const source = '''
precision: 9
rounding: half_up
maxExponent: 384
minExponent: -383

addx001 add 1 2 -> 3
''';

      final cases = DecTestParser().parse(source);

      expect(cases, hasLength(1));
      expect(cases.first.id, equals('addx001'));
      expect(cases.first.operation, equals('add'));
      expect(cases.first.operands, equals(<String>['1', '2']));
      expect(cases.first.expected, equals('3'));
      expect(cases.first.precision, equals(9));
      expect(cases.first.rounding, equals('half_up'));
      expect(cases.first.maxExponent, equals(384));
      expect(cases.first.minExponent, equals(-383));
    });

    test('directive changes affect only subsequent cases', () {
      const source = '''
precision: 7
addx001 add 1 2 -> 3
precision: 34
addx002 add 4 5 -> 9
''';

      final cases = DecTestParser().parse(source);

      expect(cases, hasLength(2));
      expect(cases[0].precision, equals(7));
      expect(cases[1].precision, equals(34));
    });

    test('strips comments outside quoted operands', () {
      const source = "addx001 add '1--2' 3 -> '1--23' -- trailing comment";

      final cases = DecTestParser().parse(source);

      expect(cases.single.operands, equals(<String>['1--2', '3']));
      expect(cases.single.expected, equals('1--23'));
      expect(cases.single.conditions, isEmpty);
    });

    test('parses quoted operands and conditions', () {
      const source = "divx001 divide '1.5' 2 -> '0.75' Inexact Rounded";

      final cases = DecTestParser().parse(source);

      expect(cases.single.operands, equals(<String>['1.5', '2']));
      expect(cases.single.expected, equals('0.75'));
      expect(cases.single.conditions, equals(<String>{'inexact', 'rounded'}));
    });

    test('parses double-quoted operands and expected tokens', () {
      const source = 'addx6069 add "-1234567890123455.234567890123454" '
          '"1234567890123456" -> "0.765432109876546"';

      final cases = DecTestParser().parse(source);

      expect(
        cases.single.operands,
        equals(<String>['-1234567890123455.234567890123454', '1234567890123456']),
      );
      expect(cases.single.expected, equals('0.765432109876546'));
    });

    test('skip checker allows supported condition assertions', () {
      const source = "divx001 divide '1.5' 2 -> '0.75' Inexact Rounded";

      final cases = DecTestParser().parse(source);

      expect(skipReason(cases.single), isNull);
    });

    test('parses dectest includes with an isolated parser state', () {
      final tempDirectory = Directory.systemTemp.createTempSync('precise-decimal-dectest');
      addTearDown(() => tempDirectory.deleteSync(recursive: true));

      final includeFile = File('${tempDirectory.path}/sub.decTest')
        ..writeAsStringSync('precision: 12\nsubx001 add 1 1 -> 2\n');

      final source = '''
precision: 7
dectest: ${includeFile.path.split('/').last}
addx002 add 4 5 -> 9
''';

      final cases = DecTestParser().parse(
        source,
        sourceDir: tempDirectory.path,
        sourcePath: '${tempDirectory.path}/root.decTest',
      );

      expect(cases, hasLength(2));
      expect(cases[0].id, equals('subx001'));
      expect(cases[0].precision, equals(12));
      expect(cases[1].id, equals('addx002'));
      expect(cases[1].precision, equals(7));
    });

    test('skip checker rejects special values and unsupported operations', () {
      final addNanCase = DecTestParser().parse('addx001 add NaN 2 -> NaN').single;
      final unsupportedOperationCase = DecTestParser().parse('expx001 exp 2 -> 7.38905610').single;
      // compare with NaN is now in the supported special-value scope via _compareResult.
      final compareNanCase = DecTestParser().parse('cmpx001 compare NaN 2 -> NaN').single;

      // add and compare with NaN are now in the supported special-value scope.
      expect(skipReason(addNanCase), isNull);
      expect(skipReason(unsupportedOperationCase), contains('not implemented'));
      expect(skipReason(compareNanCase), isNull);
    });
  });
}
