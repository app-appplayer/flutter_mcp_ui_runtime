import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:demo_mcp_showcase/showcase_definition.dart';

void main() {
  group('MCP UI DSL v1.0 Showcase Integration Tests', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: true);
    });

    tearDown(() async {
      await runtime.destroy();
    });

    group('Complete User Journey Tests', () {
      testWidgets('should complete full user journey through all pages', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Start at home page
        expect(find.text('Welcome to MCP UI DSL v1.0 Showcase'), findsOneWidget);
        expect(find.text('Key Features'), findsOneWidget);

        // Test navigation through all pages
        final pagesToTest = [
          'Layout Widgets',
          'Display Widgets', 
          'Input Widgets',
          'List Widgets',
          'Navigation',
          'Theme System',
          'Actions & State',
          'Advanced Features',
        ];

        for (final pageName in pagesToTest) {
          // Open drawer
          final scaffold = find.byType(Scaffold);
          final scaffoldState = tester.state<ScaffoldState>(scaffold);
          scaffoldState.openDrawer();
          await tester.pumpAndSettle();

          // Navigate to page
          await tester.tap(find.text(pageName).last);
          await tester.pumpAndSettle();

          // Verify page loaded
          expect(find.text(pageName), findsWidgets);
          
          // Close drawer if it's still open
          if (scaffoldState.isDrawerOpen) {
            Navigator.of(tester.element(scaffold)).pop();
            await tester.pumpAndSettle();
          }
        }
      });
    });

    group('Complex State Interaction Tests', () {
      testWidgets('should handle multiple state changes correctly', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to input page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Input Widgets'));
        await tester.pumpAndSettle();

        // Interact with multiple widgets
        // 1. Increment counter
        await tester.tap(find.text('Elevated'));
        await tester.pumpAndSettle();
        expect(find.text('Counter: 1'), findsOneWidget);

        // 2. Enter text
        final textInput = find.byType(TextField).first;
        await tester.enterText(textInput, 'Test Input');
        await tester.pumpAndSettle();
        expect(find.text('You typed: Test Input'), findsOneWidget);

        // 3. Toggle switch
        final switchWidget = find.byType(Switch).first;
        await tester.tap(switchWidget);
        await tester.pumpAndSettle();
        expect(find.text('Toggle is ON'), findsOneWidget);

        // 4. Change dropdown
        final dropdown = find.byType(DropdownButton<String>).first;
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Option 2').last);
        await tester.pumpAndSettle();
        expect(find.text('Selected: option2'), findsOneWidget);

        // Verify all states are maintained
        expect(runtime.stateManager.get('counter'), equals(1));
        expect(runtime.stateManager.get('textInput'), equals('Test Input'));
        expect(runtime.stateManager.get('toggleValue'), equals(true));
        expect(runtime.stateManager.get('selectedOption'), equals('option2'));
      });
    });

    group('Widget Binding Tests', () {
      testWidgets('should update UI when state changes', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to input page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Input Widgets'));
        await tester.pumpAndSettle();

        // Verify initial counter
        expect(find.text('Counter: 0'), findsOneWidget);

        // Update state programmatically
        runtime.stateManager.set('counter', 42);
        await tester.pumpAndSettle();

        // UI should update
        expect(find.text('Counter: 42'), findsOneWidget);

        // Update multiple states
        runtime.stateManager.set('textInput', 'Programmatic Update');
        runtime.stateManager.set('toggleValue', true);
        runtime.stateManager.set('sliderValue', 75.0);
        await tester.pumpAndSettle();

        // Verify all bindings updated
        expect(find.text('You typed: Programmatic Update'), findsOneWidget);
        expect(find.text('Toggle is ON'), findsOneWidget);
        expect(find.text('Value: 75'), findsOneWidget);
      });
    });

    group('List Performance Tests', () {
      testWidgets('should render large lists efficiently', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to lists page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('List Widgets'));
        await tester.pumpAndSettle();

        // Verify list renders
        expect(find.text('List Item 1'), findsOneWidget);
        
        // Scroll to bottom
        final listView = find.byType(ListView).first;
        await tester.scrollUntilVisible(
          find.text('List Item 10'),
          500.0,
          scrollable: listView,
        );
        
        expect(find.text('List Item 10'), findsOneWidget);
        
        // Verify grid renders
        expect(find.text('Grid 1'), findsOneWidget);
      });
    });

    group('Error Recovery Tests', () {
      testWidgets('should handle action errors gracefully', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Try to set invalid state
        runtime.stateManager.set('nonExistentKey', 'value');
        await tester.pumpAndSettle();

        // App should not crash
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Responsive Layout Tests', () {
      testWidgets('should handle different screen sizes', (tester) async {
        // Test phone size
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;

        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome to MCP UI DSL v1.0 Showcase'), findsOneWidget);

        // Test tablet size
        tester.view.physicalSize = const Size(768, 1024);
        await tester.pumpAndSettle();

        expect(find.text('Welcome to MCP UI DSL v1.0 Showcase'), findsOneWidget);

        // Reset
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should have proper semantics', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Check buttons have semantics
        final semantics = tester.getSemantics(find.byType(ElevatedButton).first);
        expect(semantics.label, isNotEmpty);
        
        // Check text fields have labels
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Input Widgets'));
        await tester.pumpAndSettle();

        final textFieldSemantics = tester.getSemantics(find.byType(TextField).first);
        expect(textFieldSemantics.label, isNotNull);
      });
    });

    group('Memory Leak Tests', () {
      testWidgets('should not leak memory on navigation', (tester) async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate between pages multiple times
        for (int i = 0; i < 3; i++) {
          final scaffold = find.byType(Scaffold);
          final scaffoldState = tester.state<ScaffoldState>(scaffold);
          scaffoldState.openDrawer();
          await tester.pumpAndSettle();

          await tester.tap(find.text('Layout Widgets'));
          await tester.pumpAndSettle();

          scaffoldState.openDrawer();
          await tester.pumpAndSettle();

          await tester.tap(find.text('Home'));
          await tester.pumpAndSettle();
        }

        // State should be consistent
        expect(runtime.stateManager.get('counter'), equals(0));
      });
    });
  });
}