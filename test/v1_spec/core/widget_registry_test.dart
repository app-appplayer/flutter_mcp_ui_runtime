import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/display/text_factory.dart';

/// MCP UI DSL v1.0 Widget Registry Tests
/// 
/// Tests widget registration according to the MCP UI DSL v1.0 specification.
/// Verifies that all widgets defined in the spec are properly registered.
void main() {
  group('MCP UI DSL v1.0 - Widget Registry', () {
    late WidgetRegistry registry;
    
    setUp(() {
      registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
    });
    
    group('Widget Registration (Spec 4.1)', () {
      test('should register all layout widgets per v1.0 spec', () {
        // Layout widgets as defined in MCP UI DSL v1.0
        final layoutWidgets = [
          'linear',     // v1.0: linear layout (not row/column)
          'box',        // v1.0: box container
          'stack',      // v1.0: stack layout
          'grid',       // v1.0: grid layout
          'positioned', // v1.0: positioned within stack
        ];
        
        for (final widgetType in layoutWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register all display widgets per v1.0 spec', () {
        // Display widgets as defined in MCP UI DSL v1.0
        final displayWidgets = [
          'text',     // v1.0: text display
          'image',    // v1.0: image display
          'icon',     // v1.0: icon display
          'divider',  // v1.0: visual divider
        ];
        
        for (final widgetType in displayWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register all input widgets per v1.0 spec', () {
        // Input widgets with v1.0 CamelCase naming
        final inputWidgets = [
          'button',      // v1.0: button widget
          'textInput',   // v1.0: text input (CamelCase)
          'checkbox',    // v1.0: checkbox
          'radioGroup',  // v1.0: radio group (CamelCase)
          'select',      // v1.0: dropdown select
          'slider',      // v1.0: slider input
          'switch',      // v1.0: toggle switch
        ];
        
        for (final widgetType in inputWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register all list widgets per v1.0 spec', () {
        // List-related widgets as defined in MCP UI DSL v1.0
        final listWidgets = [
          'list',         // v1.0: list container
          'listTile',     // v1.0: list tile (CamelCase)
          'listView',     // v1.0: scrollable list (CamelCase)
        ];
        
        for (final widgetType in listWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register all navigation widgets per v1.0 spec', () {
        // Navigation widgets with v1.0 CamelCase naming
        final navigationWidgets = [
          'headerBar',   // v1.0: header bar (CamelCase)
          'bottomNav',   // v1.0: bottom navigation (CamelCase)
          'drawer',      // v1.0: drawer navigation
          'tabBar',      // v1.0: tab bar (CamelCase)
        ];
        
        for (final widgetType in navigationWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register all special widgets per v1.0 spec', () {
        // Special widgets as defined in MCP UI DSL v1.0
        final specialWidgets = [
          'conditional',        // v1.0: conditional rendering
          'form',              // v1.0: form container
          'card',              // v1.0: card container
          'chip',              // v1.0: chip display
          'badge',             // v1.0: badge display
          'loadingIndicator',  // v1.0: loading indicator (CamelCase)
          'progressBar',       // v1.0: progress bar (CamelCase)
        ];
        
        for (final widgetType in specialWidgets) {
          expect(
            registry.has(widgetType),
            isTrue,
            reason: 'Widget "$widgetType" must be registered per v1.0 spec',
          );
        }
      });
      
      test('should register only the kebab-case aliases explicitly listed in §17.3.1', () {
        // Per spec §17.1.2 widget type names are canonical as camelCase.
        // §17.3.1 Widget Type Aliases lists exactly three kebab forms as
        // legitimate legacy aliases; any other kebab spelling is out of spec
        // and MUST NOT be registered.
        final allowedKebab = <String>{
          'list-tile',          // listItem alias
          'progress-bar',       // progressBar alias
          'loading-indicator',  // progressBar alias
        };
        for (final name in allowedKebab) {
          expect(
            registry.has(name),
            isTrue,
            reason: '§17.3.1 declares "$name" as a legacy alias — must be registered',
          );
        }
        // Negative cases: previously-registered kebab forms that are NOT in
        // §17.3.1 must not exist in the runtime registry.
        final forbiddenKebab = <String>[
          'text-input',
          'list-item',
          'header-bar',
          'sized-box',
          'icon-button',
          'rich-text',
          'scroll-view',
          'page-view',
          'alert-dialog',
          'bottom-sheet',
        ];
        for (final name in forbiddenKebab) {
          expect(
            registry.has(name),
            isFalse,
            reason:
                '"$name" is not sanctioned by §17.3.1 and must not be registered',
          );
        }
      });
    });
    
    group('Widget Factory Creation (Spec 4.2)', () {
      test('should get widget factories with correct types', () {
        expect(registry.get('text'), isNotNull);
        expect(registry.get('button'), isNotNull);
        expect(registry.get('linear'), isNotNull);
        expect(registry.get('textInput'), isNotNull);
        expect(registry.get('conditional'), isNotNull);
      });
      
      test('should return null for unregistered widget types', () {
        expect(registry.get('nonexistent'), isNull);
      });
      
      test('should maintain case sensitivity for widget names', () {
        // v1.0 spec uses exact case matching
        expect(registry.has('textInput'), isTrue);
        expect(registry.has('TextInput'), isFalse);
        expect(registry.has('TEXTINPUT'), isFalse);
        expect(registry.has('text_input'), isFalse);
      });
    });
    
    group('Custom Widget Registration (Spec 4.3)', () {
      test('should allow registering custom widgets', () {
        final customFactory = TextWidgetFactory();
        
        registry.register('customWidget', customFactory);
        
        expect(registry.has('customWidget'), isTrue);
        expect(registry.get('customWidget'), equals(customFactory));
      });
      
      test('should allow overriding existing widgets', () {
        final originalFactory = registry.get('text');
        final customFactory = TextWidgetFactory();
        
        registry.register('text', customFactory);
        
        expect(registry.get('text'), equals(customFactory));
        expect(registry.get('text'), isNot(equals(originalFactory)));
      });
      
      test('should support widget aliasing', () {
        // Some implementations might want aliases for compatibility
        final buttonFactory = registry.get('button');
        
        registry.register('btn', buttonFactory!);
        
        expect(registry.has('btn'), isTrue);
        expect(registry.get('btn'), equals(buttonFactory));
        expect(registry.get('btn'), equals(registry.get('button')));
      });
    });
    
    group('Widget Categories (Spec 4.4)', () {
      test('should have all required widget categories', () {
        // Ensure we have at least one widget from each category
        final categories = {
          'layout': ['linear', 'box', 'stack', 'grid'],
          'display': ['text', 'image', 'icon'],
          'input': ['button', 'textInput', 'checkbox'],
          'list': ['list', 'listTile'],
          'navigation': ['headerBar', 'bottomNav'],
          'special': ['conditional', 'form'],
        };
        
        for (final entry in categories.entries) {
          final hasCategory = entry.value.any((widget) => registry.has(widget));
          expect(
            hasCategory,
            isTrue,
            reason: 'Must have at least one widget from ${entry.key} category',
          );
        }
      });
    });
    
    group('Widget Factory Interface (Spec 4.5)', () {
      test('should implement WidgetFactory interface correctly', () {
        final factory = registry.get('text');
        
        // Verify factory implements required interface
        expect(factory, isA<WidgetFactory>());
        
        // Just verify factory exists
        expect(factory, isNotNull);
      });
    });

    group('TC-153: WidgetRegistry — unregister', () {
    test('Normal: unregister removes factory by type', () {
      expect(registry.has('text'), isTrue);
      registry.unregister('text');
      expect(registry.has('text'), isFalse);
      expect(registry.get('text'), isNull);
    });

    test('Boundary: unregister non-existent type → no error', () {
      registry.unregister('nonexistent_widget_type_xyz');
      // Should not throw
    });
  });

  group('TC-154: WidgetRegistry — clear', () {
    test('Normal: clear removes all registrations', () {
      expect(registry.registeredTypes, isNotEmpty);
      registry.clear();
      expect(registry.registeredTypes, isEmpty);
    });

    test('Normal: re-register after clear works', () {
      registry.clear();
      expect(registry.has('text'), isFalse);
      DefaultWidgets.registerAll(registry);
      expect(registry.has('text'), isTrue);
    });
  });

  group('TC-155: WidgetRegistry — registeredTypes getter', () {
    test('Normal: returns sorted list of all registered types', () {
      final types = registry.registeredTypes;
      expect(types, isNotEmpty);
      expect(types, contains('text'));
      expect(types, contains('button'));
      expect(types, contains('linear'));

      // Verify sorted order
      final sorted = List<String>.from(types)..sort();
      expect(types, equals(sorted));
    });

    test('Boundary: empty registry → empty list', () {
      registry.clear();
      expect(registry.registeredTypes, isEmpty);
    });
  });

  group('TC-156: WidgetRegistry — getTypesByCategory', () {
    test('Normal: returns types for layout category', () {
      final layoutTypes = registry.getTypesByCategory('layout');
      expect(layoutTypes, isNotEmpty);
      expect(layoutTypes, contains('linear'));
    });

    test('Normal: returns types for display category', () {
      final displayTypes = registry.getTypesByCategory('display');
      expect(displayTypes, isNotEmpty);
      expect(displayTypes, contains('text'));
    });

    test('Normal: returns types for input category', () {
      final inputTypes = registry.getTypesByCategory('input');
      expect(inputTypes, isNotEmpty);
      expect(inputTypes, contains('button'));
    });

    test('Boundary: unknown category → empty list', () {
      final result = registry.getTypesByCategory('nonexistent_category');
      expect(result, isEmpty);
    });
  });
  });
}