// `link`, `radio`, `drawer`, `floatingActionButton`, `dragTarget` and the
// `table` column widths.
//
// Small widgets, and all six carry the same kind of gap: the branch that fires
// when the user actually uses them. A link that navigates nowhere, a radio
// that will not select, a drawer item that reports nothing — each renders
// perfectly and does nothing.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> record(String binding, String field) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': '{{event.$field}}',
      };

  group('link', () {
    testWidgets('shows its label, and an external one is marked', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Open the docs',
        'url': 'https://example.com',
      });

      expect(find.text('Open the docs'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget,
          reason: '§2.8.13 — the cue is what a user needs before leaving the '
              'app, and the composed inkWell+text version cannot have it');
    });

    testWidgets('a route link pushes rather than opening a browser',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Jobs',
        'route': '/jobs',
        'onClick': record('clicked', 'value'),
      });

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('clicked'), '/jobs',
          reason: 'onClick runs beside the navigation, so a document can log '
              'the click without replacing the destination');
    });

    testWidgets('a url link reports the url it opened', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Docs',
        'url': 'https://example.com',
        'onClick': record('clicked', 'value'),
      });

      await tester.tap(find.text('Docs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('clicked'), 'https://example.com');
    });

    testWidgets('a link with neither destination still runs its onClick',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Nowhere',
        'onClick': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'clicked',
          'value': true,
        },
      });

      await tester.tap(find.text('Nowhere'));
      await tester.pumpAndSettle();

      expect(stateManager.get('clicked'), isTrue);
    });

    testWidgets('a child replaces the label', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'ignored',
        'route': '/jobs',
        'child': <String, dynamic>{'type': 'text', 'content': 'Custom'},
      });

      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });

    testWidgets('an icon is drawn beside the label', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Settings',
        'route': '/settings',
        'icon': 'settings',
      });

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('hovering changes the underline', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Hover me',
        'route': '/jobs',
        'underline': 'hover',
      });

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Hover me')));
      await tester.pumpAndSettle();

      expect(
          tester.widget<Text>(find.text('Hover me')).style?.decoration,
          TextDecoration.underline,
          reason: 'the hover affordance is the other half of what makes a '
              'link read as a link');
    });
  });

  group('radio', () {
    testWidgets('selecting writes the binding even with no onChange declared',
        (tester) async {
      stateManager.set('choice', 'a');
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'radio',
            'value': 'a',
            'groupValue': '{{choice}}',
            'binding': 'choice',
            'label': 'First',
          },
          <String, dynamic>{
            'type': 'radio',
            'value': 'b',
            'groupValue': '{{choice}}',
            'binding': 'choice',
            'label': 'Second',
          },
        ],
      });

      await tester.tap(find.byType(Radio<dynamic>).last);
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'b',
          reason: 'a radio declared with nothing but a binding is the '
              'shortest correct form; requiring onChange makes it inert');
    });

    testWidgets('tapping the label selects it too', (tester) async {
      stateManager.set('choice', 'a');
      await pump(tester, <String, dynamic>{
        'type': 'radio',
        'value': 'b',
        'groupValue': '{{choice}}',
        'binding': 'choice',
        'label': 'Second',
      });

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'b',
          reason: 'the label is part of the control; a label that does '
              'nothing makes the hit area a fraction of what it looks like');
    });

    testWidgets('onChange is told the value', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'radio',
        'value': 'b',
        'groupValue': 'a',
        'onChange': record('picked', 'value'),
      });

      await tester.tap(find.byType(Radio<dynamic>));
      await tester.pumpAndSettle();

      expect(stateManager.get('picked'), 'b');
    });

    testWidgets('the declared colours are applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'radio',
        'value': 'a',
        'groupValue': 'a',
        'activeColor': '#FF0000',
        'fillColor': '#00FF00',
        'focusColor': '#0000FF',
        'hoverColor': '#FFFF00',
        'splashRadius': 24,
      });

      final radio = tester.widget<Radio<dynamic>>(find.byType(Radio<dynamic>));
      expect(radio.activeColor, const Color(0xFFFF0000));
      expect(radio.fillColor!.resolve(<WidgetState>{}),
          const Color(0xFF00FF00));
      expect(radio.focusColor, const Color(0xFF0000FF));
      expect(radio.hoverColor, const Color(0xFFFFFF00));
      expect(radio.splashRadius, 24);
    });

    testWidgets('tapping the label of the already-selected one changes nothing',
        (tester) async {
      stateManager.set('choice', 'a');
      await pump(tester, <String, dynamic>{
        'type': 'radio',
        'value': 'a',
        'groupValue': '{{choice}}',
        'binding': 'choice',
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'increment',
          'binding': 'changes',
        },
        'label': 'First',
      });

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();

      expect(stateManager.get('changes'), isNull,
          reason: 're-selecting the current value is not a change; firing '
              'here would re-run whatever the document does on change');
    });
  });

  group('drawer', () {
    testWidgets('builds a list from `items`, with a header', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'header': <String, dynamic>{'type': 'text', 'content': 'Account'},
        'items': <dynamic>[
          <String, dynamic>{'icon': 'home', 'label': 'Home', 'route': '/'},
          <String, dynamic>{'title': 'Jobs', 'route': '/jobs'},
          'not an item',
        ],
        'onSelect': record('chosen', 'value'),
      });

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget,
          reason: '§17.3.2 — `title` is the legacy spelling of `label`');
      expect(find.byIcon(Icons.home), findsOneWidget);

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(stateManager.get('chosen'), '/jobs');
    });

    testWidgets('an item may name its own value', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'items': <dynamic>[
          <String, dynamic>{'label': 'Home', 'value': 'home-id'},
        ],
        'onSelect': record('chosen', 'value'),
      });

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'home-id');
    });

    testWidgets('with no handler the items are inert but still drawn',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'items': <dynamic>[
          <String, dynamic>{'label': 'Home'},
        ],
      });

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a child is used when no items are declared', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'child': <String, dynamic>{'type': 'text', 'content': 'Custom body'},
      });

      expect(find.text('Custom body'), findsOneWidget);
    });

    testWidgets('a rounded shape is built, including the right-only form',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'drawer',
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
        'shape': <String, dynamic>{
          'type': 'rounded',
          'radius': 16,
          'onlyRight': true,
        },
      });

      final shape =
          tester.widget<Drawer>(find.byType(Drawer)).shape! as RoundedRectangleBorder;
      expect(shape.borderRadius,
          const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          reason: 'a drawer slides in from one edge; rounding the hidden side '
              'is a corner nobody sees');
    });
  });

  group('floatingActionButton', () {
    testWidgets('a press and a long press each report', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'floatingActionButton',
        'child': <String, dynamic>{'type': 'icon', 'icon': 'add'},
        'onPressed': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'pressed',
          'value': true,
        },
        'onLongPress': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'held',
          'value': true,
        },
      });

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('pressed'), isTrue);

      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('held'), isTrue);
    });

    testWidgets('a children list stands in for a child', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'floatingActionButton',
        'children': <dynamic>[
          <String, dynamic>{'type': 'icon', 'icon': 'add'},
        ],
      });

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('each declared shape is built', (tester) async {
      for (final entry in <String, Type>{
        'circle': CircleBorder,
        'rounded': RoundedRectangleBorder,
        'stadium': StadiumBorder,
      }.entries) {
        await pump(tester, <String, dynamic>{
          'type': 'floatingActionButton',
          'child': <String, dynamic>{'type': 'icon', 'icon': 'add'},
          'shape': <String, dynamic>{'type': entry.key, 'radius': 12},
        });

        expect(
            tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .shape
                .runtimeType,
            entry.value,
            reason: entry.key);
      }
    });
  });

  group('dragTarget', () {
    Map<String, dynamic> target({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'dragTarget',
          'builder': <String, dynamic>{
            'type': 'container',
            'width': 120,
            'height': 120,
            'color': '#EEEEEE',
          },
          ...extra,
        };

    testWidgets('a target with nothing to build is refused by name',
        (tester) async {
      expect(
          () => context.renderer.renderWidgetRethrowingErrors(
              <String, dynamic>{'type': 'dragTarget'}, context),
          throwsA(isA<Exception>()),
          reason: 'a drop zone that draws nothing accepts drops the user '
              'cannot see the destination of');
    });

    testWidgets('a children list is wrapped rather than rejected',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dragTarget',
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'first'},
          <String, dynamic>{'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget,
          reason: 'the registry documents `children`; a factory that rejects '
              'it makes the documentation wrong');
    });

    testWidgets('a drag over the target reports entering and leaving',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'draggable',
            'data': 'card-1',
            'child': <String, dynamic>{
              'type': 'container',
              'width': 60,
              'height': 60,
              'color': '#FF0000',
            },
          },
          target(extra: <String, dynamic>{
            'onDragEnter': record('entered', 'data'),
            'onDragLeave': record('left', 'data'),
            'onDrop': record('dropped', 'data'),
          }),
        ],
      });

      final from = tester.getCenter(find.byType(Container).first);
      final to = tester.getCenter(find.byType(Container).last);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(to);
      await tester.pump();

      expect(stateManager.get('entered'), 'card-1');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('dropped'), 'card-1');
    });

    testWidgets('canDrop refuses the drop it was written to refuse',
        (tester) async {
      stateManager.set('allowed', false);
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'draggable',
            'data': 'card-1',
            'child': <String, dynamic>{
              'type': 'container',
              'width': 60,
              'height': 60,
              'color': '#FF0000',
            },
          },
          target(extra: <String, dynamic>{
            'canDrop': '{{allowed}}',
            'onDrop': record('dropped', 'data'),
          }),
        ],
      });

      final from = tester.getCenter(find.byType(Container).first);
      final to = tester.getCenter(find.byType(Container).last);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('dropped'), isNull,
          reason: 'the check is what the document wrote to keep a card out of '
              'this column; accepting anyway is the check not existing');
    });
  });

  group('table column widths', () {
    testWidgets('a bare number is a fixed width', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'table',
        'columnWidths': <String, dynamic>{'0': 80},
        'rows': <dynamic>[
          <String, dynamic>{
            'cells': <dynamic>['a', 'b'],
          },
        ],
      });

      final table = tester.widget<Table>(find.byType(Table));
      expect(table.columnWidths![0], isA<FixedColumnWidth>());
    });

    testWidgets('each declared width kind is built', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'table',
        'columnWidths': <String, dynamic>{
          '0': <String, dynamic>{'type': 'fixed', 'value': 90},
          '1': <String, dynamic>{'type': 'flex', 'value': 2},
          '2': <String, dynamic>{'type': 'fraction', 'value': 0.25},
          '3': <String, dynamic>{'type': 'intrinsic'},
        },
        'rows': <dynamic>[
          <String, dynamic>{
            'cells': <dynamic>['a', 'b', 'c', 'd'],
          },
        ],
      });

      final widths =
          tester.widget<Table>(find.byType(Table)).columnWidths!;
      expect(widths[0], isA<FixedColumnWidth>());
      expect(widths[1], isA<FlexColumnWidth>());
      expect(widths[2], isA<FractionColumnWidth>());
      expect(widths[3], isA<IntrinsicColumnWidth>());
    });

    testWidgets('cells that are plain values are drawn as text',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'table',
        'rows': <dynamic>[
          <String, dynamic>{
            'cells': <dynamic>['Ada', 36],
          },
        ],
      });

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('36'), findsOneWidget,
          reason: 'a number cell that renders nothing leaves a hole where the '
              'document put data');
    });
  });
}
