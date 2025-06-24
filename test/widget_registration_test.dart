import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

void main() {
  group('Widget Registration Tests', () {
    late WidgetRegistry registry;

    setUp(() {
      registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
    });

    test('All MCP UI DSL v1.0 widgets are registered', () {
      // Layout widgets
      expect(registry.has('linear'), isTrue);
      expect(registry.has('stack'), isTrue);
      expect(registry.has('box'), isTrue);
      expect(registry.has('center'), isTrue);
      expect(registry.has('align'), isTrue);
      expect(registry.has('padding'), isTrue);
      expect(registry.has('sizedBox'), isTrue);
      expect(registry.has('expanded'), isTrue);
      expect(registry.has('flexible'), isTrue);
      expect(registry.has('spacer'), isTrue);
      expect(registry.has('wrap'), isTrue);
      expect(registry.has('positioned'), isTrue);
      expect(registry.has('intrinsicHeight'), isTrue);
      expect(registry.has('intrinsicWidth'), isTrue);
      expect(registry.has('visibility'), isTrue);
      expect(registry.has('aspectRatio'), isTrue);
      expect(registry.has('baseline'), isTrue);
      expect(registry.has('constrainedBox'), isTrue);
      expect(registry.has('fittedBox'), isTrue);
      expect(registry.has('limitedBox'), isTrue);
      expect(registry.has('table'), isTrue);
      expect(registry.has('flow'), isTrue);
      expect(registry.has('margin'), isTrue);

      // Display widgets
      expect(registry.has('text'), isTrue);
      expect(registry.has('richText'), isTrue);
      expect(registry.has('image'), isTrue);
      expect(registry.has('icon'), isTrue);
      expect(registry.has('card'), isTrue);
      expect(registry.has('divider'), isTrue);
      expect(registry.has('badge'), isTrue);
      expect(registry.has('chip'), isTrue);
      expect(registry.has('avatar'), isTrue);
      expect(registry.has('tooltip'), isTrue);
      expect(registry.has('placeholder'), isTrue);
      expect(registry.has('banner'), isTrue);
      expect(registry.has('clipOval'), isTrue);
      expect(registry.has('clipRRect'), isTrue);
      expect(registry.has('decoratedBox'), isTrue);
      expect(registry.has('loadingIndicator'), isTrue);
      expect(registry.has('verticalDivider'), isTrue);
      expect(registry.has('decoration'), isTrue);

      // Input widgets
      expect(registry.has('button'), isTrue);
      expect(registry.has('textInput'), isTrue);
      expect(registry.has('textFormField'), isTrue);
      expect(registry.has('checkbox'), isTrue);
      expect(registry.has('radio'), isTrue);
      expect(registry.has('toggle'), isTrue);
      expect(registry.has('slider'), isTrue);
      expect(registry.has('rangeSlider'), isTrue);
      expect(registry.has('select'), isTrue);
      expect(registry.has('dateField'), isTrue);
      expect(registry.has('timeField'), isTrue);
      expect(registry.has('numberField'), isTrue);
      expect(registry.has('colorPicker'), isTrue);
      expect(registry.has('radioGroup'), isTrue);
      expect(registry.has('checkboxGroup'), isTrue);
      expect(registry.has('segmentedControl'), isTrue);
      expect(registry.has('dateRangePicker'), isTrue);
      expect(registry.has('iconButton'), isTrue);
      expect(registry.has('form'), isTrue);

      // List widgets
      expect(registry.has('list'), isTrue);
      expect(registry.has('grid'), isTrue);
      expect(registry.has('listTile'), isTrue);

      // Navigation widgets
      expect(registry.has('headerBar'), isTrue);
      expect(registry.has('tabBar'), isTrue);
      expect(registry.has('drawer'), isTrue);
      expect(registry.has('bottomNavigation'), isTrue);
      expect(registry.has('navigationRail'), isTrue);
      expect(registry.has('floatingActionButton'), isTrue);
      expect(registry.has('popupMenuButton'), isTrue);
      expect(registry.has('tabBarView'), isTrue);

      // Scroll widgets
      expect(registry.has('singleChildScrollView'), isTrue);
      expect(registry.has('scrollView'), isTrue);
      expect(registry.has('scrollBar'), isTrue);

      // Animation widgets
      expect(registry.has('animatedContainer'), isTrue);

      // Interactive widgets
      expect(registry.has('gestureDetector'), isTrue);
      expect(registry.has('inkWell'), isTrue);
      expect(registry.has('draggable'), isTrue);
      expect(registry.has('dragTarget'), isTrue);

      // Dialog widgets
      expect(registry.has('alertDialog'), isTrue);
      expect(registry.has('snackBar'), isTrue);
      expect(registry.has('bottomSheet'), isTrue);
      
      // Control flow widgets
      expect(registry.has('conditional'), isTrue);
      
      // Media widgets
      expect(registry.has('mediaPlayer'), isTrue);
    });

    test('Widget registry reports correct count', () {
      final stats = registry.getRegistrationStatus();
      expect(registry.registeredTypes.length, greaterThanOrEqualTo(75));
      print('Total registered widgets: ${registry.registeredTypes.length}');
      print('Registration status: $stats');
    });

    test('All widget categories have registrations', () {
      expect(registry.getTypesByCategory('layout').length, greaterThan(0));
      expect(registry.getTypesByCategory('display').length, greaterThan(0));
      expect(registry.getTypesByCategory('input').length, greaterThan(0));
      expect(registry.getTypesByCategory('list').length, greaterThan(0));
      expect(registry.getTypesByCategory('navigation').length, greaterThan(0));
      expect(registry.getTypesByCategory('scroll').length, greaterThan(0));
      expect(registry.getTypesByCategory('animation').length, greaterThan(0));
      expect(registry.getTypesByCategory('interactive').length, greaterThan(0));
      expect(registry.getTypesByCategory('dialog').length, greaterThan(0));
    });
  });
}