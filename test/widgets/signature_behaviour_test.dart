// `signature` — a drawing surface whose whole output is what the user drew.
//
// 70% covered, and the uncovered part was the drawing: the pan handlers that
// collect a stroke, the serialisation that puts it into state, the clear
// button, and the three events. A signature pad that accepts a drawing and
// writes nothing to its binding is the worst version of the silent failure
// this sweep is about — the user signs, the form submits, and the field is
// null.

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
        body: SizedBox(
          width: 300,
          height: 200,
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> pad({Map<String, dynamic> extra = const {}}) => {
        'type': 'signature',
        'binding': 'signed',
        ...extra,
      };

  /// Draws a stroke of several points — a single-point drag records nothing,
  /// which is the shape of a tap rather than a signature.
  ///
  /// Inside `runAsync` because what the pad publishes is an encoded PNG, and
  /// a real encode does not complete under the fake clock.
  Future<void> draw(WidgetTester tester,
      {Offset from = const Offset(60, 60)}) async {
    await tester.runAsync(() async {
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 5; i++) {
        await gesture.moveBy(const Offset(12, 6));
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();
  }

  group('drawing', () {
    testWidgets('a stroke is serialised into the binding', (tester) async {
      await pump(tester, pad());
      expect(stateManager.get('signed'), isNull);

      await draw(tester);

      final signature = stateManager.get<String>('signed');
      expect(signature, isNotNull,
          reason: 'the user signed; a null binding means the form submits '
              'without the signature and nobody finds out until it matters');
      expect(signature, startsWith('data:image/png;base64,'),
          reason: '§10.19 says the binding holds a base64 PNG or an SVG path — '
              'something a document can render and a server can store');
      expect(signature!.length, greaterThan(100));
    });

    testWidgets('a second stroke is added rather than replacing the first',
        (tester) async {
      await pump(tester, pad(extra: {
        'onSignatureEnd': {
          'type': 'state',
          'action': 'set',
          'binding': 'strokes',
          'value': '{{event.strokes}}',
        },
      }));

      await draw(tester);
      await draw(tester, from: const Offset(60, 120));

      expect(stateManager.get<List<dynamic>>('strokes'), hasLength(2),
          reason: 'a signature with a lifted pen is still one signature — '
              'keeping only the last stroke throws away most of it');
    });

    testWidgets('the strokes are painted', (tester) async {
      await pump(tester, pad());
      await draw(tester);

      expect(find.byType(CustomPaint), findsWidgets,
          reason: 'state without paint is a signature the user cannot see '
              'themselves make');
    });
  });

  group('the events', () {
    testWidgets('onSignatureStart fires as the pen goes down', (tester) async {
      await pump(tester, pad(extra: {
        'onSignatureStart': {
          'type': 'state',
          'action': 'set',
          'binding': 'started',
          'value': true,
        },
      }));

      final gesture = await tester.startGesture(const Offset(60, 60));
      await tester.pump();
      expect(stateManager.get('started'), isTrue,
          reason: 'a "clear" button that only appears once drawing starts is '
              'bound to this');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('onSignatureEnd carries the stroke count', (tester) async {
      await pump(tester, pad(extra: {
        'onSignatureEnd': {
          'type': 'state',
          'action': 'set',
          'binding': 'strokes',
          'value': '{{event.strokeCount}}',
        },
      }));

      await draw(tester);
      expect(stateManager.get('strokes'), 1);

      await draw(tester, from: const Offset(60, 120));
      expect(stateManager.get('strokes'), 2);
    });

    testWidgets('onClear fires and the binding is emptied', (tester) async {
      await pump(tester, pad(extra: {
        'onClear': {
          'type': 'state',
          'action': 'set',
          'binding': 'cleared',
          'value': true,
        },
      }));

      await draw(tester);
      expect(stateManager.get('signed'), isNotNull);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(stateManager.get('cleared'), isTrue);
      expect(stateManager.get('signed'), isNull,
          reason: 'clearing the drawing and leaving the old signature in '
              'state is how a rejected signature still gets submitted');
    });
  });

  group('the surface', () {
    testWidgets('the clear button appears only once there is something to '
        'clear, and can be turned off', (tester) async {
      // It is drawn behind `_hasSignature`, so an empty pad shows nothing —
      // a clear button on a blank surface is a control that does nothing.
      await pump(tester, pad());
      expect(find.byIcon(Icons.clear), findsNothing);

      await draw(tester);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await pump(tester, pad(extra: {'showClearButton': false}));
      await draw(tester);
      expect(find.byIcon(Icons.clear), findsNothing,
          reason: 'a document that hides the control keeps the drawing — the '
              'flag governs the affordance, not the capture');
      expect(stateManager.get('signed'), isNotNull);
    });

    testWidgets('the guide line can be turned off', (tester) async {
      await pump(tester, pad(extra: {'showGuide': false}));
      expect(tester.takeException(), isNull);

      await pump(tester, pad(extra: {'showGuide': true}));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the declared pen and background reach the painter',
        (tester) async {
      await pump(tester, pad(extra: {
        'penColor': '#FF0000',
        'penWidth': 6,
        'backgroundColor': '#00FF00',
        'borderColor': '#0000FF',
        'borderWidth': 4,
      }));
      await draw(tester);

      expect(tester.takeException(), isNull);
      expect(stateManager.get('signed'), isNotNull,
          reason: 'the styling must not change what is captured');
    });

    testWidgets('a pad with no binding still draws', (tester) async {
      await pump(tester, {'type': 'signature'});
      await draw(tester);
      expect(tester.takeException(), isNull,
          reason: 'a signature used only for a screenshot declares no binding, '
              'and must not fail for it');
    });
  });
}
