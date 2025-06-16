import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('UIDefinition Tests', () {
    test('creates application type from JSON', () {
      final json = {
        'type': 'application',
        'properties': {
          'title': 'Test App',
          'version': '1.0.0',
          'initialRoute': '/home',
        },
        'routes': {
          '/home': 'mcp://server/pages/home',
          '/settings': 'mcp://server/pages/settings',
        },
        'state': {
          'initial': {'counter': 0}
        },
        'navigation': {
          'type': 'drawer',
          'items': [
            {'title': 'Home', 'route': '/home', 'icon': 'home'}
          ]
        },
        'lifecycle': {
          'onInitialize': [
            {'type': 'log', 'message': 'App starting'}
          ]
        },
        'services': {
          'state': {
            'initialState': {'count': 0}
          }
        }
      };

      final definition = UIDefinition.fromJson(json);

      expect(definition.type, UIDefinitionType.application);
      expect(definition.properties['title'], 'Test App');
      expect(definition.routes, isNotNull);
      expect(definition.routes!['/home'], 'mcp://server/pages/home');
      expect(definition.state, isNotNull);
      expect(definition.navigation, isNotNull);
      expect(definition.lifecycle, isNotNull);
      expect(definition.services, isNotNull);
    });

    test('creates page type from JSON', () {
      final json = {
        'type': 'page',
        'properties': {
          'title': 'Test Page',
          'route': '/test',
        },
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'properties': {'content': 'Hello World'}
            }
          ]
        },
        'lifecycle': {
          'onMount': [
            {'type': 'log', 'message': 'Page mounted'}
          ]
        }
      };

      final definition = UIDefinition.fromJson(json);

      expect(definition.type, UIDefinitionType.page);
      expect(definition.properties['title'], 'Test Page');
      expect(definition.content, isNotNull);
      expect(definition.lifecycle, isNotNull);
    });

    test('defaults to page type for unknown type', () {
      final json = {
        'type': 'unknown',
        'properties': {},
      };

      final definition = UIDefinition.fromJson(json);
      expect(definition.type, UIDefinitionType.page);
    });

    test('converts to JSON correctly', () {
      final definition = UIDefinition(
        type: UIDefinitionType.application,
        properties: {'title': 'Test'},
        routes: {'/home': 'home.json'},
        state: {'initial': {}},
      );

      final json = definition.toJson();

      expect(json['type'], 'application');
      expect(json['properties']['title'], 'Test');
      expect(json['routes']['/home'], 'home.json');
      expect(json['state']['initial'], {});
    });
  });

  group('ApplicationDefinition Tests', () {
    test('creates from UIDefinition correctly', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.application,
        properties: {
          'title': 'My App',
          'version': '2.0.0',
          'initialRoute': '/dashboard',
          'theme': {'primaryColor': '#FF0000'},
        },
        routes: {
          '/dashboard': 'dashboard.json',
          '/profile': 'profile.json',
        },
        state: {
          'initial': {'user': 'test'}
        },
        navigation: {
          'type': 'tabs',
          'items': [
            {'title': 'Dashboard', 'route': '/dashboard'},
            {'title': 'Profile', 'route': '/profile'},
          ]
        },
        lifecycle: {
          'onInitialize': [{'type': 'log', 'message': 'init'}]
        },
        services: {
          'state': {'initialState': {'count': 0}}
        }
      );

      final appDef = ApplicationDefinition.fromUIDefinition(uiDef);

      expect(appDef.title, 'My App');
      expect(appDef.version, '2.0.0');
      expect(appDef.initialRoute, '/dashboard');
      expect(appDef.routes['/dashboard'], 'dashboard.json');
      expect(appDef.theme!['primaryColor'], '#FF0000');
      expect(appDef.initialState!['user'], 'test');
      expect(appDef.navigationDefinition, isNotNull);
      expect(appDef.navigationDefinition!.type, 'tabs');
      expect(appDef.lifecycleDefinition, isNotNull);
      expect(appDef.servicesDefinition, isNotNull);
    });

    test('uses defaults for missing properties', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.application,
        properties: {},
        routes: {'/': 'home.json'},
      );

      final appDef = ApplicationDefinition.fromUIDefinition(uiDef);

      expect(appDef.title, 'MCP Application');
      expect(appDef.version, '1.0.0');
      expect(appDef.initialRoute, '/');
    });

    test('throws for non-application type', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.page,
        properties: {},
      );

      expect(
        () => ApplicationDefinition.fromUIDefinition(uiDef),
        throwsArgumentError,
      );
    });

    test('throws for missing routes', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.application,
        properties: {},
      );

      expect(
        () => ApplicationDefinition.fromUIDefinition(uiDef),
        throwsArgumentError,
      );
    });
  });

  group('PageDefinition Tests', () {
    test('creates from UIDefinition correctly', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.page,
        properties: {
          'title': 'Test Page',
          'route': '/test',
        },
        content: {
          'type': 'scaffold',
          'properties': {
            'body': {
              'type': 'text',
              'properties': {'content': 'Hello'}
            }
          }
        },
        lifecycle: {
          'onMount': [{'type': 'log', 'message': 'mounted'}]
        }
      );

      final pageDef = PageDefinition.fromUIDefinition(uiDef);

      expect(pageDef.title, 'Test Page');
      expect(pageDef.route, '/test');
      expect(pageDef.content['type'], 'scaffold');
      expect(pageDef.lifecycle, isNotNull);
    });

    test('throws for non-page type', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.application,
        properties: {},
      );

      expect(
        () => PageDefinition.fromUIDefinition(uiDef),
        throwsArgumentError,
      );
    });

    test('throws for missing content', () {
      final uiDef = UIDefinition(
        type: UIDefinitionType.page,
        properties: {},
      );

      expect(
        () => PageDefinition.fromUIDefinition(uiDef),
        throwsArgumentError,
      );
    });
  });

  group('NavigationDefinition Tests', () {
    test('creates from JSON correctly', () {
      final json = {
        'type': 'drawer',
        'items': [
          {'title': 'Home', 'route': '/home', 'icon': 'home'},
          {'title': 'Settings', 'route': '/settings', 'icon': 'settings'},
        ]
      };

      final navDef = NavigationDefinition.fromJson(json);

      expect(navDef.type, 'drawer');
      expect(navDef.items.length, 2);
      expect(navDef.items[0].title, 'Home');
      expect(navDef.items[0].route, '/home');
      expect(navDef.items[0].icon, 'home');
    });

    test('uses defaults for missing properties', () {
      final json = {
        'items': []
      };

      final navDef = NavigationDefinition.fromJson(json);
      expect(navDef.type, 'drawer');
      expect(navDef.items, isEmpty);
    });
  });

  group('LifecycleDefinition Tests', () {
    test('creates from JSON correctly', () {
      final json = {
        'onInitialize': [
          {'type': 'log', 'message': 'initializing'}
        ],
        'onReady': [
          {'type': 'tool', 'tool': 'setup'}
        ],
        'onMount': [
          {'type': 'setState', 'path': 'mounted', 'value': true}
        ],
        'onUnmount': [
          {'type': 'cleanup'}
        ],
        'onDestroy': [
          {'type': 'log', 'message': 'destroying'}
        ]
      };

      final lifecycle = LifecycleDefinition.fromJson(json);

      expect(lifecycle.onInitialize, isNotNull);
      expect(lifecycle.onInitialize!.length, 1);
      expect(lifecycle.onReady, isNotNull);
      expect(lifecycle.onMount, isNotNull);
      expect(lifecycle.onUnmount, isNotNull);
      expect(lifecycle.onDestroy, isNotNull);
    });

    test('handles null values', () {
      final json = <String, dynamic>{};
      final lifecycle = LifecycleDefinition.fromJson(json);

      expect(lifecycle.onInitialize, isNull);
      expect(lifecycle.onReady, isNull);
      expect(lifecycle.onMount, isNull);
      expect(lifecycle.onUnmount, isNull);
      expect(lifecycle.onDestroy, isNull);
    });
  });

  group('BackgroundServiceDefinition Tests', () {
    test('creates periodic service from JSON', () {
      final json = {
        'type': 'periodic',
        'tool': 'sync_data',
        'interval': 60000,
        'params': {'endpoint': '/api/data'},
        'constraints': {'requiresNetwork': true},
        'priority': 'high'
      };

      final service = BackgroundServiceDefinition.fromJson('sync', json);

      expect(service.id, 'sync');
      expect(service.type, BackgroundServiceType.periodic);
      expect(service.tool, 'sync_data');
      expect(service.interval, 60000);
      expect(service.params!['endpoint'], '/api/data');
      expect(service.constraints!['requiresNetwork'], true);
      expect(service.priority, 'high');
    });

    test('creates scheduled service from JSON', () {
      final json = {
        'type': 'scheduled',
        'tool': 'backup',
        'schedule': '0 2 * * *',
        'runInBackground': false
      };

      final service = BackgroundServiceDefinition.fromJson('backup', json);

      expect(service.type, BackgroundServiceType.scheduled);
      expect(service.schedule, '0 2 * * *');
      expect(service.runInBackground, false);
    });

    test('creates event service from JSON', () {
      final json = {
        'type': 'event',
        'tool': 'handle_notification',
        'events': ['notification_received', 'app_resumed']
      };

      final service = BackgroundServiceDefinition.fromJson('events', json);

      expect(service.type, BackgroundServiceType.event);
      expect(service.events, ['notification_received', 'app_resumed']);
    });

    test('uses defaults for missing properties', () {
      final json = {
        'type': 'oneoff',
        'tool': 'init_task'
      };

      final service = BackgroundServiceDefinition.fromJson('init', json);

      expect(service.runInBackground, true);
      expect(service.priority, 'normal');
      expect(service.params, isNull);
    });

    test('throws for unknown service type', () {
      final json = {
        'type': 'unknown',
        'tool': 'test'
      };

      expect(
        () => BackgroundServiceDefinition.fromJson('test', json),
        throwsArgumentError,
      );
    });
  });
}