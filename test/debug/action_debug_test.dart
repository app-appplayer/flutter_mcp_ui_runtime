import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The exported runtime, not the superseded duplicate under src/runtime/.
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

/// Debug test to diagnose action button issues
void main() {
  group('Action Button Debug Tests', () {
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
    testWidgets('Simple counter action should work', (tester) async {
      bool incrementCalled = false;
      bool decrementCalled = false;
      Map<String, dynamic> lastArgs = {};
      
      // Create runtime
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      // Simple counter definition
      final counterDemo = {
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Counter Test',
            },
            {
              'type': 'button',
              'label': 'Increment',
              'onTap': {
                'type': 'tool',
                'tool': 'increment',
                'params': {},
              },
            },
            {
              'type': 'button',
              'label': 'Decrement',
              'onTap': {
                'type': 'tool',
                'tool': 'decrement',
                'params': {},
              },
            },
          ],
        },
      };

      // Initialize runtime first
      await runtime.initialize(counterDemo);

      // Register tool executors after initialization
      runtime.registerToolExecutor('increment', (args) async {
        lastArgs = args;
        incrementCalled = true;
        return {'success': true};
      });

      runtime.registerToolExecutor('decrement', (args) async {
        lastArgs = args;
        decrementCalled = true;
        return {'success': true};
      });

      // Create the app widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify UI rendered
      expect(find.text('Counter Test'), findsOneWidget);
      expect(find.text('Increment'), findsOneWidget);
      expect(find.text('Decrement'), findsOneWidget);

      // Test increment button
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(incrementCalled, isTrue, reason: 'Increment tool should have been called');
      expect(lastArgs, isEmpty,
          reason: 'the button declares `params: {}` — an executor handed keys '
              'nobody wrote would mean the runtime is inventing arguments');

      // Test decrement button
      await tester.tap(find.text('Decrement'));
      await tester.pumpAndSettle();
      expect(decrementCalled, isTrue, reason: 'Decrement tool should have been called');
      expect(lastArgs, isEmpty);

      await runtime.destroy();
    });

    testWidgets('Debug tool execution path', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final debugDemo = {
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'button',
              'label': 'Runtime Tool',
              'onTap': {
                'type': 'tool',
                'tool': 'test_runtime_tool',
                'params': {'test': 'data'},
              },
            },
            {
              'type': 'button',
              'label': 'Callback Tool',
              'onTap': {
                'type': 'tool',
                'tool': 'test_callback_tool',
                'params': {'test': 'callback'},
              },
            },
          ],
        },
      };

      await runtime.initialize(debugDemo);

      // Register tool executors after initialization
      bool runtimeToolCalled = false;
      runtime.registerToolExecutor('test_runtime_tool', (args) {
        runtimeToolCalled = true;
        return {'success': true};
      });

      bool callbackToolCalled = false;
      runtime.registerToolExecutor('test_callback_tool', (args) async {
        callbackToolCalled = true;
        return {'success': true};
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test runtime registered tool
      await tester.tap(find.text('Runtime Tool'));
      await tester.pumpAndSettle();
      expect(runtimeToolCalled, isTrue, reason: 'Runtime registered tool should execute');

      // Test callback tool
      await tester.tap(find.text('Callback Tool'));
      await tester.pumpAndSettle();
      expect(callbackToolCalled, isTrue, reason: 'Callback tool should execute');

      await runtime.destroy();
    });

    testWidgets('Verify button widget factory creates proper onPressed', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final buttonDemo = {
        'type': 'page',
        'content': {
          'type': 'button',
          'label': 'Test Button',
          'onTap': {
            'type': 'tool',
            'tool': 'button_test',
            'params': {'button': 'test'},
          },
        },
      };

      await runtime.initialize(buttonDemo);

      // Register the button_test tool after initialization
      bool buttonPressed = false;
      runtime.registerToolExecutor('button_test', (args) async {
        buttonPressed = true;
        return {'success': true};
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the actual button widget
      final buttonWidget = find.byType(ElevatedButton);
      expect(buttonWidget, findsOneWidget);

      // Verify button has onPressed callback
      final elevatedButton = tester.widget<ElevatedButton>(buttonWidget);
      expect(elevatedButton.onPressed, isNotNull, 
        reason: 'Button should have onPressed callback');

      // Test button press
      await tester.tap(buttonWidget);
      await tester.pumpAndSettle();
      
      expect(buttonPressed, isTrue, reason: 'Button press should trigger tool call');

      await runtime.destroy();
    });
  });
}