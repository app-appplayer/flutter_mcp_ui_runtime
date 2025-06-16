import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/mcp_ui_runtime.dart';

/// Simple test to verify StateManager initialization
void main() {
  test('StateManager should be initialized with page runtime services', () async {
    final runtime = MCPUIRuntime(enableDebugMode: true);
    
    final pageWithState = {
      'type': 'page',
      'content': {
        'type': 'text',
        'content': 'Test',
      },
      'runtime': {
        'services': {
          'state': {
            'initialState': {
              'counter': 42,
              'message': 'Hello World',
            },
          },
        },
      },
    };

    await runtime.initialize(pageWithState);

    // Check if StateManager has the values
    final counterValue = runtime.stateManager.get<int>('counter');
    final messageValue = runtime.stateManager.get<String>('message');
    
    print('StateManager counter: $counterValue');
    print('StateManager message: $messageValue');
    
    expect(counterValue, equals(42));
    expect(messageValue, equals('Hello World'));

    await runtime.destroy();
  });
}