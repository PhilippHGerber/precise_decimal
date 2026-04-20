import 'package:test/test.dart';

import 'dec_test_case.dart';
import 'skip_checker.dart';

void main() {
  group('skipReason', () {
    test('does not skip exact-token-sensitive abs and add cases', () {
      final absCase = _testCase(
        id: 'absx038',
        operation: 'abs',
        operands: <String>['0.000000000001'],
        expected: '1E-12',
      );
      final addCase = _testCase(
        id: 'addx035',
        operation: 'add',
        operands: <String>['70', '10000e+9'],
        expected: '1.00000000E+13',
      );

      expect(skipReason(absCase), isNull);
      expect(skipReason(addCase), isNull);
    });

    test('allows currently supported rounded and inexact condition checks', () {
      final conditionCase = _testCase(
        id: 'divx001',
        operation: 'divide',
        operands: <String>['1.5', '2'],
        expected: '0.75',
        conditions: <String>{'inexact', 'rounded'},
      );

      expect(skipReason(conditionCase), isNull);
    });

    test('allows special-value divide semantics with supported conditions', () {
      final conditionCase = _testCase(
        id: 'divx002',
        operation: 'divide',
        operands: <String>['1', '0'],
        expected: 'Infinity',
        conditions: <String>{'division_by_zero'},
      );

      expect(skipReason(conditionCase), isNull);
    });

    test('skips only truly unsupported semantics', () {
      final unsupportedOperationCase = _testCase(
        id: 'expx001',
        operation: 'exp',
        operands: <String>['2'],
        expected: '7.38905610',
      );
      final specialOperandCase = _testCase(
        id: 'addx901',
        operation: 'add',
        operands: <String>['NaN', '1'],
        expected: 'NaN',
      );
      final compareNanCase = _testCase(
        id: 'cmpx901',
        operation: 'compare',
        operands: <String>['NaN', '1'],
        expected: 'NaN',
      );

      expect(skipReason(unsupportedOperationCase), contains('not implemented'));
      // add with NaN is now in the supported special-value scope.
      expect(skipReason(specialOperandCase), isNull);
      // compare with NaN is now in the supported special-value scope via _compareResult.
      expect(skipReason(compareNanCase), isNull);
    });

    test('skips unsupported condition families even on finite cases', () {
      // subnormal is not yet in supportedConditionAssertions.
      final subnormalCase = _testCase(
        id: 'maxx500',
        operation: 'max',
        operands: <String>['9.999E+10', '0'],
        expected: '9.999E+10',
        conditions: <String>{'subnormal', 'rounded'},
      );

      expect(skipReason(subnormalCase), contains('unsupported signals'));
    });

    test('skips finite literals outside the current supported scale range', () {
      final outOfRangeCase = _testCase(
        id: 'comx095',
        operation: 'compare',
        operands: <String>['1E+1000000001', '1E+1000000001'],
        expected: '0',
      );

      expect(
        skipReason(outOfRangeCase),
        contains('outside the current supported scale range'),
      );
    });

    test('does not skip large integer power exponents for canonical unit base', () {
      final largePowerCase = _testCase(
        id: 'powx2041',
        operation: 'power',
        operands: <String>['1', '1000000000'],
        expected: '1',
      );

      expect(skipReason(largePowerCase), isNull);
    });

    test('does not skip exact negative power-of-ten parity cases', () {
      final regularCase = _testCase(
        id: 'powx121',
        operation: 'power',
        operands: <String>['10', '-77'],
        expected: '1E-77',
      );
      final boundaryCase = _testCase(
        id: 'powx2317',
        operation: 'power',
        operands: <String>['10', '-383'],
        expected: '1E-383',
      );

      expect(skipReason(regularCase), isNull);
      expect(skipReason(boundaryCase), isNull);
    });

    test('skips giant finite exponents that would exceed decTest runner limits', () {
      final giantFiniteCase = _testCase(
        id: 'divx970',
        operation: 'divide',
        operands: <String>['1e+600000000', '1e-400000001'],
        expected: '1E+1000000001',
      );

      expect(
        skipReason(giantFiniteCase),
        contains('outside the current supported scale range'),
      );
    });

    test('skips condition-bearing operations without emission support', () {
      final remainderCase = _testCase(
        id: 'remx343',
        operation: 'remainder',
        operands: <String>['0.5', '0.5000000001'],
        expected: '0.500000000',
        conditions: <String>{'rounded'},
      );

      expect(skipReason(remainderCase), contains('remainder'));
    });
  });
}

DecTestCase _testCase({
  required String id,
  required String operation,
  required List<String> operands,
  required String expected,
  Set<String> conditions = const <String>{},
}) {
  return DecTestCase(
    id: id,
    operation: operation,
    operands: operands,
    expected: expected,
    conditions: conditions,
    context: DecTestDirectiveState.initial,
    sourcePath: '<test>',
    lineNumber: 1,
  );
}
