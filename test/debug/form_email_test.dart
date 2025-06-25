import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('Form Email Field Test', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      // Clean up any previous test state
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
      runtime = MCPUIRuntime();
    });
    
    tearDown(() async {
      await runtime.destroy();
      // Clean up after test
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
    });
    
    testWidgets('should update email field in form', (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'state': {
          'initial': {
            'form': {
              'email': '',
            },
          },
        },
        'content': {
          'type': 'form',
          'children': [
            {
              'type': 'textInput',
              'label': 'Email',
              'value': '{{form.email}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'form.email',
                'value': '{{event.value}}',
              },
            },
            {
              'type': 'text',
              'content': 'Email: {{form.email}}',
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
      expect(find.text('Email: '), findsOneWidget);
      
      // Find all TextFields
      final textFields = find.byType(TextField);
      print('Found ${textFields.evaluate().length} TextFields');
      
      // Type email
      await tester.enterText(textFields.first, 'test@example.com');
      await tester.pump();
      
      // Check state was updated
      final email = runtime.stateManager.get('form.email');
      print('Email in state: $email');
      expect(email, 'test@example.com');
      expect(find.text('Email: test@example.com'), findsOneWidget);
    });
  });
}