import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_runtime/debug_panel.dart';

void main() {
  group('Debug Panel Tests', () {
    testWidgets('Debug panel displays correctly', (WidgetTester tester) async {
      final testState = {
        'counter': 42,
        'message': 'Test message',
        'user': {'name': 'Test User'}
      };

      final testJson = {
        'mcpRuntime': {
          'runtime': {
            'id': 'test_app',
            'domain': 'com.test.app',
            'version': '1.0.0',
            'services': {
              'state': {'initialState': testState}
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DebugPanel(
            jsonDefinition: testJson,
            currentState: testState,
            onStateChange: (key, value) {},
          ),
        ),
      ));

      // Verify debug panel header
      expect(find.text('Runtime Debug'), findsOneWidget);
      
      // Verify tabs
      expect(find.text('State'), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Runtime'), findsOneWidget);
    });

    testWidgets('State tab shows current state', (WidgetTester tester) async {
      final testState = {
        'counter': 42,
        'message': 'Test message'
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DebugPanel(
            jsonDefinition: {},
            currentState: testState,
            onStateChange: (key, value) {},
          ),
        ),
      ));

      // Should show current state values
      expect(find.text('counter'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('message'), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('State modification works', (WidgetTester tester) async {
      String? lastKey;
      dynamic lastValue;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DebugPanel(
            jsonDefinition: {},
            currentState: {},
            onStateChange: (key, value) {
              lastKey = key;
              lastValue = value;
            },
          ),
        ),
      ));

      // Enter key and value
      await tester.enterText(find.byType(TextField).first, 'testKey');
      await tester.enterText(find.byType(TextField).last, 'testValue');

      // Tap Set button
      await tester.tap(find.text('Set'));
      await tester.pump();

      // Verify callback was called
      expect(lastKey, 'testKey');
      expect(lastValue, 'testValue');
    });

    testWidgets('JSON tab displays correctly', (WidgetTester tester) async {
      final testJson = {
        'mcpRuntime': {
          'runtime': {
            'id': 'test_app',
            'version': '1.0.0'
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DebugPanel(
            jsonDefinition: testJson,
            currentState: {},
            onStateChange: (key, value) {},
          ),
        ),
      ));

      // Switch to JSON tab
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      // Verify JSON content is displayed
      expect(find.text('JSON Definition'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('Runtime tab shows runtime info', (WidgetTester tester) async {
      final testJson = {
        'mcpRuntime': {
          'runtime': {
            'id': 'test_app',
            'domain': 'com.test.app',
            'version': '1.0.0',
            'services': {
              'state': {},
              'notifications': {}
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DebugPanel(
            jsonDefinition: testJson,
            currentState: {},
            onStateChange: (key, value) {},
          ),
        ),
      ));

      // Switch to Runtime tab
      await tester.tap(find.text('Runtime'));
      await tester.pumpAndSettle();

      // Verify runtime information
      expect(find.text('Runtime Information'), findsOneWidget);
      expect(find.text('test_app'), findsOneWidget);
      expect(find.text('com.test.app'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });
  });
}