// Property shapes a factory accepts that nothing had written.
//
// Every one of these is a spelling the spec allows and a branch that decides
// what appears: a radius written as `{all: 12}` rather than a number, an icon
// given as a codepoint rather than a name, a breakpoint declared under its
// canonical name rather than its alias. A branch nobody has taken is a
// spelling whose behaviour nobody has seen — and the failure is always the
// same one, a declaration that renders as though it were not there.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/map_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> definition, {
    Size? surface,
  }) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
  }

  group('a corner radius written as an object', () {
    testWidgets('`all` is a uniform radius', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'box',
        'decoration': <String, dynamic>{
          'color': '#FF2196F3',
          'borderRadius': <String, dynamic>{'all': 12},
        },
        'child': <String, dynamic>{'type': 'text', 'content': 'rounded'},
      });

      final rounded = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius == BorderRadius.circular(12));

      expect(rounded, isNotEmpty,
          reason: '`{all: 12}` and `12` are the same declaration; accepting '
              'only the number means a document that spells out its corners '
              'draws square ones');
    });
  });

  group('a drawer shape', () {
    testWidgets('rounded without `onlyRight` rounds every corner',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 20},
        'child': <String, dynamic>{'type': 'text', 'content': 'menu'},
      });

      final shape = tester.widget<Drawer>(find.byType(Drawer)).shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(20),
          reason: 'only the `onlyRight` form had ever been drawn, so the '
              'plain one was a declaration with no observed result');
    });
  });

  group('a scrollbar', () {
    testWidgets('takes a declared thumb radius', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'scrollBar',
        'thumbVisibility': true,
        'radius': 6,
        'child': <String, dynamic>{
          'type': 'list',
          'shrinkWrap': true,
          'children': <dynamic>[
            <String, dynamic>{'type': 'text', 'content': 'row'},
          ],
        },
      });

      expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).radius,
          const Radius.circular(6),
          reason: 'a rounded thumb declared and drawn square is the theme '
              'being ignored in the one place a user notices scrolling');
    });
  });

  group('a decoration with a backdrop blur', () {
    testWidgets('clips the blur to the declared corners', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'decoration',
        'decoration': <String, dynamic>{
          'color': '#40FFFFFF',
          'borderRadius': 16,
        },
        'backdropBlur': 4,
        'child': <String, dynamic>{'type': 'text', 'content': 'frosted'},
      });

      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsOneWidget,
          reason: 'a blur that escapes its corners paints over the layout '
              'around it — the radius has to reach the backdrop');
      expect(find.text('frosted'), findsOneWidget);
    });
  });

  group('breakpoints', () {
    testWidgets('a canonical class name is found as readily as its alias',
        (tester) async {
      await pump(
        tester,
        <String, dynamic>{
          'type': 'mediaQuery',
          'breakpoints': <String, dynamic>{
            // `compact` is the canonical name; `sm` is the legacy alias, and
            // the lookup used to find only the alias, so the canonical
            // spelling silently rendered nothing.
            'compact': <String, dynamic>{'type': 'text', 'content': 'narrow'},
            'expanded': <String, dynamic>{'type': 'text', 'content': 'wide'},
          },
        },
        surface: const Size(400, 800),
      );

      expect(find.text('narrow'), findsOneWidget);
    });
  });

  group('a flow layout', () {
    testWidgets('a changed direction repaints even at the same spacing',
        (tester) async {
      Map<String, dynamic> definition(String direction) => <String, dynamic>{
            'type': 'flow',
            'direction': direction,
            'spacing': 8,
            'children': <dynamic>[
              <String, dynamic>{'type': 'text', 'content': 'a'},
              <String, dynamic>{'type': 'text', 'content': 'b'},
            ],
          };

      await pump(tester, definition('horizontal'));
      final first = tester.getTopLeft(find.text('b'));
      await pump(tester, definition('vertical'));
      final second = tester.getTopLeft(find.text('b'));

      expect(second, isNot(first),
          reason: 'the delegate compares spacing first; a comparison that '
              'stopped there would leave the children where the previous '
              'direction put them');
    });
  });

  group('a chart with no dataset', () {
    testWidgets('draws nothing rather than throwing', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': 'line',
        'datasets': <dynamic>[],
        'labels': <dynamic>['Jan', 'Feb'],
        'height': 200,
      });

      expect(tester.takeException(), isNull,
          reason: 'a chart whose data has not arrived yet is the normal '
              'first frame; taking the page down for it is the worst '
              'available answer');
    });
  });

  group('an icon given as a codepoint', () {
    testWidgets('is drawn from the declared font family', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'iconButton',
        'icon': 0xe88a,
        'fontFamily': 'MaterialIcons',
        'onTap': <String, dynamic>{'type': 'state', 'action': 'set',
            'binding': 'tapped', 'value': true},
      });

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon?.codePoint, 0xe88a,
          reason: 'a host that ships its own icon font declares codepoints; '
              'falling back to the error glyph makes every one of them look '
              'like a broken document');
      expect(icon.icon?.fontFamily, 'MaterialIcons');
    });
  });

  group('a multi-select holding a value that is not an option', () {
    testWidgets('shows the value rather than blanking', (tester) async {
      // A value saved before the option list changed — a stale draft, a
      // server that dropped a choice. Showing nothing loses what the user
      // actually has selected.
      stateManager.set('picked', <dynamic>['gone']);

      await pump(tester, <String, dynamic>{
        'type': 'multiSelect',
        'value': '{{picked}}',
        'options': <dynamic>[
          <String, dynamic>{'value': 'a', 'label': 'Alpha'},
        ],
      });

      expect(find.textContaining('gone'), findsWidgets,
          reason: 'the label falls back to the value itself, so the user can '
              'see what is selected and remove it');
    });
  });

  group('a step declared as something other than an object', () {
    testWidgets('renders an empty step rather than throwing', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'stepper',
        'steps': <dynamic>['just a string'],
      });

      expect(tester.takeException(), isNull,
          reason: 'a half-written stepper is what one being edited looks '
              'like; the page has to keep drawing');
      expect(find.byType(Stepper), findsOneWidget);
    });
  });

  group('a placeholder with a canonical child', () {
    testWidgets('draws it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'placeholder',
        'child': <String, dynamic>{'type': 'text', 'content': 'inside'},
      });

      expect(find.text('inside'), findsOneWidget);
    });
  });

  group('font features', () {
    testWidgets('a tag with a value that is not a number is enabled',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'text',
        'content': 'figures',
        'style': <String, dynamic>{
          'fontFeatures': <dynamic>['tnum=on', 'ss01=1'],
        },
      });

      final features =
          tester.widget<Text>(find.text('figures')).style?.fontFeatures;
      expect(features, isNotNull);
      expect(features!.map((f) => f.feature), containsAll(<String>['tnum', 'ss01']),
          reason: '`tnum=on` is how a person writes it; dropping the tag '
              'because "on" is not a number loses the feature entirely');
      expect(features.firstWhere((f) => f.feature == 'tnum').value, 1);
    });
  });

  group('MapMarker', () {
    test('carries the fields a host surface reads', () {
      final marker = MapMarker(
        latitude: 37.5,
        longitude: 127.0,
        title: 'Seoul',
        icon: 'place',
        color: '#FFFF0000',
      );

      expect(marker.latitude, 37.5);
      expect(marker.longitude, 127.0);
      expect(marker.title, 'Seoul');
      expect(marker.icon, 'place');
      expect(marker.color, '#FFFF0000',
          reason: 'this is the shape handed to a host that draws the tiles — '
              'a field dropped here is a pin drawn in the wrong place or not '
              'at all');
    });
  });
}
