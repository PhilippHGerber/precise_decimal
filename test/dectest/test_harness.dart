import 'dart:io';

import 'package:precise_decimal/precise_decimal.dart';
import 'package:test/test.dart';

import 'dec_test_case.dart';
import 'dec_test_parser.dart';
import 'operation_dispatcher.dart';
import 'skip_checker.dart';

const Set<String> _knownSlowTests = {
  'powx383',
  'powx387',
};

/// Registers one shard of dynamically discovered decTest fixtures.
void registerGdaShard({required int shardIndex, required int shardCount}) {
  final rootDirectory = Directory('test/testdata/dectest');
  final fixtureFiles = _discoverFixtureFiles(rootDirectory);

  if (fixtureFiles.isEmpty) {
    test(
      'GDA shard ${shardIndex + 1}/$shardCount has no committed fixtures yet',
      () {},
      skip: 'No decTest fixtures have been committed to test/testdata/dectest.',
    );
    return;
  }

  final shardFiles = fixtureFiles
      .where((entry) => entry.$1 % shardCount == shardIndex)
      .map((entry) => entry.$2)
      .toList(growable: false);

  if (shardFiles.isEmpty) {
    test(
      'GDA shard ${shardIndex + 1}/$shardCount is empty',
      () {},
      skip: 'No decTest fixtures are assigned to this shard.',
    );
    return;
  }

  group('GDA shard ${shardIndex + 1}/$shardCount', () {
    for (final file in shardFiles) {
      final parsedCases = DecTestParser().parse(
        file.readAsStringSync(),
        sourceDir: file.parent.path,
        sourcePath: file.path,
      );

      group(_fixtureLabel(file.path), () {
        for (final testCase in parsedCases) {
          test(
            '${testCase.id}: ${testCase.operation}',
            () {
              final actual = dispatch(testCase);
              expect(
                actual.resultToken,
                equals(testCase.expected),
                reason: _failureReason(
                  testCase,
                  actualToken: actual.resultToken,
                  actualConditions: actual.emittedConditions,
                ),
              );
              expect(
                actual.emittedConditions,
                equals(testCase.conditions),
                reason: _failureReason(
                  testCase,
                  actualToken: actual.resultToken,
                  actualConditions: actual.emittedConditions,
                ),
              );

              if (testCase.conditions.isNotEmpty) {
                expect(
                  () => dispatchTrapping(testCase),
                  throwsA(
                    isA<BigDecimalSignalException>().having(
                      (exception) => exception.condition,
                      'condition',
                      _expectedTrapCondition(testCase.conditions),
                    ),
                  ),
                  reason: _failureReason(
                    testCase,
                    actualToken: actual.resultToken,
                    actualConditions: actual.emittedConditions,
                  ),
                );
              }
            },
            skip: skipReason(testCase),
            tags: _knownSlowTests.contains(testCase.id) ? ['slow'] : null,
          );
        }
      });
    }
  });
}

List<(int, File)> _discoverFixtureFiles(Directory rootDirectory) {
  if (!rootDirectory.existsSync()) {
    return const <(int, File)>[];
  }

  final files = rootDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.decTest'))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));

  return files.indexed.map((entry) => (entry.$1, entry.$2)).toList(growable: false);
}

String _fixtureLabel(String path) {
  const prefix = 'test/testdata/dectest/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

String _failureReason(
  DecTestCase testCase, {
  required String actualToken,
  required Set<String> actualConditions,
}) {
  final expectedConditions = testCase.conditions.toList()..sort();
  final emittedConditions = actualConditions.toList()..sort();

  return '[${testCase.id}] ${testCase.sourcePath}:${testCase.lineNumber} '
      'precision=${testCase.precision} rounding=${testCase.rounding} '
      'expected=${testCase.expected} actual=$actualToken '
      'expectedConditions=$expectedConditions actualConditions=$emittedConditions';
}

DecimalCondition _expectedTrapCondition(Set<String> expectedConditions) {
  if (expectedConditions.contains('invalid_operation')) {
    return DecimalCondition.invalidOperation;
  }
  if (expectedConditions.contains('division_by_zero')) {
    return DecimalCondition.divisionByZero;
  }
  if (expectedConditions.contains('overflow')) {
    return DecimalCondition.overflow;
  }
  if (expectedConditions.contains('underflow')) {
    return DecimalCondition.underflow;
  }
  if (expectedConditions.contains('subnormal')) {
    return DecimalCondition.subnormal;
  }
  if (expectedConditions.contains('inexact')) {
    return DecimalCondition.inexact;
  }
  if (expectedConditions.contains('rounded')) {
    return DecimalCondition.rounded;
  }
  if (expectedConditions.contains('clamped')) {
    return DecimalCondition.clamped;
  }

  throw ArgumentError(
    'Unsupported trap expectation for conditions: ${expectedConditions.toList()..sort()}',
  );
}
