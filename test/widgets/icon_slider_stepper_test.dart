// `icon` (the size tokens and the asset forms), `slider`, `stepper` and
// `draggable`.
//
// `icon` is the one widget where the same property carries four different
// kinds of value — a name, a codepoint, a URL, an inline SVG — and each is a
// separate path. `slider` and `stepper` are the interaction halves that had
// never run: what they report is all the document ever learns.

import 'dart:convert';

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

  group('icon', () {
    testWidgets('a size token resolves to a scaled dp value', (tester) async {
      final sizes = <String, double>{};

      for (final token in const ['sm', 'md', 'lg', 'xl']) {
        await pump(tester, <String, dynamic>{
          'type': 'icon',
          'icon': 'home',
          'size': token,
        });
        sizes[token] =
            tester.widget<Icon>(find.byIcon(Icons.home)).size!;
      }

      expect(sizes['sm']! < sizes['md']!, isTrue);
      expect(sizes['md']! < sizes['lg']!, isTrue);
      expect(sizes['lg']! < sizes['xl']!, isTrue,
          reason: 'the tokens are a scale; collapsing them to one value makes '
              'every icon in a document the same size');
    });

    testWidgets('a numeric size is a dp value, not a token', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'icon',
        'icon': 'home',
        'size': 40,
      });

      expect(tester.widget<Icon>(find.byIcon(Icons.home)).size, 40);
    });

    testWidgets('an unknown token falls back to the default size',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'icon',
        'icon': 'home',
        'size': 'enormous',
      });

      expect(tester.widget<Icon>(find.byIcon(Icons.home)).size, 24);
    });

    testWidgets('an inline SVG is drawn as a vector, tinted', (tester) async {
      const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="8" '
          'height="8"><rect width="8" height="8" fill="#000"/></svg>';
      final uri = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

      await pump(tester, <String, dynamic>{
        'type': 'icon',
        'icon': uri,
        'size': 16,
        'color': '#FF0000',
      });

      expect(find.byType(Icon), findsNothing,
          reason: '§2.5 — an icon may be a vector asset; falling back to the '
              'named-icon path would draw a question mark');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bitmap URL is drawn as an image with a broken-image '
        'fallback', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await pump(tester, <String, dynamic>{
        'type': 'icon',
        'icon': 'https://example.com/star.png',
        'size': 16,
      });

      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).errorBuilder, isNotNull,
          reason: 'a URL that will not load must leave a visible placeholder '
              'rather than a hole in the row');
    });

    testWidgets('a bare name is still a name, not an asset path',
        (tester) async {
      await pump(tester, <String, dynamic>{'type': 'icon', 'icon': 'settings'});

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('slider', () {
    Map<String, dynamic> slider({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'slider',
          'binding': 'level',
          'min': 0,
          'max': 10,
          ...extra,
        };

    testWidgets('dragging writes the value back', (tester) async {
      stateManager.set('level', 0);
      await pump(tester, slider());

      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pumpAndSettle();

      expect(stateManager.get<num>('level'), greaterThan(0));
    });

    testWidgets('the start and end of a drag are each reported',
        (tester) async {
      stateManager.set('level', 2);
      await pump(tester, slider(extra: <String, dynamic>{
        'onChangeStart': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'started',
          'value': '{{event.value}}',
        },
        'onChangeEnd': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'ended',
          'value': '{{event.value}}',
        },
      }));

      final centre = tester.getCenter(find.byType(Slider));
      final gesture = await tester.startGesture(centre);
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('started'), isNotNull,
          reason: 'a document that pauses a live feed while the user is '
              'scrubbing needs to know the drag began');
      expect(stateManager.get('ended'), isNotNull,
          reason: 'and needs to know it finished, or the feed stays paused');
    });
  });

  group('stepper', () {
    Map<String, dynamic> stepper({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'stepper',
          'currentStep': 0,
          'steps': <dynamic>[
            <String, dynamic>{
              'title': 'Details',
              'content': <String, dynamic>{
                'type': 'text',
                'content': 'step one',
              },
            },
            <String, dynamic>{'title': 'Review'},
          ],
          ...extra,
        };

    testWidgets('draws its steps, and a step with no content still builds',
        (tester) async {
      await pump(tester, stepper());

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a step reports which one, and writes the binding',
        (tester) async {
      stateManager.set('step', 0);
      await pump(tester, stepper(extra: <String, dynamic>{
        'binding': 'step',
        'onStepTapped': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': '{{event.index}}',
        },
      }));

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      expect(stateManager.get('step'), 1);
      expect(stateManager.get('tapped'), 1,
          reason: 'a stepper that highlights its own row and reports nothing '
              'leaves the document showing the first step forever');
    });

    testWidgets('continue and cancel each reach their action', (tester) async {
      await pump(tester, stepper(extra: <String, dynamic>{
        'onStepContinue': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'continued',
          'value': true,
        },
        'onStepCancel': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'cancelled',
          'value': true,
        },
      }));

      await tester.tap(find.text('Continue').first);
      await tester.pumpAndSettle();
      expect(stateManager.get('continued'), isTrue);

      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();
      expect(stateManager.get('cancelled'), isTrue);
    });
  });

  group('draggable', () {
    Map<String, dynamic> draggable({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'draggable',
          'data': 'card-1',
          'child': <String, dynamic>{
            'type': 'container',
            'width': 60,
            'height': 60,
            'color': '#FF0000',
          },
          ...extra,
        };

    testWidgets('the lifecycle of a drag is reported', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          draggable(extra: <String, dynamic>{
            'onDragStarted': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'started',
              'value': true,
            },
            'onDragEnd': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'ended',
              'value': true,
            },
            'onDraggableCanceled': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'cancelled',
              'value': true,
            },
          }),
        ],
      });

      final from = tester.getCenter(find.byType(Container).first);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();

      expect(stateManager.get('started'), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('ended'), isTrue);
      expect(stateManager.get('cancelled'), isTrue,
          reason: 'a drop on nothing is a cancellation; a document that shows '
              'a "moving…" state has no other way to clear it');
    });

    testWidgets('a feedback and a while-dragging child are both built',
        (tester) async {
      await pump(tester, draggable(extra: <String, dynamic>{
        'feedback': <String, dynamic>{'type': 'text', 'content': 'dragging'},
        'childWhenDragging': <String, dynamic>{
          'type': 'text',
          'content': 'gap',
        },
      }));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();

      expect(find.text('dragging'), findsOneWidget,
          reason: 'the feedback is what the user sees under their finger');
      expect(find.text('gap'), findsOneWidget,
          reason: 'and the placeholder is what stops the list collapsing '
              'behind it');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a declared axis constrains the drag', (tester) async {
      await pump(tester, draggable(extra: <String, dynamic>{
        'axis': 'horizontal',
        'affinity': 'horizontal',
      }));

      final widget =
          tester.widget<Draggable<Object>>(find.byType(Draggable<Object>));
      expect(widget.axis, Axis.horizontal);
      expect(widget.affinity, Axis.horizontal);
    });

    testWidgets('an axis nobody defined falls back rather than throwing',
        (tester) async {
      await pump(tester, draggable(extra: <String, dynamic>{
        'axis': 'diagonal',
        'affinity': 'diagonal',
      }));

      final widget =
          tester.widget<Draggable<Object>>(find.byType(Draggable<Object>));
      expect(widget.axis, Axis.vertical);
      expect(widget.affinity, Axis.vertical);
    });
  });
}
