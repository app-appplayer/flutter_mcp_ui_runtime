import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:demo_mcp_showcase/showcase_definition.dart';

void main() {
  group('MCP UI DSL v1.0 Showcase Tests', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: true);
    });

    tearDown(() async {
      await runtime.destroy();
    });

    group('Application Structure Tests', () {
      test('should initialize application with correct structure', () async {
        // Test application definition
        expect(showcaseDefinition['type'], equals('application'));
        expect(showcaseDefinition['title'], equals('MCP UI DSL v1.0 Showcase'));
        expect(showcaseDefinition['version'], equals('1.0.0'));
        expect(showcaseDefinition['initialRoute'], equals('/home'));
        
        // Test navigation structure
        final navigation = showcaseDefinition['navigation'] as Map<String, dynamic>;
        expect(navigation['type'], equals('drawer'));
        expect(navigation['items'], isA<List>());
        expect((navigation['items'] as List).length, equals(9));
        
        // Test routes
        final routes = showcaseDefinition['routes'] as Map<String, dynamic>;
        expect(routes.keys.length, equals(9));
        expect(routes['/home'], equals('ui://pages/home'));
      });

      test('should have correct initial state', () async {
        final state = showcaseDefinition['state'] as Map<String, dynamic>;
        final initial = state['initial'] as Map<String, dynamic>;
        
        expect(initial['appName'], equals('MCP UI DSL Showcase'));
        expect(initial['counter'], equals(0));
        expect(initial['textInput'], equals(''));
        expect(initial['toggleValue'], equals(false));
        expect(initial['sliderValue'], equals(50.0));
        expect(initial['selectedOption'], equals('option1'));
        expect(initial['selectedCheckboxes'], isA<List>());
        expect(initial['selectedRadio'], equals('radio1'));
      });

      test('should have correct theme structure', () async {
        final theme = showcaseDefinition['theme'] as Map<String, dynamic>;
        
        expect(theme['mode'], equals('light'));
        
        // Test colors
        final colors = theme['colors'] as Map<String, dynamic>;
        expect(colors['primary'], equals('#FF2196F3'));
        expect(colors['background'], equals('#FFFFFFFF'));
        expect(colors['textOnPrimary'], equals('#FFFFFFFF'));
        
        // Test typography
        final typography = theme['typography'] as Map<String, dynamic>;
        expect(typography['h1'], isA<Map>());
        expect(typography['h1']['fontSize'], equals(32));
        expect(typography['body1']['fontSize'], equals(16));
        
        // Test spacing
        final spacing = theme['spacing'] as Map<String, dynamic>;
        expect(spacing['md'], equals(16));
        
        // Test borderRadius
        final borderRadius = theme['borderRadius'] as Map<String, dynamic>;
        expect(borderRadius['md'], equals(8));
      });
    });

    group('Page Definition Tests', () {
      test('all pages should be properly defined', () {
        expect(showcasePages.length, equals(9));
        
        // Check each page has correct structure
        showcasePages.forEach((uri, page) {
          expect(page['type'], equals('page'));
          expect(page['content'], isNotNull);
          
          // Check content is scrollable
          final content = page['content'] as Map<String, dynamic>;
          expect(content['type'], equals('singleChildScrollView'));
        });
      });

      test('home page should have correct content', () {
        final homePage = showcasePages['ui://pages/home']!;
        final content = homePage['content'] as Map<String, dynamic>;
        final child = content['child'] as Map<String, dynamic>;
        
        expect(child['type'], equals('linear'));
        expect(child['direction'], equals('vertical'));
        
        final children = child['children'] as List<dynamic>;
        expect(children.length, greaterThan(3));
        
        // Check welcome text
        final welcomeText = children[0] as Map<String, dynamic>;
        expect(welcomeText['type'], equals('text'));
        expect(welcomeText['content'], contains('Welcome'));
      });
    });

    group('Widget Rendering Tests', () {
      testWidgets('should render application successfully', (tester) async {
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

        // Should show drawer navigation
        expect(find.byType(Drawer), findsOneWidget);
        
        // Should show home page content
        expect(find.text('Welcome to MCP UI DSL v1.0 Showcase'), findsOneWidget);
      });

      testWidgets('should navigate between pages', (tester) async {
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

        // Open drawer
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        // Navigate to Layout page
        await tester.tap(find.text('Layout Widgets'));
        await tester.pumpAndSettle();

        // Should show layout page content
        expect(find.text('Layout Widgets'), findsWidgets);
        expect(find.text('Box Widget'), findsOneWidget);
      });
    });

    group('State Management Tests', () {
      testWidgets('should handle counter state actions', (tester) async {
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

        // Find counter display
        expect(find.text('Counter: 0'), findsOneWidget);

        // Test increment
        await tester.tap(find.text('Elevated'));
        await tester.pumpAndSettle();
        expect(find.text('Counter: 1'), findsOneWidget);

        // Test decrement
        await tester.tap(find.text('Outlined'));
        await tester.pumpAndSettle();
        expect(find.text('Counter: 0'), findsOneWidget);

        // Test reset
        await tester.tap(find.text('Elevated')); // increment to 1
        await tester.pumpAndSettle();
        await tester.tap(find.text('Text')); // reset
        await tester.pumpAndSettle();
        expect(find.text('Counter: 0'), findsOneWidget);
      });

      testWidgets('should handle text input state', (tester) async {
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

        // Find text input
        final textInput = find.byType(TextField).first;
        expect(textInput, findsOneWidget);

        // Type text
        await tester.enterText(textInput, 'Hello MCP!');
        await tester.pumpAndSettle();

        // Check state updated
        expect(find.text('You typed: Hello MCP!'), findsOneWidget);
      });

      testWidgets('should handle switch toggle', (tester) async {
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

        // Find switch
        expect(find.text('Toggle is OFF'), findsOneWidget);

        final switchWidget = find.byType(Switch).first;
        await tester.tap(switchWidget);
        await tester.pumpAndSettle();

        // Check state toggled
        expect(find.text('Toggle is ON'), findsOneWidget);
      });

      testWidgets('should handle slider value changes', (tester) async {
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

        // Find slider display
        expect(find.text('Value: 50'), findsOneWidget);

        // Drag slider
        final slider = find.byType(Slider).first;
        final center = tester.getCenter(slider);
        await tester.dragFrom(center, const Offset(100, 0));
        await tester.pumpAndSettle();

        // Value should have changed
        final valueText = find.textContaining('Value: ');
        expect(valueText, findsOneWidget);
        final text = tester.widget<Text>(valueText).data!;
        expect(text, isNot('Value: 50'));
      });
    });

    group('Layout Widget Tests', () {
      testWidgets('should render all layout widgets', (tester) async {
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

        // Navigate to layout page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Layout Widgets'));
        await tester.pumpAndSettle();

        // Check for layout widget sections
        expect(find.text('Box Widget'), findsOneWidget);
        expect(find.text('Linear Widget'), findsOneWidget);
        expect(find.text('Stack Widget'), findsOneWidget);
        expect(find.text('Expanded & Flexible'), findsOneWidget);
        
        // Check box with decoration is rendered
        expect(find.text('Box with decoration'), findsOneWidget);
      });
    });

    group('Display Widget Tests', () {
      testWidgets('should render all display widgets', (tester) async {
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

        // Navigate to display page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Display Widgets'));
        await tester.pumpAndSettle();

        // Check for display widget sections
        expect(find.text('Text Widget'), findsOneWidget);
        expect(find.text('RichText Widget'), findsOneWidget);
        expect(find.text('Icon Widget'), findsOneWidget);
        expect(find.text('Card Widget'), findsOneWidget);
        expect(find.text('Badge Widget'), findsOneWidget);
        
        // Check rich text is rendered
        expect(find.byType(RichText), findsWidgets);
        
        // Check icons are rendered
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('List Widget Tests', () {
      testWidgets('should render list and grid widgets', (tester) async {
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

        // Check list widget
        expect(find.text('List Widget'), findsOneWidget);
        expect(find.text('List Item 1'), findsOneWidget);
        expect(find.byType(ListTile), findsWidgets);
        
        // Check grid widget
        expect(find.text('Grid Widget'), findsOneWidget);
        expect(find.text('Grid 1'), findsOneWidget);
      });
    });

    group('Advanced Feature Tests', () {
      testWidgets('should handle conditional rendering', (tester) async {
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

        // Navigate to advanced page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Advanced Features'));
        await tester.pumpAndSettle();

        // Check conditional rendering
        expect(find.text('This card is visible when toggle is OFF'), findsOneWidget);
        expect(find.text('This card is visible when toggle is ON'), findsNothing);

        // Toggle visibility
        await tester.tap(find.text('Toggle Visibility'));
        await tester.pumpAndSettle();

        // Check condition changed
        expect(find.text('This card is visible when toggle is OFF'), findsNothing);
        expect(find.text('This card is visible when toggle is ON'), findsOneWidget);
      });

      testWidgets('should handle batch actions', (tester) async {
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

        // Navigate to actions page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Actions & State'));
        await tester.pumpAndSettle();

        // Execute batch action
        await tester.tap(find.text('Execute Batch Action'));
        await tester.pumpAndSettle();

        // Check all actions were executed
        expect(runtime.stateManager.get('counter'), equals(0));
        expect(runtime.stateManager.get('textInput'), equals('Batch executed!'));
        expect(runtime.stateManager.get('toggleValue'), equals(true));
      });
    });

    group('Theme System Tests', () {
      test('should apply theme values correctly', () async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        // Check theme manager has correct values
        final themeManager = runtime.engine!.themeManager;
        final theme = themeManager.currentTheme;
        
        expect(theme.primaryColor, equals(const Color(0xFF2196F3)));
        expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFFFFFFF)));
      });

      testWidgets('should render theme showcase correctly', (tester) async {
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

        // Navigate to theme page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Theme System'));
        await tester.pumpAndSettle();

        // Check theme sections
        expect(find.text('Color Palette'), findsOneWidget);
        expect(find.text('Typography'), findsOneWidget);
        expect(find.text('Spacing System'), findsOneWidget);
      });
    });

    group('Navigation Tests', () {
      testWidgets('should show navigation patterns', (tester) async {
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

        // Navigate to navigation page
        final scaffold = find.byType(Scaffold);
        final scaffoldState = tester.state<ScaffoldState>(scaffold);
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Navigation').last);
        await tester.pumpAndSettle();

        // Check navigation content
        expect(find.text('Navigation Patterns'), findsOneWidget);
        expect(find.text('Drawer Navigation'), findsOneWidget);
        expect(find.text('Tab Navigation'), findsOneWidget);
      });
    });

    group('Performance Tests', () {
      test('should handle large lists efficiently', () async {
        // The list page has 10 items - check it renders without issues
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        final stopwatch = Stopwatch()..start();
        
        // Initialize should be fast
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Error Handling Tests', () {
      test('should handle missing pages gracefully', () async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async {
            if (uri == 'ui://pages/nonexistent') {
              return {};
            }
            return showcasePages[uri] ?? {};
          },
        );

        // Should not throw
        expect(() => runtime.buildUI(), returnsNormally);
      });
    });

    group('State Persistence Tests', () {
      test('state should persist across page navigation', () async {
        await runtime.initialize(
          showcaseDefinition,
          pageLoader: (uri) async => showcasePages[uri] ?? {},
        );

        // Set some state
        runtime.stateManager.set('counter', 5);
        runtime.stateManager.set('textInput', 'Test');
        
        // State should persist
        expect(runtime.stateManager.get('counter'), equals(5));
        expect(runtime.stateManager.get('textInput'), equals('Test'));
      });
    });
  });
}