import 'dart:convert';
import 'dart:io';

/// Define what is considered a "slow" test in milliseconds.
const slowThresholdMs = 800;

void main() async {
  print('Running tests to profile execution time (this will take 45+ minutes)...');
  print('Grab a coffee! ☕\n');

  // We use '--timeout=none' so the runner doesn't kill 30+ second tests,
  // allowing us to measure their true duration.
  final process = await Process.start('dart', [
    'test',
    '--timeout=none',
    '--reporter', 'json'
  ]);

  final activeTests = <int, Map<String, dynamic>>{};
  final slowTests = <Map<String, dynamic>>[];

  // Parse the JSON stream from the test runner
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    if (!line.startsWith('{')) return;

    try {
      final event = jsonDecode(line);
      final type = event['type'];

      if (type == 'testStart') {
        final test = event['test'];
        // Ignore internal loading tasks
        if (test['name'].startsWith('loading ')) return;

        activeTests[test['id']] = {
          'name': test['name'],
          'url': test['url'] ?? 'unknown',
          'line': test['line'] ?? 0,
          'startTime': event['time'],
        };
      } else if (type == 'testDone') {
        final testID = event['testID'];
        final testInfo = activeTests.remove(testID);

        // We log it whether it succeeded or failed
        if (testInfo != null) {
          final duration = event['time'] - testInfo['startTime'];
          if (duration >= slowThresholdMs) {
            testInfo['duration'] = duration;
            slowTests.add(testInfo);
            // Print live feedback so you know it hasn't frozen
            print('Found slow test: ${duration}ms | ${testInfo['name']}');
          }
        }
      }
    } catch (e) {
      // Ignore non-JSON lines
    }
  });

  await process.exitCode;

  // Sort all slow tests from slowest to fastest
  slowTests.sort((a, b) => (b['duration'] as int).compareTo(a['duration'] as int));

  final unitTests = [];
  final decTests = [];

  for (final test in slowTests) {
    final name = test['name'] as String;
    // Identify decTests by checking for the shard grouping syntax
    if (name.contains('GDA shard')) {
      // Extract the specific decTest ID (e.g., from "... pow.decTest powx2041: power")
      final match = RegExp(r' (\w+):\s+\w+$').firstMatch(name);
      final decTestId = match != null ? match.group(1) : name;
      decTests.add({...test, 'decTestId': decTestId});
    } else {
      unitTests.add(test);
    }
  }

  _printReport(unitTests, decTests);
}

void _printReport(List unitTests, List decTests) {
  print('\n' + '=' * 80);
  print('⏱️  SLOW TESTS REPORT (Threshold: ${slowThresholdMs}ms)');
  print('=' * 80 + '\n');

  print('🤖 INSTRUCTIONS FOR AI AGENT 🤖:');
  print('1. Open the files listed in STANDARD UNIT TESTS and add `tags: [\'slow\']` to those `test()` calls.');
  print('2. Open `test/dectest/test_harness.dart` and add the IDs from the DECTEST section into a `_knownSlowTests` Set.\n');

  print('--- STANDARD UNIT TESTS ---');
  if (unitTests.isEmpty) {
    print('None found.');
  } else {
    for (final test in unitTests) {
      String filePath = test['url'];
      if (filePath.startsWith('file://')) {
        filePath = Uri.parse(filePath).toFilePath();
      }
      print('- ${test['duration']}ms | File: $filePath | Line: ${test['line']} | Name: "${test['name']}"');
    }
  }

  print('\n--- DECTEST CASES (Dynamic) ---');
  if (decTests.isEmpty) {
    print('None found.');
  } else {
    for (final test in decTests) {
      print('- ${test['duration']}ms | ID: ${test['decTestId']} | Name: "${test['name']}"');
    }
    print('\n📋 Quick Copy/Paste list of IDs for `_knownSlowTests`:');
    final ids = decTests.map((t) => "'${t['decTestId']}'").join(',\n  ');
    print('const Set<String> _knownSlowTests = {\n  $ids\n};');
  }
}