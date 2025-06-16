import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/mcp_ui_runtime.dart';

/// Debug test to verify state binding and action integration
void main() {
  group('State Binding Debug Tests', () {
    testWidgets('State binding {{counter}} should show initial value', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final stateDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}',
            },
            {
              'type': 'text',
              'content': 'Message: {{message}}',
            },
          ],
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

      await runtime.initialize(stateDemo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if state bindings are resolved correctly
      print('Looking for: "Counter: 42"');
      print('Looking for: "Message: Hello World"');
      
      // First check if the binding text exists
      expect(find.text('Counter: {{counter}}'), findsNothing, 
        reason: 'Raw binding should be resolved');
      expect(find.text('Message: {{message}}'), findsNothing, 
        reason: 'Raw binding should be resolved');
      
      // Check if resolved values exist
      expect(find.text('Counter: 42'), findsOneWidget, 
        reason: 'Counter binding should resolve to initial value');
      expect(find.text('Message: Hello World'), findsOneWidget, 
        reason: 'Message binding should resolve to initial value');

      await runtime.destroy();
    });

    testWidgets('Action should update state and binding should reflect change', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final stateActionDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}',
            },
            {
              'type': 'button',
              'label': 'Increment',
              'onTap': {
                'type': 'state',
                'action': 'increment',
                'path': 'counter',
                'value': 1,
              },
            },
            {
              'type': 'button',
              'label': 'Set to 100',
              'onTap': {
                'type': 'state',
                'action': 'set',
                'path': 'counter',
                'value': 100,
              },
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
              },
            },
          },
        },
      };

      await runtime.initialize(stateActionDemo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check initial state
      print('Initial state check...');
      expect(find.text('Counter: 0'), findsOneWidget);

      // Test state increment action
      print('Testing increment action...');
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      
      print('After increment, looking for: "Counter: 1"');
      expect(find.text('Counter: 1'), findsOneWidget, 
        reason: 'Counter should increment to 1');

      // Test state set action
      print('Testing set action...');
      await tester.tap(find.text('Set to 100'));
      await tester.pumpAndSettle();
      
      print('After set, looking for: "Counter: 100"');
      expect(find.text('Counter: 100'), findsOneWidget, 
        reason: 'Counter should be set to 100');

      await runtime.destroy();
    });

    testWidgets('Tool action should update state via callback', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final toolActionDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}',
            },
            {
              'type': 'button',
              'label': 'Tool Increment',
              'onTap': {
                'type': 'tool',
                'tool': 'increment',
                'args': {},
              },
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
              },
            },
          },
        },
      };

      await runtime.initialize(toolActionDemo);

      // Register tool executor after initialization
      int toolCallCount = 0;
      runtime.registerToolExecutor('increment', (args) async {
        print('TOOL CALLED: increment with args: $args');
        toolCallCount++;
        
        final current = runtime.stateManager.get<int>('counter') ?? 0;
        runtime.stateManager.set('counter', current + 1);
        print('Updated counter to: ${current + 1}');
        
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

      // Check initial state
      print('Initial state check...');
      expect(find.text('Counter: 0'), findsOneWidget);

      // Test tool action
      print('Testing tool action...');
      await tester.tap(find.text('Tool Increment'));
      await tester.pumpAndSettle();
      
      print('Tool call count: $toolCallCount');
      expect(toolCallCount, equals(1), 
        reason: 'Tool should have been called once');
        
      print('After tool action, looking for: "Counter: 1"');
      expect(find.text('Counter: 1'), findsOneWidget, 
        reason: 'Counter should increment via tool action');

      await runtime.destroy();
    });

    testWidgets('StateManager direct test', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      });

      // Test StateManager directly
      print('Testing StateManager directly...');
      runtime.stateManager.initialize({'counter': 5});
      
      final value = runtime.stateManager.get<int>('counter');
      print('StateManager get counter: $value');
      expect(value, equals(5));
      
      runtime.stateManager.set('counter', 10);
      final newValue = runtime.stateManager.get<int>('counter');
      print('StateManager after set counter: $newValue');
      expect(newValue, equals(10));

      await runtime.destroy();
    });
  });
}