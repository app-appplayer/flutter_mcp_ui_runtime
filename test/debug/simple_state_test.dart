import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

/// Simple test to verify StateManager initialization
void main() {
  setUp(() {
    // Clean up any previous test state
    NavigationActionExecutor.clearGlobalNavigationHandler();
    ThemeManager.instance.reset();
    I18nManager.instance.clear();
    WidgetCache.instance.clear();
  });

  tearDown(() {
    // Clean up after test
    NavigationActionExecutor.clearGlobalNavigationHandler();
    ThemeManager.instance.reset();
    I18nManager.instance.clear();
    WidgetCache.instance.clear();
  });

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