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
      expect(registry.has('column'), isTrue);
      expect(registry.has('row'), isTrue);
      expect(registry.has('stack'), isTrue);
      expect(registry.has('container'), isTrue);
      expect(registry.has('center'), isTrue);
      expect(registry.has('align'), isTrue);
      expect(registry.has('padding'), isTrue);
      expect(registry.has('sizedbox'), isTrue);
      expect(registry.has('expanded'), isTrue);
      expect(registry.has('flexible'), isTrue);
      expect(registry.has('spacer'), isTrue);
      expect(registry.has('wrap'), isTrue);
      expect(registry.has('positioned'), isTrue);
      expect(registry.has('intrinsicheight'), isTrue);
      expect(registry.has('intrinsicwidth'), isTrue);
      expect(registry.has('visibility'), isTrue);
      expect(registry.has('aspectratio'), isTrue);
      expect(registry.has('baseline'), isTrue);
      expect(registry.has('constrainedbox'), isTrue);
      expect(registry.has('fittedbox'), isTrue);
      expect(registry.has('limitedbox'), isTrue);
      expect(registry.has('table'), isTrue);
      expect(registry.has('flow'), isTrue);
      expect(registry.has('margin'), isTrue);

      // Display widgets
      expect(registry.has('text'), isTrue);
      expect(registry.has('richtext'), isTrue);
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
      expect(registry.has('clipoval'), isTrue);
      expect(registry.has('cliprrect'), isTrue);
      expect(registry.has('decoratedbox'), isTrue);
      expect(registry.has('circularprogressindicator'), isTrue);
      expect(registry.has('linearprogressindicator'), isTrue);
      expect(registry.has('progressindicator'), isTrue);
      expect(registry.has('verticaldivider'), isTrue);
      expect(registry.has('decoration'), isTrue);

      // Input widgets
      expect(registry.has('button'), isTrue);
      expect(registry.has('textfield'), isTrue);
      expect(registry.has('textformfield'), isTrue);
      expect(registry.has('checkbox'), isTrue);
      expect(registry.has('radio'), isTrue);
      expect(registry.has('switch'), isTrue);
      expect(registry.has('slider'), isTrue);
      expect(registry.has('rangeslider'), isTrue);
      expect(registry.has('dropdown'), isTrue);
      expect(registry.has('stepper'), isTrue);
      expect(registry.has('datepicker'), isTrue);
      expect(registry.has('timepicker'), isTrue);
      expect(registry.has('iconbutton'), isTrue);
      expect(registry.has('form'), isTrue);

      // List widgets
      expect(registry.has('listview'), isTrue);
      expect(registry.has('gridview'), isTrue);
      expect(registry.has('listtile'), isTrue);

      // Navigation widgets
      expect(registry.has('appbar'), isTrue);
      expect(registry.has('tabbar'), isTrue);
      expect(registry.has('drawer'), isTrue);
      expect(registry.has('bottomnavigationbar'), isTrue);
      expect(registry.has('navigationrail'), isTrue);
      expect(registry.has('floatingactionbutton'), isTrue);
      expect(registry.has('popupmenubutton'), isTrue);
      expect(registry.has('tabbarview'), isTrue);

      // Scroll widgets
      expect(registry.has('singlechildscrollview'), isTrue);
      expect(registry.has('pageview'), isTrue);
      expect(registry.has('scrollbar'), isTrue);

      // Animation widgets
      expect(registry.has('animatedcontainer'), isTrue);

      // Interactive widgets
      expect(registry.has('gesturedetector'), isTrue);
      expect(registry.has('inkwell'), isTrue);

      // Dialog widgets
      expect(registry.has('alertdialog'), isTrue);
      expect(registry.has('snackbar'), isTrue);
      expect(registry.has('bottomsheet'), isTrue);
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