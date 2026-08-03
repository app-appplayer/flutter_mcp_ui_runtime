// A host can receive the runtime's diagnostics.
//
// Without this the runtime talks only to `dart:developer`: whoever has
// DevTools open sees it and nobody else. Some of what it says is for the
// person writing the document — "this theme role was declared and dropped" —
// and that person is not holding a debugger. konpi went looking for one such
// warning and found it nowhere a host could reach: app stdout, the run
// console, and AppPlayer's own log screen were all empty.
//
// `stdout` cannot be the answer: on a stdio MCP connection it carries the
// protocol.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  tearDown(() => MCPLogger.onRecord = null);

  test('an installed sink receives every level', () {
    final seen = <MCPLogRecord>[];
    MCPLogger.onRecord = seen.add;

    final logger = MCPLogger('probe');
    logger.debug('d');
    logger.info('i');
    logger.warning('w');
    logger.error('e');

    expect(seen.map((r) => r.level).toList(),
        <String>['DEBUG', 'INFO', 'WARN', 'ERROR']);
    expect(seen.every((r) => r.logger == 'probe'), isTrue);
    expect(seen.last.message, 'e');
  });

  test('records reach the sink even when developer logging is off', () {
    // `enableLogging` decides whether the runtime talks to `dart:developer`,
    // and defaults to debug-only so a release build pays nothing. A host that
    // installed a sink asked for the records; dropping them in release would
    // silence exactly the diagnostics a released app needs to surface.
    final seen = <MCPLogRecord>[];
    MCPLogger.onRecord = seen.add;

    MCPLogger('quiet', enableLogging: false).warning('still reported');

    expect(seen, hasLength(1));
    expect(seen.single.message, 'still reported');
  });

  test('an error carries its cause and stack', () {
    final seen = <MCPLogRecord>[];
    MCPLogger.onRecord = seen.add;
    final trace = StackTrace.current;

    MCPLogger('probe').error('failed', 'because', trace);

    expect(seen.single.error, 'because');
    expect(seen.single.stackTrace, same(trace));
  });

  test('a sink that throws does not take the runtime down', () {
    // A host's logging is not allowed to become the runtime's failure mode.
    MCPLogger.onRecord = (_) => throw StateError('sink is broken');
    expect(() => MCPLogger('probe').warning('w'), returnsNormally);
  });

  test('no sink installed is the normal case and costs nothing', () {
    MCPLogger.onRecord = null;
    expect(() => MCPLogger('probe').warning('w'), returnsNormally);
  });
}
