import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import 'dec_test_case.dart';
import 'operation_dispatcher.dart';

void main() {
  group('dispatch', () {
    test('applies context rounding to addition', () {
      final testCase = _testCase(
        id: 'addx001',
        operation: 'add',
        operands: <String>['1.2345', '0.00006'],
        expected: '1.235',
        precision: 4,
      );

      final result = dispatch(testCase);

      expect(result.resultToken, equals('1.235'));
      expect(result.emittedConditions, equals(<String>{'inexact', 'rounded'}));
    });

    test('emits rounded without inexact when only zero digits are discarded', () {
      final testCase = _testCase(
        id: 'addx002',
        operation: 'add',
        operands: <String>['1000', '0'],
        expected: '1.00E+3',
        precision: 3,
        conditions: <String>{'rounded'},
      );

      final result = dispatch(testCase);

      expect(result.resultToken, equals('1.00E+3'));
      expect(result.emittedConditions, equals(<String>{'rounded'}));
    });

    test('uses context-aware multiply', () {
      final testCase = _testCase(
        id: 'mulx001',
        operation: 'multiply',
        operands: <String>['12.34', '5.67'],
        expected: '69.97',
        precision: 4,
      );

      expect(dispatch(testCase).resultToken, equals('69.97'));
    });

    test('derives compare-total from the current finite representation', () {
      final leftLower = _testCase(
        id: 'cotot001',
        operation: 'comparetotal',
        operands: <String>['12.30', '12.3'],
        expected: '-1',
      );
      final leftHigher = _testCase(
        id: 'cotot002',
        operation: 'comparetotal',
        operands: <String>['12.3', '12.300'],
        expected: '1',
      );

      expect(dispatch(leftLower).resultToken, equals('-1'));
      expect(dispatch(leftHigher).resultToken, equals('1'));
    });

    test('accepts the archive comparetotmag spelling', () {
      final testCase = _testCase(
        id: 'cotom001',
        operation: 'comparetotmag',
        operands: <String>['12.30', '12.3'],
        expected: '-1',
      );

      expect(dispatch(testCase).resultToken, equals('-1'));
    });

    test('normalizes compare-family outputs to canonical signum tokens', () {
      final compareCase = _testCase(
        id: 'comx001',
        operation: 'compare',
        operands: <String>['1', '1E+10'],
        expected: '-1',
      );
      final compareTotalCase = _testCase(
        id: 'cotot003',
        operation: 'comparetotal',
        operands: <String>['1', '1E+10'],
        expected: '-1',
      );
      final compareTotMagCase = _testCase(
        id: 'cotom002',
        operation: 'comparetotmag',
        operands: <String>['1', '1E+10'],
        expected: '-1',
      );
      final compareTotMagLargeGapCase = _testCase(
        id: 'cotom003',
        operation: 'comparetotmag',
        operands: <String>['20', '1'],
        expected: '1',
      );

      expect(dispatch(compareCase).resultToken, equals('-1'));
      expect(dispatch(compareTotalCase).resultToken, equals('-1'));
      expect(dispatch(compareTotMagCase).resultToken, equals('-1'));
      expect(dispatch(compareTotMagLargeGapCase).resultToken, equals('1'));
    });

    test('emits signed zero for divideint when the quotient truncates to zero', () {
      final testCase = _testCase(
        id: 'dvix040',
        operation: 'divideint',
        operands: <String>['1', '-2'],
        expected: '-0',
      );

      expect(dispatch(testCase).resultToken, equals('-0'));
    });

    test('emits scientific tokens for tiny exact abs results', () {
      final testCase = _testCase(
        id: 'absx038',
        operation: 'abs',
        operands: <String>['0.000000000001'],
        expected: '1E-12',
      );

      expect(dispatch(testCase).resultToken, equals('1E-12'));
    });

    test('emits scientific tokens for rounded abs results with negative scale', () {
      final testCase = _testCase(
        id: 'absx301',
        operation: 'abs',
        operands: <String>['12345678000'],
        expected: '1.23456780E+10',
      );

      expect(dispatch(testCase).resultToken, equals('1.23456780E+10'));
    });

    test('preserves preferred exponent for exact divide results', () {
      final testCase = _testCase(
        id: 'divx116',
        operation: 'divide',
        operands: <String>['1', '1E-8'],
        expected: '1E+8',
      );

      expect(dispatch(testCase).resultToken, equals('1E+8'));
    });

    test('keeps exact negative power-of-ten cases quiet in the final context', () {
      final regular = _testCase(
        id: 'powx121',
        operation: 'power',
        operands: <String>['10', '-77'],
        expected: '1E-77',
      );
      final boundary = _testCase(
        id: 'powx2317',
        operation: 'power',
        operands: <String>['10', '-383'],
        expected: '1E-383',
      );

      expect(dispatch(regular).resultToken, equals('1E-77'));
      expect(dispatch(regular).emittedConditions, isEmpty);
      expect(dispatch(boundary).resultToken, equals('1E-383'));
      expect(dispatch(boundary).emittedConditions, isEmpty);
    });

    test('preserves scientific cohort when divide rounding carries', () {
      final testCase = _testCase(
        id: 'divx072',
        operation: 'divide',
        operands: <String>['999999999.5', '1'],
        expected: '1.00000000E+9',
      );

      expect(dispatch(testCase).resultToken, equals('1.00000000E+9'));
    });

    test('emits scientific tokens for rounded add results from official fixtures', () {
      final testCase = _testCase(
        id: 'addx035',
        operation: 'add',
        operands: <String>['70', '10000e+9'],
        expected: '1.00000000E+13',
      );

      expect(dispatch(testCase).resultToken, equals('1.00000000E+13'));
    });

    test('preserves scale-sensitive zero outputs from add fixtures', () {
      final testCase = _testCase(
        id: 'addx055',
        operation: 'add',
        operands: <String>['1.3', '-1.30'],
        expected: '0.00',
      );

      expect(dispatch(testCase).resultToken, equals('0.00'));
    });

    test('preserves preferred exponent for integral exponent-valued operands', () {
      final testCase = _testCase(
        id: 'intx067',
        operation: 'tointegral',
        operands: <String>['56267E+1'],
        expected: '5.6267E+5',
      );

      expect(dispatch(testCase).resultToken, equals('5.6267E+5'));
    });

    test('canonicalizes unary plus and minus zero signs to positive', () {
      final plusCase = _testCase(
        id: 'plux120',
        operation: 'plus',
        operands: <String>['-0E3'],
        expected: '0E+3',
      );
      final minusCase = _testCase(
        id: 'minx025',
        operation: 'minus',
        operands: <String>['0E1'],
        expected: '0E+1',
      );

      expect(dispatch(plusCase).resultToken, equals('0E+3'));
      expect(dispatch(minusCase).resultToken, equals('0E+1'));
    });

    test('canonicalizes zero remainder exponents per fixture expectations', () {
      final testCase = _testCase(
        id: 'remx083',
        operation: 'remainder',
        operands: <String>['0.00E+9', '1'],
        expected: '0',
      );

      expect(dispatch(testCase).resultToken, equals('0'));
    });

    test('preserves negative zero for floor-rounded exact zero sums', () {
      final testCase = _testCase(
        id: 'addx1621',
        operation: 'add',
        operands: <String>['-0', '0E-19'],
        expected: '-0E-19',
        rounding: 'floor',
      );

      expect(dispatch(testCase).resultToken, equals('-0E-19'));
    });

    test('implements max and min magnitude tie-breaking via GDA rules', () {
      final maxMagnitudeCase = _testCase(
        id: 'maxmag001',
        operation: 'maxmag',
        operands: <String>['-2.0', '2.00'],
        expected: '2.00',
      );
      final minMagnitudeCase = _testCase(
        id: 'minmag001',
        operation: 'minmag',
        operands: <String>['1.00', '1'],
        expected: '1.00',
      );

      expect(dispatch(maxMagnitudeCase).resultToken, equals('2.00'));
      expect(dispatch(minMagnitudeCase).resultToken, equals('1.00'));
    });

    test('preserves signed zero tie-breaking for min and max families', () {
      final minCase = _testCase(
        id: 'mnmx032',
        operation: 'min',
        operands: <String>['0', '-0.0'],
        expected: '-0.0',
      );
      final maxCase = _testCase(
        id: 'maxx036',
        operation: 'max',
        operands: <String>['-0', '-0.0'],
        expected: '-0.0',
      );

      expect(dispatch(minCase).resultToken, equals('-0.0'));
      expect(dispatch(maxCase).resultToken, equals('-0.0'));
    });

    test('maps GDA rescale exponent to BigDecimal scale', () {
      final testCase = _testCase(
        id: 'rescale001',
        operation: 'rescale',
        operands: <String>['217', '-1'],
        expected: '217.0',
      );

      expect(dispatch(testCase).resultToken, equals('217.0'));
    });

    test('emits rescale rounding conditions', () {
      final roundedOnly = _testCase(
        id: 'rescalex002',
        operation: 'rescale',
        operands: <String>['1.2300', '-2'],
        expected: '1.23',
      );
      final inexact = _testCase(
        id: 'rescalex003',
        operation: 'rescale',
        operands: <String>['1.234', '-2'],
        expected: '1.23',
      );

      expect(dispatch(roundedOnly).emittedConditions, equals(<String>{'rounded'}));
      expect(dispatch(inexact).emittedConditions, equals(<String>{'inexact', 'rounded'}));
    });

    test('distinguishes tointegral from tointegralx condition emission', () {
      final quietCase = _testCase(
        id: 'intx068',
        operation: 'tointegral',
        operands: <String>['1.1'],
        expected: '1',
      );
      final roundedOnlyCase = _testCase(
        id: 'intx069',
        operation: 'tointegralx',
        operands: <String>['1.0'],
        expected: '1',
      );
      final inexactCase = _testCase(
        id: 'intx070',
        operation: 'tointegralx',
        operands: <String>['1.1'],
        expected: '1',
      );
      final zeroCase = _testCase(
        id: 'intx071',
        operation: 'tointegralx',
        operands: <String>['0.0'],
        expected: '0',
      );

      expect(dispatch(quietCase).emittedConditions, isEmpty);
      expect(dispatch(roundedOnlyCase).emittedConditions, equals(<String>{'rounded'}));
      expect(dispatch(inexactCase).emittedConditions, equals(<String>{'inexact', 'rounded'}));
      expect(dispatch(zeroCase).emittedConditions, isEmpty);
    });

    test('emits divide rounding conditions for exact and inexact quotients', () {
      final exactRounded = _testCase(
        id: 'divx200',
        operation: 'divide',
        operands: <String>['1000', '1'],
        expected: '1.00E+3',
        precision: 3,
      );
      final inexactRounded = _testCase(
        id: 'divx201',
        operation: 'divide',
        operands: <String>['1', '3'],
        expected: '0.333',
        precision: 3,
      );

      expect(dispatch(exactRounded).emittedConditions, equals(<String>{'rounded'}));
      expect(dispatch(inexactRounded).emittedConditions, equals(<String>{'inexact', 'rounded'}));
    });

    test('supports apply and formatting operations', () {
      final applyCase = _testCase(
        id: 'apply001',
        operation: 'apply',
        operands: <String>['123.45'],
        expected: '123.5',
        precision: 4,
      );
      final toSciCase = _testCase(
        id: 'tosci001',
        operation: 'tosci',
        operands: <String>['1500'],
        expected: '1.5E+3',
      );
      final toEngCase = _testCase(
        id: 'toeng001',
        operation: 'toeng',
        operands: <String>['0.5'],
        expected: '500E-3',
      );

      expect(dispatch(applyCase).resultToken, equals('123.5'));
      expect(dispatch(toSciCase).resultToken, equals('1.5E+3'));
      expect(dispatch(toEngCase).resultToken, equals('500E-3'));
    });

    test('dispatchTrapping throws the expected condition for inexact operations', () {
      final testCase = _testCase(
        id: 'trap001',
        operation: 'divide',
        operands: <String>['1', '3'],
        expected: '0.333',
        precision: 3,
        conditions: <String>{'inexact', 'rounded'},
      );

      expect(
        () => dispatchTrapping(testCase),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.inexact,
          ),
        ),
      );
    });

    test('dispatchTrapping throws rounded for rounded-only cases', () {
      final testCase = _testCase(
        id: 'trap002',
        operation: 'apply',
        operands: <String>['1000'],
        expected: '1.00E+3',
        precision: 3,
        conditions: <String>{'rounded'},
      );

      expect(
        () => dispatchTrapping(testCase),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.rounded,
          ),
        ),
      );
    });

    test('propagates divide-by-zero special result conditions', () {
      final testCase = _testCase(
        id: 'trap003',
        operation: 'divide',
        operands: <String>['1', '0'],
        expected: 'Infinity',
        conditions: <String>{'division_by_zero'},
      );

      final result = dispatch(testCase);

      expect(result.resultToken, equals('Infinity'));
      expect(result.emittedConditions, equals(<String>{'division_by_zero'}));
      expect(
        () => dispatchTrapping(testCase),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.divisionByZero,
          ),
        ),
      );
    });

    test(
        'uses invalid-operation trap for divide 0/0 (GDA: only invalid_operation, not division_by_zero)',
        () {
      final testCase = _testCase(
        id: 'trap004',
        operation: 'divide',
        operands: <String>['0', '0'],
        expected: 'NaN',
        conditions: <String>{'invalid_operation'},
      );

      final result = dispatch(testCase);

      expect(result.resultToken, equals('NaN'));
      expect(
        result.emittedConditions,
        equals(<String>{'invalid_operation'}),
      );
      expect(
        () => dispatchTrapping(testCase),
        throwsA(
          isA<BigDecimalSignalException>().having(
            (exception) => exception.condition,
            'condition',
            DecimalCondition.invalidOperation,
          ),
        ),
      );
    });
  });
}

DecTestCase _testCase({
  required String id,
  required String operation,
  required List<String> operands,
  required String expected,
  int precision = 9,
  String rounding = 'half_up',
  Set<String> conditions = const <String>{},
}) {
  return DecTestCase(
    id: id,
    operation: operation,
    operands: operands,
    expected: expected,
    conditions: conditions,
    context: DecTestDirectiveState.initial.copyWith(
      precision: precision,
      rounding: rounding,
    ),
    sourcePath: '<test>',
    lineNumber: 1,
  );
}
