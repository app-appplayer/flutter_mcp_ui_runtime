import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('Form Multiple Fields Test', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      // Clean up any previous test state
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
      
      // Create runtime instance in setUp
      runtime = MCPUIRuntime(enableDebugMode: false);
    });

    tearDown(() async {
      // Destroy runtime first
      await runtime.destroy();
      
      // Clean up after test
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
    });

    testWidgets('should update multiple fields in form', (WidgetTester tester) async {
      // Force a clean widget tree
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      
      // Pump a completely new app to clear any widget state
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Container(),
        ),
      ));
      await tester.pumpAndSettle();
      
      // Use the runtime created in setUp
      await runtime.initialize({
        'type': 'page',
        'state': {
          'initial': {
            'form': {
              'name': '',
              'email': '',
              'age': '',
            },
          },
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
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
      await tester.pumpAndSettle();
      
      // Initial state - more flexible check
      final nameLabelFinder = find.text('Name');
      final emailLabelFinder = find.text('Email');
      final ageLabelFinder = find.text('Age');
      
      // Verify labels are present first
      expect(nameLabelFinder, findsOneWidget);
      expect(emailLabelFinder, findsOneWidget);
      expect(ageLabelFinder, findsOneWidget);
      
      // Wait a bit more to ensure all bindings are evaluated
      await tester.pump();
      await tester.pump(); // Double pump to ensure state updates
      
      // Find the text widget showing the combined state - be more flexible
      final allTextWidgets = find.byType(Text);
      expect(allTextWidgets, findsWidgets, reason: 'Should find text widgets');
      
      // Print all text widgets for debugging
      if (const String.fromEnvironment('DEBUG_TEST') == 'true') {
        for (var i = 0; i < allTextWidgets.evaluate().length; i++) {
          final widget = tester.widget<Text>(allTextWidgets.at(i));
          debugPrint('Text widget $i: "${widget.data}"');
        }
      }
      
      // Find the specific text that shows all three fields
      String? foundText;
      bool foundStateDisplay = false;
      
      for (var i = 0; i < allTextWidgets.evaluate().length; i++) {
        final widget = tester.widget<Text>(allTextWidgets.at(i));
        final text = widget.data ?? '';
        
        if (text.contains('Name:') && text.contains('Email:') && text.contains('Age:')) {
          foundText = text;
          foundStateDisplay = true;
          break;
        }
      }
      
      // If we didn't find it, let's be more permissive and check what we actually have
      if (!foundStateDisplay) {
        // Maybe the state is not initialized properly - check if state is correct
        final actualState = runtime.stateManager.state;
        debugPrint('Current state manager state: $actualState');
        
        // Try to find any text widget that might be our state display
        for (var i = 0; i < allTextWidgets.evaluate().length; i++) {
          final widget = tester.widget<Text>(allTextWidgets.at(i));
          final text = widget.data ?? '';
          if (text.contains(':')) {  // Any text with colon might be our display
            debugPrint('Found text with colon: "$text"');
          }
        }
      }
      
      if (!foundStateDisplay) {
        fail('Could not find state display widget. Found texts: ${allTextWidgets.evaluate().map((e) => '"${(e.widget as Text).data}"').join(", ")}');
      }
      expect(foundText, equals('Name: , Email: , Age: '));
      
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
        debugPrint('ERROR: Final UI check failed');
        debugPrint('Expected to find: "Name: John Doe, Email: john@example.com, Age: 25"');
        final textWidgets = find.byType(Text);
        debugPrint('All Text widgets found: ${textWidgets.evaluate().length}');
        for (var i = 0; i < textWidgets.evaluate().length; i++) {
          final widget = tester.widget<Text>(textWidgets.at(i));
          debugPrint('Text $i: "${widget.data}"');
        }
        debugPrint('Final state: ${runtime.stateManager.state}');
        rethrow;
      }
      
      // Extra cleanup - ensure widget tree is completely cleared
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });
  });
}