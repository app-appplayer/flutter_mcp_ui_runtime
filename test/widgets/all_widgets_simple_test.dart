import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

void main() {
  group('Simple Widget Factory Tests', () {
    late WidgetRegistry registry;

    setUp(() {
      registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
    });

    test('All Layout widgets are registered and instantiable', () {
      final layoutWidgets = [
        'column', 'row', 'stack', 'container', 'center', 'align', 
        'padding', 'sizedbox', 'expanded', 'flexible', 'spacer', 
        'wrap', 'positioned', 'intrinsicheight', 'intrinsicwidth', 
        'visibility', 'aspectratio', 'baseline', 'constrainedbox', 
        'fittedbox', 'limitedbox', 'table', 'flow', 'margin'
      ];

      for (final widgetType in layoutWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Layout widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Layout widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Layout widget $widgetType should have proper factory type');
      }
    });

    test('All Display widgets are registered and instantiable', () {
      final displayWidgets = [
        'text', 'richtext', 'image', 'icon', 'card', 'divider', 
        'badge', 'chip', 'avatar', 'tooltip', 'placeholder', 
        'banner', 'clipoval', 'cliprrect', 'decoratedbox', 
        'circularprogressindicator', 'linearprogressindicator', 
        'progressindicator', 'verticaldivider', 'decoration'
      ];

      for (final widgetType in displayWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Display widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Display widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Display widget $widgetType should have proper factory type');
      }
    });

    test('All Input widgets are registered and instantiable', () {
      final inputWidgets = [
        'button', 'textfield', 'textformfield', 'checkbox', 'radio', 
        'switch', 'slider', 'rangeslider', 'dropdown', 'stepper', 
        'datepicker', 'timepicker', 'iconbutton', 'form'
      ];

      for (final widgetType in inputWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Input widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Input widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Input widget $widgetType should have proper factory type');
      }
    });

    test('All List widgets are registered and instantiable', () {
      final listWidgets = ['listview', 'gridview', 'listtile'];

      for (final widgetType in listWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'List widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'List widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'List widget $widgetType should have proper factory type');
      }
    });

    test('All Navigation widgets are registered and instantiable', () {
      final navigationWidgets = [
        'appbar', 'tabbar', 'drawer', 'bottomnavigationbar', 
        'navigationrail', 'floatingactionbutton', 'popupmenubutton', 'tabbarview'
      ];

      for (final widgetType in navigationWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Navigation widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Navigation widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Navigation widget $widgetType should have proper factory type');
      }
    });

    test('All Scroll widgets are registered and instantiable', () {
      final scrollWidgets = ['singlechildscrollview', 'pageview', 'scrollbar'];

      for (final widgetType in scrollWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Scroll widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Scroll widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Scroll widget $widgetType should have proper factory type');
      }
    });

    test('All Animation widgets are registered and instantiable', () {
      final animationWidgets = ['animatedcontainer'];

      for (final widgetType in animationWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Animation widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Animation widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Animation widget $widgetType should have proper factory type');
      }
    });

    test('All Interactive widgets are registered and instantiable', () {
      final interactiveWidgets = ['gesturedetector', 'inkwell'];

      for (final widgetType in interactiveWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Interactive widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Interactive widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Interactive widget $widgetType should have proper factory type');
      }
    });

    test('All Dialog widgets are registered and instantiable', () {
      final dialogWidgets = ['alertdialog', 'snackbar', 'bottomsheet'];

      for (final widgetType in dialogWidgets) {
        expect(registry.has(widgetType), isTrue, reason: 'Dialog widget $widgetType should be registered');
        
        final factory = registry.get(widgetType);
        expect(factory, isNotNull, reason: 'Dialog widget $widgetType factory should exist');
        expect(factory.runtimeType.toString(), contains('WidgetFactory'), 
               reason: 'Dialog widget $widgetType should have proper factory type');
      }
    });

    test('Widget registry statistics are accurate', () {
      final stats = registry.getRegistrationStatus();
      final totalRegistered = registry.registeredTypes.length;
      
      expect(totalRegistered, greaterThanOrEqualTo(75), 
             reason: 'Should have at least 75 widgets registered');
      
      expect(stats['totalMissing'], equals(0), 
             reason: 'Should have no missing widgets from expected set');
      
      expect(stats['percentage'], greaterThanOrEqualTo(100), 
             reason: 'Should have 100% or more coverage of expected widgets');
      
      print('Total widgets registered: $totalRegistered');
      print('Coverage percentage: ${stats['percentage']}%');
      
      final byCategory = stats['byCategory'] as Map<String, dynamic>;
      for (final category in byCategory.keys) {
        final categoryStats = byCategory[category] as Map<String, dynamic>;
        print('Category $category: ${categoryStats['registered']}/${categoryStats['expected']} widgets (${categoryStats['percentage']}%)');
        
        expect(categoryStats['missing'], isEmpty, 
               reason: 'Category $category should have no missing widgets');
      }
    });

    test('All expected widget types can be retrieved', () {
      final allRegisteredTypes = registry.registeredTypes;
      
      for (final type in allRegisteredTypes) {
        final factory = registry.get(type);
        expect(factory, isNotNull, reason: 'Widget type $type should have retrievable factory');
      }
    });

    test('Widget categories are properly tracked', () {
      final categories = registry.categories;
      final expectedCategories = [
        'layout', 'display', 'input', 'list', 'navigation', 
        'scroll', 'animation', 'interactive', 'dialog'
      ];
      
      for (final expectedCategory in expectedCategories) {
        expect(categories, contains(expectedCategory), 
               reason: 'Should contain category $expectedCategory');
        
        final categoryTypes = registry.getTypesByCategory(expectedCategory);
        expect(categoryTypes, isNotEmpty, 
               reason: 'Category $expectedCategory should have registered widgets');
      }
    });
  });
}