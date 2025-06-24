import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('Form Multiple Fields Test', () {
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
      // Pump a completely new app to clear any widget state
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Container(),
        ),
      ));
      await tester.pumpAndSettle();
      
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
      
      // Wait for widget tree to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Initial state
      try {
        expect(find.text('Name: , Email: , Age: '), findsOneWidget);
      } catch (e) {
        print('ERROR: Initial state check failed');
        print('Found widgets: ${find.text('Name: , Email: , Age: ').evaluate()}');
        final textWidgets = find.byType(Text);
        print('All Text widgets found: ${textWidgets.evaluate().length}');
        for (var i = 0; i < textWidgets.evaluate().length; i++) {
          final widget = tester.widget<Text>(textWidgets.at(i));
          print('Text $i: "${widget.data}"');
        }
        rethrow;
      }
      
      // Verify labels are present
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      
      // Use a more robust approach: find each field by its associated label
      // This works regardless of widget tree structure
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      
      // Helper function to find TextField near a label
      Future<void> enterTextNearLabel(String label, String text) async {
        // Find all text widgets with the label
        final labelWidget = find.text(label);
        expect(labelWidget, findsOneWidget);
        
        // Find the closest TextField to this label
        final labelPosition = tester.getCenter(labelWidget);
        
        // Get all TextField positions and find the closest one
        double minDistance = double.infinity;
        Finder? closestField;
        
        for (int i = 0; i < textFields.evaluate().length; i++) {
          final field = textFields.at(i);
          final fieldPosition = tester.getCenter(field);
          final distance = (fieldPosition - labelPosition).distance;
          
          if (distance < minDistance) {
            minDistance = distance;
            closestField = field;
          }
        }
        
        expect(closestField, isNotNull);
        await tester.enterText(closestField!, text);
        await tester.pumpAndSettle();
      }
      
      // Enter text using label-based approach
      await enterTextNearLabel('Name', 'John Doe');
      await enterTextNearLabel('Email', 'john@example.com');
      await enterTextNearLabel('Age', '25');
      
      // Check state was updated
      expect(runtime.stateManager.get('form.name'), 'John Doe');
      expect(runtime.stateManager.get('form.email'), 'john@example.com');
      expect(runtime.stateManager.get('form.age'), '25');
      
      // Check UI was updated
      try {
        expect(find.text('Name: John Doe, Email: john@example.com, Age: 25'), findsOneWidget);
      } catch (e) {
        print('ERROR: Final UI check failed');
        final textWidgets = find.byType(Text);
        print('All Text widgets found: ${textWidgets.evaluate().length}');
        for (var i = 0; i < textWidgets.evaluate().length; i++) {
          final widget = tester.widget<Text>(textWidgets.at(i));
          print('Text $i: "${widget.data}"');
        }
        rethrow;
      }
      
      // Clean up
      await runtime.destroy();
      
      // Extra cleanup - ensure widget tree is completely cleared
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });
  });
}