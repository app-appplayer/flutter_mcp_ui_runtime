import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_bundle/mcp_bundle.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart' hide PageDefinition;

void main() {
  // ==========================================================================
  // toRoutes (TC-V12-019 ~ TC-V12-021)
  // ==========================================================================
  group('BundlePageAdapter.toRoutes()', () {
    // TC-V12-020: toRoutes — null UiSection
    test('returns empty map for null UiSection', () {
      final routes = BundlePageAdapter.toRoutes(null);
      expect(routes, isEmpty);
    });

    // TC-V12-021: toRoutes — empty UiSection (no pages)
    test('returns empty map for UiSection with no screens', () {
      const uiSection = UiSection(pages: <String, PageDefinition>{});
      final routes = BundlePageAdapter.toRoutes(uiSection);
      expect(routes, isEmpty);
    });

    // TC-V12-019: toRoutes — convert UiSection pages to route map
    test('uses screen.route when present', () {
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'home',
            name: 'Home',
            route: '/',
            root: WidgetNode(type: 'text', props: {'content': 'Hello'}),
          ),
        ],
      );

      final routes = BundlePageAdapter.toRoutes(uiSection);
      expect(routes.length, equals(1));
      expect(routes['/'], equals('ui://pages/home'));
    });

    // TC-V12-019 (boundary): Page without explicit route → uses /{id} fallback
    test('falls back to /{id} when route is null', () {
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'settings',
            name: 'Settings',
            root: WidgetNode(type: 'container'),
          ),
        ],
      );

      final routes = BundlePageAdapter.toRoutes(uiSection);
      expect(routes['/settings'], equals('ui://pages/settings'));
    });

    // TC-V12-019 (continued): Multiple screens mapped
    test('maps multiple screens', () {
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'home',
            name: 'Home',
            route: '/',
            root: WidgetNode(type: 'text'),
          ),
          ScreenDefinition(
            id: 'profile',
            name: 'Profile',
            route: '/profile',
            root: WidgetNode(type: 'container'),
          ),
        ],
      );

      final routes = BundlePageAdapter.toRoutes(uiSection);
      expect(routes.length, equals(2));
      expect(routes['/'], equals('ui://pages/home'));
      expect(routes['/profile'], equals('ui://pages/profile'));
    });
  });

  // ==========================================================================
  // toPageContent (TC-V12-022 ~ TC-V12-024)
  // ==========================================================================
  group('BundlePageAdapter.toPageContent()', () {
    // TC-V12-023: toPageContent — null UiSection
    test('returns empty map for null UiSection', () {
      final pages = BundlePageAdapter.toPageContent(null);
      expect(pages, isEmpty);
    });

    // TC-V12-024: toPageContent — empty UiSection
    test('returns empty map for UiSection with no screens', () {
      const uiSection = UiSection(pages: <String, PageDefinition>{});
      final pages = BundlePageAdapter.toPageContent(uiSection);
      expect(pages, isEmpty);
    });

    // TC-V12-022: toPageContent — convert UiSection pages to content map
    test('maps screen id to serialized content', () {
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'home',
            name: 'Home',
            route: '/',
            root: WidgetNode(type: 'text', props: {'content': 'Hello'}),
          ),
        ],
      );

      final pages = BundlePageAdapter.toPageContent(uiSection);
      expect(pages.length, equals(1));
      expect(pages.containsKey('home'), isTrue);
      // Pass-through: mcp_bundle `PageDefinition.toJson` emits
      // `{id, name, route, root}` verbatim.
      expect(pages['home']!['id'], equals('home'));
      expect(pages['home']!['route'], equals('/'));
      expect(pages['home']!['root'], isNotNull);
    });

    // TC-V12-022 (continued): Multiple screens in page content
    test('maps multiple screens', () {
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'home',
            name: 'Home',
            route: '/',
            root: WidgetNode(type: 'text'),
          ),
          ScreenDefinition(
            id: 'about',
            name: 'About',
            route: '/about',
            root: WidgetNode(type: 'container'),
          ),
        ],
      );

      final pages = BundlePageAdapter.toPageContent(uiSection);
      expect(pages.length, equals(2));
      expect(pages.containsKey('home'), isTrue);
      expect(pages.containsKey('about'), isTrue);
    });
  });

  // ==========================================================================
  // Private constructor (TC-V12-025)
  // ==========================================================================
  group('BundlePageAdapter private constructor', () {
    // TC-V12-025: BundlePageAdapter has private constructor —
    // cannot be instantiated, only static methods accessible.
    // Verified by confirming static methods work directly on the class
    // without any instance creation.
    test('static methods accessible without instantiation', () {
      // BundlePageAdapter._() is private, so it cannot be instantiated.
      // Only static methods toRoutes() and toPageContent() are accessible.
      final routes = BundlePageAdapter.toRoutes(null);
      expect(routes, isEmpty);

      final pages = BundlePageAdapter.toPageContent(null);
      expect(pages, isEmpty);

      // With actual UiSection data
      final uiSection = UiSection.fromPagesList([
          ScreenDefinition(
            id: 'test',
            name: 'Test',
            route: '/test',
            root: WidgetNode(type: 'text'),
          ),
        ],
      );
      final routesWithData = BundlePageAdapter.toRoutes(uiSection);
      expect(routesWithData['/test'], equals('ui://pages/test'));

      final pagesWithData = BundlePageAdapter.toPageContent(uiSection);
      expect(pagesWithData.containsKey('test'), isTrue);
    });
  });
}
