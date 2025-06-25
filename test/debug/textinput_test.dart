import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('TextInput onChange Test', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      // Clean up any previous test state
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
      // Clean up after test
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
    });
    
    testWidgets('should update state on text change', (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'text': '',
              },
            },
          },
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'textInput',
              'label': 'Enter Text',
              'value': '{{text}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'text',
                'value': '{{event.value}}',
              },
            },
            {
              'type': 'text',
              'content': 'You typed: {{text}}',
            },
          ],
        },
      });
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Initial state
      expect(find.text('You typed: '), findsOneWidget);
      
      // Type some text
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.pump();
      
      // Check state was updated
      expect(runtime.stateManager.get('text'), 'Hello World');
      expect(find.text('You typed: Hello World'), findsOneWidget);
    });
  });
}