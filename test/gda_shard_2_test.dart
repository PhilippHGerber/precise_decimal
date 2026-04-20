@TestOn('vm')
library;

import 'package:test/test.dart';

import 'dectest/test_harness.dart';

void main() {
  registerGdaShard(shardIndex: 1, shardCount: 2);
}
