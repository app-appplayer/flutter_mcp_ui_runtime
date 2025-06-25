import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_showcase/showcase_definition.dart';

void main() {
  group('MCP UI DSL v1.0 Spec Compliance Tests', () {
    group('Application Definition Compliance', () {
      test('application should have required fields per spec', () {
        // Per MCP UI DSL v1.0 spec section 1.1
        expect(showcaseDefinition['type'], equals('application'));
        expect(showcaseDefinition['title'], isNotNull);
        expect(showcaseDefinition['version'], isNotNull);
        expect(showcaseDefinition['initialRoute'], isNotNull);
        expect(showcaseDefinition['routes'], isNotNull);
        
        // Should not have metadata at top level (v1.0 change)
        expect(showcaseDefinition['metadata'], isNull);
      });

      test('state should follow v1.0 structure', () {
        // Per spec: state.initial not runtime.services.state.initialState
        expect(showcaseDefinition['state'], isNotNull);
        expect(showcaseDefinition['state']['initial'], isNotNull);
        
        // Should not have runtime.services structure
        expect(showcaseDefinition['runtime']?['services']?['state'], isNull);
      });

      test('theme should be at top level per v1.0', () {
        // Theme should be at application root, not in runtime.services
        expect(showcaseDefinition['theme'], isNotNull);
        expect(showcaseDefinition['theme']['colors'], isNotNull);
        expect(showcaseDefinition['theme']['typography'], isNotNull);
        
        // Colors should support 8-digit hex per spec update
        final colors = showcaseDefinition['theme']['colors'];
        expect(colors['primary'], matches(RegExp(r'^#[A-F0-9]{8}$')));
        expect(colors['background'], matches(RegExp(r'^#[A-F0-9]{8}$')));
      });

      test('navigation should follow v1.0 structure', () {
        final navigation = showcaseDefinition['navigation'];
        expect(navigation['type'], equals('drawer'));
        expect(navigation['items'], isA<List>());
        
        // Items should have title (not label)
        final firstItem = navigation['items'][0];
        expect(firstItem['title'], isNotNull);
        expect(firstItem['icon'], isNotNull);
        expect(firstItem['route'], isNotNull);
        expect(firstItem['label'], isNull); // Should not have label
      });
    });

    group('Page Definition Compliance', () {
      test('pages should follow v1.0 structure', () {
        showcasePages.forEach((uri, page) {
          // Must be type page
          expect(page['type'], equals('page'));
          
          // Must have content
          expect(page['content'], isNotNull);
          
          // Can have optional metadata
          if (page['metadata'] != null) {
            final metadata = page['metadata'];
            expect(metadata['title'], isNotNull);
          }
        });
      });
    });

    group('Widget Type Compliance', () {
      test('should use v1.0 compliant widget types', () {
        // Check home page for correct widget types
        final homePage = showcasePages['ui://pages/home']!;
        final content = homePage['content'];
        
        // Should use singleChildScrollView not scroll
        expect(content['type'], equals('singleChildScrollView'));
        
        // Check for linear not column/row
        final child = content['child'];
        expect(child['type'], equals('linear'));
        expect(child['direction'], isIn(['vertical', 'horizontal']));
      });

      test('should not use deprecated widget types', () {
        // Search all pages for deprecated types
        final deprecatedTypes = [
          'column', 'row', // Should use linear
          'container', // Should use box
          'toggle', // Should use switch
          'dropdown', // Should use select
          'listItem', // Should use listTile
          'appBar', // Should use headerBar
          'template', // Not in v1.0 spec
        ];

        void checkForDeprecatedTypes(dynamic node, String uri) {
          if (node is Map) {
            if (node['type'] != null && deprecatedTypes.contains(node['type'])) {
              fail('Found deprecated type ${node['type']} in $uri');
            }
            for (var value in node.values) {
              checkForDeprecatedTypes(value, uri);
            }
          } else if (node is List) {
            for (var item in node) {
              checkForDeprecatedTypes(item, uri);
            }
          }
        }

        showcasePages.forEach((uri, page) {
          checkForDeprecatedTypes(page, uri);
        });
      });
    });

    group('Action Type Compliance', () {
      test('should use v1.0 compliant action types', () {
        // Check all pages for action examples
        bool hasStateActions = false;
        bool hasIncrementAction = false;
        bool hasSetAction = false;
        bool hasToggleAction = false;
        bool hasParams = false;
        
        void checkForActions(dynamic node) {
          if (node is Map) {
            // Check for action types
            if (node['type'] == 'state') hasStateActions = true;
            if (node['action'] == 'increment') hasIncrementAction = true;
            if (node['action'] == 'set') hasSetAction = true;
            if (node['action'] == 'toggle') hasToggleAction = true;
            if (node.containsKey('params')) hasParams = true;
            
            // Recursively check all values
            node.values.forEach(checkForActions);
          } else if (node is List) {
            node.forEach(checkForActions);
          }
        }
        
        showcasePages.values.forEach(checkForActions);
        
        expect(hasStateActions, isTrue, reason: 'Should have state actions');
        expect(hasIncrementAction, isTrue, reason: 'Should have increment action');
        expect(hasSetAction, isTrue, reason: 'Should have set action');
        expect(hasToggleAction, isTrue, reason: 'Should have toggle action');
        expect(hasParams, isFalse, reason: 'Should not contain params in state actions');
      });

      test('should use event context for input bindings', () {
        final inputPage = showcasePages['ui://pages/input']!;
        final json = inputPage.toString();
        
        // Should use {{event.value}} not {{value}}
        expect(json.contains('{{event.value}}'), isTrue);
      });
    });

    group('Data Binding Compliance', () {
      test('should use valid binding expressions', () {
        // Check all pages for theme bindings
        bool hasColorBinding = false;
        bool hasTypographyBinding = false;
        bool hasSpacingBinding = false;
        
        void checkForBindings(dynamic node) {
          if (node is String) {
            if (node.contains('{{theme.colors.primary}}')) hasColorBinding = true;
            if (node.contains('{{theme.typography.')) hasTypographyBinding = true;
            if (node.contains('{{theme.spacing.')) hasSpacingBinding = true;
          } else if (node is Map) {
            node.values.forEach(checkForBindings);
          } else if (node is List) {
            node.forEach(checkForBindings);
          }
        }
        
        showcasePages.values.forEach(checkForBindings);
        
        expect(hasColorBinding, isTrue, reason: 'Should have theme color bindings');
        expect(hasTypographyBinding, isTrue, reason: 'Should have theme typography bindings');
        expect(hasSpacingBinding, isTrue, reason: 'Should have theme spacing bindings');
      });

      test('should use conditional expressions correctly', () {
        bool hasConditionalExpression = false;
        
        void checkForConditionals(dynamic node) {
          if (node is String) {
            if (node.contains('{{toggleValue ? "ON" : "OFF"}}')) {
              hasConditionalExpression = true;
            }
          } else if (node is Map) {
            node.values.forEach(checkForConditionals);
          } else if (node is List) {
            node.forEach(checkForConditionals);
          }
        }
        
        checkForConditionals(showcasePages['ui://pages/input']!);
        
        expect(hasConditionalExpression, isTrue);
      });
    });

    group('List Widget Compliance', () {
      test('should use correct list structure', () {
        bool hasListWidget = false;
        bool hasItemsProperty = false;
        bool hasListTile = false;
        bool hasListItem = false;
        
        void checkListStructure(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'list') {
              hasListWidget = true;
              if (node.containsKey('items')) hasItemsProperty = true;
            }
            if (node['type'] == 'listTile') hasListTile = true;
            if (node['type'] == 'listItem') hasListItem = true;
            
            node.values.forEach(checkListStructure);
          } else if (node is List) {
            node.forEach(checkListStructure);
          }
        }
        
        checkListStructure(showcasePages['ui://pages/lists']!);
        
        // Should have list with items
        expect(hasListWidget, isTrue);
        expect(hasItemsProperty, isTrue);
        
        // Items should be listTile not listItem
        expect(hasListTile, isTrue);
        expect(hasListItem, isFalse);
      });

      test('should use correct grid structure', () {
        bool hasGridWidget = false;
        bool hasColumns = false;
        
        void checkGridStructure(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'grid') {
              hasGridWidget = true;
              if (node['columns'] == 2) hasColumns = true;
            }
            
            node.values.forEach(checkGridStructure);
          } else if (node is List) {
            node.forEach(checkGridStructure);
          }
        }
        
        checkGridStructure(showcasePages['ui://pages/lists']!);
        
        // Should have grid with columns
        expect(hasGridWidget, isTrue);
        expect(hasColumns, isTrue);
      });
    });

    group('Advanced Features Compliance', () {
      test('should use conditional widget correctly', () {
        bool hasConditionalWidget = false;
        bool hasCondition = false;
        bool hasTrueBranch = false;
        bool hasFalseBranch = false;
        
        void checkConditionalStructure(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'conditional') {
              hasConditionalWidget = true;
              if (node.containsKey('condition')) hasCondition = true;
              if (node.containsKey('true')) hasTrueBranch = true;
              if (node.containsKey('false')) hasFalseBranch = true;
            }
            
            node.values.forEach(checkConditionalStructure);
          } else if (node is List) {
            node.forEach(checkConditionalStructure);
          }
        }
        
        checkConditionalStructure(showcasePages['ui://pages/advanced']!);
        
        // Should have conditional with condition, true, false
        expect(hasConditionalWidget, isTrue);
        expect(hasCondition, isTrue);
        expect(hasTrueBranch, isTrue);
        expect(hasFalseBranch, isTrue);
      });

      test('should use batch actions correctly', () {
        // Check all pages for batch actions
        bool hasBatchAction = false;
        bool hasActionsArray = false;
        
        void checkBatchActions(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'batch') {
              hasBatchAction = true;
              if (node.containsKey('actions')) hasActionsArray = true;
            }
            
            node.values.forEach(checkBatchActions);
          } else if (node is List) {
            node.forEach(checkBatchActions);
          }
        }
        
        showcasePages.values.forEach(checkBatchActions);
        
        expect(hasBatchAction, isTrue, reason: 'Should have batch actions');
        expect(hasActionsArray, isTrue, reason: 'Should have actions array');
      });

      test('should use form widgets correctly', () {
        bool hasFormWidget = false;
        bool hasValidation = false;
        bool hasRequiredField = false;
        
        void checkFormStructure(dynamic node) {
          if (node is Map) {
            if (node['type'] == 'form') {
              hasFormWidget = true;
              if (node.containsKey('validation')) hasValidation = true;
            }
            if (node['required'] == true) hasRequiredField = true;
            
            node.values.forEach(checkFormStructure);
          } else if (node is List) {
            node.forEach(checkFormStructure);
          }
        }
        
        checkFormStructure(showcasePages['ui://pages/advanced']!);
        
        // Should have form with validation
        expect(hasFormWidget, isTrue);
        expect(hasValidation, isTrue);
        expect(hasRequiredField, isTrue);
      });
    });

    group('Style Property Compliance', () {
      test('should use numeric values for sizes', () {
        // Font sizes should be numbers not strings
        final homePage = showcasePages['ui://pages/home']!;
        
        void checkNumericSizes(dynamic node) {
          if (node is Map) {
            if (node['style'] != null) {
              final style = node['style'];
              if (style['fontSize'] != null) {
                final fontSize = style['fontSize'];
                // Should be number or binding expression
                expect(fontSize is num || fontSize is String && fontSize.contains('{{'),
                    isTrue,
                    reason: 'fontSize should be numeric or binding expression, got: $fontSize');
              }
            }
            node.values.forEach(checkNumericSizes);
          } else if (node is List) {
            node.forEach(checkNumericSizes);
          }
        }
        
        checkNumericSizes(homePage);
      });

      test('should use correct color format', () {
        // Colors should be hex strings
        void checkColors(dynamic node) {
          if (node is Map<String, dynamic>) {
            if (node['style'] != null && node['style'] is Map) {
              final style = node['style'] as Map<String, dynamic>;
              if (style['color'] != null) {
                final color = style['color'];
                if (color is String && !color.contains('{{')) {
                  expect(color, matches(RegExp(r'^#[A-Fa-f0-9]{6,8}$')),
                      reason: 'Color should be 6 or 8 digit hex, got: $color');
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