import 'dart:io';

import 'dec_test_case.dart';

/// Stateful parser for General Decimal Arithmetic decTest files.
final class DecTestParser {
  /// Parses [content] and returns every discovered test case.
  ///
  /// When [sourceDir] is provided it is used to resolve `dectest:` includes.
  List<DecTestCase> parse(
    String content, {
    String sourceDir = '',
    String sourcePath = '<memory>',
  }) {
    return _parseInternal(
      content,
      sourceDir: sourceDir,
      sourcePath: sourcePath,
      includeStack: <String>{},
    );
  }

  List<DecTestCase> _parseInternal(
    String content, {
    required String sourceDir,
    required String sourcePath,
    required Set<String> includeStack,
  }) {
    var state = DecTestDirectiveState.initial;
    final cases = <DecTestCase>[];
    final lines = content.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index];
      final lineNumber = index + 1;
      final line = _stripComment(rawLine).trim();

      if (line.isEmpty) {
        continue;
      }

      if (_isDirective(line)) {
        state = _applyDirective(
          line,
          state: state,
          sourceDir: sourceDir,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
          cases: cases,
          includeStack: includeStack,
        );
        continue;
      }

      cases.add(
        _parseTestCase(
          line,
          state: state,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
        ),
      );
    }

    return cases;
  }

  String _stripComment(String line) {
    var inQuotedToken = false;
    String? quoteDelimiter;

    for (var index = 0; index < line.length - 1; index++) {
      final char = line[index];

      if (_isQuoteDelimiter(char)) {
        if (!inQuotedToken) {
          inQuotedToken = true;
          quoteDelimiter = char;
          continue;
        }

        if (char == quoteDelimiter) {
          inQuotedToken = false;
          quoteDelimiter = null;
        }
        continue;
      }

      if (!inQuotedToken && char == '-' && line[index + 1] == '-') {
        return line.substring(0, index);
      }
    }

    return line;
  }

  bool _isDirective(String line) => RegExp(r'^\w+\s*:').hasMatch(line);

  DecTestDirectiveState _applyDirective(
    String line, {
    required DecTestDirectiveState state,
    required String sourceDir,
    required String sourcePath,
    required int lineNumber,
    required List<DecTestCase> cases,
    required Set<String> includeStack,
  }) {
    final separatorIndex = line.indexOf(':');
    final key = line.substring(0, separatorIndex).trim().toLowerCase();
    final value = line.substring(separatorIndex + 1).trim();

    switch (key) {
      case 'precision':
        return state.copyWith(precision: int.parse(value));
      case 'rounding':
        return state.copyWith(rounding: value.toLowerCase());
      case 'maxexponent':
        return state.copyWith(maxExponent: int.parse(value));
      case 'minexponent':
        return state.copyWith(minExponent: int.parse(value));
      case 'extended':
        return state.copyWith(extended: value == '1');
      case 'clamp':
        return state.copyWith(clamp: value == '1');
      case 'version':
        return state;
      case 'dectest':
        final includeFile = _resolveInclude(sourceDir: sourceDir, path: value);
        final normalizedPath = includeFile.absolute.path;

        if (includeStack.contains(normalizedPath)) {
          throw FormatException(
            'Recursive dectest include detected for $normalizedPath '
            'from $sourcePath:$lineNumber',
          );
        }
        if (!includeFile.existsSync()) {
          throw FormatException(
            'Missing dectest include $normalizedPath referenced from '
            '$sourcePath:$lineNumber',
          );
        }

        includeStack.add(normalizedPath);
        try {
          cases.addAll(
            _parseInternal(
              includeFile.readAsStringSync(),
              sourceDir: includeFile.parent.path,
              sourcePath: normalizedPath,
              includeStack: includeStack,
            ),
          );
        } finally {
          includeStack.remove(normalizedPath);
        }
        return state;
      default:
        return state;
    }
  }

  File _resolveInclude({required String sourceDir, required String path}) {
    if (sourceDir.isEmpty) {
      return File(path);
    }

    return File('$sourceDir/$path');
  }

  DecTestCase _parseTestCase(
    String line, {
    required DecTestDirectiveState state,
    required String sourcePath,
    required int lineNumber,
  }) {
    final tokens = _tokenize(line);
    final arrowIndex = tokens.indexOf('->');

    if (arrowIndex < 0 || arrowIndex < 3 || arrowIndex + 1 >= tokens.length) {
      throw FormatException('Invalid decTest case at $sourcePath:$lineNumber: $line');
    }

    return DecTestCase(
      id: tokens[0],
      operation: tokens[1].toLowerCase(),
      operands: tokens.sublist(2, arrowIndex).map(_stripQuotes).toList(growable: false),
      expected: _stripQuotes(tokens[arrowIndex + 1]),
      conditions:
          tokens.sublist(arrowIndex + 2).map((condition) => condition.toLowerCase()).toSet(),
      context: state,
      sourcePath: sourcePath,
      lineNumber: lineNumber,
    );
  }

  List<String> _tokenize(String line) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inQuotedToken = false;
    String? quoteDelimiter;

    void flushBuffer() {
      if (buffer.isEmpty) {
        return;
      }
      tokens.add(buffer.toString());
      buffer.clear();
    }

    for (var index = 0; index < line.length; index++) {
      final char = line[index];

      if (inQuotedToken) {
        buffer.write(char);
        if (char == quoteDelimiter) {
          flushBuffer();
          inQuotedToken = false;
          quoteDelimiter = null;
        }
        continue;
      }

      if (char.trim().isEmpty) {
        flushBuffer();
        continue;
      }

      if (_isQuoteDelimiter(char)) {
        flushBuffer();
        buffer.write(char);
        inQuotedToken = true;
        quoteDelimiter = char;
        continue;
      }

      if (char == '-' && index + 1 < line.length && line[index + 1] == '>') {
        flushBuffer();
        tokens.add('->');
        index += 1;
        continue;
      }

      buffer.write(char);
    }

    if (inQuotedToken) {
      throw FormatException('Unterminated quoted token in decTest line: $line');
    }

    flushBuffer();
    return tokens;
  }

  String _stripQuotes(String token) {
    final hasMatchingSingleQuotes = token.startsWith("'") && token.endsWith("'");
    final hasMatchingDoubleQuotes = token.startsWith('"') && token.endsWith('"');
    return hasMatchingSingleQuotes || hasMatchingDoubleQuotes
        ? token.substring(1, token.length - 1)
        : token;
  }

  bool _isQuoteDelimiter(String char) => char == "'" || char == '"';
}
