import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_showcase/showcase_definition.dart';

void main() {
  group('MCP UI DSL v1.0 Showcase Simple Tests', () {
    test('showcase definition is valid', () {
      expect(showcaseDefinition, isNotNull);
      expect(showcaseDefinition['type'], equals('application'));
      expect(showcaseDefinition['title'], equals('MCP UI DSL v1.0 Showcase'));
      expect(showcaseDefinition['version'], equals('1.0.0'));
    });

    test('all required pages are defined', () {
      expect(showcasePages.length, equals(9));
      expect(showcasePages['ui://pages/home'], isNotNull);
      expect(showcasePages['ui://pages/layout'], isNotNull);
      expect(showcasePages['ui://pages/display'], isNotNull);
      expect(showcasePages['ui://pages/input'], isNotNull);
      expect(showcasePages['ui://pages/lists'], isNotNull);
      expect(showcasePages['ui://pages/navigation'], isNotNull);
      expect(showcasePages['ui://pages/theme'], isNotNull);
      expect(showcasePages['ui://pages/actions'], isNotNull);
      expect(showcasePages['ui://pages/advanced'], isNotNull);
    });

    test('theme is properly structured', () {
      final theme = showcaseDefinition['theme'];
      expect(theme, isNotNull);
      expect(theme['mode'], equals('light'));
      
      final colors = theme['colors'];
      expect(colors, isNotNull);
      expect(colors['primary'], equals('#FF2196F3'));
      expect(colors['background'], equals('#FFFFFFFF'));
      
      final typography = theme['typography'];
      expect(typography, isNotNull);
      expect(typography['h1']['fontSize'], equals(32));
      expect(typography['body1']['fontSize'], equals(16));
    });

    test('state is properly initialized', () {
      final state = showcaseDefinition['state'];
      expect(state, isNotNull);
      
      final initial = state['initial'];
      expect(initial, isNotNull);
      expect(initial['counter'], equals(0));
      expect(initial['textInput'], equals(''));
      expect(initial['toggleValue'], equals(false));
      expect(initial['sliderValue'], equals(50.0));
      expect(initial['selectedOption'], equals('option1'));
    });

    test('navigation is properly configured', () {
      final navigation = showcaseDefinition['navigation'];
      expect(navigation, isNotNull);
      expect(navigation['type'], equals('drawer'));
      
      final items = navigation['items'];
      expect(items, isNotNull);
      expect(items.length, equals(9));
      
      final firstItem = items[0];
      expect(firstItem['title'], equals('Home'));
      expect(firstItem['icon'], equals('home'));
      expect(firstItem['route'], equals('/home'));
    });

    test('routes are properly mapped', () {
      final routes = showcaseDefinition['routes'];
      expect(routes, isNotNull);
      expect(routes.length, equals(9));
      expect(routes['/home'], equals('ui://pages/home'));
      expect(routes['/layout'], equals('ui://pages/layout'));
      expect(routes['/display'], equals('ui://pages/display'));
      expect(routes['/input'], equals('ui://pages/input'));
      expect(routes['/lists'], equals('ui://pages/lists'));
      expect(routes['/navigation'], equals('ui://pages/navigation'));
      expect(routes['/theme'], equals('ui://pages/theme'));
      expect(routes['/actions'], equals('ui://pages/actions'));
      expect(routes['/advanced'], equals('ui://pages/advanced'));
    });

    group('Page Content Tests', () {
      test('home page has correct structure', () {
        final homePage = showcasePages['ui://pages/home']!;
        expect(homePage['type'], equals('page'));
        
        final content = homePage['content'];
        expect(content['type'], equals('singleChildScrollView'));
        
        final child = content['child'];
        expect(child['type'], equals('linear'));
        expect(child['direction'], equals('vertical'));
      });

      test('input page has state actions', () {
        final inputPage = showcasePages['ui://pages/input']!;
        
        // Find button widgets with state actions
        bool hasIncrementAction = false;
        bool hasDecrementAction = false;
        bool hasSetAction = false;
        
        void checkForActions(dynamic node) {
          if (node is Map) {
            if (node['click'] != null && node['click'] is Map) {
              final click = node['click'];
              if (click['type'] == 'state') {
                if (click['action'] == 'increment') hasIncrementAction = true;
                if (click['action'] == 'decrement') hasDecrementAction = true;
                if (click['action'] == 'set') hasSetAction = true;
              }
            }
            node.values.forEach(checkForActions);
          } else if (node is List) {
            node.forEach(checkForActions);
          }
        }
        
        checkForActions(inputPage);
        
        expect(hasIncrementAction, isTrue);
        expect(hasDecrementAction, isTrue);
        expect(hasSetAction, isTrue);
      });

      test('lists page has list and grid widgets', () {
        final listsPage = showcasePages['ui://pages/lists']!;
        
        bool hasListWidget = false;
        bool hasGridWidget = false;
        
        void checkForListWidgets(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'list') hasListWidget = true;
            if (node['type'] == 'grid') hasGridWidget = true;
            node.values.forEach(checkForListWidgets);
          } else if (node is List) {
            node.forEach(checkForListWidgets);
          }
        }
        
        checkForListWidgets(listsPage);
        
        expect(hasListWidget, isTrue);
        expect(hasGridWidget, isTrue);
      });

      test('advanced page has conditional and form widgets', () {
        final advancedPage = showcasePages['ui://pages/advanced']!;
        
        bool hasConditionalWidget = false;
        bool hasFormWidget = false;
        
        void checkForAdvancedWidgets(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'conditional') hasConditionalWidget = true;
            if (node['type'] == 'form') hasFormWidget = true;
            node.values.forEach(checkForAdvancedWidgets);
          } else if (node is List) {
            node.forEach(checkForAdvancedWidgets);
          }
        }
        
        checkForAdvancedWidgets(advancedPage);
        
        expect(hasConditionalWidget, isTrue);
        expect(hasFormWidget, isTrue);
      });

      test('actions page has batch actions', () {
        final actionsPage = showcasePages['ui://pages/actions']!;
        
        bool hasBatchAction = false;
        
        void checkForBatchActions(dynamic node) {
          if (node is Map) {
            if (node['click'] != null && node['click'] is Map) {
              final click = node['click'];
              if (click['type'] == 'batch') hasBatchAction = true;
            }
            node.values.forEach(checkForBatchActions);
          } else if (node is List) {
            node.forEach(checkForBatchActions);
          }
        }
        
        checkForBatchActions(actionsPage);
        
        expect(hasBatchAction, isTrue);
      });
    });

    group('Widget Naming Compliance', () {
      test('uses correct widget names', () {
        // Check that we're not using deprecated names
        void checkWidgetNames(dynamic node) {
          if (node is Map) {
            if (node['type'] != null) {
              final type = node['type'];
              // These should NOT be found
              expect(type, isNot('container')); // Should be 'box'
              expect(type, isNot('column')); // Should be 'linear'
              expect(type, isNot('row')); // Should be 'linear'
              expect(type, isNot('toggle')); // Should be 'switch'
              expect(type, isNot('dropdown')); // Should be 'select'
              expect(type, isNot('listItem')); // Should be 'listTile'
            }
            node.values.forEach(checkWidgetNames);
          } else if (node is List) {
            node.forEach(checkWidgetNames);
          }
        }
        
        showcasePages.values.forEach(checkWidgetNames);
      });
    });

    group('Color Format Tests', () {
      test('theme colors use 8-digit hex format', () {
        final colors = showcaseDefinition['theme']['colors'];
        
        colors.forEach((key, value) {
          expect(value, matches(RegExp(r'^#[A-F0-9]{8}$')),
              reason: 'Color $key should be 8-digit hex, got: $value');
        });
      });

      test('widget colors use valid hex format', () {
        void checkColors(dynamic node) {
          if (node is Map) {
            if (node['style'] != null && node['style'] is Map) {
              final style = node['style'];
              if (style['color'] != null) {
                final color = style['color'];
                if (color is String && !color.contains('{{')) {
                  expect(color, matches(RegExp(r'^#[A-Fa-f0-9]{6,8}$')),
                      reason: 'Color should be 6 or 8 digit hex, got: $color');
                }
              }
              if (style['backgroundColor'] != null) {
                final bgColor = style['backgroundColor'];
                if (bgColor is String && !bgColor.contains('{{')) {
                  expect(bgColor, matches(RegExp(r'^#[A-Fa-f0-9]{6,8}$')),
                      reason: 'Background color should be 6 or 8 digit hex, got: $bgColor');
                }
              }
            }
            if (node['decoration'] != null && node['decoration'] is Map) {
              final decoration = node['decoration'];
              if (decoration['backgroundColor'] != null) {
                final bgColor = decoration['backgroundColor'];
                if (bgColor is String && !bgColor.contains('{{')) {
                  expect(bgColor, matches(RegExp(r'^#[A-Fa-f0-9]{6,8}$')),
                      reason: 'Decoration background color should be 6 or 8 digit hex, got: $bgColor');
                }
              }
            }
            node.values.forEach(checkColors);
          } else if (node is List) {
            node.forEach(checkColors);
          }
        }
        
        showcasePages.values.forEach(checkColors);
      });
    });
  });
}