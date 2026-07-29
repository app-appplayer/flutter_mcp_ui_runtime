import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/routing/route_value.dart';

/// `RouteValue` normalisation — MCP UI DSL v1.4 §1.2.1 / §1.9.1.
///
/// A route may now be any `DefinitionSource`. Only a plain resource URI still
/// needs the host's page loader; every other form normalises locally, and the
/// origin-carrying forms become a page whose content is a single `view` so that
/// route-level and widget-level composition cannot drift apart (§1.9.4).
void main() {
  applicationRouteParsingTests();
  group('plain resource URI stays a loader round-trip (v1.0)', () {
    test('returns null so the caller fetches it', () {
      expect(routeValueToPageJson('ui://pages/main'), isNull);
      expect(routeValueIsLocal('ui://pages/main'), isFalse);
    });

    test('caches by uri so two routes to one page share an entry', () {
      expect(routeValueCacheKey('/a', 'ui://pages/shared'),
          routeValueCacheKey('/b', 'ui://pages/shared'));
    });
  });

  group('inline definitions resolve locally (v1.0)', () {
    test('inline page passes through', () {
      final page = <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'hi'},
      };
      expect(routeValueToPageJson(page), page);
    });

    test('legacy `screen` root is accepted (§17.3.5)', () {
      final page = <String, dynamic>{'type': 'screen', 'content': <String, dynamic>{}};
      expect(routeValueToPageJson(page), page);
    });

    test('a bare widget tree is wrapped as a page', () {
      final json = routeValueToPageJson(
          <String, dynamic>{'type': 'text', 'content': 'bare'})!;
      expect(json['type'], 'page');
      expect((json['content'] as Map)['type'], 'text');
    });
  });

  group('transition wrapper unwraps (v1.3)', () {
    test('wrapper around a uri still defers to the loader', () {
      expect(
        routeValueToPageJson(<String, dynamic>{
          'page': 'ui://pages/main',
          'transition': <String, dynamic>{'style': 'fade'},
        }),
        isNull,
      );
    });

    test('wrapper around a qualified ref becomes a view page', () {
      final json = routeValueToPageJson(<String, dynamic>{
        'page': <String, dynamic>{
          r'$ref': 'ui://app',
          'from': <String, dynamic>{'connection': 'c1'},
        },
        'transition': <String, dynamic>{'style': 'slide'},
      })!;
      expect((json['content'] as Map)['type'], 'view');
    });
  });

  group('multi-origin route values become a `view` page (v1.4)', () {
    test('qualified ref carries the whole source through to view', () {
      final source = <String, dynamic>{
        r'$ref': 'ui://views/summary',
        'from': <String, dynamic>{'connection': '{{conn.temp}}'},
      };
      final json = routeValueToPageJson(source)!;
      expect(json['type'], 'page');
      final content = json['content'] as Map<String, dynamic>;
      expect(content['type'], 'view');
      // The source is handed over verbatim — the route layer does not
      // reinterpret the origin; `view` owns resolution (§1.9.4).
      expect(content['source'], source);
      expect(routeValueIsLocal(source), isTrue);
    });

    test('a binding route value becomes a view page too', () {
      final json = routeValueToPageJson('{{cached.ctrlUi}}')!;
      final content = json['content'] as Map<String, dynamic>;
      expect(content['type'], 'view');
      expect(content['source'], '{{cached.ctrlUi}}');
    });

    test('a binding is NOT mistaken for a resource uri', () {
      expect(routeValueIsLocal('{{cached.ctrlUi}}'), isTrue);
      expect(routeValueCacheKey('/x', '{{cached.ctrlUi}}'), 'route:/x');
    });

    test('structural routes cache per route path, not per shape', () {
      final a = routeValueCacheKey('/temp', <String, dynamic>{
        r'$ref': 'ui://app',
        'from': <String, dynamic>{'connection': 'c1'},
      });
      final b = routeValueCacheKey('/humid', <String, dynamic>{
        r'$ref': 'ui://app',
        'from': <String, dynamic>{'connection': 'c2'},
      });
      // Two routes reading the same uri from DIFFERENT origins must not
      // collide in the page cache — that would render one device's UI on the
      // other's route.
      expect(a, isNot(b));
    });
  });
}

/// Opening an application whose routes name another origin.
///
/// Separate from the route-value helpers above because the failure was not in
/// them: `ApplicationDefinition.fromUIDefinition` narrowed routes to
/// `Map<String, String>`, so an application carrying a v1.4 route object threw
/// during parsing and the app never opened. The user saw only "Cannot open
/// app — type '_Map<String, dynamic>' is not a subtype of type 'String'",
/// which names neither routes nor composition.
void applicationRouteParsingTests() {
  group('application routes (v1.4)', () {
    UIDefinition appWith(Map<String, dynamic> routes) => UIDefinition.fromJson({
          'type': 'application',
          'title': 'Composed',
          'version': '1.4',
          'initialRoute': '/',
          'routes': routes,
        });

    test('a route naming another origin parses', () {
      final app = ApplicationDefinition.fromUIDefinition(appWith({
        '/': 'ui://pages/main',
        '/node': {
          r'$ref': 'ui://app',
          'from': {'connection': 'esp32.node'},
        },
      }));

      expect(app.routes['/'], 'ui://pages/main');
      expect(app.routes['/node'], isA<Map>(),
          reason: 'the origin-carrying value survives parsing intact');
      expect((app.routes['/node'] as Map)['from'],
          <String, dynamic>{'connection': 'esp32.node'});
    });

    test('a string-only application still parses', () {
      final app = ApplicationDefinition.fromUIDefinition(appWith({
        '/': 'ui://pages/main',
        '/second': 'ui://pages/second',
      }));
      expect(app.routes['/second'], 'ui://pages/second');
    });
  });
}
