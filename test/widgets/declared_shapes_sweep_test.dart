// A sweep over the property shapes a document may write that nothing in this
// suite had written yet.
//
// Each of these is a branch a factory takes for a shape the spec allows: the
// legacy `children[0]` where `child` is canonical, a value bound to a double
// where the code reads an int, a list handed in directly instead of through a
// binding, a widget declared with nothing inside it. None of them are exotic —
// they are what a document written by hand, or generated, or half-edited,
// arrives as. A branch that has never run is a shape whose behaviour nobody
// has seen.

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
    await tester.pump();
  }

  group('the legacy children[0] where child is canonical', () {
    testWidgets('placeholder takes it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'placeholder',
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'inside'},
        ],
      });

      expect(find.text('inside'), findsOneWidget,
          reason: 'a document written before `child` was canonical still has '
              'to draw its content rather than an empty box');
    });

    testWidgets('flexible takes it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'flexible',
            'children': <dynamic>[
              <String, dynamic>{'type': 'text', 'content': 'flexed'},
            ],
          },
        ],
      });

      expect(find.text('flexed'), findsOneWidget);
    });

    testWidgets('expanded takes it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'expanded',
            'children': <dynamic>[
              <String, dynamic>{'type': 'text', 'content': 'expanded child'},
            ],
          },
        ],
      });

      expect(find.text('expanded child'), findsOneWidget);
    });

    testWidgets('margin takes it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'margin',
        'margin': 8,
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'spaced'},
        ],
      });

      expect(find.text('spaced'), findsOneWidget);
    });
  });

  group('a wrapper declared with nothing inside it', () {
    testWidgets('flexible draws an empty box rather than throwing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{'type': 'flexible'},
          <String, dynamic>{'type': 'text', 'content': 'sibling'},
        ],
      });

      expect(tester.takeException(), isNull,
          reason: 'a half-written document is the normal state of one being '
              'edited; taking the page down for it hides everything else the '
              'author is looking at');
      expect(find.text('sibling'), findsOneWidget);
    });

    testWidgets('expanded does the same', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{'type': 'expanded'},
          <String, dynamic>{'type': 'text', 'content': 'sibling'},
        ],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('sibling'), findsOneWidget);
    });

    testWidgets('margin does the same', (tester) async {
      await pump(tester, <String, dynamic>{'type': 'margin', 'margin': 4});

      expect(tester.takeException(), isNull);
    });
  });

  group('numbers that arrive as doubles', () {
    testWidgets('indexedStack takes a bound double as its index',
        (tester) async {
      // A binding that came from arithmetic — `{{page * 1}}` — is a double,
      // and an index read as an int only would silently show page one.
      stateManager.set('page', 1.0);

      await pump(tester, <String, dynamic>{
        'type': 'indexedStack',
        'index': '{{page}}',
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'first'},
          <String, dynamic>{'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('second'), findsOneWidget,
          reason: 'the declared index was 1; showing the first child means '
              'the double branch dropped the value');
    });
  });

  group('a list handed in directly rather than through a binding', () {
    testWidgets('grid builds from `items` given inline', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'grid',
        'items': <dynamic>[
          <String, dynamic>{'label': 'one'},
          <String, dynamic>{'label': 'two'},
        ],
        'itemTemplate': <String, dynamic>{
          'type': 'text',
          'content': '{{item.label}}',
        },
        'crossAxisCount': 2,
      });

      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget,
          reason: 'a small grid is often written inline; requiring a binding '
              'for it would make the simplest case the one that fails');
    });
  });

  group('painters redraw when what they draw changes', () {
    /// The painters of a widget currently on screen.
    List<Object?> painters(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .toList();

    Future<void> expectRepaint(
      WidgetTester tester,
      Map<String, dynamic> Function(dynamic value) definition,
      dynamic before,
      dynamic after,
    ) async {
      await pump(tester, definition(before));
      final first = painters(tester);
      await pump(tester, definition(after));
      final second = painters(tester);

      expect(second.any((p) => !first.any((q) => identical(p, q))), isTrue,
          reason: 'a painter that compares equal to its predecessor is a '
              'picture that never changes while its data does');
    }

    testWidgets('gauge follows its colours', (tester) async {
      await expectRepaint(
        tester,
        (v) => <String, dynamic>{
          'type': 'gauge',
          'value': 0.4,
          'valueColor': v,
        },
        '#FF0000FF',
        '#FF00FF00',
      );
    });

    testWidgets('barcode follows its colours', (tester) async {
      await expectRepaint(
        tester,
        (v) => <String, dynamic>{
          'type': 'barcode',
          'value': '12345670',
          'format': 'ean8',
          'foregroundColor': v,
          'backgroundColor': '#FFFFFFFF',
        },
        '#FF000000',
        '#FF202020',
      );
    });
  });

  group('terminal', () {
    testWidgets('more lines than maxLines keeps the newest', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'maxLines': 2,
        'lines': <dynamic>['one', 'two', 'three', 'four'],
        'height': 200,
      });

      expect(find.textContaining('four'), findsWidgets,
          reason: 'a console keeps the end of the output — the newest lines '
              'are the ones being read');
      expect(find.textContaining('one'), findsNothing,
          reason: 'and the oldest are dropped, or `maxLines` is advisory');
    });

    testWidgets('the cap holds as new lines arrive too', (tester) async {
      stateManager.set('log', <dynamic>['one', 'two']);
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'maxLines': 2,
        'lines': '{{log}}',
        'height': 200,
      });
      expect(find.textContaining('one'), findsWidgets);

      stateManager.set('log', <dynamic>['one', 'two', 'three', 'four']);
      await tester.pumpAndSettle();

      expect(find.textContaining('four'), findsWidgets);
      expect(find.textContaining('one'), findsNothing,
          reason: 'the cap is what keeps a long-running console from growing '
              'without bound');
    });
  });
}
