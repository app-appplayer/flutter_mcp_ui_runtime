import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('AccessibleWrapper Widget Tests', () {
    late MCPUIRuntime runtime;
    
    setUp(() async {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() async {
      await runtime.destroy();
    });
    
    testWidgets('should render child widget', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'content': {
          'type': 'accessibleWrapper',
          'child': {
            'type': 'button',
            'label': 'Test Button',
          },
        },
      };
      
      await runtime.initialize(definition);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Verify the child button is rendered
      final buttonFinder = find.text('Test Button');
      expect(buttonFinder, findsOneWidget);
    });
    
    testWidgets('should apply focus management', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'content': {
          'type': 'accessibleWrapper',
          'focusGroup': 'main',
          'focusOrder': 1,
          'child': {
            'type': 'button',
            'label': 'Focusable Button',
          },
        },
      };
      
      await runtime.initialize(definition);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Find the button
      final buttonFinder = find.text('Focusable Button');
      expect(buttonFinder, findsOneWidget);
      
      // Verify FocusTraversalOrder is applied
      final traversalOrderFinder = find.ancestor(
        of: buttonFinder,
        matching: find.byType(FocusTraversalOrder),
      );
      expect(traversalOrderFinder, findsOneWidget);
    });
    
    testWidgets('should handle live region with state changes', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'message': 'Initial message',
              },
            },
          },
        },
        'content': {
          'type': 'accessibleWrapper',
          'liveRegion': 'polite',
          'announceOnChange': true,
          'watchPath': 'message',
          'child': {
            'type': 'text',
            'value': '{{message}}',
          },
        },
      };
      
      await runtime.initialize(definition);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Find the text widget
      expect(find.text('Initial message'), findsOneWidget);
      
      // Update the message
      runtime.engine!.stateManager.set('message', 'Updated message');
      await tester.pump();
      
      // Verify text updated
      expect(find.text('Updated message'), findsOneWidget);
      expect(find.text('Initial message'), findsNothing);
    });
    
    testWidgets('should wrap with Semantics for live regions', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'content': {
          'type': 'accessibleWrapper',
          'liveRegion': 'assertive',
          'child': {
            'type': 'text',
            'value': 'Alert message',
          },
        },
      };
      
      await runtime.initialize(definition);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Find the text widget
      expect(find.text('Alert message'), findsOneWidget);
      
      // Verify Semantics widget is present in the tree
      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsAtLeastNWidgets(1));
    });
    
    testWidgets('should support navigation announcements', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'content': {
          'type': 'accessibleWrapper',
          'announceNavigation': true,
          'navigationMessage': 'Welcome to the home page',
          'child': {
            'type': 'text',
            'value': 'Home Page',
          },
        },
      };
      
      await runtime.initialize(definition);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      // Wait for post-frame callback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      
      // Verify the child is rendered
      expect(find.text('Home Page'), findsOneWidget);
      
      // Navigation announcement would be made through LiveRegionManager
      // In a real app, this would trigger screen reader announcements
    });
  });
}