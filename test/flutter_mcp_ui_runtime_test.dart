import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('MCPUIRuntime Tests', () {
    test('initializes with single widget definition', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'container',
          'child': {
            'type': 'text',
            'content': 'Test Content'
          }
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(definition);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);
    });

    test('initializes with page definition', () async {
      final pageDefinition = {
        'type': 'page',
        'title': 'Test Page',
        'content': {
          'type': 'scaffold',
          'body': {
            'type': 'text',
            'content': 'Page Content'
          }
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(pageDefinition);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);
    });

    test('throws when already initialized', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize({
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {'type': 'text', 'content': 'Test'}
      });

      expect(
        () => runtime.initialize({
          'type': 'page',
          'metadata': {
            'title': 'Test Page 2',
          },
          'content': {'type': 'text', 'content': 'Test'}
        }),
        throwsStateError,
      );
    });

    test('destroys runtime correctly', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize({
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {'type': 'text', 'content': 'Test'}
      });
      
      expect(runtime.isInitialized, isTrue);
      
      await runtime.destroy();
      
      expect(runtime.isInitialized, isFalse);
      expect(runtime.engine, isNull);
    });

    test('runtime builds UI correctly', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'UI Test Page',
        },
        'content': {
          'type': 'container',
          'child': {
            'type': 'text',
            'content': 'UI Test'
          }
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(definition);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);
      expect(runtime.engine!.uiDefinition, isNotNull);
    });
  });

  group('MCPUIRuntimeHelper Tests', () {
    testWidgets('renders page specification', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'title': 'Test Page',
        'content': {
          'type': 'center',
          'child': {
            'type': 'text',
            'content': 'Test Runtime'
          }
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(
            definition,
            onToolCall: (tool, args) {},
          ),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      expect(find.text('Test Runtime'), findsOneWidget);
    });

    testWidgets('renders container specification', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Container Test',
        },
        'content': {
          'type': 'container',
          'child': {
            'type': 'text',
            'content': 'Container Test'
          }
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(definition),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Container Test'), findsOneWidget);
    });

    testWidgets('shows loading state during initialization', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Loading Test',
        },
        'content': {
          'type': 'text',
          'content': 'Test'
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(definition),
        ),
      );

      // Initial pump should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After settling, loading should be gone
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('handles initialization errors', (WidgetTester tester) async {
      // Invalid definition that might cause an error
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Error Test',
        },
        'content': {
          'type': 'invalid_widget_type'
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(definition),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error container with red background
      expect(find.byType(Container), findsWidgets);
      expect(find.text('Unknown widget type: invalid_widget_type'), findsOneWidget);
    });
  });

  group('MCPRuntimeWidget Tests', () {
    testWidgets('builds UI from engine', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'title': 'Test Page',
        'content': {
          'type': 'container',
          'child': {
            'type': 'text',
            'content': 'Engine Test',
          },
        },
        'state': {
          'initial': {}
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(definition);

      await tester.pumpWidget(
        MaterialApp(
          home: runtime.buildUI(),
        ),
      );

      // Wait for ready callback
      await tester.pumpAndSettle();

      expect(find.text('Engine Test'), findsOneWidget);
    });

    testWidgets('handles tool calls', (WidgetTester tester) async {
      String? capturedTool;
      Map<String, dynamic>? capturedArgs;

      final definition = {
        'type': 'page',
        'title': 'Tool Test',
        'content': {
          'type': 'center',
          'child': {
            'type': 'button',
            'label': 'Call Tool',
            'onTap': {
              'type': 'tool',
              'tool': 'test_tool',
              'args': {'param': 'value'}
            }
          }
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(definition);

      await tester.pumpWidget(
        MaterialApp(
          home: runtime.buildUI(
            onToolCall: (tool, args) {
              capturedTool = tool;
              capturedArgs = args;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Call Tool'));
      await tester.pump();

      expect(capturedTool, 'test_tool');
      expect(capturedArgs, {'param': 'value'});
    });
  });

  group('Application Type Support Tests', () {
    test('initializes with application definition', () async {
      final appDefinition = {
        'type': 'application',
        'title': 'Test MCP App',
        'version': '1.0.0',
        'initialRoute': '/home',
        'routes': {
          '/home': 'mcp://server/pages/home',
          '/settings': 'mcp://server/pages/settings',
        },
        'state': {
          'initial': {
            'user': {'name': 'Test User'},
            'theme': 'light',
          }
        },
        'navigation': {
          'type': 'drawer',
          'items': [
            {'title': 'Home', 'route': '/home', 'icon': 'home'},
            {'title': 'Settings', 'route': '/settings', 'icon': 'settings'},
          ]
        },
        'lifecycle': {
          'onInitialize': [
            {'type': 'log', 'message': 'App initializing'}
          ],
          'onReady': [
            {'type': 'log', 'message': 'App ready'}
          ]
        },
        'services': {
          'state': {
            'initialState': {'counter': 0}
          },
          'backgroundServices': {
            'sync': {
              'type': 'periodic',
              'interval': 30000,
              'tool': 'sync_data'
            }
          }
        }
      };

      final runtime = MCPUIRuntime();
      
      // Mock page loader
      Future<Map<String, dynamic>> pageLoader(String uri) async {
        if (uri.endsWith('/home')) {
          return {
            'type': 'page',
            'title': 'Home Page',
            'content': {
              'type': 'text',
              'content': 'Welcome Home'
            }
          };
        } else if (uri.endsWith('/settings')) {
          return {
            'type': 'page',
            'title': 'Settings Page',
            'content': {
              'type': 'text',
              'content': 'Settings'
            }
          };
        }
        throw ArgumentError('Unknown page: $uri');
      }

      await runtime.initialize(appDefinition, pageLoader: pageLoader);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);
      expect(runtime.engine!.isApplication, isTrue);
      expect(runtime.engine!.applicationDefinition, isNotNull);
      expect(runtime.engine!.routeManager, isNotNull);
      expect(runtime.engine!.applicationDefinition!.title, 'Test MCP App');
      expect(runtime.engine!.applicationDefinition!.routes['/home'], 'mcp://server/pages/home');
    });

    test('initializes with page definition (backward compatibility)', () async {
      final pageDefinition = {
        'type': 'page',
        'title': 'Single Page',
        'route': '/page',
        'content': {
          'type': 'text',
          'content': 'Single Page Content'
        },
        'lifecycle': {
          'onMount': [
            {'type': 'log', 'message': 'Page mounted'}
          ]
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(pageDefinition);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine!.isApplication, isFalse);
      expect(runtime.engine!.parsedUIDefinition!.type, UIDefinitionType.page);
    });

    test('throws when pageLoader not provided for application type', () async {
      final appDefinition = {
        'type': 'application',
        'title': 'Test App',
        'initialRoute': '/home',
        'routes': {
          '/home': 'home.json',
        }
      };

      final runtime = MCPUIRuntime();

      expect(
        () => runtime.initialize(appDefinition), // No pageLoader
        throwsArgumentError,
      );
    });

    testWidgets('builds application UI with navigation', (WidgetTester tester) async {
      final appDefinition = {
        'type': 'application',
        'title': 'Nav Test App',
        'version': '1.0.0',
        'initialRoute': '/home',
        'routes': {
          '/home': 'home.json',
          '/profile': 'profile.json',
        },
        'navigation': {
          'type': 'bottom',
          'items': [
            {'title': 'Home', 'route': '/home', 'icon': 'home'},
            {'title': 'Profile', 'route': '/profile', 'icon': 'person'},
          ]
        }
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(appDefinition, pageLoader: (uri) async {
        return {
          'type': 'page',
          'title': 'Test Page',
          'content': {
            'type': 'text',
            'content': 'Page Content'
          }
        };
      });

      await tester.pumpWidget(
        MaterialApp(home: runtime.buildUI()),
      );

      await tester.pumpAndSettle();

      // Should have MaterialApp with navigation
      expect(find.byType(MaterialApp), findsWidgets);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('builds application UI without navigation', (WidgetTester tester) async {
      final appDefinition = {
        'type': 'application',
        'title': 'Simple App',
        'initialRoute': '/main',
        'routes': {
          '/main': 'main.json',
        }
        // No navigation definition
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(appDefinition, pageLoader: (uri) async {
        return {
          'type': 'page',
          'title': 'Main Page',
          'content': {
            'type': 'text',
            'content': 'Main Content'
          }
        };
      });

      await tester.pumpWidget(
        MaterialApp(home: runtime.buildUI()),
      );

      await tester.pumpAndSettle();

      // Should have MaterialApp without navigation wrapper
      expect(find.byType(MaterialApp), findsWidgets);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    });
  });
}