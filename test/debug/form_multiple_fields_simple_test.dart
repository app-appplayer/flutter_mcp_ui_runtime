import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('Form Multiple Fields Simple Test', () {
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

    testWidgets('should update multiple fields in form', (WidgetTester tester) async {
      final runtime = MCPUIRuntime();
      
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'form': {
                  'name': '',
                  'email': '',
                  'age': '',
                },
              },
            },
          },
        },
        'content': {
          'type': 'form',
          'children': [
            {
              'type': 'textInput',
              'label': 'Name',
              'value': '{{form.name}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'form.name',
                'value': '{{event.value}}',
              },
            },
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
              'type': 'textInput',
              'label': 'Age',
              'value': '{{form.age}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'form.age',
                'value': '{{event.value}}',
              },
            },
            {
              'type': 'text',
              'content': 'Name: {{form.name}}, Email: {{form.email}}, Age: {{form.age}}',
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
      
      // Use pump instead of pumpAndSettle for more control
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Initial state
      expect(find.text('Name: , Email: , Age: '), findsOneWidget);
      
      // Find fields by their labels - more robust approach
      final nameField = find.ancestor(
        of: find.text('Name'),
        matching: find.byType(TextField),
      );
      expect(nameField, findsOneWidget);
      
      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextField),
      );
      expect(emailField, findsOneWidget);
      
      final ageField = find.ancestor(
        of: find.text('Age'),
        matching: find.byType(TextField),
      );
      expect(ageField, findsOneWidget);
      
      // Enter text in each field
      await tester.enterText(nameField, 'John Doe');
      await tester.pump(const Duration(milliseconds: 100));
      
      await tester.enterText(emailField, 'john@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      
      await tester.enterText(ageField, '25');
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verify state was updated
      expect(runtime.stateManager.get('form.name'), 'John Doe');
      expect(runtime.stateManager.get('form.email'), 'john@example.com');
      expect(runtime.stateManager.get('form.age'), '25');
      
      // Verify UI was updated
      expect(find.text('Name: John Doe, Email: john@example.com, Age: 25'), findsOneWidget);
      
      // Clean up properly
      await runtime.destroy();
    });
  });
}