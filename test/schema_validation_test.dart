// Phase 4 schema validation tests.
//
// Verifies that when `validateSchema: true` is passed to
// MCPUIRuntime.initialize(), valid DSL loads unchanged and invalid DSL
// aborts with a clear error. Default behavior (validateSchema not passed)
// is preserved by the existing runtime test suite.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  test('TC-230a: valid DSL passes schema validation', () async {
    await runtime.initialize(
      {
        'type': 'page',
        'content': {
          'type': 'box',
          'child': {'type': 'text', 'text': 'hello'},
        },
      },
      validateSchema: true,
    );
    expect(runtime.isInitialized, isTrue);
  });

  test('TC-230b: unknown widget type is rejected', () async {
    await expectLater(
      () => runtime.initialize(
        {
          'type': 'page',
          'content': {
            'type': 'not-a-real-widget-type',
          },
        },
        validateSchema: true,
      ),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('schema validation failed'),
      )),
    );
  });

  test('TC-230c: validation can be disabled explicitly', () async {
    // Same broken DSL as TC-230b — without validation, initialize() returns
    // (the widget factory layer will still fail to render, but that is a
    // separate concern from schema validation).
    await runtime.initialize(
      {
        'type': 'page',
        'content': {
          'type': 'not-a-real-widget-type',
        },
      },
      validateSchema: false,
    );
    expect(runtime.isInitialized, isTrue);
  });
}
