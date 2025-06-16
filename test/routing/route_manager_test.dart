import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('RouteManager Tests', () {
    late ApplicationDefinition appDefinition;
    late RuntimeEngine runtimeEngine;
    late Map<String, Map<String, dynamic>> mockPages;

    setUp(() {
      appDefinition = ApplicationDefinition(
        title: 'Test App',
        version: '1.0.0',
        initialRoute: '/home',
        routes: {
          '/home': 'mcp://server/pages/home',
          '/profile': 'mcp://server/pages/profile',
          '/users/:id': 'mcp://server/pages/user-detail',
        },
      );

      runtimeEngine = RuntimeEngine(enableDebugMode: true);

      mockPages = {
        'mcp://server/pages/home': {
          'type': 'page',
          'metadata': {'title': 'Home Page'},
          'content': {
            'type': 'scaffold',
            'body': {
              'type': 'text',
              'content': 'Welcome Home'
            }
          }
        },
        'mcp://server/pages/profile': {
          'type': 'page',
          'metadata': {'title': 'Profile Page'},
          'content': {
            'type': 'scaffold',
            'body': {
              'type': 'text',
              'content': 'User Profile'
            }
          }
        },
        'mcp://server/pages/user-detail': {
          'type': 'page',
          'metadata': {'title': 'User Detail'},
          'content': {
            'type': 'scaffold',
            'body': {
              'type': 'text',
              'content': 'User Details'
            }
          }
        },
      };
    });

    testWidgets('generates routes correctly', (WidgetTester tester) async {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final routes = routeManager.generateRoutes(context);
              
              expect(routes.keys, contains('/home'));
              expect(routes.keys, contains('/profile'));
              expect(routes.keys, contains('/users/:id'));
              
              return Container();
            },
          ),
        ),
      );
    });

    test('returns correct initial route', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      expect(routeManager.initialRoute, '/home');
    });

    test('parses simple route correctly', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      final routeInfo = routeManager.parseRoute('/home');

      expect(routeInfo.route, '/home');
      expect(routeInfo.pathParams, isEmpty);
      expect(routeInfo.queryParams, isEmpty);
      expect(routeInfo.pageUri, 'mcp://server/pages/home');
    });

    test('parses route with parameters correctly', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      final routeInfo = routeManager.parseRoute('/users/123');

      expect(routeInfo.route, '/users/:id');
      expect(routeInfo.pathParams['id'], '123');
      expect(routeInfo.pageUri, 'mcp://server/pages/user-detail');
    });

    test('parses route with query parameters correctly', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      final routeInfo = routeManager.parseRoute('/home?tab=settings&view=list');

      expect(routeInfo.route, '/home');
      expect(routeInfo.queryParams['tab'], 'settings');
      expect(routeInfo.queryParams['view'], 'list');
    });

    test('throws for unknown route', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      expect(
        () => routeManager.parseRoute('/unknown'),
        throwsArgumentError,
      );
    });

    test('extracts parameter names correctly', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      // Use reflection or make the method public for testing
      // For now, test through parseRoute which uses this internally
      final routeInfo = routeManager.parseRoute('/users/456');
      expect(routeInfo.pathParams['id'], '456');
    });

    test('combines path and query parameters', () {
      final routeManager = RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        pageLoader: (uri) async => mockPages[uri]!,
      );

      final routeInfo = routeManager.parseRoute('/users/789?edit=true');
      final allParams = routeInfo.allParams;

      expect(allParams['id'], '789');
      expect(allParams['edit'], 'true');
    });
  });

  testWidgets('RouteManager navigation tests', (WidgetTester tester) async {
    final appDefinition = ApplicationDefinition(
      title: 'Nav Test App',
      version: '1.0.0',
      initialRoute: '/home',
      routes: {
        '/home': 'home.json',
        '/profile': 'profile.json',
      },
    );

    final runtimeEngine = RuntimeEngine(enableDebugMode: true);
    await runtimeEngine.initialize(definition: {
      'type': 'page',
      'metadata': {
        'title': 'Test Page',
      },
      'content': {
        'type': 'container'
      }
    });

    final routeManager = RouteManager(
      appDefinition: appDefinition,
      runtimeEngine: runtimeEngine,
      pageLoader: (uri) async => {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {
          'type': 'scaffold',
          'body': {
            'type': 'text',
            'content': 'Test Content'
          }
        }
      },
    );

    // Test route generation without building widgets that require MaterialApp context
    bool routesGenerated = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final routes = routeManager.generateRoutes(context);
            routesGenerated = true;

            // Test that routes contain expected widgets
            expect(routes['/home'], isNotNull);
            expect(routes['/profile'], isNotNull);
            
            return const Text('Routes tested');
          },
        ),
      ),
    );

    expect(routesGenerated, isTrue);
  });
}