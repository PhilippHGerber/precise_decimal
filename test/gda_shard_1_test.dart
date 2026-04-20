@TestOn('vm')
library;

import 'package:test/test.dart';

import 'dectest/test_harness.dart';

void main() {
  registerGdaShard(shardIndex: 0, shardCount: 2);
}
